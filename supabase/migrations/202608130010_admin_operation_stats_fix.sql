-- Re-define admin_operation_stats with the corrected signature: drop the
-- key_pool_errors column because api_error_logs lives in Firebase Firestore, not
-- Postgres, so it cannot be counted here. Keep real prescription totals.

begin;

drop function if exists public.admin_operation_stats(text);

create or replace function public.admin_operation_stats(p_secret text)
returns table (
  total_extractions bigint,
  failed_extractions bigint
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (
    select 1 from public.admin_api_access a where a.secret = p_secret
  ) then
    raise exception 'INVALID_ADMIN_SECRET' using errcode = '28000';
  end if;

  return query
  select
    (select count(*) from public.prescriptions) as total_extractions,
    (select count(*) from public.prescriptions
       where status in ('failed', 'needs_review')) as failed_extractions;
end;
$$;

grant execute on function public.admin_operation_stats(text)
  to anon, authenticated;

commit;
