-- SHIFT AI-generated planning suggestions. These are NOT publishing jobs.
create table if not exists public.shift_ai_plan_items(
 id uuid primary key default gen_random_uuid(),
 workspace_id uuid not null references public.shift_workspaces(id) on delete cascade,
 generation_job_id uuid not null references public.shift_generation_jobs(id) on delete cascade,
 ordinal integer not null check(ordinal between 0 and 19),
 title text not null check(length(title) between 3 and 180),
 caption text not null check(length(caption) between 5 and 5000),
 platform text not null check(platform in
   ('Instagram','Facebook','TikTok','LinkedIn','X','Threads','YouTube','Bluesky','Pinterest')),
 planned_at timestamptz not null,
 state text not null default 'proposed' check(state in ('proposed','accepted')),
 post_id uuid references public.shift_content_posts(id) on delete set null,
 created_at timestamptz not null default now(),
 accepted_at timestamptz,
 unique(generation_job_id,ordinal)
);
create index if not exists shift_ai_plan_workspace_date
 on public.shift_ai_plan_items(workspace_id,planned_at);
alter table public.shift_ai_plan_items enable row level security;
revoke all on public.shift_ai_plan_items from public,anon,authenticated;
grant select on public.shift_ai_plan_items to authenticated;
create policy shift_ai_plan_items_owner_select on public.shift_ai_plan_items
 for select to authenticated using(
  exists(select 1 from public.shift_workspaces w
  where w.id=workspace_id and w.owner_id=(select auth.uid()))
 );

-- An explicit, authenticated action converts ONE suggestion to an unapproved
-- draft with a planning date, never a publication or scheduled publishing job.
create or replace function public.shift_accept_ai_plan(p_item_id uuid)
returns uuid language plpgsql security definer set search_path='' as $fn$
declare v_item public.shift_ai_plan_items%rowtype;
declare v_post uuid;
declare v_user uuid;
begin
 v_user:=auth.uid();
 if v_user is null then raise exception 'Sign in required' using errcode='28000'; end if;
 select i.* into v_item from public.shift_ai_plan_items i
 join public.shift_workspaces w on w.id=i.workspace_id
 where i.id=p_item_id and w.owner_id=v_user for update of i;
 if not found then raise exception 'Plan not found' using errcode='42501'; end if;
 if v_item.state='accepted' and v_item.post_id is not null then return v_item.post_id; end if;
 if v_item.planned_at <= now() then
  raise exception 'Past calendar suggestion cannot be accepted' using errcode='22023';
 end if;
 insert into public.shift_content_posts(workspace_id,title,status,client_id,planned_at,
   planning_timezone,note)
 values(v_item.workspace_id,v_item.title,'draft','ai-plan-'||v_item.id::text,
   v_item.planned_at,'UTC','AI-suggested planning date; not an automatic publication')
 returning id into v_post;
 insert into public.shift_content_versions(post_id,version_number,caption,platform,details)
 values(v_post,1,v_item.caption,v_item.platform,
   jsonb_build_object('ai_source_job',v_item.generation_job_id::text,
    'origin','shift-ai-plan','review_required',true));
 update public.shift_ai_plan_items set state='accepted',post_id=v_post,accepted_at=now()
 where id=v_item.id;
 insert into public.shift_activity_events(workspace_id,event_type,summary,subject_id,details)
 values(v_item.workspace_id,'ai_plan_accepted','AI calendar suggestion accepted as draft',
   v_post,jsonb_build_object('plan_item_id',v_item.id::text));
 return v_post;
end $fn$;
revoke all on function public.shift_accept_ai_plan(uuid) from public,anon,authenticated;
grant execute on function public.shift_accept_ai_plan(uuid) to authenticated;
