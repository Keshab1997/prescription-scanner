-- Phase 7: user-owned extraction feedback and safe history deletion.

begin;

create table if not exists public.prescription_feedback (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  prescription_id uuid not null references public.prescriptions(id) on delete cascade,
  category text not null check (
    category in ('incorrect_name', 'incorrect_details', 'missing_medicine', 'not_prescription', 'other')
  ),
  details text check (details is null or char_length(details) <= 1000),
  created_at timestamptz not null default now()
);

create index if not exists prescription_feedback_user_idx
  on public.prescription_feedback (user_id, created_at desc);
create index if not exists prescription_feedback_prescription_idx
  on public.prescription_feedback (prescription_id, created_at desc);

alter table public.prescription_feedback enable row level security;

revoke all on public.prescription_feedback from anon, authenticated;
grant select, insert on public.prescription_feedback to authenticated;

drop policy if exists prescription_feedback_select_own on public.prescription_feedback;
create policy prescription_feedback_select_own on public.prescription_feedback
  for select to authenticated
  using (user_id = auth.uid());

drop policy if exists prescription_feedback_insert_own on public.prescription_feedback;
create policy prescription_feedback_insert_own on public.prescription_feedback
  for insert to authenticated
  with check (
    user_id = auth.uid()
    and exists (
      select 1 from public.prescriptions p
      where p.id = prescription_id and p.user_id = auth.uid()
    )
  );

create or replace function public.delete_my_completed_prescription(
  p_prescription_id uuid
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.prescriptions
  where id = p_prescription_id
    and user_id = auth.uid()
    and status in ('completed', 'needs_review')
    and image_deleted_at is not null;
  return found;
end;
$$;

revoke execute on function public.delete_my_completed_prescription(uuid)
  from public, anon;
grant execute on function public.delete_my_completed_prescription(uuid)
  to authenticated;

commit;
