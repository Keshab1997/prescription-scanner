-- Admin console: list Supabase users from the Flutter web admin app.
-- The admin app authenticates with Firebase, NOT Supabase, so it cannot use
-- Supabase RLS/roles. Instead it calls a security-definer RPC with the anon
-- key plus a shared admin secret. The secret lives only in the database
-- (generated at apply time, never committed) and is compared inside the
-- function, so the public anon key alone cannot read the user directory.

begin;

-- Single-row store for the admin API secret. The value is generated here with
-- gen_random_uuid() so it is NOT present in this file / git history.
create table if not exists public.admin_api_access (
  id smallint primary key default 1 check (id = 1),
  secret text not null,
  updated_at timestamptz not null default now()
);

insert into public.admin_api_access (id, secret)
values (1, gen_random_uuid()::text)
on conflict (id) do nothing;

-- Returns the user directory joined with auth email. SECURITY DEFINER so it
-- runs with the function owner's privileges (bypassing per-row RLS), but only
-- when the supplied secret matches the stored one.
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
    u.email,
    p.role,
    p.status,
    p.created_at
  from public.profiles p
  left join auth.users u on u.id = p.id
  order by p.created_at desc;
end;
$$;

-- Only the anon/authenticated roles may invoke it; the secret check inside
-- is what actually gates access.
revoke all on function public.admin_list_users(text) from public, anon, authenticated;
grant execute on function public.admin_list_users(text) to anon, authenticated;

commit;
