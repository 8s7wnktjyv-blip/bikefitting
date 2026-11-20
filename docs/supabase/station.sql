-- FYF – Tab5-Station (Entwurf, 20.11.2026)
-- STATUS: ENTWURF, in Supabase noch NICHT ausgeführt, noch nicht in alles.sql. Mit Postgres lokal getestet: siehe tests/station_test.sql.
-- Voraussetzung: start.sql, team.sql und pair.sql sind eingespielt (Geräte-Kopplung mit Code).
--
-- Was das macht
-- * Die „FYF Station“ auf dem M5Stack-Tab5 ist ein gekoppeltes Gerät (Mitglied des Ladens, ohne E-Mail).
-- * station_customers: das Tab5 holt NUR Kundennummer, Name, Körpergröße und Schrittlänge – keine Kontaktdaten.
-- * station_push: das Tab5 legt ein Fitting (Messwerte vorher/nachher, Beobachtungen) in einen Eingangskorb.
-- * station_list / station_take: die FYF-App zeigt den Eingangskorb und markiert übernommene Einträge.
-- * Schutz: nur Mitglieder des Ladens, höchstens 20 kB je Eintrag, höchstens 300 Einträge je Laden und Tag,
--   Einträge werden nach 30 Tagen gelöscht. Keine direkten Tabellenrechte, nur über die Funktionen.

create table if not exists station_inbox (
  id bigserial primary key,
  tenant_id uuid not null references tenants(id) on delete cascade,
  payload jsonb not null,
  created_at timestamptz not null default now(),
  created_by uuid,
  taken_at timestamptz,
  taken_by uuid
);
create index if not exists station_inbox_t on station_inbox (tenant_id, created_at desc);
alter table station_inbox enable row level security;
-- Keine Policies: direkte Zugriffe gesperrt, alles über die Funktionen unten.

create or replace function station_push(p_tenant uuid, p_payload jsonb) returns bigint
language plpgsql security definer set search_path = public as $$
declare i bigint;
begin
  if auth.uid() is null or not is_member(p_tenant) then raise exception 'FYF_DENIED'; end if;
  if p_payload is null or jsonb_typeof(p_payload) <> 'object' or octet_length(p_payload::text) > 20000 then raise exception 'FYF_BAD_DATA'; end if;
  if (select count(*) from station_inbox where tenant_id = p_tenant and created_at > now() - interval '1 day') >= 300 then raise exception 'FYF_RATE'; end if;
  delete from station_inbox where tenant_id = p_tenant and created_at < now() - interval '30 days';
  insert into station_inbox(tenant_id, payload, created_by) values (p_tenant, p_payload, auth.uid()) returning id into i;
  perform fyf_audit(p_tenant, 'station_push', jsonb_build_object('id', i));
  return i;
end $$;

create or replace function station_list(p_tenant uuid) returns table(id bigint, payload jsonb, created_at timestamptz)
language sql stable security definer set search_path = public as $$
  select s.id, s.payload, s.created_at from station_inbox s
  where s.tenant_id = p_tenant and s.taken_at is null and is_member(p_tenant)
  order by s.created_at desc limit 50;
$$;

create or replace function station_take(p_tenant uuid, p_id bigint) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null or not is_member(p_tenant) then raise exception 'FYF_DENIED'; end if;
  update station_inbox set taken_at = now(), taken_by = auth.uid() where tenant_id = p_tenant and id = p_id and taken_at is null;
end $$;

-- Nur Name und Körpermaße, keine Kontaktdaten. Werte aus dem gespeicherten FYF-Stand (tenant_state.data.customers).
create or replace function station_customers(p_tenant uuid) returns table(id text, name text, height numeric, inseam numeric)
language sql stable security definer set search_path = public as $$
  select c->>'id', left(c->>'name', 60),
         case when jsonb_typeof(c->'body'->'height') = 'number' then (c->'body'->>'height')::numeric end,
         case when jsonb_typeof(c->'body'->'inseam') = 'number' then (c->'body'->>'inseam')::numeric end
  from tenant_state t, jsonb_array_elements(case when jsonb_typeof(t.data->'customers') = 'array' then t.data->'customers' else '[]'::jsonb end) c
  where t.tenant_id = p_tenant and is_member(p_tenant) and coalesce(c->>'id', '') <> '' and coalesce(c->>'name', '') <> ''
  order by 2 limit 500;
$$;

revoke all on function station_push(uuid, jsonb), station_list(uuid), station_take(uuid, bigint), station_customers(uuid) from public, anon;
grant execute on function station_push(uuid, jsonb), station_list(uuid), station_take(uuid, bigint), station_customers(uuid) to authenticated;
