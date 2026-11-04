
-- Authenticated idempotent, rate limited search jobs. Only backend workers
-- can write results or sourced provenance rows.
alter table public.shift_research_jobs add column request_key text;
alter table public.shift_research_jobs add constraint shift_research_request_key_length
  check(request_key is null or length(request_key) between 8 and 150);
create unique index shift_research_job_dedupe
  on public.shift_research_jobs(workspace_id,request_key)
  where request_key is not null;
create index shift_research_jobs_recent
  on public.shift_research_jobs(workspace_id,created_at desc);

create or replace function public.shift_request_research(
  p_request_key text, p_query text
) returns uuid
language plpgsql security definer set search_path='' as $f$
declare
  v_workspace uuid;
  v_job uuid;
  v_minute_count integer;
  v_day_count integer;
begin
  if auth.uid() is null then raise exception 'Sign-in required' using errcode='28000'; end if;
  if p_request_key is null or length(p_request_key) not between 8 and 150
      or p_query is null or length(trim(p_query)) not between 3 and 600 then
    raise exception 'Invalid research query' using errcode='22023'; end if;
  select w.id into v_workspace from public.shift_workspaces w
    where w.owner_id=auth.uid() for update;
  if v_workspace is null then raise exception 'Workspace unavailable' using errcode='42501'; end if;
  select id into v_job from public.shift_research_jobs
    where workspace_id=v_workspace and request_key=p_request_key;
  if found then return v_job; end if;
  select count(*) into v_minute_count from public.shift_research_jobs
    where workspace_id=v_workspace and created_at>=now()-interval '1 minute';
  select count(*) into v_day_count from public.shift_research_jobs
    where workspace_id=v_workspace and created_at>=now()-interval '24 hours';
  if v_minute_count>=5 or v_day_count>=50 then
    raise exception 'Research quota exceeded' using errcode='53300'; end if;
  insert into public.shift_research_jobs(workspace_id,request_key,query,status)
    values(v_workspace,p_request_key,trim(p_query),'pending') returning id into v_job;
  return v_job;
end $f$;
revoke all on function public.shift_request_research(text,text) from public,anon;
grant execute on function public.shift_request_research(text,text) to authenticated;
