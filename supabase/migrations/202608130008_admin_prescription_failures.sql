-- Admin console: list prescription extraction failures (metadata only) for the
-- Usage dashboard. The real AI flow runs through the Supabase Edge Function, so
-- failures land in `prescriptions.error_code`, not in the key-manager's
-- `api_error_logs`. This RPC exposes those failures, secret-gated, so the Usage
-- page reflects reality. No image bytes are returned.

begin;

create or replace function public.admin_prescription_failures(
  p_secret text,
  p_limit integer default 200
)
returns table (
  id uuid,
  user_email text,
  display_name text,
  provider public.ai_provider_type,
  model text,
  error_code text,
  created_at timestamptz
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
    pr.provider,
    pr.model,
    pr.error_code,
    pr.created_at
  from public.prescriptions pr
  left join public.profiles p on p.id = pr.user_id
  left join auth.users u on u.id = pr.user_id
  where pr.status = 'failed'
    and pr.error_code is not null
  order by pr.created_at desc
  limit least(greatest(p_limit, 1), 500);
end;
$$;

grant execute on function public.admin_prescription_failures(text, integer)
  to anon, authenticated;

commit;
