-- Admin console: list prescription records (metadata only, no image bytes).
-- Mirrors admin_list_users: secret-gated, security definer. Image storage paths
-- and raw bytes are intentionally NOT returned — prescriptions are private and
-- must stay audit-safe in the admin console.

begin;

create or replace function public.admin_list_prescriptions(
  p_secret text,
  p_status public.prescription_status default null,
  p_limit integer default 100
)
returns table (
  id uuid,
  user_email text,
  display_name text,
  status public.prescription_status,
  provider public.ai_provider_type,
  model text,
  overall_confidence numeric,
  error_code text,
  created_at timestamptz,
  processed_at timestamptz
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
    pr.id,
    u.email::text,
    p.display_name,
    pr.status,
    pr.provider,
    pr.model,
    pr.overall_confidence,
    pr.error_code,
    pr.created_at,
    pr.processed_at
  from public.prescriptions pr
  left join public.profiles p on p.id = pr.user_id
  left join auth.users u on u.id = pr.user_id
  where (p_status is null or pr.status = p_status)
  order by pr.created_at desc
  limit least(greatest(p_limit, 1), 500);
end;
$$;

grant execute on function public.admin_list_prescriptions(text, public.prescription_status, integer)
  to anon, authenticated;

commit;
