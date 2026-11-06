-- NVIDIA Nemotron 3.5 Embed 1B: semantic index isolated to SHIFT workspaces.
-- NVIDIA supports 1024-dimensional output for this 2048-dimension model.
create extension if not exists vector with schema extensions;

create table if not exists public.shift_knowledge_embeddings (
 id uuid primary key default gen_random_uuid(),
 workspace_id uuid not null references public.shift_workspaces(id) on delete cascade,
 source_type text not null check (source_type in ('bookmark','research')),
 source_id uuid not null,
 model_id text not null check(length(model_id) between 1 and 180),
 title text not null check(length(title) between 1 and 400),
 snippet text not null check(length(snippet) between 1 and 5000),
 source_url text not null check(length(source_url) between 1 and 2000),
 content_hash text not null check(length(content_hash)=64),
 embedding extensions.vector(1024) not null,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 unique(workspace_id,source_type,source_id,model_id)
);
create index if not exists shift_knowledge_workspace_model
 on public.shift_knowledge_embeddings(workspace_id,model_id);
create index if not exists shift_knowledge_vector_cosine
 on public.shift_knowledge_embeddings using hnsw (embedding extensions.vector_cosine_ops);
alter table public.shift_knowledge_embeddings enable row level security;
revoke all on public.shift_knowledge_embeddings from public,anon,authenticated;
-- The backend authenticates with Supabase Auth, validates the workspace owner,
-- then accesses the index via its service-role connection. No client write grants.

create or replace function public.shift_match_knowledge(
 p_workspace uuid,
 p_model text,
 p_query_text text,
 p_limit integer default 8
)
returns table (
 source_type text,
 source_id uuid,
 title text,
 snippet text,
 source_url text,
 similarity double precision
)
language sql
stable
security invoker
set search_path = ''
as $body$
 select k.source_type,k.source_id,k.title,k.snippet,k.source_url,
  (1 - (k.embedding <=> (p_query_text::extensions.vector(1024))))::double precision as similarity
 from public.shift_knowledge_embeddings k
 where k.workspace_id=p_workspace and k.model_id=p_model
 order by k.embedding <=> (p_query_text::extensions.vector(1024))
 limit least(greatest(coalesce(p_limit,8),1),12)
$body$;
revoke all on function public.shift_match_knowledge(uuid,text,text,integer) from public,anon,authenticated;
grant execute on function public.shift_match_knowledge(uuid,text,text,integer) to service_role;
