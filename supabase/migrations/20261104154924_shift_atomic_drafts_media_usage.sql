
-- Atomic, owner-checked cloud draft editing (in addition to RLS).
-- RPC caller supplies expected version to prevent lost updates between devices.
create or replace function public.shift_save_draft(
  p_client_id text,
  p_expected_version integer,
  p_title text,
  p_caption text,
  p_platform text default 'Instagram',
  p_headline text default '',
  p_hashtags text default '',
  p_details jsonb default '{}'::jsonb,
  p_media_path text default null,
  p_planned_at timestamptz default null,
  p_planning_timezone text default 'UTC',
  p_note text default ''
) returns table(post_id uuid, saved_version integer)
language plpgsql security definer set search_path = ''
as $f$
declare
  v_user uuid := (select auth.uid());
  v_workspace uuid;
  v_post public.shift_content_posts%rowtype;
  v_version integer;
begin
  if v_user is null then raise exception 'Authentication required' using errcode='28000'; end if;
  if p_client_id is null or length(p_client_id) not between 1 and 150
    or p_title is null or length(trim(p_title)) not between 1 and 500
    or p_caption is null or length(trim(p_caption)) not between 1 and 12000
    or p_platform not in ('Instagram','Facebook')
    or p_expected_version is null or p_expected_version < 0
    or p_details is null or jsonb_typeof(p_details) <> 'object'
    or length(coalesce(p_headline,'')) > 1000
    or length(coalesce(p_hashtags,'')) > 3000
    or length(coalesce(p_note,'')) > 5000
    or length(coalesce(p_planning_timezone,'')) not between 1 and 100
  then raise exception 'Invalid draft payload' using errcode='22023'; end if;

  select w.id into v_workspace from public.shift_workspaces w where w.owner_id=v_user;
  if v_workspace is null then raise exception 'Workspace not found' using errcode='42501'; end if;
  if p_media_path is not null and not exists(
    select 1 from public.shift_media_assets a
    where a.workspace_id=v_workspace and a.storage_path=p_media_path
      and split_part(a.storage_path,'/',1)=v_user::text
  ) then raise exception 'Media asset does not belong to workspace' using errcode='42501'; end if;

  -- Serialize draft operations for this workspace, including first insert.
  perform pg_advisory_xact_lock(hashtextextended(v_workspace::text || ':' || p_client_id, 0));
  select * into v_post from public.shift_content_posts p
    where p.workspace_id=v_workspace and p.client_id=p_client_id for update;

  if not found then
    if p_expected_version <> 0 then
      raise exception 'Draft was changed or deleted elsewhere' using errcode='40001';
    end if;
    insert into public.shift_content_posts(
      workspace_id, client_id, title, note, planning_timezone, planned_at
    ) values(
      v_workspace, p_client_id, p_title, coalesce(p_note,''),
      p_planning_timezone, p_planned_at
    ) returning * into v_post;
  else
    if v_post.current_version <> p_expected_version then
      -- Idempotent success for a retried request that already wrote the exact next version.
      if v_post.current_version = p_expected_version + 1
        and exists (
          select 1 from public.shift_content_versions v
          where v.post_id=v_post.id and v.version_number=v_post.current_version
          and v.caption=p_caption and v.platform=p_platform
          and v.headline=coalesce(p_headline,'')
          and v.hashtags=coalesce(p_hashtags,'')
          and v.details=p_details and v.media_path is not distinct from p_media_path
        )
      then
        post_id:=v_post.id; saved_version:=v_post.current_version; return next; return;
      end if;
      raise exception 'Draft was updated on another device; refresh before saving' using errcode='40001';
    end if;
    if v_post.status in ('publishing','published','scheduled','canceled') then
      raise exception 'This post cannot be edited in its current state' using errcode='23514';
    end if;
  end if;

  v_version:=v_post.current_version+1;
  -- Existing insert trigger clears any pending review and restores draft status.
  insert into public.shift_content_versions(
    post_id, version_number, caption, platform, headline, hashtags, details, media_path
  ) values (
    v_post.id, v_version, trim(p_caption), p_platform, coalesce(p_headline,''),
    coalesce(p_hashtags,''), p_details, p_media_path
  );
  update public.shift_content_posts set title=p_title, note=coalesce(p_note,''),
    planning_timezone=p_planning_timezone, planned_at=p_planned_at
    where id=v_post.id;
  post_id:=v_post.id; saved_version:=v_version;
  return next;
end $f$;

revoke all on function public.shift_save_draft(text,integer,text,text,text,text,text,jsonb,text,timestamptz,text,text) from public, anon;
grant execute on function public.shift_save_draft(text,integer,text,text,text,text,text,jsonb,text,timestamptz,text,text) to authenticated;

-- A constrained media-reference lookup: media rows must match the actual workspace subfolder.
drop policy if exists shift_media_assets_owner_insert on public.shift_media_assets;
create policy shift_media_assets_owner_insert on public.shift_media_assets for insert to authenticated
with check (
  split_part(storage_path,'/',1)=(select auth.uid())::text
  and split_part(storage_path,'/',2)=workspace_id::text
  and exists(select 1 from public.shift_workspaces w
             where w.id=workspace_id and w.owner_id=(select auth.uid()))
);

-- Stable, auditable counters for API usage (no provider keys or raw prompts).
create table public.shift_usage_daily(
  workspace_id uuid not null references public.shift_workspaces(id) on delete cascade,
  usage_day date not null,
  category text not null check(category in ('text','image','research','publish')),
  total_requests integer not null default 0 check(total_requests>=0),
  total_units bigint not null default 0 check(total_units>=0),
  updated_at timestamptz not null default now(),
  primary key(workspace_id,usage_day,category)
);
alter table public.shift_usage_daily enable row level security;
revoke all on public.shift_usage_daily from anon,authenticated;
grant select on public.shift_usage_daily to authenticated;
create policy shift_usage_daily_read on public.shift_usage_daily for select to authenticated
using(exists(select 1 from public.shift_workspaces w
  where w.id=workspace_id and w.owner_id=(select auth.uid())));

-- Rate-limit accounting and a server-side, fail-closed allowance function.
create table shift_private.usage_counters(
  user_id uuid not null,
  category text not null,
  bucket_start timestamptz not null,
  requests integer not null default 0 check(requests>=0),
  primary key(user_id,category,bucket_start)
);
revoke all on shift_private.usage_counters from public,anon,authenticated;
create or replace function shift_private.allow_request(p_user uuid,p_category text,p_limit integer)
returns boolean language plpgsql security definer set search_path='' as $f$
declare v_count integer;
begin
  if p_category not in ('text','image','research','publish')
    or p_limit not between 1 and 10000 then return false; end if;
  insert into shift_private.usage_counters(user_id,category,bucket_start,requests)
  values(p_user,p_category,date_trunc('hour',now()),1)
  on conflict(user_id,category,bucket_start) do update
     set requests=shift_private.usage_counters.requests+1
  returning requests into v_count;
  return v_count<=p_limit;
end $f$;
revoke all on function shift_private.allow_request(uuid,text,integer) from public,anon,authenticated;

-- Operational indexes to support audit and API pagination.
create index if not exists shift_versions_created on public.shift_content_versions(post_id,created_at desc);
create index if not exists shift_notifications_unread on public.shift_notifications(workspace_id,created_at desc) where read_at is null;
create index if not exists shift_activity_event_type on public.shift_activity_events(workspace_id,event_type,created_at desc);
