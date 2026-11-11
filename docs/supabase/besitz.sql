-- FYF – Stand 15: Privater Besitzerwechsel ohne Werkstatt
-- Verkäufer startet die Übergabe (mit Code von Teil II) und bekommt einen Übergabe-Link (7 Tage gültig).
-- Käufer öffnet den Link und bestätigt. Danach gilt ein NEUER Teil-II-Code (nur der Käufer kennt ihn), die Geschichte bleibt erhalten.
-- Über den Vorbesitzer wird nichts gespeichert. Mehrfach ausführen schadet nicht.

alter table bike_passes add column if not exists claim_hash text;
alter table bike_passes add column if not exists claim_until timestamptz;

create or replace function fyf_owner_ok(k bike_passes, p_transfer text) returns boolean
language plpgsql security definer set search_path = public as $$
declare t text := upper(regexp_replace(coalesce(p_transfer, ''), '[^A-Za-z0-9]', '', 'g'));
begin
  if k.owner_fails >= 10 and k.owner_fail_at > now() - interval '1 day' then return false; end if;
  if k.transfer_hash is not null and encode(sha256(convert_to(t, 'UTF8')), 'hex') = k.transfer_hash then return true; end if;
  update bike_passes set owner_fails = case when owner_fail_at > now() - interval '1 day' then owner_fails + 1 else 1 end, owner_fail_at = now() where code = k.code;
  return false;
end $$;
revoke all on function fyf_owner_ok(bike_passes, text) from public, anon, authenticated;

-- Verkäufer: Übergabe starten
create or replace function pass_claim_start(p_code text, p_transfer text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare k bike_passes; c text := upper(regexp_replace(coalesce(p_code, ''), '[^A-Za-z0-9]', '', 'g')); tok text;
begin
  select * into k from bike_passes where code = c;
  if k.code is null or k.withdrawn_at is not null then return jsonb_build_object('error', 'FYF_NOT_FOUND'); end if;
  if k.owner_fails >= 10 and k.owner_fail_at > now() - interval '1 day' then return jsonb_build_object('error', 'FYF_RATE'); end if;
  if not fyf_owner_ok(k, p_transfer) then return jsonb_build_object('error', 'FYF_BAD_TRANSFER'); end if;
  if coalesce(k.owner_stolen, k.stolen) then return jsonb_build_object('error', 'FYF_STOLEN'); end if;
  tok := fyf_transfer_code();
  update bike_passes set claim_hash = encode(sha256(convert_to(tok, 'UTF8')), 'hex'), claim_until = now() + interval '7 days' where code = c;
  return jsonb_build_object('token', tok, 'until', now() + interval '7 days');
end $$;

-- Verkäufer: Übergabe abbrechen
create or replace function pass_claim_cancel(p_code text, p_transfer text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare k bike_passes; c text := upper(regexp_replace(coalesce(p_code, ''), '[^A-Za-z0-9]', '', 'g'));
begin
  select * into k from bike_passes where code = c;
  if k.code is null then return jsonb_build_object('error', 'FYF_NOT_FOUND'); end if;
  if not fyf_owner_ok(k, p_transfer) then return jsonb_build_object('error', 'FYF_BAD_TRANSFER'); end if;
  update bike_passes set claim_hash = null, claim_until = null where code = c;
  return jsonb_build_object('ok', true);
end $$;

-- Käufer: Übernahme bestätigen
create or replace function pass_claim(p_code text, p_token text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare k bike_passes; c text := upper(regexp_replace(coalesce(p_code, ''), '[^A-Za-z0-9]', '', 'g')); tk text := upper(regexp_replace(coalesce(p_token, ''), '[^A-Za-z0-9]', '', 'g')); t text;
begin
  select * into k from bike_passes where code = c;
  if k.code is null or k.withdrawn_at is not null then return jsonb_build_object('error', 'FYF_NOT_FOUND'); end if;
  if k.owner_fails >= 10 and k.owner_fail_at > now() - interval '1 day' then return jsonb_build_object('error', 'FYF_RATE'); end if;
  if k.claim_hash is null or k.claim_until < now() then return jsonb_build_object('error', 'FYF_CLAIM_EXPIRED'); end if;
  if encode(sha256(convert_to(tk, 'UTF8')), 'hex') <> k.claim_hash then
    update bike_passes set owner_fails = case when owner_fail_at > now() - interval '1 day' then owner_fails + 1 else 1 end, owner_fail_at = now() where code = c;
    return jsonb_build_object('error', 'FYF_BAD_TRANSFER');
  end if;
  if coalesce(k.owner_stolen, k.stolen) then return jsonb_build_object('error', 'FYF_STOLEN'); end if;
  t := fyf_transfer_code();
  update bike_passes set transfer_hash = encode(sha256(convert_to(t, 'UTF8')), 'hex'), claim_hash = null, claim_until = null,
    owner_no = coalesce(owner_no, 1) + 1, owner_since = current_date, owner_vis = null, owner_fails = 0, updated_at = now() where code = c;
  insert into bike_pass_entries(code, tenant_id, shop, kind, body, done_on, trust)
    values (c, null, 'FYF', 'Besitzerwechsel', 'Privater Besitzerwechsel – vom bisherigen Besitzer freigegeben und vom neuen Besitzer bestätigt', current_date, 'self');
  return jsonb_build_object('code', c, 'transfer', t, 'owner_no', coalesce(k.owner_no, 1) + 1);
end $$;

-- Käufer: Vorschau vor dem Bestätigen (nur Name des Rads, ob Link gültig)
create or replace function pass_claim_info(p_code text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare k bike_passes; c text := upper(regexp_replace(coalesce(p_code, ''), '[^A-Za-z0-9]', '', 'g'));
begin
  select * into k from bike_passes where code = c;
  if k.code is null or k.withdrawn_at is not null then return jsonb_build_object('error', 'FYF_NOT_FOUND'); end if;
  return jsonb_build_object('name', k.payload->'bike'->>'name', 'open', k.claim_hash is not null and k.claim_until > now(), 'until', k.claim_until, 'stolen', coalesce(k.owner_stolen, k.stolen), 'owner_no', k.owner_no);
end $$;

revoke all on function pass_claim_start(text, text) from public;
revoke all on function pass_claim_cancel(text, text) from public;
revoke all on function pass_claim(text, text) from public;
revoke all on function pass_claim_info(text) from public;
grant execute on function pass_claim_start(text, text), pass_claim_cancel(text, text), pass_claim(text, text), pass_claim_info(text) to anon, authenticated;
