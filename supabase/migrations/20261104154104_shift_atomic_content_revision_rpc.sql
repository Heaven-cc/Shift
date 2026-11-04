-- SHIFT atomic, owner-validated, idempotent draft versioning.
create table if not exists shift_private.content_save_operations (
  workspace_id uuid not null references public.shift_workspaces(id) on delete cascade,
  idempotency_key text not null check(length(idempotency_key) between 3 and 200),
  payload jsonb not null,
  post_id uuid not null references public.shift_content_posts(id) on delete cascade,
  version_number integer not null,
  created_at timestamptz not null default now(),
  primary key(workspace_id,idempotency_key)
);
revoke all on shift_private.content_save_operations from public,anon,authenticated;
CREATE OR REPLACE FUNCTION public.shift_save_content_revision(p_client_id text, p_expected_version integer, p_title text, p_caption text, p_platform text, p_headline text DEFAULT ''::text, p_hashtags text DEFAULT ''::text, p_details jsonb DEFAULT '{}'::jsonb, p_media_path text DEFAULT NULL::text, p_idempotency_key text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_workspace uuid;
  v_user uuid;
  v_post public.shift_content_posts%rowtype;
  v_previous shift_private.content_save_operations%rowtype;
  v_request jsonb;
  v_version integer;
begin
  v_user := auth.uid();
  if v_user is null then raise exception 'Sign-in required' using errcode='28000'; end if;
  if p_client_id is null or length(p_client_id) not between 1 and 150
    or p_idempotency_key is null or length(p_idempotency_key) not between 3 and 200
    or p_expected_version is null or p_expected_version<0
    or nullif(trim(p_caption),'') is null or length(p_caption)>20000
    or p_platform not in ('Instagram','Facebook')
    or length(coalesce(p_title,''))>300
    or jsonb_typeof(p_details) is distinct from 'object'
  then raise exception 'Invalid content payload' using errcode='22023'; end if;

  select w.id into v_workspace
    from public.shift_workspaces w
    where w.owner_id=v_user for update;
  if v_workspace is null then raise exception 'Workspace not found' using errcode='42501'; end if;

  if p_media_path is not null and not exists (
    select 1 from public.shift_media_assets m
    where m.workspace_id=v_workspace and m.storage_path=p_media_path
  ) then raise exception 'Image not owned by workspace' using errcode='42501'; end if;

  v_request := jsonb_build_object(
    'client_id',p_client_id, 'expected_version',p_expected_version,
    'title',coalesce(p_title,'Untitled post'), 'caption',p_caption,
    'platform',p_platform,'headline',coalesce(p_headline,''),
    'hashtags',coalesce(p_hashtags,''),'details',p_details,'media_path',p_media_path
  );

  select * into v_previous from shift_private.content_save_operations
    where workspace_id=v_workspace and idempotency_key=p_idempotency_key;
  if found then
    if v_previous.payload<>v_request then
      raise exception 'Idempotency key reused with different content' using errcode='23505';
    end if;
    return jsonb_build_object('post_id',v_previous.post_id,'version',v_previous.version_number,'replayed',true);
  end if;

  select * into v_post from public.shift_content_posts
    where workspace_id=v_workspace and client_id=p_client_id for update;
  if not found then
    if p_expected_version<>0 then raise exception 'Content version conflict' using errcode='40001'; end if;
    insert into public.shift_content_posts(workspace_id,client_id,title)
      values(v_workspace,p_client_id,coalesce(nullif(trim(p_title),''),'Untitled post'))
      returning * into v_post;
  end if;
  if v_post.current_version<>p_expected_version or v_post.status in ('publishing','published','scheduled') then
    raise exception 'Content version conflict' using errcode='40001'; end if;
  v_version:=p_expected_version+1;

  -- Existing BEFORE INSERT trigger advances the parent and revokes old approval.
  insert into public.shift_content_versions(
    post_id,version_number,caption,platform,headline,hashtags,media_path,details
  ) values (
    v_post.id,v_version,p_caption,p_platform,coalesce(p_headline,''),
    coalesce(p_hashtags,''),p_media_path,p_details
  );
  update public.shift_content_posts
    set title=coalesce(nullif(trim(p_title),''),'Untitled post')
    where id=v_post.id;
  insert into shift_private.content_save_operations(
    workspace_id,idempotency_key,payload,post_id,version_number
  ) values(v_workspace,p_idempotency_key,v_request,v_post.id,v_version);
  insert into public.shift_activity_events(workspace_id,event_type,summary,subject_id,details)
    values(v_workspace,'content_revision_saved','Cloud content revision saved',v_post.id,
      jsonb_build_object('version',v_version));
  return jsonb_build_object('post_id',v_post.id,'version',v_version,'replayed',false);
end $function$

CREATE OR REPLACE FUNCTION public.shift_update_content_plan(p_client_id text, p_expected_version integer, p_title text, p_planned_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_timezone text DEFAULT 'UTC'::text, p_note text DEFAULT ''::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare v_post public.shift_content_posts%rowtype;
begin
  if auth.uid() is null then raise exception 'Sign-in required' using errcode='28000'; end if;
  select p.* into v_post from public.shift_content_posts p
    join public.shift_workspaces w on w.id=p.workspace_id
    where w.owner_id=auth.uid() and p.client_id=p_client_id
    for update of p;
  if not found then raise exception 'Post not found' using errcode='42501'; end if;
  if v_post.current_version<>p_expected_version or v_post.status<>'draft' then
    raise exception 'Cannot edit a reviewed or stale draft' using errcode='40001'; end if;
  if length(coalesce(p_title,''))>300 or length(coalesce(p_note,''))>5000
    or length(coalesce(p_timezone,''))>100 then
    raise exception 'Invalid plan values' using errcode='22023'; end if;
  update public.shift_content_posts
    set title=coalesce(nullif(trim(p_title),''),'Untitled post'),
        planned_at=p_planned_at,planning_timezone=p_timezone,note=coalesce(p_note,'')
    where id=v_post.id;
end $function$

revoke all on function public.shift_save_content_revision(text,integer,text,text,text,text,text,jsonb,text,text) from public,anon;
revoke all on function public.shift_update_content_plan(text,integer,text,timestamptz,text,text) from public,anon;
grant execute on function public.shift_save_content_revision(text,integer,text,text,text,text,jsonb,text,text) to authenticated;
grant execute on function public.shift_update_content_plan(text,integer,text,timestamptz,text,text) to authenticated;
alter table public.shift_media_assets add constraint shift_media_storage_workspace_path check(split_part(storage_path,'/',2)=workspace_id::text);
comment on function public.shift_save_content_revision(text,integer,text,text,text,text,text,jsonb,text,text) is 'Owner-checked atomic version append with idempotency and optimistic locking; invalidates pending approval.';
