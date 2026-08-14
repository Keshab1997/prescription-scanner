-- Operations overview stats for the admin dashboard. The key-pool counters on
-- admin_api_keys (usageCount/errorCount) are NOT updated by the real AI flow,
-- which runs through the Supabase Edge Function and lands in `prescriptions`.
-- This RPC returns real totals so the overview reflects actual usage.

begin;

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
