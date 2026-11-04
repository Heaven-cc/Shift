
-- Server job request identity, one request per workspace; no consumer write grants.
alter table public.shift_generation_jobs
  add column if not exists request_id uuid;
alter table public.shift_research_jobs
  add column if not exists request_id uuid;
create unique index if not exists shift_generation_request_unique
  on public.shift_generation_jobs(workspace_id,request_id) where request_id is not null;
create unique index if not exists shift_research_request_unique
  on public.shift_research_jobs(workspace_id,request_id) where request_id is not null;

-- Only trusted server-side workers may debit request allowances.
create or replace function public.shift_ai_allow_request(
  p_user uuid,p_workspace uuid,p_category text
) returns boolean
language plpgsql security definer set search_path='' as $f$
declare v_limit integer;
begin
  if auth.role() is distinct from 'service_role' and current_user<>'postgres' then
    raise exception 'Server worker only' using errcode='42501';
  end if;
  if not exists(select 1 from public.shift_workspaces
                where id=p_workspace and owner_id=p_user) then
    return false;
  end if;
  v_limit:=case p_category
    when 'text' then 20
    when 'research' then 20
    when 'image' then 5
    else 0
  end;
  if v_limit=0 then return false; end if;
  return shift_private.allow_request(p_user,p_category,v_limit);
end $f$;
revoke all on function public.shift_ai_allow_request(uuid,uuid,text)
  from public,anon,authenticated;
grant execute on function public.shift_ai_allow_request(uuid,uuid,text) to service_role;

-- Research provenance is never advertised as checked facts without verification.
comment on table public.shift_research_sources is
  'Provider-returned search result metadata, not verified article contents. Exact URL, fetched_at and provider origin must be kept.';
