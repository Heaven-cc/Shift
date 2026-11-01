-- Only unreviewed drafts may be deleted directly from the mobile client.
drop policy if exists shift_content_posts_owner_delete on public.shift_content_posts;
create policy shift_content_posts_owner_delete on public.shift_content_posts for delete to authenticated
using (
  status='draft' and exists(
    select 1 from public.shift_workspaces w
    where w.id=workspace_id and w.owner_id=(select auth.uid())
  )
);
