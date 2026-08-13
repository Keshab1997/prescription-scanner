-- Phase 5: allow the authenticated owner to cancel an upload reservation
-- when client-side Storage upload fails before AI processing begins.

begin;

create or replace function public.cancel_prescription_upload(p_prescription_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.prescriptions
  where id = p_prescription_id
    and user_id = auth.uid()
    and status = 'uploaded'
    and processing_started_at is null;

  return found;
end;
$$;

revoke execute on function public.cancel_prescription_upload(uuid)
  from public, anon;
grant execute on function public.cancel_prescription_upload(uuid)
  to authenticated;

commit;
