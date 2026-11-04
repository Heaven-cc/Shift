-- Research request IDs are opaque, client-generated idempotency strings, not necessarily UUIDs.
alter table public.shift_research_jobs
  alter column request_id type text using request_id::text;
alter table public.shift_research_jobs
  add constraint shift_research_request_id_length
  check(request_id is null or length(request_id) between 8 and 100);
