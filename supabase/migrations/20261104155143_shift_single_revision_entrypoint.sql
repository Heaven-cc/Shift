
-- The existing idempotent revision RPC is the supported write entrypoint.
-- Remove the redundant draft-saving RPC to keep one authoritative cloud revision API.
drop function if exists public.shift_save_draft(text,integer,text,text,text,text,text,jsonb,text,timestamptz,text,text);
comment on function public.shift_save_content_revision(text,integer,text,text,text,text,text,jsonb,text,text)
is 'Primary client revision API: atomic, workspace-checked, version-locked and idempotent; user media paths are checked.';
