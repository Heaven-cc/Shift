
-- Secure, dormant publishing queue: not wired to any scheduler or Meta adapter.
-- No public client may insert, claim or complete a publish job directly.
create or replace function public.shift_schedule_approved_post(
  p_post_id uuid,p_version integer,p_account_id uuid,
  p_scheduled_for timestamptz,p_idempotency_key uuid
) returns uuid
language plpgsql security definer set search_path='' as $f$
declare
  v_post public.shift_content_posts%rowtype;
  v_account public.shift_social_accounts%rowtype;
  v_version public.shift_content_versions%rowtype;
  v_policy public.shift_automation_policies%rowtype;
  v_job uuid;
  v_count integer;
  v_user uuid;
begin
  v_user:=auth.uid();
  if v_user is null then raise exception 'Sign-in required' using errcode='28000'; end if;
  if p_post_id is null or p_version is null or p_account_id is null
      or p_scheduled_for is null or p_idempotency_key is null then
    raise exception 'Missing scheduling values' using errcode='22023';
  end if;
  select p.* into v_post from public.shift_content_posts p
    join public.shift_workspaces w on w.id=p.workspace_id
    where p.id=p_post_id and w.owner_id=v_user for update of p;
  if not found then raise exception 'Post unavailable' using errcode='42501'; end if;

  -- Idempotent replay of the same exact request, never change its destination.
  select id into v_job from public.shift_publish_jobs
    where idempotency_key=p_idempotency_key and post_id=p_post_id
      and version_number=p_version and social_account_id=p_account_id
      and scheduled_for=p_scheduled_for;
  if found then return v_job; end if;

  if v_post.status<>'approved'
    or v_post.current_version<>p_version
    or v_post.approved_version<>p_version
  then raise exception 'Exact approved revision required' using errcode='23514'; end if;
  if p_scheduled_for<now() or p_scheduled_for>now()+interval '365 days' then
    raise exception 'Choose a valid schedule in the next year' using errcode='22023'; end if;

  select * into v_account from public.shift_social_accounts
    where id=p_account_id and workspace_id=v_post.workspace_id and status='connected';
  if not found or v_account.token_expires_at is null
       or v_account.token_expires_at<now() then
    raise exception 'Connected, nonexpired destination required' using errcode='23514'; end if;
  select * into v_version from public.shift_content_versions
    where post_id=v_post.id and version_number=p_version;
  if not found then raise exception 'Approved revision not found' using errcode='23514'; end if;
  if lower(v_version.platform)<>v_account.provider then
    raise exception 'Post platform and destination mismatch' using errcode='23514'; end if;
  if v_account.provider='instagram' and v_version.media_path is null then
    raise exception 'Instagram requires eligible media' using errcode='23514'; end if;
  if v_version.media_path is not null and not exists (
    select 1 from public.shift_media_assets m where
      m.workspace_id=v_post.workspace_id and m.storage_path=v_version.media_path
  ) then raise exception 'Media ownership failed' using errcode='23514'; end if;
  select * into v_policy from public.shift_automation_policies
    where workspace_id=v_post.workspace_id;
  if not found then raise exception 'Posting limits missing' using errcode='23514'; end if;
  select count(*) into v_count from public.shift_publish_jobs
    where social_account_id=p_account_id
      and scheduled_for>=date_trunc('day',p_scheduled_for)
      and scheduled_for<date_trunc('day',p_scheduled_for)+interval '1 day'
      and status in ('queued','claimed','completed');
  if v_count >= v_policy.daily_limit then
    raise exception 'Daily posting cap reached' using errcode='23514'; end if;
  insert into public.shift_publish_jobs(
    workspace_id,post_id,version_number,social_account_id,scheduled_for,idempotency_key
  ) values(
    v_post.workspace_id,p_post_id,p_version,p_account_id,p_scheduled_for,p_idempotency_key
  ) returning id into v_job;
  update public.shift_content_posts set status='scheduled' where id=p_post_id;
  insert into public.shift_activity_events(workspace_id,event_type,summary,subject_id,details)
    values(v_post.workspace_id,'publish_scheduled','Approved post queued for publishing',p_post_id,
      jsonb_build_object('job_id',v_job,'version',p_version));
  return v_job;
end $f$;

create or replace function public.shift_cancel_scheduled_post(p_job_id uuid) returns boolean
language plpgsql security definer set search_path='' as $f$
declare v_post public.shift_content_posts%rowtype; v_job public.shift_publish_jobs%rowtype;
begin
  if auth.uid() is null then raise exception 'Sign-in required' using errcode='28000'; end if;
  select j.* into v_job from public.shift_publish_jobs j
    join public.shift_workspaces w on w.id=j.workspace_id
    where j.id=p_job_id and w.owner_id=auth.uid() for update of j;
  if not found then raise exception 'Schedule unavailable' using errcode='42501'; end if;
  if v_job.status<>'queued' then
    raise exception 'Job is no longer safely cancellable' using errcode='23514'; end if;
  update public.shift_publish_jobs set status='canceled' where id=p_job_id;
  update public.shift_content_posts set status='approved'
    where id=v_job.post_id and status='scheduled';
  insert into public.shift_activity_events(workspace_id,event_type,summary,subject_id,details)
    values(v_job.workspace_id,'publish_canceled','Publishing schedule canceled',v_job.post_id,
      jsonb_build_object('job_id',p_job_id));
  return true;
end $f$;

revoke all on function public.shift_schedule_approved_post(uuid,integer,uuid,timestamptz,uuid) from public,anon;
revoke all on function public.shift_cancel_scheduled_post(uuid) from public,anon;
grant execute on function public.shift_schedule_approved_post(uuid,integer,uuid,timestamptz,uuid) to authenticated;
grant execute on function public.shift_cancel_scheduled_post(uuid) to authenticated;

-- Future Edge Function worker may call the private claim function with
-- the service role only. It is *not* invoked by Cron in this release.
create or replace function shift_private.claim_publish_jobs(p_limit integer default 10)
returns setof public.shift_publish_jobs
language plpgsql security definer set search_path='' as $f$
begin
  if current_user<>'postgres' and (auth.role() is distinct from 'service_role') then
    raise exception 'Service role required' using errcode='42501';
  end if;
  return query
    with due as (
      select j.id from public.shift_publish_jobs j
      join public.shift_content_posts p on p.id=j.post_id
      join public.shift_social_accounts a on a.id=j.social_account_id
      where j.status='queued' and j.scheduled_for<=now()
        and j.attempts<5 and p.status='scheduled'
        and p.current_version=j.version_number
        and p.approved_version=j.version_number
        and a.status='connected'
        and (a.token_expires_at is null or a.token_expires_at>now())
      order by j.scheduled_for,j.created_at
      for update of j skip locked
      limit least(greatest(p_limit,0),50)
    )
    update public.shift_publish_jobs j
      set status='claimed',attempts=j.attempts+1,
          lease_expires_at=now()+interval '5 minutes'
      from due where j.id=due.id returning j.*;
end $f$;
revoke all on function shift_private.claim_publish_jobs(integer) from public,anon,authenticated;
grant execute on function shift_private.claim_publish_jobs(integer) to service_role;

comment on function public.shift_schedule_approved_post(uuid,integer,uuid,timestamptz,uuid)
is 'Dormant until Meta connection and publishing worker are operational. Owner, version, destination and daily cap enforced.';
