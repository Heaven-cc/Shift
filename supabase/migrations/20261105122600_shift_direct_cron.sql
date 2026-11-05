-- SHIFT direct scheduler: independent of the preserved Postiz integration.
create extension if not exists pg_cron with schema pg_catalog;
create extension if not exists pg_net with schema extensions;

create table if not exists public.shift_direct_accounts (
 id uuid primary key default gen_random_uuid(),
 workspace_id uuid not null references public.shift_workspaces(id) on delete cascade,
 platform text not null check(platform='bluesky'),
 handle text not null check(length(handle) between 3 and 255),
 did text not null check(length(did) between 5 and 300),
 secret_id uuid not null,
 state text not null default 'connected' check(state in ('connected','disconnected','revoked')),
 connected_at timestamptz not null default now(),
 unique(workspace_id,platform,did)
);
create table if not exists public.shift_direct_jobs (
 id uuid primary key default gen_random_uuid(),
 workspace_id uuid not null references public.shift_workspaces(id) on delete cascade,
 post_id uuid not null references public.shift_content_posts(id) on delete cascade,
 version_number integer not null check(version_number>0),
 account_id uuid not null references public.shift_direct_accounts(id),
 scheduled_for timestamptz not null,
 state text not null default 'queued' check(state in ('queued','processing','published','failed','unknown','canceled')),
 remote_uri text,
 error_code text,
 claimed_at timestamptz,
 finished_at timestamptz,
 created_at timestamptz not null default now(),
 unique(workspace_id,post_id,version_number,account_id,scheduled_for)
);
create index if not exists shift_direct_jobs_due on public.shift_direct_jobs(scheduled_for) where state='queued';
alter table public.shift_direct_accounts enable row level security;
alter table public.shift_direct_jobs enable row level security;
revoke all on public.shift_direct_accounts, public.shift_direct_jobs from public,anon,authenticated;
-- Expose non-secret job metadata only. Direct accounts include ciphertext and
-- therefore have no client SELECT grant; the Edge Function returns redacted data.
grant select on public.shift_direct_jobs to authenticated;
create policy shift_direct_jobs_owner_read on public.shift_direct_jobs for select to authenticated using (
 exists(select 1 from public.shift_workspaces w where w.id=workspace_id and w.owner_id=(select auth.uid()))
);

-- Only service-role clients can validate cron calls and atomically claim jobs.
create or replace function public.shift_verify_direct_dispatch(p_token text)
returns boolean language sql security definer set search_path=''
as $$
 select exists(
   select 1 from vault.decrypted_secrets s
   where s.name='shift_direct_dispatch_token' and s.decrypted_secret=p_token
 );
$$;
revoke all on function public.shift_verify_direct_dispatch(text) from public,anon,authenticated;
grant execute on function public.shift_verify_direct_dispatch(text) to service_role;

create or replace function public.shift_claim_direct_due(p_limit integer default 5)
returns table(job_id uuid)
language sql security definer set search_path=''
as $$
 with picked as (
  select j.id from public.shift_direct_jobs j
  join public.shift_content_posts p on p.id=j.post_id and p.workspace_id=j.workspace_id
  join public.shift_direct_accounts a on a.id=j.account_id and a.workspace_id=j.workspace_id
  where j.state='queued' and j.scheduled_for<=now()
    and p.current_version=j.version_number and p.approved_version=j.version_number
    and p.status in ('approved','scheduled') and a.state='connected'
  order by j.scheduled_for,j.id
  for update of j skip locked
  limit least(greatest(p_limit,1),10)
 )
 update public.shift_direct_jobs j
 set state='processing',claimed_at=now()
 from picked where j.id=picked.id
 returning j.id;
$$;
revoke all on function public.shift_claim_direct_due(integer) from public,anon,authenticated;
grant execute on function public.shift_claim_direct_due(integer) to service_role;


