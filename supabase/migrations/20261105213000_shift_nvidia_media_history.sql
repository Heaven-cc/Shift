-- Online NVIDIA media history. Generated files remain in the private SHIFT Storage bucket.
create table if not exists public.shift_nvidia_media (
 id uuid primary key default gen_random_uuid(),
 workspace_id uuid not null references public.shift_workspaces(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade,
 model_slot text not null check(length(model_slot) between 3 and 40),
 model_id text not null check(length(model_id) between 1 and 250),
 media_type text not null check(media_type in ('image','image_edit','voice')),
 prompt text not null check(length(prompt) between 5 and 1300),
 storage_path text not null unique,
 mime_type text not null,
 created_at timestamptz not null default now()
);
create index if not exists shift_nvidia_media_recent
 on public.shift_nvidia_media(workspace_id,created_at desc);
alter table public.shift_nvidia_media enable row level security;
revoke all on public.shift_nvidia_media from public,anon,authenticated;
grant select on public.shift_nvidia_media to authenticated;
create policy shift_nvidia_media_owner_read on public.shift_nvidia_media
 for select to authenticated using (
 exists(select 1 from public.shift_workspaces w
 where w.id=workspace_id and w.owner_id=(select auth.uid()))
);
