
-- AI requests are rate-limited per authenticated workspace. Provider usage
-- remains unavailable until server-side secrets and model selection exist.
alter table public.shift_generation_jobs add column request_key text;
create unique index shift_generation_idempotency
  on public.shift_generation_jobs(workspace_id,request_key)
  where request_key is not null;
alter table public.shift_generation_jobs add constraint shift_generation_request_key_len
  check(request_key is null or length(request_key) between 8 and 150);
create index shift_generation_workspace_recent
  on public.shift_generation_jobs(workspace_id,created_at desc);

create or replace function public.shift_request_text_generation(
  p_request_key text, p_prompt text
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
    or p_prompt is null or length(trim(p_prompt)) not between 5 and 4000
  then raise exception 'Invalid generation request' using errcode='22023'; end if;
  select w.id into v_workspace from public.shift_workspaces w
    where w.owner_id=auth.uid() for update;
  if v_workspace is null then raise exception 'Workspace not found' using errcode='42501'; end if;

  select id into v_job from public.shift_generation_jobs
    where workspace_id=v_workspace and request_key=p_request_key;
  if found then return v_job; end if;

  select count(*) into v_minute_count from public.shift_generation_jobs
    where workspace_id=v_workspace and created_at>=now()-interval '1 minute';
  select count(*) into v_day_count from public.shift_generation_jobs
    where workspace_id=v_workspace and created_at>=now()-interval '24 hours';
  if v_minute_count>=3 or v_day_count>=30 then
    raise exception 'AI usage limit reached; retry later' using errcode='53300'; end if;

  insert into public.shift_generation_jobs(
    workspace_id,request_key,prompt,output_type,status
  ) values(v_workspace,p_request_key,p_prompt,'text','pending')
    returning id into v_job;
  return v_job;
end $f$;
revoke all on function public.shift_request_text_generation(text,text) from public,anon;
grant execute on function public.shift_request_text_generation(text,text) to authenticated;
comment on function public.shift_request_text_generation(text,text) is
  'Rate limited, idempotent text generation request. AI provider is configured only on the server.';
