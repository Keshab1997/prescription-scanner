-- Phase 6: provider-attempt accounting for the Gemini processing function.

begin;

alter table public.ai_request_logs
  add column if not exists provider_attempts integer not null default 1
  check (provider_attempts between 1 and 10);

alter table public.ai_request_logs
  add column if not exists response_schema_version text
  check (response_schema_version is null or char_length(response_schema_version) <= 20);

create or replace function public.set_latest_ai_log_metadata(
  p_prescription_id uuid,
  p_provider_attempts integer,
  p_schema_version text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.ai_request_logs
  set
    provider_attempts = least(greatest(p_provider_attempts, 1), 10),
    response_schema_version = nullif(left(coalesce(p_schema_version, ''), 20), '')
  where id = (
    select id
    from public.ai_request_logs
    where prescription_id = p_prescription_id
    order by created_at desc
    limit 1
  );
end;
$$;

revoke execute on function public.set_latest_ai_log_metadata(uuid, integer, text)
  from public, anon, authenticated;
grant execute on function public.set_latest_ai_log_metadata(uuid, integer, text)
  to service_role;

commit;
