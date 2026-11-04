-- Workspace scoped editable templates and read-only server-derived research sources.
create table public.shift_content_templates (
 id uuid primary key default gen_random_uuid(),
 workspace_id uuid not null references public.shift_workspaces(id) on delete cascade,
 title text not null check(length(trim(title)) between 1 and 160),
 body text not null default '',
 platform text not null default 'Any' check(platform in ('Any','Instagram','Facebook')),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
create index shift_content_templates_by_owner on public.shift_content_templates(workspace_id,created_at desc);
create trigger shift_content_templates_touch before update on public.shift_content_templates for each row execute function shift_private.touch_updated();
create table public.shift_research_sources (
 id uuid primary key default gen_random_uuid(),
 workspace_id uuid not null references public.shift_workspaces(id) on delete cascade,
 research_job_id uuid not null references public.shift_research_jobs(id) on delete cascade,
 url text not null check(url ~* '^https://[^[:space:]]+$'),
 title text not null default '', publisher text not null default '',
 published_at timestamptz, fetched_at timestamptz not null default now(),
 summary text not null default '',verified boolean not null default false,
 unique (research_job_id,url)
);
create index shift_sources_workspace on public.shift_research_sources(workspace_id,research_job_id);
alter table public.shift_content_templates enable row level security;
alter table public.shift_research_sources enable row level security;
revoke all on public.shift_content_templates,public.shift_research_sources from public,anon,authenticated;
grant select,delete on public.shift_content_templates to authenticated;
grant insert (workspace_id,title,body,platform) on public.shift_content_templates to authenticated;
grant update (title,body,platform) on public.shift_content_templates to authenticated;
create policy shift_templates_read on public.shift_content_templates for select to authenticated using(exists(select 1 from public.shift_workspaces w where w.id=workspace_id and w.owner_id=(select auth.uid())));
create policy shift_templates_insert on public.shift_content_templates for insert to authenticated with check(exists(select 1 from public.shift_workspaces w where w.id=workspace_id and w.owner_id=(select auth.uid())));
create policy shift_templates_update on public.shift_content_templates for update to authenticated using(exists(select 1 from public.shift_workspaces w where w.id=workspace_id and w.owner_id=(select auth.uid()))) with check(exists(select 1 from public.shift_workspaces w where w.id=workspace_id and w.owner_id=(select auth.uid())));
create policy shift_templates_delete on public.shift_content_templates for delete to authenticated using(exists(select 1 from public.shift_workspaces w where w.id=workspace_id and w.owner_id=(select auth.uid())));
grant select on public.shift_research_sources to authenticated;
create policy shift_sources_read on public.shift_research_sources for select to authenticated using(exists(select 1 from public.shift_workspaces w where w.id=workspace_id and w.owner_id=(select auth.uid())));
CREATE OR REPLACE FUNCTION shift_private.ensure_workspace_references()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare v_id uuid;
begin
  if TG_TABLE_NAME='shift_publish_jobs' then
    select workspace_id into v_id from public.shift_content_posts where id=new.post_id;
    if v_id is distinct from new.workspace_id then raise exception 'Publish post workspace mismatch' using errcode='23514'; end if;
    select workspace_id into v_id from public.shift_social_accounts where id=new.social_account_id;
    if v_id is distinct from new.workspace_id then raise exception 'Destination workspace mismatch' using errcode='23514'; end if;
  elsif TG_TABLE_NAME='shift_analytics_daily' then
    select workspace_id into v_id from public.shift_social_accounts where id=new.social_account_id;
    if v_id is distinct from new.workspace_id then raise exception 'Analytics workspace mismatch' using errcode='23514'; end if;
  elsif TG_TABLE_NAME='shift_approval_requests' then
    select workspace_id into v_id from public.shift_content_posts where id=new.post_id;
    if v_id is distinct from new.workspace_id then raise exception 'Approval workspace mismatch' using errcode='23514'; end if;
  elsif TG_TABLE_NAME='shift_research_sources' then
    select workspace_id into v_id from public.shift_research_jobs where id=new.research_job_id;
    if v_id is distinct from new.workspace_id then raise exception 'Source workspace mismatch' using errcode='23514'; end if;
  end if;
  return new;
end $function$
create trigger shift_publish_workspace_guard before insert or update of workspace_id,post_id,social_account_id on public.shift_publish_jobs for each row execute function shift_private.ensure_workspace_references();
create trigger shift_analytics_workspace_guard before insert or update of workspace_id,social_account_id on public.shift_analytics_daily for each row execute function shift_private.ensure_workspace_references();
create trigger shift_approval_workspace_guard before insert or update of workspace_id,post_id on public.shift_approval_requests for each row execute function shift_private.ensure_workspace_references();
create trigger shift_research_workspace_guard before insert or update of workspace_id,research_job_id on public.shift_research_sources for each row execute function shift_private.ensure_workspace_references();
comment on table public.shift_content_templates is 'Workspace-scoped reusable content templates, without publishing permission.';
comment on table public.shift_research_sources is 'Server-populated research provenance; no assumption that metadata is fact checked.';
