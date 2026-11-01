
-- Optimize owner queries and maintain immutable approved review snapshots.
create index shift_research_workspace_date on public.shift_research_bookmarks(workspace_id,saved_at desc);
create index shift_media_workspace on public.shift_media_assets(workspace_id);
create index shift_generation_workspace on public.shift_generation_jobs(workspace_id,created_at desc);
create index shift_research_jobs_workspace on public.shift_research_jobs(workspace_id,created_at desc);
create index shift_notifications_workspace on public.shift_notifications(workspace_id,created_at desc);
create index shift_activity_workspace on public.shift_activity_events(workspace_id,created_at desc);
create index shift_analytics_workspace on public.shift_analytics_daily(workspace_id,day desc);
create index shift_approvals_workspace on public.shift_approval_requests(workspace_id,created_at desc);
create index shift_approvals_requested_by on public.shift_approval_requests(requested_by);
create index shift_approvals_reviewed_by on public.shift_approval_requests(reviewed_by) where reviewed_by is not null;
create index shift_publish_jobs_workspace on public.shift_publish_jobs(workspace_id,scheduled_for);
create index shift_publish_jobs_social_account on public.shift_publish_jobs(social_account_id);
create index shift_post_versions_post on public.shift_content_versions(post_id,version_number desc);
create index shift_social_accounts_workspace on public.shift_social_accounts(workspace_id);
-- Untrusted cloud clients cannot modify or delete previously saved revisions.
revoke update,delete on public.shift_content_versions from authenticated;
-- Server transition functions remain owner-checked; explicitly limit invocation.
revoke execute on function public.shift_submit_for_review(uuid) from public,anon;
revoke execute on function public.shift_decide_review(uuid,boolean,text) from public,anon;
