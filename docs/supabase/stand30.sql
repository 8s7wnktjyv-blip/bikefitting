-- FYF – Stand 30 (22.11.2026): Eine Rahmennummer = ein Fahrradpass (Wunsch Dominik 22.11.2026).
-- Bisher: Selbst-Registrierung lehnte doppelte Rahmennummern schon ab. Neu:
-- * Auch Läden (pass_publish) können für eine Rahmennummer, die schon einen aktiven Pass hat, keinen zweiten Pass anlegen
--   und keinem Pass eine Rahmennummer geben, die schon ein anderer aktiver Pass hat (Fehler FYF_FRAME_EXISTS).
--   Der Weg für den neuen Laden bleibt die Übernahme mit der Karte „Teil II“.
-- * Zwei gleichzeitige Anmeldungen derselben Nummer können nicht beide durchrutschen (Sperre je Rahmennummer).
-- * Zusätzlich eine eindeutige Datenbank-Regel – aber nur, wenn es heute keine Doppelten gibt. Gibt es welche,
--   bleibt alles wie es ist (keine Daten werden gelöscht oder geändert), die Funktionen verhindern neue Doppelte trotzdem.
-- Nur Funktionen ersetzt, keine Daten geändert.

create or replace function pass_publish(p_tenant uuid, p_bike text, p_payload jsonb, p_visibility text, p_stolen boolean) returns text
language plpgsql security definer set search_path = public as $$
declare c text; fh text; pl jsonb;
begin
  if not is_member(p_tenant) then raise exception 'FYF_DENIED'; end if;
  if p_payload is null or jsonb_typeof(p_payload) <> 'object' or length(p_payload::text) > 40000 or length(coalesce(p_bike, '')) not between 1 and 60 then raise exception 'FYF_BAD_DATA'; end if;
  if p_visibility not in ('public','shops') then raise exception 'FYF_BAD_DATA'; end if;
  if exists (select 1 from bike_pass_moved where tenant_id = p_tenant and bike_ref = p_bike) then raise exception 'FYF_PASS_MOVED'; end if;
  fh := nullif(p_payload->>'fh', ''); if fh is not null and fh !~ '^[0-9a-f]{64}$' then raise exception 'FYF_BAD_DATA'; end if; pl := p_payload - 'fh';
  if fh is not null then perform pg_advisory_xact_lock(hashtext('fyf_fh:' || fh)); end if;
  select code into c from bike_passes where tenant_id = p_tenant and bike_ref = p_bike;
  if fh is not null and exists (select 1 from bike_passes where frame_hash = fh and withdrawn_at is null and code is distinct from c) then raise exception 'FYF_FRAME_EXISTS'; end if;
  if c is null then
    if (select count(*) from bike_passes where tenant_id = p_tenant and created_at > now() - interval '1 day') >= 200 then raise exception 'FYF_RATE'; end if;
    c := fyf_pass_code();
    insert into bike_passes(code, tenant_id, bike_ref, visibility, stolen, payload, frame_hash) values (c, p_tenant, p_bike, p_visibility, coalesce(p_stolen, false), pl, fh);
    perform fyf_audit(p_tenant, 'pass_create', jsonb_build_object('bike', p_bike, 'code', c));
  else
    update bike_passes set payload = pl, frame_hash = coalesce(fh, frame_hash),
      owner_vis = case when p_visibility is distinct from visibility then null else owner_vis end,
      owner_stolen = case when coalesce(p_stolen, false) is distinct from stolen then null else owner_stolen end,
      visibility = p_visibility, stolen = coalesce(p_stolen, false), withdrawn_at = null, updated_at = now() where code = c;
  end if;
  return c;
end $$;

create or replace function pass_register(p_payload jsonb, p_fh text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare c text; t text;
begin
  if p_payload is null or jsonb_typeof(p_payload) <> 'object' or length(p_payload::text) > 6000 or length(coalesce(p_payload->'bike'->>'name', '')) not between 2 and 120 then return jsonb_build_object('error', 'FYF_BAD_DATA'); end if;
  if coalesce(p_fh, '') !~ '^[0-9a-f]{64}$' then return jsonb_build_object('error', 'FYF_BAD_DATA'); end if;
  perform pg_advisory_xact_lock(hashtext('fyf_fh:' || p_fh));
  if exists (select 1 from bike_passes where frame_hash = p_fh) then return jsonb_build_object('error', 'FYF_FRAME_EXISTS'); end if;
  if (select count(*) from bike_passes where tenant_id is null and created_at > now() - interval '1 day') >= 300 then return jsonb_build_object('error', 'FYF_RATE'); end if;
  c := fyf_pass_code(); t := fyf_transfer_code();
  insert into bike_passes(code, tenant_id, bike_ref, visibility, stolen, payload, frame_hash, transfer_hash)
    values (c, null, null, 'shops', false, (p_payload - 'fh') || jsonb_build_object('self', true, 'shop', jsonb_build_object('name', '')), p_fh, encode(sha256(convert_to(t, 'UTF8')), 'hex'));
  insert into bike_pass_entries(code, tenant_id, shop, kind, body, done_on, trust) values (c, null, 'Besitzer', 'Registrierung', 'Rad vom Besitzer registriert', current_date, 'self');
  return jsonb_build_object('code', c, 'transfer', t);
end $$;
revoke all on function pass_register(jsonb, text) from public;
grant execute on function pass_register(jsonb, text) to anon, authenticated;

do $$
begin
  if not exists (select 1 from pg_indexes where indexname = 'bike_passes_fh_unique')
     and not exists (select frame_hash from bike_passes where frame_hash is not null and withdrawn_at is null group by frame_hash having count(*) > 1) then
    create unique index bike_passes_fh_unique on bike_passes (frame_hash) where frame_hash is not null and withdrawn_at is null;
  end if;
end $$;