-- Store user-provided app passwords in Supabase Vault, not public tables.
-- These RPCs are callable only by the service_role and are never exposed to
-- ordinary SHIFT accounts. Account ownership is checked by the Edge Function.
create or replace function public.shift_save_direct_account(
 p_workspace uuid, p_handle text, p_did text, p_app_password text
) returns uuid language plpgsql security definer set search_path='' as $fn$
declare v_id uuid; v_old uuid; v_vault uuid;
begin
 if p_workspace is null or p_app_password is null or length(p_app_password)<8 or length(p_app_password)>200 then
  raise exception 'Invalid connection input';
 end if;
 select a.secret_id into v_old from public.shift_direct_accounts a
  where a.workspace_id=p_workspace and a.platform='bluesky' and a.did=p_did for update;
 select vault.create_secret(p_app_password,'shift_bsky_'||gen_random_uuid()::text) into v_vault;
 insert into public.shift_direct_accounts(workspace_id,platform,handle,did,secret_id,state)
 values(p_workspace,'bluesky',p_handle,p_did,v_vault,'connected')
 on conflict (workspace_id,platform,did) do update
 set handle=excluded.handle,secret_id=excluded.secret_id,state='connected',connected_at=now()
 returning id into v_id;
 if v_old is not null then delete from vault.secrets where id=v_old; end if;
 return v_id;
end; $fn$;
revoke all on function public.shift_save_direct_account(uuid,text,text,text) from public,anon,authenticated;
grant execute on function public.shift_save_direct_account(uuid,text,text,text) to service_role;

create or replace function public.shift_get_direct_secret(p_id uuid)
returns text language sql security definer set search_path='' as $fn$
 select v.decrypted_secret from public.shift_direct_accounts a
 join vault.decrypted_secrets v on v.id=a.secret_id
 where a.id=p_id and a.state='connected' and a.platform='bluesky'
$fn$;
revoke all on function public.shift_get_direct_secret(uuid) from public,anon,authenticated;
grant execute on function public.shift_get_direct_secret(uuid) to service_role;

create or replace function public.shift_disconnect_direct_account(p_id uuid,p_workspace uuid)
returns void language plpgsql security definer set search_path='' as $fn$
declare v_secret uuid;
begin
 select secret_id into v_secret from public.shift_direct_accounts
 where id=p_id and workspace_id=p_workspace for update;
 if v_secret is null then raise exception 'Account not found'; end if;
 update public.shift_direct_accounts set state='disconnected' where id=p_id and workspace_id=p_workspace;
 delete from vault.secrets where id=v_secret;
end; $fn$;
revoke all on function public.shift_disconnect_direct_account(uuid,uuid) from public,anon,authenticated;
grant execute on function public.shift_disconnect_direct_account(uuid,uuid) to service_role;

-- Generate the one-time dispatcher token inside Postgres; never commit it or put
-- a service-role JWT in a Git-tracked cron command.
select vault.create_secret(encode(gen_random_bytes(32),'hex'),'shift_direct_dispatch_token');

create or replace function shift_private.direct_scheduler_tick()
returns void language plpgsql security definer set search_path=''
as $$
declare v_token text;
begin
 if not exists(select 1 from public.shift_direct_jobs j where j.state='queued' and j.scheduled_for<=now()) then
   return;
 end if;
 select s.decrypted_secret into v_token from vault.decrypted_secrets s
 where s.name='shift_direct_dispatch_token' limit 1;
 if v_token is null then raise exception 'SHIFT direct cron token missing'; end if;
 perform net.http_post(
   url := 'https://axgzpbtnqhuytlsanyto.supabase.co/functions/v1/shift-direct',
   headers := jsonb_build_object('Content-Type','application/json','x-shift-dispatch-token',v_token),
   body := '{"action":"dispatch"}'::jsonb,
   timeout_milliseconds := 15000
 );
end;
$$;
revoke all on function shift_private.direct_scheduler_tick() from public,anon,authenticated;
select cron.schedule('shift-direct-publish-every-minute','* * * * *',
 $$select shift_private.direct_scheduler_tick();$$);
