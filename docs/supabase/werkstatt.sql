-- FYF – Fit your Frame · Freie Werkstatt-/Fitting-Termine auf der öffentlichen Profilseite (Stand 9)
-- Die App rechnet freie Zeiten aus Öffnungszeiten, Kapazität und Terminen aus und stellt sie hier ein.
-- Kunden schicken darüber eine Terminanfrage mit fester Uhrzeit; der Laden bestätigt sie.

alter table dealer_profiles add column if not exists slots jsonb not null default '[]'::jsonb;
alter table dealer_profiles add column if not exists slots_at timestamptz;

create or replace function profile_slots(p_tenant uuid, p_slots jsonb) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not is_member(p_tenant) then raise exception 'FYF_DENIED'; end if;
  if p_slots is null or jsonb_typeof(p_slots) <> 'array' or jsonb_array_length(p_slots) > 31 or length(p_slots::text) > 8000 then raise exception 'FYF_BAD_DATA'; end if;
  update dealer_profiles set slots = p_slots, slots_at = now() where tenant_id = p_tenant;
end $$;

revoke all on function profile_slots(uuid, jsonb) from public, anon;
grant execute on function profile_slots(uuid, jsonb) to authenticated;
