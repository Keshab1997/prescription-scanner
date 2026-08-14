-- Fix admin_list_users return type: auth.users.email is varchar(255), so cast
-- it to text to match the declared RETURN TABLE column type.

begin;

create or replace function public.admin_list_users(p_secret text)
returns table (
  id uuid,
  display_name text,
  email text,
  role public.app_role,
  status public.profile_status,
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
    p.id,
    p.display_name,
    u.email::text,
    p.role,
    p.status,
    p.created_at
  from public.profiles p
  left join auth.users u on u.id = p.id
  order by p.created_at desc;
end;
$$;

grant execute on function public.admin_list_users(text) to anon, authenticated;

commit;
