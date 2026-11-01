-- Preserve existing device-side IDs while mapping to server UUIDs. All keys are workspace scoped.
alter table public.shift_content_posts add column client_id text;
create unique index shift_posts_workspace_client_id on public.shift_content_posts(workspace_id,client_id) where client_id is not null;
grant insert (client_id) on public.shift_content_posts to authenticated;
alter table public.shift_research_bookmarks add column client_id text;
create unique index shift_bookmarks_workspace_client_id on public.shift_research_bookmarks(workspace_id,client_id) where client_id is not null;
grant insert (client_id) on public.shift_research_bookmarks to authenticated;
-- Restrict client ownership fields, which remain protected by existing RLS policies.
alter table public.shift_content_posts add constraint shift_post_client_id_length check(client_id is null or length(client_id) between 1 and 150);
alter table public.shift_research_bookmarks add constraint shift_bookmark_client_id_length check(client_id is null or length(client_id) between 1 and 150);
