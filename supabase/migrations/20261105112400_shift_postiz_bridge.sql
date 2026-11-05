-- SHIFT Postiz OAuth and scheduled publishing (server-controlled).
-- No hosted workers or automatic dispatch are enabled in SHIFT.
create table if not exists public.shift_postiz_oauth_states (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.shift_workspaces(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  state_hash text not null unique,
  expires_at timestamptz not null,
  consumed_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists shift_postiz_state_expiry on public.shift_postiz_oauth_states(expires_at);
create table if not exists public.shift_postiz_connections (
  workspace_id uuid primary key references public.shift_workspaces(id) on delete cascade,
  token_iv text not null,
  token_ciphertext text not null,
  organization_id text,
  connected_at timestamptz not null default now()
);
comment on table public.shift_postiz_connections is 'Encrypted tenant-scoped Postiz token; service role only. NEVER expose via user Data API grants.';
create table if not exists public.shift_postiz_schedules (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.shift_workspaces(id) on delete cascade,
  post_id uuid not null references public.shift_content_posts(id) on delete cascade,
  version_number integer not null check(version_number > 0),
  account_id text not null check(length(account_id) between 1 and 256),
  provider text not null check(length(provider) between 1 and 64),
  scheduled_for timestamptz not null,
  status text not null default 'submitting' check(status in ('submitting','scheduled','unknown','failed','canceled')),
  remote_ref text,
  error_code text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(workspace_id,post_id,version_number,account_id,scheduled_for)
);
create index if not exists shift_postiz_schedules_owner on public.shift_postiz_schedules(workspace_id,scheduled_for desc);
alter table public.shift_postiz_oauth_states enable row level security;
alter table public.shift_postiz_connections enable row level security;
alter table public.shift_postiz_schedules enable row level security;
revoke all on public.shift_postiz_oauth_states from public, anon, authenticated;
revoke all on public.shift_postiz_connections from public, anon, authenticated;
revoke all on public.shift_postiz_schedules from public, anon, authenticated;
-- Reading non-secret schedule metadata is safe, always scoped to workspace ownership.
grant select on public.shift_postiz_schedules to authenticated;
create policy "shift_postiz_schedule_owner_read" on public.shift_postiz_schedules
  for select to authenticated
  using (exists (
    select 1 from public.shift_workspaces w
    where w.id=workspace_id and w.owner_id=(select auth.uid())
  ));
-- No INSERT/UPDATE/DELETE grants for authenticated clients; only authenticated edge requests
-- validated against workspace ownership can drive mutations with a server-side credential.
