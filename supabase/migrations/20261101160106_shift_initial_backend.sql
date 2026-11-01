
-- SHIFT v1. Owned workspaces, immutable versions and review-gated content.
create schema if not exists shift_private;
revoke all on schema shift_private from public, anon, authenticated;

create table public.shift_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default '',
  avatar_path text,
  locale text not null default 'en',
  timezone text not null default 'UTC',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table public.shift_workspaces (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  name text not null default 'My workspace',
  onboarding_completed boolean not null default false,
  timezone text not null default 'UTC',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index shift_workspaces_one_per_owner on public.shift_workspaces(owner_id);
create table public.shift_brands (
  workspace_id uuid primary key references public.shift_workspaces(id) on delete cascade,
  name text not null default '',
  description text not null default '',
  audience text not null default '',
  brand_voice text not null default '',
  guidelines text not null default '',
  logo_path text,
  settings jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  constraint shift_brand_settings_object check (jsonb_typeof(settings) = 'object')
);
create table public.shift_preferences (
  workspace_id uuid primary key references public.shift_workspaces(id) on delete cascade,
  preferences jsonb not null default '{}'::jsonb,
  interests text[] not null default '{}',
  notification_preferences jsonb not null default '{"Approvals":true,"Failures":true,"Published posts":true,"Research":true,"Weekly reports":true}'::jsonb,
  updated_at timestamptz not null default now(),
  constraint shift_preferences_object check (jsonb_typeof(preferences)='object' and jsonb_typeof(notification_preferences)='object')
);
create table public.shift_automation_policies (
  workspace_id uuid primary key references public.shift_workspaces(id) on delete cascade,
  status text not null default 'disabled' check(status in ('disabled','paused','enabled')),
  approval_mode text not null default 'approval_required' check(approval_mode in ('manual','approval_required','trusted_autopilot')),
  daily_limit integer not null default 1 check (daily_limit between 0 and 100),
  weekly_limit integer not null default 5 check (weekly_limit between 0 and 500),
  blocked_topics text[] not null default '{}',
  allowed_topics text[] not null default '{}',
  allowed_weekdays integer[] not null default '{1,3,5}',
  posting_window_start time not null default '09:00',
  posting_window_end time not null default '18:00',
  requires_source boolean not null default true,
  allow_generated_images boolean not null default false,
  authorization_expires_at timestamptz,
  updated_at timestamptz not null default now(),
  constraint shift_automation_weekdays check (allowed_weekdays <@ array[0,1,2,3,4,5,6]::integer[])
);
create table public.shift_research_bookmarks (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.shift_workspaces(id) on delete cascade,
  topic text not null check(length(trim(topic)) between 1 and 500),
  url text not null check(url ~* '^https://[^[:space:]]+$'),
  publisher text not null default '',
  notes text not null default '',
  published_at timestamptz,
  saved_at timestamptz not null default now()
);
create table public.shift_content_posts (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.shift_workspaces(id) on delete cascade,
  title text not null default 'Untitled post',
  status text not null default 'draft' check(status in ('draft','pending_approval','approved','scheduled','publishing','published','failed','canceled')),
  current_version integer not null default 0 check(current_version >= 0),
  approved_version integer check(approved_version > 0),
  planned_at timestamptz,
  planning_timezone text not null default 'UTC',
  note text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint shift_approved_version_valid check(approved_version is null or approved_version <= current_version)
);
create index shift_posts_workspace_recent on public.shift_content_posts(workspace_id,updated_at desc);
create table public.shift_content_versions (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.shift_content_posts(id) on delete cascade,
  version_number integer not null check(version_number >= 1),
  caption text not null check(length(trim(caption)) > 0),
  platform text not null check(platform in ('Instagram','Facebook')),
  headline text not null default '',
  hashtags text not null default '',
  media_path text,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique(post_id,version_number),
  constraint shift_content_details_object check(jsonb_typeof(details)='object')
);
create table public.shift_approval_requests (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.shift_workspaces(id) on delete cascade,
  post_id uuid not null references public.shift_content_posts(id) on delete cascade,
  version_number integer not null check(version_number >= 1),
  requested_by uuid not null references auth.users(id),
  reviewed_by uuid references auth.users(id),
  state text not null default 'pending' check(state in ('pending','approved','rejected','superseded')),
  comment text not null default '',
  created_at timestamptz not null default now(),
  reviewed_at timestamptz
);
create unique index shift_one_pending_review on public.shift_approval_requests(post_id) where state='pending';
create table public.shift_social_accounts (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.shift_workspaces(id) on delete cascade,
  provider text not null check(provider in ('instagram','facebook')),
  provider_user_id text not null,
  display_name text not null default '',
  status text not null default 'disconnected' check(status in ('connected','expired','revoked','disconnected')),
  permissions text[] not null default '{}',
  token_expires_at timestamptz,
  connected_at timestamptz,
  created_at timestamptz not null default now(),
  unique(workspace_id, provider, provider_user_id)
);
comment on table public.shift_social_accounts is 'Public-safe metadata only; provider access tokens must never live in this exposed table.';
create table public.shift_media_assets (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.shift_workspaces(id) on delete cascade,
  storage_path text not null unique,
  mime_type text not null check(mime_type in ('image/jpeg','image/png','image/webp')),
  size_bytes bigint not null check(size_bytes between 1 and 10485760),
  created_at timestamptz not null default now()
);
create table public.shift_research_jobs (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.shift_workspaces(id) on delete cascade,
  query text not null,
  status text not null default 'pending' check(status in ('pending','running','completed','failed','canceled')),
  result jsonb,
  error_code text,
  created_at timestamptz not null default now(),
  completed_at timestamptz
);
create table public.shift_generation_jobs (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.shift_workspaces(id) on delete cascade,
  prompt text not null,
  output_type text not null check(output_type in ('text','image','text_image')),
  status text not null default 'pending' check(status in ('pending','running','completed','failed','canceled')),
  result jsonb,
  error_code text,
  created_at timestamptz not null default now(),
  completed_at timestamptz
);
create table public.shift_publish_jobs (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.shift_workspaces(id) on delete cascade,
  post_id uuid not null references public.shift_content_posts(id) on delete cascade,
  version_number integer not null,
  social_account_id uuid not null references public.shift_social_accounts(id),
  scheduled_for timestamptz not null,
  status text not null default 'queued' check(status in ('queued','claimed','completed','failed','canceled')),
  attempts integer not null default 0 check(attempts between 0 and 20),
  idempotency_key uuid not null unique default gen_random_uuid(),
  provider_post_id text,
  error_code text,
  lease_expires_at timestamptz,
  created_at timestamptz not null default now(),
  completed_at timestamptz,
  unique(post_id,version_number,social_account_id,scheduled_for)
);
create index shift_publish_jobs_due on public.shift_publish_jobs(scheduled_for) where status='queued';
create table public.shift_analytics_daily (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.shift_workspaces(id) on delete cascade,
  social_account_id uuid not null references public.shift_social_accounts(id) on delete cascade,
  day date not null,
  impressions bigint not null default 0 check(impressions>=0),
  reach bigint not null default 0 check(reach>=0),
  reactions bigint not null default 0 check(reactions>=0),
  comments bigint not null default 0 check(comments>=0),
  shares bigint not null default 0 check(shares>=0),
  clicks bigint not null default 0 check(clicks>=0),
  fetched_at timestamptz not null default now(),
  unique(social_account_id,day)
);
create table public.shift_notifications (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.shift_workspaces(id) on delete cascade,
  kind text not null,
  title text not null,
  body text not null default '',
  payload jsonb not null default '{}'::jsonb,
  read_at timestamptz,
  created_at timestamptz not null default now()
);
create table public.shift_activity_events (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.shift_workspaces(id) on delete cascade,
  event_type text not null,
  summary text not null,
  subject_id uuid,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

-- Updates and signup provisioning are server-controlled.
create function shift_private.touch_updated() returns trigger
language plpgsql set search_path='' as $f$
begin new.updated_at = now(); return new; end $f$;
create trigger shift_profiles_touch before update on public.shift_profiles for each row execute function shift_private.touch_updated();
create trigger shift_workspaces_touch before update on public.shift_workspaces for each row execute function shift_private.touch_updated();
create trigger shift_brands_touch before update on public.shift_brands for each row execute function shift_private.touch_updated();
create trigger shift_preferences_touch before update on public.shift_preferences for each row execute function shift_private.touch_updated();
create trigger shift_automation_touch before update on public.shift_automation_policies for each row execute function shift_private.touch_updated();
create trigger shift_posts_touch before update on public.shift_content_posts for each row execute function shift_private.touch_updated();

create function shift_private.provision_user() returns trigger
language plpgsql security definer set search_path='' as $f$
declare wid uuid;
begin
  insert into public.shift_profiles(user_id, display_name)
  values(new.id, left(coalesce(new.raw_user_meta_data->>'full_name',''),200));
  insert into public.shift_workspaces(owner_id) values(new.id) returning id into wid;
  insert into public.shift_brands(workspace_id) values(wid);
  insert into public.shift_preferences(workspace_id) values(wid);
  insert into public.shift_automation_policies(workspace_id) values(wid);
  return new;
end $f$;
create trigger shift_user_provision after insert on auth.users
for each row execute function shift_private.provision_user();

create function shift_private.advance_version() returns trigger
language plpgsql security definer set search_path='' as $f$
declare v_number integer; v_status text;
begin
  select current_version,status into v_number,v_status from public.shift_content_posts where id=new.post_id for update;
  if v_number is null or v_status in ('publishing','published') or new.version_number <> v_number + 1 then
    raise exception 'Invalid content version sequence or post state' using errcode='23514';
  end if;
  update public.shift_content_posts set current_version=new.version_number, approved_version=null,
    status='draft', planned_at=null where id=new.post_id;
  update public.shift_approval_requests set state='superseded'
    where post_id=new.post_id and state='pending';
  return new;
end $f$;
create trigger shift_version_insert before insert on public.shift_content_versions
for each row execute function shift_private.advance_version();

create function public.shift_submit_for_review(p_post_id uuid) returns uuid
language plpgsql security definer set search_path='' as $f$
declare v_post public.shift_content_posts%rowtype; v_review uuid; v_user uuid;
begin
  v_user := (select auth.uid());
  if v_user is null then raise exception 'Authentication required' using errcode='28000'; end if;
  select p.* into v_post from public.shift_content_posts p join public.shift_workspaces w
    on w.id=p.workspace_id where p.id=p_post_id and w.owner_id=v_user for update of p;
  if not found or v_post.current_version<1 or v_post.status<>'draft' then
    raise exception 'Draft unavailable for review' using errcode='23514';
  end if;
  insert into public.shift_approval_requests(workspace_id,post_id,version_number,requested_by)
    values(v_post.workspace_id,v_post.id,v_post.current_version,v_user) returning id into v_review;
  update public.shift_content_posts set status='pending_approval' where id=p_post_id;
  insert into public.shift_notifications(workspace_id,kind,title,body,payload)
    values(v_post.workspace_id,'approval','Post ready for review',v_post.title,
      jsonb_build_object('post_id',p_post_id,'approval_id',v_review));
  return v_review;
end $f$;

create function public.shift_decide_review(p_review_id uuid,p_approve boolean,p_comment text default '') returns void
language plpgsql security definer set search_path='' as $f$
declare v_post public.shift_content_posts%rowtype; v_request public.shift_approval_requests%rowtype; v_user uuid;
begin
  v_user := (select auth.uid());
  if v_user is null then raise exception 'Authentication required' using errcode='28000'; end if;
  select r.* into v_request from public.shift_approval_requests r
  join public.shift_workspaces w on w.id=r.workspace_id where r.id=p_review_id and w.owner_id=v_user for update of r;
  if not found or v_request.state<>'pending' then raise exception 'Review unavailable' using errcode='23514'; end if;
  select * into v_post from public.shift_content_posts where id=v_request.post_id for update;
  if v_post.status<>'pending_approval' or v_post.current_version<>v_request.version_number then
    raise exception 'Stale or changed draft requires a new review' using errcode='23514';
  end if;
  update public.shift_approval_requests set state=case when p_approve then 'approved' else 'rejected' end,
    reviewed_by=v_user,reviewed_at=now(),comment=left(coalesce(p_comment,''),2000) where id=p_review_id;
  update public.shift_content_posts set status=case when p_approve then 'approved' else 'draft' end,
    approved_version=case when p_approve then v_request.version_number else null end where id=v_post.id;
  insert into public.shift_activity_events(workspace_id,event_type,summary,subject_id)
    values(v_post.workspace_id,case when p_approve then 'review_approved' else 'review_rejected' end,
    case when p_approve then 'Content approved' else 'Content returned to draft' end,v_post.id);
end $f$;

revoke all on function public.shift_submit_for_review(uuid) from public, anon;
revoke all on function public.shift_decide_review(uuid,boolean,text) from public, anon;
grant execute on function public.shift_submit_for_review(uuid) to authenticated;
grant execute on function public.shift_decide_review(uuid,boolean,text) to authenticated;

-- RLS on all exposed tables, with explicit grants (no anonymous access).
alter table public.shift_profiles enable row level security;
revoke all on public.shift_profiles from anon, authenticated;
alter table public.shift_workspaces enable row level security;
revoke all on public.shift_workspaces from anon, authenticated;
alter table public.shift_brands enable row level security;
revoke all on public.shift_brands from anon, authenticated;
alter table public.shift_preferences enable row level security;
revoke all on public.shift_preferences from anon, authenticated;
alter table public.shift_automation_policies enable row level security;
revoke all on public.shift_automation_policies from anon, authenticated;
alter table public.shift_research_bookmarks enable row level security;
revoke all on public.shift_research_bookmarks from anon, authenticated;
alter table public.shift_content_posts enable row level security;
revoke all on public.shift_content_posts from anon, authenticated;
alter table public.shift_content_versions enable row level security;
revoke all on public.shift_content_versions from anon, authenticated;
alter table public.shift_approval_requests enable row level security;
revoke all on public.shift_approval_requests from anon, authenticated;
alter table public.shift_social_accounts enable row level security;
revoke all on public.shift_social_accounts from anon, authenticated;
alter table public.shift_media_assets enable row level security;
revoke all on public.shift_media_assets from anon, authenticated;
alter table public.shift_research_jobs enable row level security;
revoke all on public.shift_research_jobs from anon, authenticated;
alter table public.shift_generation_jobs enable row level security;
revoke all on public.shift_generation_jobs from anon, authenticated;
alter table public.shift_publish_jobs enable row level security;
revoke all on public.shift_publish_jobs from anon, authenticated;
alter table public.shift_analytics_daily enable row level security;
revoke all on public.shift_analytics_daily from anon, authenticated;
alter table public.shift_notifications enable row level security;
revoke all on public.shift_notifications from anon, authenticated;
alter table public.shift_activity_events enable row level security;
revoke all on public.shift_activity_events from anon, authenticated;
grant select on public.shift_profiles to authenticated;
create policy "shift_profiles_owner_read" on public.shift_profiles for select to authenticated using (user_id=(select auth.uid()));
grant select on public.shift_workspaces to authenticated;
create policy "shift_workspaces_owner_read" on public.shift_workspaces for select to authenticated using (owner_id=(select auth.uid()));
grant select on public.shift_brands to authenticated;
create policy "shift_brands_owner_read" on public.shift_brands for select to authenticated using (exists(select 1 from public.shift_workspaces w where w.id=workspace_id and w.owner_id=(select auth.uid())));
grant select on public.shift_preferences to authenticated;
create policy "shift_preferences_owner_read" on public.shift_preferences for select to authenticated using (exists(select 1 from public.shift_workspaces w where w.id=workspace_id and w.owner_id=(select auth.uid())));
grant select on public.shift_automation_policies to authenticated;
create policy "shift_automation_policies_owner_read" on public.shift_automation_policies for select to authenticated using (exists(select 1 from public.shift_workspaces w where w.id=workspace_id and w.owner_id=(select auth.uid())));
grant select on public.shift_research_bookmarks to authenticated;
create policy "shift_research_bookmarks_owner_read" on public.shift_research_bookmarks for select to authenticated using (exists(select 1 from public.shift_workspaces w where w.id=workspace_id and w.owner_id=(select auth.uid())));
grant select on public.shift_content_posts to authenticated;
create policy "shift_content_posts_owner_read" on public.shift_content_posts for select to authenticated using (exists(select 1 from public.shift_workspaces w where w.id=workspace_id and w.owner_id=(select auth.uid())));
grant select on public.shift_content_versions to authenticated;
create policy "shift_content_versions_owner_read" on public.shift_content_versions for select to authenticated using (exists(select 1 from public.shift_content_posts p join public.shift_workspaces w on w.id=p.workspace_id where p.id=post_id and w.owner_id=(select auth.uid())));
grant select on public.shift_approval_requests to authenticated;
create policy "shift_approval_requests_owner_read" on public.shift_approval_requests for select to authenticated using (exists(select 1 from public.shift_workspaces w where w.id=workspace_id and w.owner_id=(select auth.uid())));
grant select on public.shift_social_accounts to authenticated;
create policy "shift_social_accounts_owner_read" on public.shift_social_accounts for select to authenticated using (exists(select 1 from public.shift_workspaces w where w.id=workspace_id and w.owner_id=(select auth.uid())));
grant select on public.shift_media_assets to authenticated;
create policy "shift_media_assets_owner_read" on public.shift_media_assets for select to authenticated using (exists(select 1 from public.shift_workspaces w where w.id=workspace_id and w.owner_id=(select auth.uid())));
grant select on public.shift_research_jobs to authenticated;
create policy "shift_research_jobs_owner_read" on public.shift_research_jobs for select to authenticated using (exists(select 1 from public.shift_workspaces w where w.id=workspace_id and w.owner_id=(select auth.uid())));
grant select on public.shift_generation_jobs to authenticated;
create policy "shift_generation_jobs_owner_read" on public.shift_generation_jobs for select to authenticated using (exists(select 1 from public.shift_workspaces w where w.id=workspace_id and w.owner_id=(select auth.uid())));
grant select on public.shift_publish_jobs to authenticated;
create policy "shift_publish_jobs_owner_read" on public.shift_publish_jobs for select to authenticated using (exists(select 1 from public.shift_workspaces w where w.id=workspace_id and w.owner_id=(select auth.uid())));
grant select on public.shift_analytics_daily to authenticated;
create policy "shift_analytics_daily_owner_read" on public.shift_analytics_daily for select to authenticated using (exists(select 1 from public.shift_workspaces w where w.id=workspace_id and w.owner_id=(select auth.uid())));
grant select on public.shift_notifications to authenticated;
create policy "shift_notifications_owner_read" on public.shift_notifications for select to authenticated using (exists(select 1 from public.shift_workspaces w where w.id=workspace_id and w.owner_id=(select auth.uid())));
grant select on public.shift_activity_events to authenticated;
create policy "shift_activity_events_owner_read" on public.shift_activity_events for select to authenticated using (exists(select 1 from public.shift_workspaces w where w.id=workspace_id and w.owner_id=(select auth.uid())));
grant update (display_name,avatar_path,locale,timezone) on public.shift_profiles to authenticated;
create policy "shift_profiles_owner_update" on public.shift_profiles for update to authenticated using (user_id=(select auth.uid())) with check (user_id=(select auth.uid()));
grant update (name,onboarding_completed,timezone) on public.shift_workspaces to authenticated;
create policy "shift_workspaces_owner_update" on public.shift_workspaces for update to authenticated using (owner_id=(select auth.uid())) with check (owner_id=(select auth.uid()));
grant update (name,description,audience,brand_voice,guidelines,logo_path,settings) on public.shift_brands to authenticated;
create policy "shift_brands_owner_update" on public.shift_brands for update to authenticated using (exists(select 1 from public.shift_workspaces w where w.id=workspace_id and w.owner_id=(select auth.uid()))) with check (exists(select 1 from public.shift_workspaces w where w.id=workspace_id and w.owner_id=(select auth.uid())));
grant update (preferences,interests,notification_preferences) on public.shift_preferences to authenticated;
create policy "shift_preferences_owner_update" on public.shift_preferences for update to authenticated using (exists(select 1 from public.shift_workspaces w where w.id=workspace_id and w.owner_id=(select auth.uid()))) with check (exists(select 1 from public.shift_workspaces w where w.id=workspace_id and w.owner_id=(select auth.uid())));
grant update (approval_mode,daily_limit,weekly_limit,blocked_topics,allowed_topics,allowed_weekdays,posting_window_start,posting_window_end,requires_source,allow_generated_images,authorization_expires_at) on public.shift_automation_policies to authenticated;
create policy "shift_automation_policies_owner_update" on public.shift_automation_policies for update to authenticated using (exists(select 1 from public.shift_workspaces w where w.id=workspace_id and w.owner_id=(select auth.uid()))) with check (exists(select 1 from public.shift_workspaces w where w.id=workspace_id and w.owner_id=(select auth.uid())));
grant insert (workspace_id,topic,url,publisher,notes,published_at) on public.shift_research_bookmarks to authenticated;
create policy "shift_research_bookmarks_owner_insert" on public.shift_research_bookmarks for insert to authenticated with check (exists(select 1 from public.shift_workspaces w where w.id=workspace_id and w.owner_id=(select auth.uid())));
grant update (topic,url,publisher,notes,published_at) on public.shift_research_bookmarks to authenticated;
create policy "shift_research_bookmarks_owner_update" on public.shift_research_bookmarks for update to authenticated using (exists(select 1 from public.shift_workspaces w where w.id=workspace_id and w.owner_id=(select auth.uid()))) with check (exists(select 1 from public.shift_workspaces w where w.id=workspace_id and w.owner_id=(select auth.uid())));
grant delete on public.shift_research_bookmarks to authenticated;
create policy "shift_research_bookmarks_owner_delete" on public.shift_research_bookmarks for delete to authenticated using (exists(select 1 from public.shift_workspaces w where w.id=workspace_id and w.owner_id=(select auth.uid())));
grant insert (workspace_id,title,planned_at,planning_timezone,note) on public.shift_content_posts to authenticated;
create policy "shift_content_posts_owner_insert" on public.shift_content_posts for insert to authenticated with check (exists(select 1 from public.shift_workspaces w where w.id=workspace_id and w.owner_id=(select auth.uid())) and status='draft');
grant update (title,planned_at,planning_timezone,note) on public.shift_content_posts to authenticated;
create policy "shift_content_posts_owner_update" on public.shift_content_posts for update to authenticated using (exists(select 1 from public.shift_workspaces w where w.id=workspace_id and w.owner_id=(select auth.uid())) and status='draft') with check (exists(select 1 from public.shift_workspaces w where w.id=workspace_id and w.owner_id=(select auth.uid())) and status='draft');
grant delete on public.shift_content_posts to authenticated;
create policy "shift_content_posts_owner_delete" on public.shift_content_posts for delete to authenticated using (exists(select 1 from public.shift_workspaces w where w.id=workspace_id and w.owner_id=(select auth.uid())));
grant insert (post_id,version_number,caption,platform,headline,hashtags,media_path,details) on public.shift_content_versions to authenticated;
create policy "shift_content_versions_owner_insert" on public.shift_content_versions for insert to authenticated with check (exists(select 1 from public.shift_content_posts p join public.shift_workspaces w on w.id=p.workspace_id where p.id=post_id and w.owner_id=(select auth.uid())));
grant insert (workspace_id,storage_path,mime_type,size_bytes) on public.shift_media_assets to authenticated;
create policy "shift_media_assets_owner_insert" on public.shift_media_assets for insert to authenticated with check (exists(select 1 from public.shift_workspaces w where w.id=workspace_id and w.owner_id=(select auth.uid())) and split_part(storage_path,'/',1)=(select auth.uid())::text);
grant delete on public.shift_media_assets to authenticated;
create policy "shift_media_assets_owner_delete" on public.shift_media_assets for delete to authenticated using (exists(select 1 from public.shift_workspaces w where w.id=workspace_id and w.owner_id=(select auth.uid())));
grant update (read_at) on public.shift_notifications to authenticated;
create policy "shift_notifications_owner_update" on public.shift_notifications for update to authenticated using (exists(select 1 from public.shift_workspaces w where w.id=workspace_id and w.owner_id=(select auth.uid()))) with check (exists(select 1 from public.shift_workspaces w where w.id=workspace_id and w.owner_id=(select auth.uid())));

-- Private media bucket; each user's uploads live under <auth.uid()>/.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('shift-media','shift-media',false,10485760,array['image/jpeg','image/png','image/webp'])
on conflict(id) do nothing;
create policy shift_media_owner_read on storage.objects for select to authenticated
  using(bucket_id='shift-media' and split_part(name,'/',1)=(select auth.uid())::text);
create policy shift_media_owner_create on storage.objects for insert to authenticated
  with check(bucket_id='shift-media' and split_part(name,'/',1)=(select auth.uid())::text);
create policy shift_media_owner_modify on storage.objects for update to authenticated
  using(bucket_id='shift-media' and split_part(name,'/',1)=(select auth.uid())::text)
  with check(bucket_id='shift-media' and split_part(name,'/',1)=(select auth.uid())::text);
create policy shift_media_owner_delete on storage.objects for delete to authenticated
  using(bucket_id='shift-media' and split_part(name,'/',1)=(select auth.uid())::text);

comment on table public.shift_publish_jobs is 'Server-only. No worker is activated; no client write access exists.';
comment on table public.shift_automation_policies is 'Client cannot enable automation; status changes require trusted server workflow.';
