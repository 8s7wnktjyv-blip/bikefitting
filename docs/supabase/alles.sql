-- FYF – Fit your Frame · KOMPLETTE Datenbank (Stand 13). Automatisch erzeugt aus: start.sql media.sql team.sql netz.sql freigabe.sql pair.sql ausbau.sql feedback.sql werkstatt.sql pass.sql passport.sql
-- Nicht von Hand ändern – stattdessen die Einzeldatei ändern und tools/build-alles.sh ausführen.
-- Mehrfach ausführen schadet nicht: es wird nur ergänzt und ersetzt, keine Daten gelöscht.
-- Normal läuft das über GitHub → Actions → „Datenbank aktualisieren“ → Run workflow.

-- ===================== start.sql =====================
-- FYF – Fit your Frame · Cloud-Start (Schritt 1) für Supabase
-- STATUS: VORBEREITET, lokal mit Postgres 16 getestet, in Supabase noch NICHT ausgeführt.
--
-- Was das macht
-- * Jeder Laden (Betrieb) speichert seinen kompletten FYF-Stand als einen Datensatz (tenant_state).
-- * Jede Änderung erhöht die Versionsnummer. Wer mit einem veralteten Stand speichern will,
--   bekommt einen Konflikt statt fremde Änderungen zu überschreiben.
-- * Die letzten 30 Stände je Laden bleiben im Verlauf (tenant_state_history) als Sicherung.
-- * Zugriff nur für angemeldete Mitglieder des Ladens (Row Level Security).
--   Schreiben geht nur über die Funktionen create_tenant und save_state.
--
-- Ausführen: Supabase → SQL Editor → diesen Text einfügen → Run.
-- Schritt 2 (später): Aufteilung auf einzelne Tabellen laut schema.sql. tenants/memberships sind dort gleich aufgebaut.

create extension if not exists pgcrypto;

create table if not exists tenants (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  created_at timestamptz not null default now()
);

create table if not exists memberships (
  user_id uuid not null references auth.users(id) on delete cascade,
  tenant_id uuid not null references tenants(id) on delete cascade,
  role text not null check (role in ('admin','fitter','mitarbeiter')),
  primary key (user_id, tenant_id)
);

create or replace function is_member(t uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from memberships m where m.user_id = auth.uid() and m.tenant_id = t);
$$;

create or replace function has_role(t uuid, roles text[]) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from memberships m where m.user_id = auth.uid() and m.tenant_id = t and m.role = any(roles));
$$;

create table if not exists tenant_state (
  tenant_id uuid primary key references tenants(id) on delete cascade,
  data jsonb not null,
  version int not null default 1,
  updated_at timestamptz not null default now(),
  updated_by uuid
);

create table if not exists tenant_state_history (
  id bigserial primary key,
  tenant_id uuid not null references tenants(id) on delete cascade,
  version int not null,
  data jsonb not null,
  saved_at timestamptz not null default now(),
  saved_by uuid
);
create index if not exists tenant_state_history_t on tenant_state_history (tenant_id, version desc);

alter table tenants enable row level security;
alter table memberships enable row level security;
alter table tenant_state enable row level security;
alter table tenant_state_history enable row level security;

drop policy if exists tenant_read on tenants;
create policy tenant_read on tenants for select using (is_member(id));
drop policy if exists own_membership on memberships;
create policy own_membership on memberships for select using (user_id = auth.uid() or has_role(tenant_id, array['admin']));
drop policy if exists state_read on tenant_state;
create policy state_read on tenant_state for select using (is_member(tenant_id));
drop policy if exists history_read on tenant_state_history;
create policy history_read on tenant_state_history for select using (has_role(tenant_id, array['admin']));
-- Keine insert/update/delete-Regeln: direkte Schreibzugriffe sind damit gesperrt.

-- Ersten Laden anlegen: der angemeldete Nutzer wird Admin. Hat er schon einen Laden, kommt dessen id zurück.
create or replace function create_tenant(p_name text) returns uuid
language plpgsql security definer set search_path = public as $$
declare t uuid;
begin
  if auth.uid() is null then raise exception 'FYF_NOT_AUTHENTICATED'; end if;
  select tenant_id into t from memberships where user_id = auth.uid() limit 1;
  if t is not null then return t; end if;
  insert into tenants(name) values (coalesce(nullif(trim(p_name), ''), 'Mein Laden')) returning id into t;
  insert into memberships(user_id, tenant_id, role) values (auth.uid(), t, 'admin');
  return t;
end $$;

-- Stand speichern. p_expected = Version, auf der die Änderung beruht (0 = noch nichts in der Cloud).
-- Gibt die neue Version zurück oder bricht mit FYF_CONFLICT <aktuelle Version> ab.
create or replace function save_state(p_tenant uuid, p_data jsonb, p_expected int) returns int
language plpgsql security definer set search_path = public as $$
declare v int;
begin
  if auth.uid() is null or not is_member(p_tenant) then raise exception 'FYF_DENIED'; end if;
  if p_data is null or jsonb_typeof(p_data) <> 'object' then raise exception 'FYF_BAD_DATA'; end if;
  select version into v from tenant_state where tenant_id = p_tenant for update;
  if v is null then
    if coalesce(p_expected, 0) <> 0 then raise exception 'FYF_CONFLICT 0'; end if;
    insert into tenant_state(tenant_id, data, version, updated_by) values (p_tenant, p_data, 1, auth.uid());
    return 1;
  end if;
  if p_expected is distinct from v then raise exception 'FYF_CONFLICT %', v; end if;
  insert into tenant_state_history(tenant_id, version, data, saved_by)
    select tenant_id, version, data, updated_by from tenant_state where tenant_id = p_tenant;
  delete from tenant_state_history h where h.tenant_id = p_tenant
    and h.id not in (select id from tenant_state_history where tenant_id = p_tenant order by version desc limit 30);
  update tenant_state set data = p_data, version = v + 1, updated_at = now(), updated_by = auth.uid() where tenant_id = p_tenant;
  return v + 1;
end $$;

revoke all on function create_tenant(text) from public, anon;
revoke all on function save_state(uuid, jsonb, int) from public, anon;
grant execute on function create_tenant(text) to authenticated;
grant execute on function save_state(uuid, jsonb, int) to authenticated;

-- Leserechte für angemeldete Nutzer. Neue Supabase-Projekte vergeben diese nicht mehr automatisch.
-- Was jemand tatsächlich sieht, begrenzen weiterhin die Regeln (RLS) oben.
grant usage on schema public to authenticated;
grant select on tenants, memberships, tenant_state, tenant_state_history to authenticated;

-- ===================== media.sql =====================
-- FYF – Fit your Frame · Cloud-Speicher für Fotos und Videos (Schritt 2)
-- Voraussetzung: start.sql wurde schon ausgeführt.
-- Ausführen: Supabase → SQL Editor → diesen Text einfügen → Run. Mehrfach ausführen schadet nicht.
--
-- Was das macht
-- * Legt den privaten Speicher „media“ an (nicht öffentlich, max. 50 MB je Datei – Grenze im Free-Plan).
-- * Dateien liegen unter <Laden-ID>/<Datei-ID>. Zugriff nur für angemeldete Mitglieder dieses Ladens.
-- * Löschen dürfen nur Admin und Fitter (wie in der App).

insert into storage.buckets (id, name, public, file_size_limit)
values ('media', 'media', false, 52428800)
on conflict (id) do update set public = false, file_size_limit = 52428800;

create or replace function public.fyf_media_member(p_folder text) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from memberships m where m.user_id = auth.uid() and m.tenant_id::text = p_folder);
$$;

create or replace function public.fyf_media_can_delete(p_folder text) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from memberships m where m.user_id = auth.uid() and m.tenant_id::text = p_folder and m.role in ('admin','fitter'));
$$;

revoke all on function public.fyf_media_member(text) from public, anon;
revoke all on function public.fyf_media_can_delete(text) from public, anon;
grant execute on function public.fyf_media_member(text) to authenticated;
grant execute on function public.fyf_media_can_delete(text) to authenticated;

drop policy if exists fyf_media_read on storage.objects;
create policy fyf_media_read on storage.objects for select to authenticated
  using (bucket_id = 'media' and public.fyf_media_member((storage.foldername(name))[1]));

drop policy if exists fyf_media_insert on storage.objects;
create policy fyf_media_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'media' and public.fyf_media_member((storage.foldername(name))[1]));

drop policy if exists fyf_media_update on storage.objects;
create policy fyf_media_update on storage.objects for update to authenticated
  using (bucket_id = 'media' and public.fyf_media_member((storage.foldername(name))[1]))
  with check (bucket_id = 'media' and public.fyf_media_member((storage.foldername(name))[1]));

drop policy if exists fyf_media_delete on storage.objects;
create policy fyf_media_delete on storage.objects for delete to authenticated
  using (bucket_id = 'media' and public.fyf_media_can_delete((storage.foldername(name))[1]));

-- ===================== team.sql =====================
-- FYF – Fit your Frame · Team und Rechte auf dem Server (Schritt 3)
-- Voraussetzung: start.sql (und media.sql) wurden schon ausgeführt.
-- Ausführen: Supabase → SQL Editor → diesen Text einfügen → Run. Mehrfach ausführen schadet nicht.
-- Wird start.sql später noch einmal ausgeführt, danach auch diese Datei erneut ausführen
-- (start.sql setzt save_state sonst auf die Version ohne Rechteprüfung zurück).
--
-- Was das macht
-- * Admins laden Mitarbeiter per E-Mail ein und vergeben die Rolle (admin, fitter, mitarbeiter).
--   Meldet sich die eingeladene Person mit dieser E-Mail an, ist sie automatisch im Laden.
-- * Rollen ändern und Mitglieder entfernen darf nur ein Admin. Der letzte Admin kann nicht entfernt werden.
-- * Der Server prüft beim Speichern:
--     - Ausgestellte Rechnungen dürfen von niemandem gelöscht oder inhaltlich geändert werden
--       (nur Status „bezahlt/offen/storniert“ darf sich ändern).
--     - Nur Admins dürfen Kunden und Messmittel löschen.
--     - Mitarbeiter dürfen keine Rechnungen anlegen, stornieren oder als bezahlt markieren.
--   Grenzen: Weitere Rechte (z. B. Produktliste, Einstellungen) prüft weiter nur die App.
--   Feinere Rechte je Datensatz kommen mit der Aufteilung in einzelne Tabellen.
-- * Protokoll (audit_log): Einladungen, Rollenwechsel, Entfernen und jede gespeicherte Version.
--   Lesen dürfen nur Admins. Niemand kann Einträge ändern oder löschen.

create table if not exists invitations (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id) on delete cascade,
  email text not null check (email = lower(trim(email)) and position('@' in email) > 1),
  role text not null check (role in ('admin','fitter','mitarbeiter')),
  invited_by uuid,
  created_at timestamptz not null default now(),
  accepted_at timestamptz,
  accepted_by uuid,
  unique (tenant_id, email)
);

create table if not exists audit_log (
  id bigserial primary key,
  tenant_id uuid not null references tenants(id) on delete cascade,
  at timestamptz not null default now(),
  user_id uuid,
  action text not null,
  detail jsonb
);
create index if not exists audit_log_t on audit_log (tenant_id, at desc);

alter table invitations enable row level security;
alter table audit_log enable row level security;
drop policy if exists invite_read on invitations;
create policy invite_read on invitations for select using (has_role(tenant_id, array['admin']));
drop policy if exists audit_read on audit_log;
create policy audit_read on audit_log for select using (has_role(tenant_id, array['admin']));
grant select on invitations, audit_log to authenticated;
-- Keine insert/update/delete-Regeln: geschrieben wird nur über die Funktionen unten.

create or replace function fyf_audit(p_tenant uuid, p_action text, p_detail jsonb) returns void
language sql security definer set search_path = public as $$
  insert into audit_log(tenant_id, user_id, action, detail) values (p_tenant, auth.uid(), p_action, p_detail);
$$;

create or replace function fyf_my_email() returns text
language sql stable security definer set search_path = public, auth as $$
  select lower(email) from auth.users where id = auth.uid();
$$;

-- Mitarbeiter einladen (nur Admin). Gibt die Einladungs-ID zurück.
create or replace function invite_member(p_tenant uuid, p_email text, p_role text) returns uuid
language plpgsql security definer set search_path = public, auth as $$
declare e text := lower(trim(coalesce(p_email, ''))); i uuid;
begin
  if not has_role(p_tenant, array['admin']) then raise exception 'FYF_DENIED'; end if;
  if p_role not in ('admin','fitter','mitarbeiter') then raise exception 'FYF_BAD_ROLE'; end if;
  if e !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then raise exception 'FYF_BAD_EMAIL'; end if;
  if exists (select 1 from memberships m join auth.users u on u.id = m.user_id where m.tenant_id = p_tenant and lower(u.email) = e)
    then raise exception 'FYF_ALREADY_MEMBER'; end if;
  insert into invitations(tenant_id, email, role, invited_by) values (p_tenant, e, p_role, auth.uid())
    on conflict (tenant_id, email) do update set role = excluded.role, invited_by = excluded.invited_by, created_at = now(), accepted_at = null, accepted_by = null
    returning id into i;
  perform fyf_audit(p_tenant, 'invite', jsonb_build_object('email', e, 'role', p_role));
  return i;
end $$;

create or replace function revoke_invite(p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
declare t uuid; e text;
begin
  select tenant_id, email into t, e from invitations where id = p_id and accepted_at is null;
  if t is null or not has_role(t, array['admin']) then raise exception 'FYF_DENIED'; end if;
  delete from invitations where id = p_id;
  perform fyf_audit(t, 'invite_revoke', jsonb_build_object('email', e));
end $$;

-- Nach der Anmeldung aufrufen: nimmt offene Einladungen für die eigene E-Mail an.
-- Eine Person gehört (vorerst) zu genau einem Laden. Ist sie schon Mitglied, bleibt die Einladung offen.
create or replace function accept_invites() returns uuid
language plpgsql security definer set search_path = public as $$
declare e text := fyf_my_email(); inv record;
begin
  if auth.uid() is null or e is null then return null; end if;
  if exists (select 1 from memberships where user_id = auth.uid()) then return null; end if;
  select * into inv from invitations where email = e and accepted_at is null order by created_at desc limit 1;
  if inv.id is null then return null; end if;
  insert into memberships(user_id, tenant_id, role) values (auth.uid(), inv.tenant_id, inv.role);
  update invitations set accepted_at = now(), accepted_by = auth.uid() where id = inv.id;
  perform fyf_audit(inv.tenant_id, 'join', jsonb_build_object('email', e, 'role', inv.role));
  return inv.tenant_id;
end $$;

-- Team-Liste: alle Mitglieder sehen ihre Kollegen (E-Mail und Rolle).
create or replace function list_members(p_tenant uuid) returns table(user_id uuid, email text, role text, is_me boolean)
language sql stable security definer set search_path = public, auth as $$
  select m.user_id, u.email::text, m.role, m.user_id = auth.uid()
  from memberships m join auth.users u on u.id = m.user_id
  where m.tenant_id = p_tenant and is_member(p_tenant)
  order by (m.role = 'admin') desc, u.email;
$$;

create or replace function set_member_role(p_tenant uuid, p_user uuid, p_role text) returns void
language plpgsql security definer set search_path = public as $$
declare old text;
begin
  if not has_role(p_tenant, array['admin']) then raise exception 'FYF_DENIED'; end if;
  if p_role not in ('admin','fitter','mitarbeiter') then raise exception 'FYF_BAD_ROLE'; end if;
  select role into old from memberships where tenant_id = p_tenant and user_id = p_user for update;
  if old is null then raise exception 'FYF_NOT_FOUND'; end if;
  if old = 'admin' and p_role <> 'admin' and (select count(*) from memberships where tenant_id = p_tenant and role = 'admin') <= 1
    then raise exception 'FYF_LAST_ADMIN'; end if;
  update memberships set role = p_role where tenant_id = p_tenant and user_id = p_user;
  perform fyf_audit(p_tenant, 'role', jsonb_build_object('user', p_user, 'from', old, 'to', p_role));
end $$;

create or replace function remove_member(p_tenant uuid, p_user uuid) returns void
language plpgsql security definer set search_path = public as $$
declare old text;
begin
  if not has_role(p_tenant, array['admin']) then raise exception 'FYF_DENIED'; end if;
  select role into old from memberships where tenant_id = p_tenant and user_id = p_user for update;
  if old is null then raise exception 'FYF_NOT_FOUND'; end if;
  if old = 'admin' and (select count(*) from memberships where tenant_id = p_tenant and role = 'admin') <= 1
    then raise exception 'FYF_LAST_ADMIN'; end if;
  delete from memberships where tenant_id = p_tenant and user_id = p_user;
  perform fyf_audit(p_tenant, 'remove', jsonb_build_object('user', p_user, 'role', old));
end $$;

-- Prüft eine Änderung am Laden-Stand. Gibt null zurück, wenn sie erlaubt ist, sonst den Grund.
create or replace function fyf_guard(p_role text, o jsonb, n jsonb) returns text
language plpgsql immutable as $$
declare x jsonb; y jsonb;
begin
  if o is null then return null; end if;
  -- Rechnungen: für alle Rollen unveränderlich (außer Status)
  for x in select * from jsonb_array_elements(coalesce(o->'invoices', '[]'::jsonb)) loop
    select e into y from jsonb_array_elements(coalesce(n->'invoices', '[]'::jsonb)) e where e->>'id' = x->>'id' limit 1;
    if y is null then return 'Rechnung ' || coalesce(x->>'no', '?') || ' darf nicht gelöscht werden'; end if;
    if (x - 'status' - 'paidAt') <> (y - 'status' - 'paidAt') then return 'Rechnung ' || coalesce(x->>'no', '?') || ' darf nicht geändert werden'; end if;
  end loop;
  if p_role = 'admin' then return null; end if;
  if exists (select 1 from jsonb_array_elements(coalesce(o->'customers', '[]'::jsonb)) a
             where not exists (select 1 from jsonb_array_elements(coalesce(n->'customers', '[]'::jsonb)) b where b->>'id' = a->>'id'))
    then return 'Kunden löschen darf nur ein Admin'; end if;
  if exists (select 1 from jsonb_array_elements(coalesce(o->'tools', '[]'::jsonb)) a
             where not exists (select 1 from jsonb_array_elements(coalesce(n->'tools', '[]'::jsonb)) b where b->>'id' = a->>'id'))
    then return 'Messmittel löschen darf nur ein Admin'; end if;
  if p_role = 'mitarbeiter' and coalesce(o->'invoices', '[]'::jsonb) <> coalesce(n->'invoices', '[]'::jsonb)
    then return 'Rechnungen anlegen oder ändern darf ein Mitarbeiter nicht'; end if;
  return null;
end $$;

-- save_state wie in start.sql, zusätzlich mit Rechteprüfung und Protokoll.
create or replace function save_state(p_tenant uuid, p_data jsonb, p_expected int) returns int
language plpgsql security definer set search_path = public as $$
declare v int; r text; old jsonb; why text;
begin
  if auth.uid() is null then raise exception 'FYF_DENIED'; end if;
  select role into r from memberships where user_id = auth.uid() and tenant_id = p_tenant;
  if r is null then raise exception 'FYF_DENIED'; end if;
  if p_data is null or jsonb_typeof(p_data) <> 'object' then raise exception 'FYF_BAD_DATA'; end if;
  select version, data into v, old from tenant_state where tenant_id = p_tenant for update;
  if v is null then
    if coalesce(p_expected, 0) <> 0 then raise exception 'FYF_CONFLICT 0'; end if;
    insert into tenant_state(tenant_id, data, version, updated_by) values (p_tenant, p_data, 1, auth.uid());
    perform fyf_audit(p_tenant, 'save', jsonb_build_object('version', 1));
    return 1;
  end if;
  if p_expected is distinct from v then raise exception 'FYF_CONFLICT %', v; end if;
  why := fyf_guard(r, old, p_data);
  if why is not null then raise exception 'FYF_ROLE %', why; end if;
  insert into tenant_state_history(tenant_id, version, data, saved_by)
    select tenant_id, version, data, updated_by from tenant_state where tenant_id = p_tenant;
  delete from tenant_state_history h where h.tenant_id = p_tenant
    and h.id not in (select id from tenant_state_history where tenant_id = p_tenant order by version desc limit 30);
  update tenant_state set data = p_data, version = v + 1, updated_at = now(), updated_by = auth.uid() where tenant_id = p_tenant;
  perform fyf_audit(p_tenant, 'save', jsonb_build_object('version', v + 1));
  return v + 1;
end $$;

revoke all on function fyf_audit(uuid, text, jsonb) from public, anon, authenticated;
revoke all on function fyf_my_email() from public, anon, authenticated;
revoke all on function fyf_guard(text, jsonb, jsonb) from public, anon;
revoke all on function invite_member(uuid, text, text) from public, anon;
revoke all on function revoke_invite(uuid) from public, anon;
revoke all on function accept_invites() from public, anon;
revoke all on function list_members(uuid) from public, anon;
revoke all on function set_member_role(uuid, uuid, text) from public, anon;
revoke all on function remove_member(uuid, uuid) from public, anon;
revoke all on function save_state(uuid, jsonb, int) from public, anon;
grant execute on function invite_member(uuid, text, text) to authenticated;
grant execute on function revoke_invite(uuid) to authenticated;
grant execute on function accept_invites() to authenticated;
grant execute on function list_members(uuid) to authenticated;
grant execute on function set_member_role(uuid, uuid, text) to authenticated;
grant execute on function remove_member(uuid, uuid) to authenticated;
grant execute on function save_state(uuid, jsonb, int) to authenticated;

-- ===================== netz.sql =====================
-- FYF – Fit your Frame · Händlernetzwerk (Schritt 4)
-- Voraussetzung: start.sql und team.sql wurden schon ausgeführt.
-- Ausführen: Supabase → SQL Editor → diesen Text einfügen → Run. Mehrfach ausführen schadet nicht.
--
-- Was das macht
-- 1. Lesekopie in Tabellen: Kunden, Räder, Fittings, Rechnungen und Produkte jedes Ladens werden bei jedem
--    Speichern automatisch in einzelne Tabellen kopiert (fyf_customers, fyf_bikes, fyf_sessions, fyf_invoices,
--    fyf_products). Geschrieben wird weiter nur über save_state. Lesen nur Mitglieder des Ladens.
-- 2. Händlerprofil (dealer_profiles): öffentlich sichtbar, sobald der Admin es veröffentlicht.
--    Öffentlich sind nur die Felder dieses Profils und Produkte, die ausdrücklich „öffentlich“ markiert sind.
-- 3. Anfragen (inquiries): Endkunden schicken ohne Konto eine Anfrage an einen Laden. Spam-Schutz:
--    verstecktes Feld, Längenbegrenzung, höchstens 20 Anfragen je Laden und Stunde und 3 je Absender und Tag.
--    Kontaktdaten sieht nur der Laden.
-- 4. Händlerbörse (trade_offers, trade_requests): nur für Läden, die von der Plattform geprüft wurden.
--    Kein Bezahlen, nur Angebot und Anfrage.
-- 5. Plattform-Verwaltung: Wer in platform_admins steht, prüft Läden (verified) und vergibt
--    „FYF Certified Fitter“ (certified) – nur nach echter Prüfung.
--    Dich selbst einmal eintragen (E-Mail anpassen, dann Run):
--      insert into platform_admins(user_id) select id from auth.users where lower(email) = 'deine@email.de' on conflict do nothing;

-- ---------- 1. Lesekopie ----------
create table if not exists fyf_customers (tenant_id uuid not null references tenants(id) on delete cascade, id text not null, name text, email text, phone text, since date, primary key (tenant_id, id));
create table if not exists fyf_bikes (tenant_id uuid not null references tenants(id) on delete cascade, id text not null, customer_id text, brand text, model text, type text, size text, frame_no text, km numeric, primary key (tenant_id, id));
create table if not exists fyf_sessions (tenant_id uuid not null references tenants(id) on delete cascade, id text not null, customer_id text, bike_id text, date date, type text, status text, fitter text, primary key (tenant_id, id));
create table if not exists fyf_invoices (tenant_id uuid not null references tenants(id) on delete cascade, id text not null, no text, date date, type text, status text, customer_id text, primary key (tenant_id, id));
create table if not exists fyf_products (tenant_id uuid not null references tenants(id) on delete cascade, id text not null, cat text, name text, price numeric, pub boolean not null default false, note text, primary key (tenant_id, id));

create or replace function fyf_d(t text) returns date language sql immutable as $$
  select case when t ~ '^\d{4}-\d{2}-\d{2}' then substr(t, 1, 10)::date end $$;
create or replace function fyf_n(t text) returns numeric language sql immutable as $$
  select case when t ~ '^-?\d+(\.\d+)?$' then t::numeric end $$;

create or replace function fyf_project() returns trigger
language plpgsql security definer set search_path = public as $$
declare t uuid := new.tenant_id; d jsonb := new.data;
begin
  delete from fyf_customers where tenant_id = t;
  insert into fyf_customers select t, e->>'id', e->>'name', e->>'email', e->>'phone', fyf_d(e->>'since')
    from jsonb_array_elements(coalesce(d->'customers', '[]')) e where e->>'id' is not null on conflict do nothing;
  delete from fyf_bikes where tenant_id = t;
  insert into fyf_bikes select t, e->>'id', e->>'customerId', e->>'brand', e->>'model', e->>'type', e->>'size', e->>'frameNo', fyf_n(e->>'km')
    from jsonb_array_elements(coalesce(d->'bikes', '[]')) e where e->>'id' is not null on conflict do nothing;
  delete from fyf_sessions where tenant_id = t;
  insert into fyf_sessions select t, e->>'id', e->>'customerId', e->>'bikeId', fyf_d(e->>'date'), e->>'type', e->>'status', e->>'fitter'
    from jsonb_array_elements(coalesce(d->'sessions', '[]')) e where e->>'id' is not null on conflict do nothing;
  delete from fyf_invoices where tenant_id = t;
  insert into fyf_invoices select t, e->>'id', e->>'no', fyf_d(e->>'date'), e->>'type', e->>'status', e->>'customerId'
    from jsonb_array_elements(coalesce(d->'invoices', '[]')) e where e->>'id' is not null on conflict do nothing;
  delete from fyf_products where tenant_id = t;
  insert into fyf_products select t, e->>'id', e->>'cat', left(e->>'name', 200), fyf_n(e->>'price'), coalesce((e->>'pub')::boolean, false), left(e->>'note', 300)
    from jsonb_array_elements(coalesce(d->'products', '[]')) e where e->>'id' is not null on conflict do nothing;
  return new;
end $$;

drop trigger if exists fyf_project_t on tenant_state;
create trigger fyf_project_t after insert or update of data on tenant_state for each row execute function fyf_project();

alter table fyf_customers enable row level security;
alter table fyf_bikes enable row level security;
alter table fyf_sessions enable row level security;
alter table fyf_invoices enable row level security;
alter table fyf_products enable row level security;
drop policy if exists r on fyf_customers; create policy r on fyf_customers for select using (is_member(tenant_id));
drop policy if exists r on fyf_bikes; create policy r on fyf_bikes for select using (is_member(tenant_id));
drop policy if exists r on fyf_sessions; create policy r on fyf_sessions for select using (is_member(tenant_id));
drop policy if exists r on fyf_invoices; create policy r on fyf_invoices for select using (is_member(tenant_id));
drop policy if exists r on fyf_products; create policy r on fyf_products for select using (is_member(tenant_id));
grant select on fyf_customers, fyf_bikes, fyf_sessions, fyf_invoices, fyf_products to authenticated;

-- Bestehende Stände einmal kopieren
update tenant_state set data = data;

-- ---------- 5. Plattform ----------
create table if not exists platform_admins (user_id uuid primary key references auth.users(id) on delete cascade);
alter table platform_admins enable row level security;
alter table tenants add column if not exists verified boolean not null default false;

create or replace function is_platform_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from platform_admins where user_id = auth.uid()) $$;

-- ---------- 2. Händlerprofil ----------
create table if not exists dealer_profiles (
  tenant_id uuid primary key references tenants(id) on delete cascade,
  slug text unique not null check (slug ~ '^[a-z0-9][a-z0-9-]{2,60}$'),
  published boolean not null default false,
  name text not null check (length(name) between 2 and 120),
  street text, zip text, city text,
  phone text, email text, web text,
  about text check (length(about) <= 1500),
  services text[] not null default '{}',
  hours text check (length(hours) <= 500),
  partner boolean not null default false,
  certified boolean not null default false,
  updated_at timestamptz not null default now()
);
alter table dealer_profiles enable row level security;
drop policy if exists pub_read on dealer_profiles;
create policy pub_read on dealer_profiles for select using (published or is_member(tenant_id) or is_platform_admin());
grant select on dealer_profiles to anon, authenticated;

create or replace function save_profile(p_tenant uuid, p jsonb) returns text
language plpgsql security definer set search_path = public as $$
declare s text := lower(regexp_replace(coalesce(p->>'slug', ''), '[^a-zA-Z0-9-]+', '-', 'g')); sv text[];
begin
  if not has_role(p_tenant, array['admin']) then raise exception 'FYF_DENIED'; end if;
  s := trim(both '-' from s);
  if s !~ '^[a-z0-9][a-z0-9-]{2,60}$' then raise exception 'FYF_BAD_SLUG'; end if;
  if exists (select 1 from dealer_profiles where slug = s and tenant_id <> p_tenant) then raise exception 'FYF_SLUG_TAKEN'; end if;
  select coalesce(array_agg(left(x, 60)), '{}') into sv from (select jsonb_array_elements_text(coalesce(p->'services', '[]')) x limit 20) q;
  insert into dealer_profiles(tenant_id, slug, published, name, street, zip, city, phone, email, web, about, services, hours, partner, updated_at)
  values (p_tenant, s, coalesce((p->>'published')::boolean, false), left(trim(p->>'name'), 120), left(p->>'street', 120), left(p->>'zip', 10), left(p->>'city', 80),
          left(p->>'phone', 40), left(p->>'email', 120), left(p->>'web', 200), left(p->>'about', 1500), sv, left(p->>'hours', 500), true, now())
  on conflict (tenant_id) do update set slug = excluded.slug, published = excluded.published, name = excluded.name, street = excluded.street, zip = excluded.zip,
    city = excluded.city, phone = excluded.phone, email = excluded.email, web = excluded.web, about = excluded.about, services = excluded.services,
    hours = excluded.hours, partner = true, updated_at = now();
  perform fyf_audit(p_tenant, 'profile', jsonb_build_object('published', coalesce((p->>'published')::boolean, false)));
  return s;
end $$;

-- Öffentliche Produkte: nur „pub“ markierte Produkte veröffentlichter Läden
create or replace view public_products with (security_invoker = false) as
  select d.slug, p.id, p.cat, p.name, p.price, p.note from fyf_products p join dealer_profiles d on d.tenant_id = p.tenant_id
  where p.pub and d.published and p.price is not null;
grant select on public_products to anon, authenticated;

-- ---------- 3. Anfragen ----------
create table if not exists inquiries (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id) on delete cascade,
  created_at timestamptz not null default now(),
  topic text not null,
  product_id text,
  name text not null,
  contact text not null,
  message text not null,
  status text not null default 'neu' check (status in ('neu','in Arbeit','erledigt','Spam'))
);
create index if not exists inquiries_t on inquiries (tenant_id, created_at desc);
alter table inquiries enable row level security;
drop policy if exists inq_read on inquiries;
create policy inq_read on inquiries for select using (is_member(tenant_id));
grant select on inquiries to authenticated;

create or replace function submit_inquiry(p_slug text, p_topic text, p_name text, p_contact text, p_message text, p_product text default null, p_hp text default '') returns boolean
language plpgsql security definer set search_path = public as $$
declare t uuid; c text := lower(trim(coalesce(p_contact, '')));
begin
  if coalesce(p_hp, '') <> '' then return true; end if;  -- verstecktes Feld ausgefüllt: still verwerfen
  select tenant_id into t from dealer_profiles where slug = p_slug and published;
  if t is null then raise exception 'FYF_NOT_FOUND'; end if;
  if length(trim(coalesce(p_name, ''))) < 2 or length(c) < 5 or length(trim(coalesce(p_message, ''))) < 5 then raise exception 'FYF_BAD_DATA'; end if;
  if length(p_name) > 100 or length(c) > 120 or length(p_message) > 2000 or length(coalesce(p_topic, '')) > 60 then raise exception 'FYF_TOO_LONG'; end if;
  if (select count(*) from inquiries where tenant_id = t and created_at > now() - interval '1 hour') >= 20 then raise exception 'FYF_RATE'; end if;
  if (select count(*) from inquiries where tenant_id = t and lower(contact) = c and created_at > now() - interval '1 day') >= 3 then raise exception 'FYF_RATE'; end if;
  insert into inquiries(tenant_id, topic, product_id, name, contact, message)
    values (t, coalesce(nullif(trim(p_topic), ''), 'Allgemein'), left(p_product, 60), trim(p_name), trim(p_contact), trim(p_message));
  return true;
end $$;

create or replace function set_inquiry_status(p_id uuid, p_status text) returns void
language plpgsql security definer set search_path = public as $$
declare t uuid;
begin
  select tenant_id into t from inquiries where id = p_id;
  if t is null or not is_member(t) then raise exception 'FYF_DENIED'; end if;
  update inquiries set status = p_status where id = p_id;
end $$;

-- ---------- 4. Händlerbörse ----------
create table if not exists trade_offers (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id) on delete cascade,
  created_at timestamptz not null default now(),
  title text not null check (length(title) between 3 and 120),
  category text not null,
  qty int not null check (qty > 0),
  price_net numeric check (price_net >= 0),
  condition text not null default 'neu' check (condition in ('neu','neu ohne OVP','Vorführware','gebraucht')),
  note text check (length(note) <= 1000),
  status text not null default 'aktiv' check (status in ('aktiv','reserviert','verkauft','beendet'))
);
create table if not exists trade_requests (
  id uuid primary key default gen_random_uuid(),
  offer_id uuid not null references trade_offers(id) on delete cascade,
  from_tenant uuid not null references tenants(id) on delete cascade,
  created_at timestamptz not null default now(),
  qty int not null check (qty > 0),
  price_net numeric check (price_net >= 0),
  message text check (length(message) <= 1000),
  status text not null default 'offen' check (status in ('offen','angenommen','abgelehnt','zurückgezogen'))
);
alter table trade_offers enable row level security;
alter table trade_requests enable row level security;

create or replace function my_verified_tenant() returns uuid
language sql stable security definer set search_path = public as $$
  select m.tenant_id from memberships m join tenants t on t.id = m.tenant_id where m.user_id = auth.uid() and t.verified limit 1 $$;

drop policy if exists offer_read on trade_offers;
create policy offer_read on trade_offers for select using (my_verified_tenant() is not null and (status in ('aktiv','reserviert') or is_member(tenant_id)));
drop policy if exists req_read on trade_requests;
create policy req_read on trade_requests for select using (is_member(from_tenant) or exists (select 1 from trade_offers o where o.id = offer_id and is_member(o.tenant_id)));
grant select on trade_offers, trade_requests to authenticated;

create or replace function trade_offer_save(p jsonb) returns uuid
language plpgsql security definer set search_path = public as $$
declare t uuid := my_verified_tenant(); i uuid := nullif(p->>'id', '')::uuid;
begin
  if t is null or not has_role(t, array['admin','fitter']) then raise exception 'FYF_NOT_VERIFIED'; end if;
  if i is null then
    insert into trade_offers(tenant_id, title, category, qty, price_net, condition, note)
      values (t, trim(p->>'title'), coalesce(p->>'category', 'Sonstiges'), (p->>'qty')::int, fyf_n(p->>'price_net'), coalesce(p->>'condition', 'neu'), p->>'note') returning id into i;
  else
    update trade_offers set title = trim(p->>'title'), category = coalesce(p->>'category', category), qty = (p->>'qty')::int, price_net = fyf_n(p->>'price_net'),
      condition = coalesce(p->>'condition', condition), note = p->>'note', status = coalesce(p->>'status', status) where id = i and tenant_id = t;
    if not found then raise exception 'FYF_DENIED'; end if;
  end if;
  return i;
end $$;

create or replace function trade_request_send(p_offer uuid, p_qty int, p_price numeric, p_message text) returns uuid
language plpgsql security definer set search_path = public as $$
declare t uuid := my_verified_tenant(); o record; i uuid;
begin
  if t is null then raise exception 'FYF_NOT_VERIFIED'; end if;
  select * into o from trade_offers where id = p_offer and status = 'aktiv';
  if o.id is null then raise exception 'FYF_NOT_FOUND'; end if;
  if o.tenant_id = t then raise exception 'FYF_OWN_OFFER'; end if;
  insert into trade_requests(offer_id, from_tenant, qty, price_net, message) values (p_offer, t, greatest(1, p_qty), p_price, left(p_message, 1000)) returning id into i;
  return i;
end $$;

create or replace function trade_request_answer(p_id uuid, p_status text) returns void
language plpgsql security definer set search_path = public as $$
declare r record;
begin
  select q.*, o.tenant_id as owner into r from trade_requests q join trade_offers o on o.id = q.offer_id where q.id = p_id;
  if r.id is null then raise exception 'FYF_NOT_FOUND'; end if;
  if p_status in ('angenommen','abgelehnt') and is_member(r.owner) then
    update trade_requests set status = p_status where id = p_id;
    if p_status = 'angenommen' then update trade_offers set status = 'reserviert' where id = r.offer_id and status = 'aktiv'; end if;
  elsif p_status = 'zurückgezogen' and is_member(r.from_tenant) then
    update trade_requests set status = p_status where id = p_id;
  else raise exception 'FYF_DENIED'; end if;
end $$;

-- Kontaktdaten des Gegenübers: nur wenn eine Anfrage zwischen beiden Läden besteht
create or replace function trade_contact(p_request uuid) returns table(name text, city text, phone text, email text)
language sql stable security definer set search_path = public as $$
  select coalesce(d.name, t.name), d.city, d.phone, d.email
  from trade_requests q join trade_offers o on o.id = q.offer_id
  join tenants t on t.id = case when is_member(o.tenant_id) then q.from_tenant else o.tenant_id end
  left join dealer_profiles d on d.tenant_id = t.id
  where q.id = p_request and (is_member(o.tenant_id) or is_member(q.from_tenant)) $$;

create or replace function trade_names() returns table(tenant_id uuid, name text, city text)
language sql stable security definer set search_path = public as $$
  select t.id, coalesce(d.name, t.name), d.city from tenants t left join dealer_profiles d on d.tenant_id = t.id
  where my_verified_tenant() is not null and t.verified $$;

-- ---------- 5. Plattform-Verwaltung ----------
create or replace function platform_tenants() returns table(id uuid, name text, verified boolean, certified boolean, published boolean, slug text, members int, created_at timestamptz)
language sql stable security definer set search_path = public as $$
  select t.id, t.name, t.verified, coalesce(d.certified, false), coalesce(d.published, false), d.slug,
         (select count(*)::int from memberships m where m.tenant_id = t.id), t.created_at
  from tenants t left join dealer_profiles d on d.tenant_id = t.id where is_platform_admin() order by t.created_at desc $$;

create or replace function platform_set(p_tenant uuid, p_field text, p_on boolean) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not is_platform_admin() then raise exception 'FYF_DENIED'; end if;
  if p_field = 'verified' then update tenants set verified = p_on where id = p_tenant;
  elsif p_field = 'certified' then update dealer_profiles set certified = p_on where tenant_id = p_tenant;
  else raise exception 'FYF_BAD_DATA'; end if;
  perform fyf_audit(p_tenant, 'platform_' || p_field, jsonb_build_object('on', p_on));
end $$;

create or replace function my_platform_state() returns table(verified boolean, platform_admin boolean)
language sql stable security definer set search_path = public as $$
  select coalesce((select t.verified from memberships m join tenants t on t.id = m.tenant_id where m.user_id = auth.uid() limit 1), false), is_platform_admin() $$;

-- ---------- Rechte ----------
revoke all on function fyf_project() from public, anon, authenticated;
revoke all on function save_profile(uuid, jsonb) from public, anon;
revoke all on function set_inquiry_status(uuid, text) from public, anon;
revoke all on function trade_offer_save(jsonb) from public, anon;
revoke all on function trade_request_send(uuid, int, numeric, text) from public, anon;
revoke all on function trade_request_answer(uuid, text) from public, anon;
revoke all on function trade_contact(uuid) from public, anon;
revoke all on function trade_names() from public, anon;
revoke all on function platform_tenants() from public, anon;
revoke all on function platform_set(uuid, text, boolean) from public, anon;
revoke all on function my_platform_state() from public, anon;
grant execute on function submit_inquiry(text, text, text, text, text, text, text) to anon, authenticated;
grant execute on function save_profile(uuid, jsonb), set_inquiry_status(uuid, text), trade_offer_save(jsonb),
  trade_request_send(uuid, int, numeric, text), trade_request_answer(uuid, text), trade_contact(uuid), trade_names(),
  platform_tenants(), platform_set(uuid, text, boolean), my_platform_state() to authenticated;
grant execute on function is_member(uuid), is_platform_admin(), my_verified_tenant() to anon, authenticated;

-- ===================== freigabe.sql =====================
-- FYF – Fit your Frame · Kostenvoranschlag per Link freigeben (Schritt 5)
-- Voraussetzung: start.sql, team.sql und netz.sql wurden schon ausgeführt.
-- Ausführen: Supabase → SQL Editor → diesen Text einfügen → Run. Mehrfach ausführen schadet nicht.
--
-- Was das macht
-- * Der Laden stellt einen Kostenvoranschlag als Link bereit (kva_publish). Der Link enthält einen zufälligen,
--   nicht erratbaren Schlüssel (32 Zeichen) und gilt 30 Tage.
-- * Der Kunde öffnet den Link ohne Konto, sieht Laden, Fahrrad und Positionen und tippt „Freigeben“ oder „Ablehnen“.
--   Eine Antwort ist nur einmal möglich.
-- * Im Link stehen keine Telefonnummer und keine E-Mail des Kunden.
-- * Die Antworten liest nur der Laden (RLS).

create table if not exists kva_links (
  token text primary key,
  tenant_id uuid not null references tenants(id) on delete cascade,
  wo_id text not null,
  payload jsonb not null,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '30 days',
  decision text check (decision in ('freigegeben','abgelehnt')),
  decided_at timestamptz,
  decided_name text,
  note text
);
create index if not exists kva_links_t on kva_links (tenant_id, created_at desc);
alter table kva_links enable row level security;
drop policy if exists kva_read on kva_links;
create policy kva_read on kva_links for select using (is_member(tenant_id));
grant select on kva_links to authenticated;

create or replace function kva_publish(p_tenant uuid, p_wo text, p_payload jsonb) returns text
language plpgsql security definer set search_path = public as $$
declare tk text := replace(gen_random_uuid()::text, '-', '');
begin
  if not is_member(p_tenant) then raise exception 'FYF_DENIED'; end if;
  if p_payload is null or jsonb_typeof(p_payload) <> 'object' or length(p_payload::text) > 20000 then raise exception 'FYF_BAD_DATA'; end if;
  delete from kva_links where tenant_id = p_tenant and wo_id = p_wo and decision is null;
  insert into kva_links(token, tenant_id, wo_id, payload) values (tk, p_tenant, left(p_wo, 60), p_payload);
  perform fyf_audit(p_tenant, 'kva_publish', jsonb_build_object('wo', p_wo));
  return tk;
end $$;

create or replace function kva_get(p_token text) returns table(payload jsonb, decision text, decided_at timestamptz, expired boolean)
language sql stable security definer set search_path = public as $$
  select k.payload, k.decision, k.decided_at, k.expires_at < now() from kva_links k where k.token = p_token and length(p_token) = 32 $$;

create or replace function kva_answer(p_token text, p_decision text, p_name text, p_note text default null) returns boolean
language plpgsql security definer set search_path = public as $$
declare k record;
begin
  if p_decision not in ('freigegeben','abgelehnt') then raise exception 'FYF_BAD_DATA'; end if;
  if length(trim(coalesce(p_name, ''))) < 2 or length(p_name) > 100 or length(coalesce(p_note, '')) > 1000 then raise exception 'FYF_BAD_DATA'; end if;
  select * into k from kva_links where token = p_token for update;
  if k.token is null or k.expires_at < now() then raise exception 'FYF_NOT_FOUND'; end if;
  if k.decision is not null then raise exception 'FYF_ALREADY'; end if;
  update kva_links set decision = p_decision, decided_at = now(), decided_name = trim(p_name), note = nullif(trim(coalesce(p_note, '')), '') where token = p_token;
  return true;
end $$;

revoke all on function kva_publish(uuid, text, jsonb) from public, anon;
grant execute on function kva_publish(uuid, text, jsonb) to authenticated;
grant execute on function kva_get(text), kva_answer(text, text, text, text) to anon, authenticated;

-- ===================== pair.sql =====================
-- FYF – Fit your Frame · Geräte per Code koppeln (Schritt 6)
-- Voraussetzung: start.sql und team.sql wurden schon ausgeführt.
-- Zusätzlich in Supabase einschalten: Authentication → Sign In / Providers → „Allow anonymous sign-ins“.
-- Ausführen: Supabase → SQL Editor → diesen Text einfügen → Run. Mehrfach ausführen schadet nicht.
--
-- Was das macht
-- * Ein angemeldetes Gerät erzeugt einen Kopplungscode (8 Zeichen, 10 Minuten gültig, nur einmal nutzbar).
-- * Das neue Gerät meldet sich ohne E-Mail als „Gerät“ an und löst den Code ein. Es wird Mitglied des Ladens
--   mit derselben Rolle wie das Gerät, das den Code erzeugt hat.
-- * Geräte erscheinen im Team als „Gerät: …“ und können vom Admin entfernt werden.
-- * Schutz: höchstens 5 falsche Versuche je Gerät in 10 Minuten. Falscher Code liefert null.

alter table memberships add column if not exists label text;

create table if not exists pair_codes (
  code text primary key,
  tenant_id uuid not null references tenants(id) on delete cascade,
  role text not null,
  created_by uuid,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '10 minutes',
  used_at timestamptz,
  used_by uuid
);
create table if not exists pair_attempts (user_id uuid not null, at timestamptz not null default now());
alter table pair_codes enable row level security;
alter table pair_attempts enable row level security;

create or replace function pair_create() returns text
language plpgsql security definer set search_path = public as $$
declare m record; a text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; b bytea := decode(replace(gen_random_uuid()::text, '-', ''), 'hex'); c text := ''; i int;
begin
  select tenant_id, role into m from memberships where user_id = auth.uid() limit 1;
  if m.tenant_id is null then raise exception 'FYF_DENIED'; end if;
  for i in 0..7 loop c := c || substr(a, (get_byte(b, i) % 32) + 1, 1); end loop;
  delete from pair_codes where created_by = auth.uid() and used_at is null;
  delete from pair_codes where expires_at < now() - interval '1 day';
  insert into pair_codes(code, tenant_id, role, created_by) values (c, m.tenant_id, m.role, auth.uid());
  perform fyf_audit(m.tenant_id, 'pair_create', jsonb_build_object('role', m.role));
  return c;
end $$;

create or replace function pair_redeem(p_code text, p_label text) returns uuid
language plpgsql security definer set search_path = public as $$
declare c text := upper(regexp_replace(coalesce(p_code, ''), '[^A-Za-z0-9]', '', 'g')); p record; t uuid;
begin
  if auth.uid() is null then raise exception 'FYF_DENIED'; end if;
  select tenant_id into t from memberships where user_id = auth.uid() limit 1;
  if t is not null then return t; end if;
  if (select count(*) from pair_attempts where user_id = auth.uid() and at > now() - interval '10 minutes') >= 5 then raise exception 'FYF_RATE'; end if;
  select * into p from pair_codes where code = c and used_at is null and expires_at > now() for update;
  if p.code is null then insert into pair_attempts(user_id) values (auth.uid()); return null; end if;  -- falscher Code: null (Versuch bleibt gezählt)
  insert into memberships(user_id, tenant_id, role, label) values (auth.uid(), p.tenant_id, p.role, left(coalesce(nullif(trim(p_label), ''), 'Gerät'), 40));
  update pair_codes set used_at = now(), used_by = auth.uid() where code = c;
  perform fyf_audit(p.tenant_id, 'pair_join', jsonb_build_object('role', p.role, 'label', p_label));
  return p.tenant_id;
end $$;

-- Team-Liste: Geräte ohne E-Mail mit ihrem Namen zeigen
create or replace function list_members(p_tenant uuid) returns table(user_id uuid, email text, role text, is_me boolean)
language sql stable security definer set search_path = public, auth as $$
  select m.user_id, coalesce(u.email::text, 'Gerät: ' || coalesce(m.label, 'ohne Namen')), m.role, m.user_id = auth.uid()
  from memberships m join auth.users u on u.id = m.user_id
  where m.tenant_id = p_tenant and is_member(p_tenant)
  order by (m.role = 'admin') desc, u.email nulls last;
$$;

revoke all on function pair_create() from public, anon;
revoke all on function pair_redeem(text, text) from public, anon;
grant execute on function pair_create(), pair_redeem(text, text) to authenticated;

-- ===================== ausbau.sql =====================
-- FYF – Fit your Frame · Terminwünsche und Kundenportal per Link (Schritt 7)
-- Voraussetzung: start.sql, team.sql, netz.sql wurden schon ausgeführt.
-- Ausführen: Supabase → SQL Editor → diesen Text einfügen → Run. Mehrfach ausführen schadet nicht.
--
-- Was das macht
-- 1. Anfragen bekommen einen Wunschtermin (Feld „preferred“). Die öffentliche Seite schickt ihn mit.
-- 2. Kundenportal per persönlichem Link: Der Laden stellt für einen Kunden eine Übersicht bereit
--    (Fahrräder, Einstellungen, Fitting-Ergebnisse, Empfehlungen, nächste Termine). Zufälliger Schlüssel,
--    180 Tage gültig, jederzeit widerrufbar. Ohne Kunden-Konto.

alter table inquiries add column if not exists preferred text;

drop function if exists submit_inquiry(text, text, text, text, text, text, text);
create or replace function submit_inquiry(p_slug text, p_topic text, p_name text, p_contact text, p_message text, p_product text default null, p_hp text default '', p_pref text default null) returns boolean
language plpgsql security definer set search_path = public as $$
declare t uuid; c text := lower(trim(coalesce(p_contact, '')));
begin
  if coalesce(p_hp, '') <> '' then return true; end if;
  select tenant_id into t from dealer_profiles where slug = p_slug and published;
  if t is null then raise exception 'FYF_NOT_FOUND'; end if;
  if length(trim(coalesce(p_name, ''))) < 2 or length(c) < 5 or length(trim(coalesce(p_message, ''))) < 5 then raise exception 'FYF_BAD_DATA'; end if;
  if length(p_name) > 100 or length(c) > 120 or length(p_message) > 2000 or length(coalesce(p_topic, '')) > 60 or length(coalesce(p_pref, '')) > 200 then raise exception 'FYF_TOO_LONG'; end if;
  if (select count(*) from inquiries where tenant_id = t and created_at > now() - interval '1 hour') >= 20 then raise exception 'FYF_RATE'; end if;
  if (select count(*) from inquiries where tenant_id = t and lower(contact) = c and created_at > now() - interval '1 day') >= 3 then raise exception 'FYF_RATE'; end if;
  insert into inquiries(tenant_id, topic, product_id, name, contact, message, preferred)
    values (t, coalesce(nullif(trim(p_topic), ''), 'Allgemein'), left(p_product, 60), trim(p_name), trim(p_contact), trim(p_message), nullif(trim(coalesce(p_pref, '')), ''));
  return true;
end $$;
grant execute on function submit_inquiry(text, text, text, text, text, text, text, text) to anon, authenticated;

create table if not exists portal_links (
  token text primary key,
  tenant_id uuid not null references tenants(id) on delete cascade,
  customer_id text not null,
  payload jsonb not null,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '180 days',
  revoked boolean not null default false,
  opened_at timestamptz
);
create index if not exists portal_links_t on portal_links (tenant_id, customer_id);
alter table portal_links enable row level security;
drop policy if exists portal_read on portal_links;
create policy portal_read on portal_links for select using (is_member(tenant_id));
grant select on portal_links to authenticated;

create or replace function portal_publish(p_tenant uuid, p_customer text, p_payload jsonb) returns text
language plpgsql security definer set search_path = public as $$
declare tk text := replace(gen_random_uuid()::text, '-', '');
begin
  if not is_member(p_tenant) then raise exception 'FYF_DENIED'; end if;
  if p_payload is null or jsonb_typeof(p_payload) <> 'object' or length(p_payload::text) > 60000 then raise exception 'FYF_BAD_DATA'; end if;
  update portal_links set revoked = true where tenant_id = p_tenant and customer_id = p_customer and not revoked;
  insert into portal_links(token, tenant_id, customer_id, payload) values (tk, p_tenant, left(p_customer, 60), p_payload);
  perform fyf_audit(p_tenant, 'portal_publish', jsonb_build_object('customer', p_customer));
  return tk;
end $$;

create or replace function portal_revoke(p_tenant uuid, p_customer text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not is_member(p_tenant) then raise exception 'FYF_DENIED'; end if;
  update portal_links set revoked = true where tenant_id = p_tenant and customer_id = p_customer and not revoked;
  perform fyf_audit(p_tenant, 'portal_revoke', jsonb_build_object('customer', p_customer));
end $$;

create or replace function portal_get(p_token text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare k record;
begin
  if length(coalesce(p_token, '')) <> 32 then return null; end if;
  select * into k from portal_links where token = p_token and not revoked and expires_at > now();
  if k.token is null then return null; end if;
  if k.opened_at is null then update portal_links set opened_at = now() where token = p_token; end if;
  return k.payload;
end $$;

revoke all on function portal_publish(uuid, text, jsonb) from public, anon;
revoke all on function portal_revoke(uuid, text) from public, anon;
grant execute on function portal_publish(uuid, text, jsonb), portal_revoke(uuid, text) to authenticated;
grant execute on function portal_get(text) to anon, authenticated;

-- ===================== feedback.sql =====================
-- FYF – Fit your Frame · Kunden-Feedback über den Kundenportal-Link (Stand 8)
-- Der Kunde bewertet sein Fitting (0–10) und schreibt kurz, wie es sich fährt – ohne Konto, über seinen persönlichen Link.
-- Die App holt neue Rückmeldungen ab und hängt sie an das letzte Fitting des Kunden.

create table if not exists portal_feedback (
  id bigserial primary key,
  token text not null,
  tenant_id uuid not null references tenants(id) on delete cascade,
  customer_id text not null,
  score int not null check (score between 0 and 10),
  body text,
  created_at timestamptz not null default now(),
  imported boolean not null default false
);
create index if not exists portal_feedback_t on portal_feedback (tenant_id, imported);
alter table portal_feedback enable row level security;
drop policy if exists portal_feedback_read on portal_feedback;
create policy portal_feedback_read on portal_feedback for select using (is_member(tenant_id));

create or replace function portal_feedback_send(p_token text, p_score int, p_text text) returns boolean
language plpgsql security definer set search_path = public as $$
declare k record;
begin
  if length(coalesce(p_token, '')) <> 32 then return false; end if;
  select * into k from portal_links where token = p_token and not revoked and expires_at > now();
  if k.token is null then return false; end if;
  if p_score is null or p_score < 0 or p_score > 10 then raise exception 'FYF_BAD_DATA'; end if;
  if length(coalesce(p_text, '')) > 1500 then raise exception 'FYF_TOO_LONG'; end if;
  if (select count(*) from portal_feedback where token = p_token and created_at > now() - interval '1 day') >= 3 then raise exception 'FYF_RATE'; end if;
  insert into portal_feedback(token, tenant_id, customer_id, score, body) values (p_token, k.tenant_id, k.customer_id, p_score, nullif(trim(coalesce(p_text, '')), ''));
  return true;
end $$;

create or replace function portal_feedback_take(p_tenant uuid) returns setof portal_feedback
language plpgsql security definer set search_path = public as $$
begin
  if not is_member(p_tenant) then raise exception 'FYF_DENIED'; end if;
  return query update portal_feedback set imported = true where tenant_id = p_tenant and not imported returning *;
end $$;

revoke all on function portal_feedback_take(uuid) from public, anon;
grant execute on function portal_feedback_take(uuid) to authenticated;
grant execute on function portal_feedback_send(text, int, text) to anon, authenticated;

-- ===================== werkstatt.sql =====================
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

-- ===================== pass.sql =====================
-- FYF – Fit your Frame · Live-Status für Werkstattaufträge und QR-Fahrradpass über alle Läden (Stand 10)
--
-- 1. Live-Status: Der Laden schickt dem Kunden einen Link. Der Kunde sieht, wo sein Rad steht
--    (Angenommen → In Arbeit → Abholbereit). Die App aktualisiert den Stand bei jedem Statuswechsel.
--    Zufälliger Schlüssel (32 Zeichen), gilt 90 Tage ab der letzten Änderung. Ohne Kunden-Konto.
-- 2. QR-Fahrradpass: Ein Aufkleber mit 8-stelligem Code am Rahmen. Der Laden stellt den Pass ein
--    (Fahrzeugdaten, Services, Teile, Gebrauchtrad-Check), ohne Name und Kontakt des Besitzers.
--    Sichtbarkeit wählt der Besitzer:
--      'public' – jeder, der den Code scannt, sieht den Pass (gut beim Verkauf)
--      'shops'  – voll sichtbar nur für geprüfte FYF-Läden und den ausstellenden Laden;
--                 alle anderen sehen nur, dass es einen Pass gibt, welcher Laden ihn führt und ob das Rad als gestohlen gemeldet ist.
--    Geprüfte FYF-Läden (tenants.verified) können Einträge ergänzen (z. B. „Kette getauscht“).
--    Der ausstellende Laden sieht diese Einträge und übernimmt sie in seinen Fahrradpass.

create table if not exists wo_status_links (
  token text primary key,
  tenant_id uuid not null references tenants(id) on delete cascade,
  wo_id text not null,
  payload jsonb not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  opened_at timestamptz,
  unique (tenant_id, wo_id)
);
alter table wo_status_links enable row level security;
drop policy if exists wo_status_read on wo_status_links;
create policy wo_status_read on wo_status_links for select using (is_member(tenant_id));
grant select on wo_status_links to authenticated;

create or replace function wo_status_publish(p_tenant uuid, p_wo text, p_payload jsonb) returns text
language plpgsql security definer set search_path = public as $$
declare tk text;
begin
  if not is_member(p_tenant) then raise exception 'FYF_DENIED'; end if;
  if p_payload is null or jsonb_typeof(p_payload) <> 'object' or length(p_payload::text) > 20000 or length(coalesce(p_wo, '')) not between 1 and 60 then raise exception 'FYF_BAD_DATA'; end if;
  insert into wo_status_links(token, tenant_id, wo_id, payload) values (replace(gen_random_uuid()::text, '-', ''), p_tenant, p_wo, p_payload)
    on conflict (tenant_id, wo_id) do update set payload = excluded.payload, updated_at = now()
    returning token into tk;
  return tk;
end $$;

create or replace function wo_status_revoke(p_tenant uuid, p_wo text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not is_member(p_tenant) then raise exception 'FYF_DENIED'; end if;
  delete from wo_status_links where tenant_id = p_tenant and wo_id = p_wo;
end $$;

create or replace function wo_status_get(p_token text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare k record;
begin
  if length(coalesce(p_token, '')) <> 32 then return null; end if;
  select * into k from wo_status_links where token = p_token and updated_at > now() - interval '90 days';
  if k.token is null then return null; end if;
  if k.opened_at is null then update wo_status_links set opened_at = now() where token = p_token; end if;
  return k.payload || jsonb_build_object('updated_at', k.updated_at);
end $$;

revoke all on function wo_status_publish(uuid, text, jsonb) from public, anon;
revoke all on function wo_status_revoke(uuid, text) from public, anon;
grant execute on function wo_status_publish(uuid, text, jsonb), wo_status_revoke(uuid, text) to authenticated;
grant execute on function wo_status_get(text) to anon, authenticated;

-- ---------- QR-Fahrradpass ----------
create table if not exists bike_passes (
  code text primary key check (code ~ '^[A-HJ-NP-Z2-9]{8}$'),
  tenant_id uuid not null references tenants(id) on delete cascade,
  bike_ref text not null,
  visibility text not null default 'shops' check (visibility in ('public','shops')),
  stolen boolean not null default false,
  payload jsonb not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id, bike_ref)
);
create table if not exists bike_pass_entries (
  id bigserial primary key,
  code text not null references bike_passes(code) on delete cascade,
  tenant_id uuid not null references tenants(id) on delete cascade,
  shop text not null,
  kind text not null,
  body text not null,
  km int,
  done_on date not null default current_date,
  created_at timestamptz not null default now()
);
create index if not exists bike_pass_entries_c on bike_pass_entries (code, created_at);
-- Kein direkter Zugriff: nur über die Funktionen unten.
alter table bike_passes enable row level security;
alter table bike_pass_entries enable row level security;

create or replace function fyf_pass_code() returns text
language plpgsql volatile set search_path = public as $$
declare a text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; b bytea; c text; i int;
begin
  loop
    b := decode(md5(gen_random_uuid()::text || clock_timestamp()::text), 'hex'); c := '';
    for i in 0..7 loop c := c || substr(a, 1 + (get_byte(b, i) % 32), 1); end loop;
    exit when not exists (select 1 from bike_passes where code = c);
  end loop;
  return c;
end $$;

create or replace function pass_publish(p_tenant uuid, p_bike text, p_payload jsonb, p_visibility text, p_stolen boolean) returns text
language plpgsql security definer set search_path = public as $$
declare c text;
begin
  if not is_member(p_tenant) then raise exception 'FYF_DENIED'; end if;
  if p_payload is null or jsonb_typeof(p_payload) <> 'object' or length(p_payload::text) > 40000 or length(coalesce(p_bike, '')) not between 1 and 60 then raise exception 'FYF_BAD_DATA'; end if;
  if p_visibility not in ('public','shops') then raise exception 'FYF_BAD_DATA'; end if;
  select code into c from bike_passes where tenant_id = p_tenant and bike_ref = p_bike;
  if c is null then
    if (select count(*) from bike_passes where tenant_id = p_tenant and created_at > now() - interval '1 day') >= 200 then raise exception 'FYF_RATE'; end if;
    c := fyf_pass_code();
    insert into bike_passes(code, tenant_id, bike_ref, visibility, stolen, payload) values (c, p_tenant, p_bike, p_visibility, coalesce(p_stolen, false), p_payload);
    perform fyf_audit(p_tenant, 'pass_create', jsonb_build_object('bike', p_bike, 'code', c));
  else
    update bike_passes set payload = p_payload, visibility = p_visibility, stolen = coalesce(p_stolen, false), updated_at = now() where code = c;
  end if;
  return c;
end $$;

create or replace function pass_delete(p_tenant uuid, p_bike text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not is_member(p_tenant) then raise exception 'FYF_DENIED'; end if;
  delete from bike_passes where tenant_id = p_tenant and bike_ref = p_bike;
  perform fyf_audit(p_tenant, 'pass_delete', jsonb_build_object('bike', p_bike));
end $$;

create or replace function pass_get(p_code text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare k record; c text := upper(regexp_replace(coalesce(p_code, ''), '[^A-Za-z0-9]', '', 'g')); full_view boolean; sh text;
begin
  if c !~ '^[A-HJ-NP-Z2-9]{8}$' then return null; end if;
  select * into k from bike_passes where code = c;
  if k.code is null then return null; end if;
  select name into sh from tenants where id = k.tenant_id;
  full_view := k.visibility = 'public' or is_member(k.tenant_id) or my_verified_tenant() is not null;
  if not full_view then
    return jsonb_build_object('code', c, 'limited', true, 'stolen', k.stolen,
      'bike', jsonb_build_object('name', k.payload->'bike'->>'name'),
      'shop', jsonb_build_object('name', coalesce(nullif(k.payload->'shop'->>'name', ''), sh), 'phone', k.payload->'shop'->>'phone'));
  end if;
  return k.payload || jsonb_build_object('shop', coalesce(k.payload->'shop', '{}'::jsonb) || jsonb_build_object('name', coalesce(nullif(k.payload->'shop'->>'name', ''), sh)), 'code', c, 'limited', false, 'stolen', k.stolen, 'visibility', k.visibility, 'updated_at', k.updated_at,
    'mine', is_member(k.tenant_id),
    'entries', coalesce((select jsonb_agg(jsonb_build_object('id', e.id, 'shop', e.shop, 'kind', e.kind, 'text', e.body, 'km', e.km, 'date', e.done_on) order by e.done_on desc, e.id desc)
                         from bike_pass_entries e where e.code = c), '[]'::jsonb));
end $$;

create or replace function pass_add(p_tenant uuid, p_code text, p_kind text, p_text text, p_km int, p_date date) returns bigint
language plpgsql security definer set search_path = public as $$
declare k record; sh text; v boolean; n bigint;
begin
  if not is_member(p_tenant) then raise exception 'FYF_DENIED'; end if;
  select * into k from bike_passes where code = upper(coalesce(p_code, ''));
  if k.code is null then raise exception 'FYF_NOT_FOUND'; end if;
  select name, verified into sh, v from tenants where id = p_tenant;
  if k.tenant_id <> p_tenant and not coalesce(v, false) then raise exception 'FYF_NOT_VERIFIED'; end if;
  if length(trim(coalesce(p_text, ''))) < 3 or length(p_text) > 500 or length(coalesce(p_kind, '')) not between 2 and 40 then raise exception 'FYF_BAD_DATA'; end if;
  if p_km is not null and (p_km < 0 or p_km > 1000000) then raise exception 'FYF_BAD_DATA'; end if;
  if p_date is not null and (p_date > current_date + 1 or p_date < current_date - 3650) then raise exception 'FYF_BAD_DATA'; end if;
  if (select count(*) from bike_pass_entries where tenant_id = p_tenant and created_at > now() - interval '1 day') >= 100 then raise exception 'FYF_RATE'; end if;
  insert into bike_pass_entries(code, tenant_id, shop, kind, body, km, done_on) values (k.code, p_tenant, coalesce(sh, 'Werkstatt'), trim(p_kind), trim(p_text), p_km, coalesce(p_date, current_date)) returning id into n;
  perform fyf_audit(p_tenant, 'pass_add', jsonb_build_object('code', k.code));
  return n;
end $$;

revoke all on function fyf_pass_code() from public, anon, authenticated;
revoke all on function pass_publish(uuid, text, jsonb, text, boolean) from public, anon;
revoke all on function pass_delete(uuid, text) from public, anon;
revoke all on function pass_add(uuid, text, text, text, int, date) from public, anon;
grant execute on function pass_publish(uuid, text, jsonb, text, boolean), pass_delete(uuid, text), pass_add(uuid, text, text, text, int, date) to authenticated;
grant execute on function pass_get(text) to anon, authenticated;

-- ---------- Partner-Seite: welche FYF-Funktionen ein Laden anbietet ----------
-- Die App meldet automatisch, was der Laden wirklich nutzt (z. B. 'fitting', 'pass', 'status', 'usedcheck').
-- Die Händlersuche zeigt das als Abzeichen und Filter.
alter table dealer_profiles add column if not exists features text[] not null default '{}';

create or replace function profile_features(p_tenant uuid, p_features text[]) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not is_member(p_tenant) then raise exception 'FYF_DENIED'; end if;
  if coalesce(array_length(p_features, 1), 0) > 12 or exists (select 1 from unnest(coalesce(p_features, '{}')) f where f !~ '^[a-z]{2,20}$') then raise exception 'FYF_BAD_DATA'; end if;
  update dealer_profiles set features = coalesce(p_features, '{}') where tenant_id = p_tenant;
end $$;
revoke all on function profile_features(uuid, text[]) from public, anon;
grant execute on function profile_features(uuid, text[]) to authenticated;

-- ===================== passport.sql =====================
-- FYF – Fit your Frame · FYF Passport, Kern (Stand 11)
--
-- 1. Einträge im Fahrradpass sind unveränderlich. Korrekturen sind neue Einträge mit Verweis (corrects).
--    Jeder Eintrag hat Herkunft (Betrieb), Zeitstempel und Vertrauensstufe:
--      'verified' – eingetragen von einem geprüften Betrieb (tenants.verified), egal ob mit FYF-Abo
--      'shop'     – eingetragen von einem Betrieb, der noch nicht geprüft ist
--      'self'     – Selbstauskunft des Besitzers (folgt mit dem Besitzer-Konto)
--    receipt = Beleg vorhanden (folgt mit der Beleg-Ablage).
-- 2. Fahrradschein nach dem Fahrzeugbrief-Prinzip: Der QR-Aufkleber (Teil I) ist öffentlich.
--    Teil II ist eine Karte mit einem geheimen Übergabe-Code. Gespeichert wird nur sein Hash.
--    Wer Teil II vorlegt, kann den Pass in einer Werkstatt auf den neuen Besitzer bzw. die neue Werkstatt übertragen.
--    Danach gilt der alte Code nicht mehr. Namen von Besitzern werden nie gespeichert – nur die Nummer (1., 2., …).
-- 3. Ein Laden kann seinen Pass nicht mehr löschen, nur zurückziehen (nicht mehr öffentlich). Die Geschichte bleibt erhalten.

alter table bike_pass_entries add column if not exists trust text not null default 'shop';
alter table bike_pass_entries add column if not exists receipt boolean not null default false;
alter table bike_pass_entries add column if not exists ref text;
alter table bike_pass_entries add column if not exists corrects bigint references bike_pass_entries(id);
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'bike_pass_entries_trust_chk') then
    alter table bike_pass_entries add constraint bike_pass_entries_trust_chk check (trust in ('verified','shop','self'));
  end if;
end $$;
-- Löscht ein Betrieb sein Konto, bleiben seine Einträge in fremden Pässen erhalten (Name des Betriebs steht im Eintrag).
alter table bike_pass_entries alter column tenant_id drop not null;
do $$ begin
  if exists (select 1 from pg_constraint where conname = 'bike_pass_entries_tenant_id_fkey' and confdeltype = 'c') then
    alter table bike_pass_entries drop constraint bike_pass_entries_tenant_id_fkey;
    alter table bike_pass_entries add constraint bike_pass_entries_tenant_id_fkey foreign key (tenant_id) references tenants(id) on delete set null;
  end if;
end $$;
create unique index if not exists bike_pass_entries_ref on bike_pass_entries (code, tenant_id, ref) where ref is not null;

alter table bike_passes add column if not exists transfer_hash text;
alter table bike_passes add column if not exists owner_no int not null default 1;
alter table bike_passes add column if not exists owner_since date not null default current_date;
alter table bike_passes add column if not exists withdrawn_at timestamptz;
-- Was der Besitzer selbst (mit Teil II) eingestellt hat, gilt vor der Einstellung des Ladens – bis einer von beiden es wieder ändert.
alter table bike_passes add column if not exists owner_vis text check (owner_vis in ('public','shops'));
alter table bike_passes add column if not exists owner_stolen boolean;
-- Selbst registrierte Räder (ohne Laden): tenant_id/bike_ref leer, bis eine Werkstatt den Pass mit Teil II übernimmt.
alter table bike_passes alter column tenant_id drop not null;
alter table bike_passes alter column bike_ref drop not null;
-- Diebstahl-Abgleich: nur der Hash der Rahmennummer (nie die Nummer selbst)
alter table bike_passes add column if not exists frame_hash text check (frame_hash ~ '^[0-9a-f]{64}$');
create index if not exists bike_passes_fh on bike_passes (frame_hash) where frame_hash is not null;
alter table bike_passes add column if not exists owner_fails int not null default 0;
alter table bike_passes add column if not exists owner_fail_at timestamptz;

-- Räder, deren Pass an einen anderen Besitzer / eine andere Werkstatt übergeben wurde (der alte Laden darf nicht mehr schreiben)
create table if not exists bike_pass_moved (
  tenant_id uuid not null references tenants(id) on delete cascade,
  bike_ref text not null,
  code text not null references bike_passes(code) on delete cascade,
  moved_at timestamptz not null default now(),
  primary key (tenant_id, bike_ref)
);
alter table bike_pass_moved enable row level security;

-- Unveränderlich: kein Ändern, kein Löschen (außer automatisch, wenn ein ganzer Betrieb gelöscht wird)
create or replace function fyf_pass_entries_lock() returns trigger
language plpgsql as $$
begin
  if pg_trigger_depth() < 2 then raise exception 'FYF_LOCKED'; end if;
  return case when tg_op = 'DELETE' then old else new end;
end $$;
drop trigger if exists bike_pass_entries_lock on bike_pass_entries;
create trigger bike_pass_entries_lock before update or delete on bike_pass_entries for each row execute function fyf_pass_entries_lock();

create or replace function pass_entry(p_tenant uuid, p_code text, p_kind text, p_text text, p_km int, p_date date, p_ref text, p_corrects bigint) returns bigint
language plpgsql security definer set search_path = public as $$
declare k record; sh text; v boolean; n bigint;
begin
  if not is_member(p_tenant) then raise exception 'FYF_DENIED'; end if;
  select * into k from bike_passes where code = upper(coalesce(p_code, ''));
  if k.code is null then raise exception 'FYF_NOT_FOUND'; end if;
  if k.withdrawn_at is not null then raise exception 'FYF_WITHDRAWN'; end if;
  select name, verified into sh, v from tenants where id = p_tenant;
  if k.tenant_id is distinct from p_tenant and not coalesce(v, false) then raise exception 'FYF_NOT_VERIFIED'; end if;
  if p_ref is not null then
    if length(p_ref) > 60 then raise exception 'FYF_BAD_DATA'; end if;
    select id into n from bike_pass_entries where code = k.code and tenant_id = p_tenant and ref = p_ref;
    if n is not null then return n; end if;
  end if;
  if length(trim(coalesce(p_text, ''))) < 3 or length(p_text) > 500 or length(coalesce(p_kind, '')) not between 2 and 40 then raise exception 'FYF_BAD_DATA'; end if;
  if p_km is not null and (p_km < 0 or p_km > 1000000) then raise exception 'FYF_BAD_DATA'; end if;
  if p_date is not null and (p_date > current_date + 1 or p_date < current_date - 7300) then raise exception 'FYF_BAD_DATA'; end if;
  if p_corrects is not null and not exists (select 1 from bike_pass_entries where id = p_corrects and code = k.code) then raise exception 'FYF_BAD_DATA'; end if;
  if (select count(*) from bike_pass_entries where tenant_id = p_tenant and created_at > now() - interval '1 day') >= 500 then raise exception 'FYF_RATE'; end if;
  insert into bike_pass_entries(code, tenant_id, shop, kind, body, km, done_on, trust, ref, corrects)
    values (k.code, p_tenant, coalesce(sh, 'Werkstatt'), trim(p_kind), trim(p_text), p_km, coalesce(p_date, current_date), case when coalesce(v, false) then 'verified' else 'shop' end, p_ref, p_corrects)
    returning id into n;
  return n;
end $$;

-- Alte Funktion bleibt (App v.79), läuft jetzt über pass_entry
create or replace function pass_add(p_tenant uuid, p_code text, p_kind text, p_text text, p_km int, p_date date) returns bigint
language plpgsql security definer set search_path = public as $$
begin
  return pass_entry(p_tenant, p_code, p_kind, p_text, p_km, p_date, null, null);
end $$;

create or replace function pass_publish(p_tenant uuid, p_bike text, p_payload jsonb, p_visibility text, p_stolen boolean) returns text
language plpgsql security definer set search_path = public as $$
declare c text; fh text; pl jsonb;
begin
  if not is_member(p_tenant) then raise exception 'FYF_DENIED'; end if;
  if p_payload is null or jsonb_typeof(p_payload) <> 'object' or length(p_payload::text) > 40000 or length(coalesce(p_bike, '')) not between 1 and 60 then raise exception 'FYF_BAD_DATA'; end if;
  if p_visibility not in ('public','shops') then raise exception 'FYF_BAD_DATA'; end if;
  if exists (select 1 from bike_pass_moved where tenant_id = p_tenant and bike_ref = p_bike) then raise exception 'FYF_PASS_MOVED'; end if;
  fh := nullif(p_payload->>'fh', ''); if fh is not null and fh !~ '^[0-9a-f]{64}$' then raise exception 'FYF_BAD_DATA'; end if; pl := p_payload - 'fh';
  select code into c from bike_passes where tenant_id = p_tenant and bike_ref = p_bike;
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

-- „Löschen“ zieht den Pass nur zurück: nicht mehr sichtbar, keine neuen Einträge, Geschichte bleibt.
create or replace function pass_delete(p_tenant uuid, p_bike text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not is_member(p_tenant) then raise exception 'FYF_DENIED'; end if;
  update bike_passes set withdrawn_at = now(), updated_at = now() where tenant_id = p_tenant and bike_ref = p_bike;
  perform fyf_audit(p_tenant, 'pass_withdraw', jsonb_build_object('bike', p_bike));
end $$;

create or replace function fyf_transfer_code() returns text
language plpgsql volatile set search_path = public as $$
declare a text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; b bytea := decode(md5(gen_random_uuid()::text) || md5(gen_random_uuid()::text), 'hex'); c text := ''; i int;
begin
  for i in 0..11 loop c := c || substr(a, 1 + (get_byte(b, i) % 32), 1); end loop;
  return c;
end $$;

-- Neuer Übergabe-Code (Teil II). Gilt ab sofort; eine früher gedruckte Karte wird ungültig.
create or replace function pass_transfer_new(p_tenant uuid, p_bike text) returns text
language plpgsql security definer set search_path = public as $$
declare c text; t text;
begin
  if not is_member(p_tenant) then raise exception 'FYF_DENIED'; end if;
  select code into c from bike_passes where tenant_id = p_tenant and bike_ref = p_bike and withdrawn_at is null;
  if c is null then raise exception 'FYF_NOT_FOUND'; end if;
  t := fyf_transfer_code();
  update bike_passes set transfer_hash = encode(sha256(convert_to(t, 'UTF8')), 'hex'), updated_at = now() where code = c;
  perform fyf_audit(p_tenant, 'pass_transfer_new', jsonb_build_object('code', c));
  return t;
end $$;

-- Besitzerwechsel / Werkstattwechsel mit Teil II. Der Pass hängt danach an p_bike des Ladens p_tenant.
create or replace function pass_handover(p_tenant uuid, p_code text, p_transfer text, p_bike text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare k record; t text := upper(regexp_replace(coalesce(p_transfer, ''), '[^A-Za-z0-9]', '', 'g')); nt text; sh text; v boolean;
begin
  if not is_member(p_tenant) then raise exception 'FYF_DENIED'; end if;
  if length(coalesce(p_bike, '')) not between 1 and 60 then raise exception 'FYF_BAD_DATA'; end if;
  if (select count(*) from audit_log where tenant_id = p_tenant and action = 'pass_handover_fail' and at > now() - interval '1 day') >= 20 then raise exception 'FYF_RATE'; end if;
  select * into k from bike_passes where code = upper(coalesce(p_code, ''));
  if k.code is null then raise exception 'FYF_NOT_FOUND'; end if;
  if k.withdrawn_at is not null then raise exception 'FYF_WITHDRAWN'; end if;
  -- Ein als gestohlen gemeldetes Rad kann nicht übergeben werden (sonst ließe sich die Meldung „waschen“).
  if coalesce(k.owner_stolen, k.stolen) then raise exception 'FYF_STOLEN'; end if;
  if k.transfer_hash is null or encode(sha256(convert_to(t, 'UTF8')), 'hex') <> k.transfer_hash then
    perform fyf_audit(p_tenant, 'pass_handover_fail', jsonb_build_object('code', k.code));
    return jsonb_build_object('error', 'FYF_BAD_TRANSFER'); -- kein raise, damit der Fehlversuch gezählt bleibt
  end if;
  if (k.tenant_id is distinct from p_tenant or k.bike_ref is distinct from p_bike) and exists (select 1 from bike_passes where tenant_id = p_tenant and bike_ref = p_bike) then raise exception 'FYF_BIKE_HAS_PASS'; end if;
  if k.tenant_id is not null and (k.tenant_id <> p_tenant or k.bike_ref <> p_bike) then
    insert into bike_pass_moved(tenant_id, bike_ref, code) values (k.tenant_id, k.bike_ref, k.code) on conflict (tenant_id, bike_ref) do update set code = excluded.code, moved_at = now();
    delete from bike_pass_moved where tenant_id = p_tenant and bike_ref = p_bike;
  end if;
  nt := fyf_transfer_code();
  update bike_passes set tenant_id = p_tenant, bike_ref = p_bike, owner_no = owner_no + 1, owner_since = current_date,
    transfer_hash = encode(sha256(convert_to(nt, 'UTF8')), 'hex'), owner_vis = null, owner_stolen = null, updated_at = now() where code = k.code;
  select name, verified into sh, v from tenants where id = p_tenant;
  insert into bike_pass_entries(code, tenant_id, shop, kind, body, done_on, trust)
    values (k.code, p_tenant, coalesce(sh, 'Werkstatt'), 'Besitzerwechsel', 'Besitzer ' || (k.owner_no + 1) || ' übernimmt das Rad (Übergabe-Code geprüft)', current_date, case when coalesce(v, false) then 'verified' else 'shop' end);
  perform fyf_audit(p_tenant, 'pass_handover', jsonb_build_object('code', k.code, 'owner_no', k.owner_no + 1));
  return jsonb_build_object('code', k.code, 'transfer', nt, 'owner_no', k.owner_no + 1, 'payload', k.payload, 'was_stolen', false);
end $$;

create or replace function pass_get(p_code text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare k record; c text := upper(regexp_replace(coalesce(p_code, ''), '[^A-Za-z0-9]', '', 'g')); full_view boolean; sh text;
begin
  if c !~ '^[A-HJ-NP-Z2-9]{8}$' then return null; end if;
  select * into k from bike_passes where code = c;
  if k.code is null then return null; end if;
  select name into sh from tenants where id = k.tenant_id;
  k.stolen := coalesce(k.owner_stolen, k.stolen); k.visibility := coalesce(k.owner_vis, k.visibility);
  if k.withdrawn_at is not null and not is_member(k.tenant_id) then
    return jsonb_build_object('code', c, 'limited', true, 'withdrawn', true, 'stolen', k.stolen, 'bike', jsonb_build_object('name', k.payload->'bike'->>'name'),
      'shop', jsonb_build_object('name', coalesce(nullif(k.payload->'shop'->>'name', ''), sh), 'phone', k.payload->'shop'->>'phone'));
  end if;
  full_view := k.visibility = 'public' or is_member(k.tenant_id) or my_verified_tenant() is not null;
  if not full_view then
    return jsonb_build_object('code', c, 'limited', true, 'stolen', k.stolen, 'owner_no', k.owner_no, 'self', k.tenant_id is null,
      'bike', jsonb_build_object('name', k.payload->'bike'->>'name'),
      'shop', jsonb_build_object('name', coalesce(nullif(k.payload->'shop'->>'name', ''), sh), 'phone', k.payload->'shop'->>'phone'));
  end if;
  return k.payload || jsonb_build_object('shop', coalesce(k.payload->'shop', '{}'::jsonb) || jsonb_build_object('name', coalesce(nullif(k.payload->'shop'->>'name', ''), sh)),
    'code', c, 'limited', false, 'stolen', k.stolen, 'visibility', k.visibility, 'updated_at', k.updated_at, 'created_at', k.created_at,
    'owner_no', k.owner_no, 'owner_since', k.owner_since, 'withdrawn', k.withdrawn_at is not null, 'has_transfer', k.transfer_hash is not null,
    'mine', is_member(k.tenant_id),
    'entries', coalesce((select jsonb_agg(jsonb_build_object('id', e.id, 'shop', e.shop, 'kind', e.kind, 'text', e.body, 'km', e.km, 'date', e.done_on,
                           'trust', e.trust, 'receipt', e.receipt, 'corrects', e.corrects, 'at', e.created_at) order by e.done_on desc, e.id desc)
                         from bike_pass_entries e where e.code = c), '[]'::jsonb));
end $$;

revoke all on function fyf_pass_entries_lock() from public, anon, authenticated;
revoke all on function fyf_transfer_code() from public, anon, authenticated;
revoke all on function pass_entry(uuid, text, text, text, int, date, text, bigint) from public, anon;
revoke all on function pass_transfer_new(uuid, text) from public, anon;
revoke all on function pass_handover(uuid, text, text, text) from public, anon;
grant execute on function pass_entry(uuid, text, text, text, int, date, text, bigint), pass_transfer_new(uuid, text), pass_handover(uuid, text, text, text) to authenticated;
grant execute on function pass_get(text) to anon, authenticated;


-- ---------- Besitzer-Funktionen mit Teil II (ohne Konto) ----------
-- Wer den Übergabe-Code kennt, ist der Besitzer: Sichtbarkeit wählen, Diebstahl melden/aufheben, Selbstauskunft eintragen.
-- Nach 10 falschen Codes pro Pass und Tag ist für 24 Stunden Schluss.
create or replace function pass_owner(p_code text, p_transfer text, p_action text, p_value jsonb) returns jsonb
language plpgsql security definer set search_path = public as $$
declare k record; c text := upper(regexp_replace(coalesce(p_code, ''), '[^A-Za-z0-9]', '', 'g')); t text := upper(regexp_replace(coalesce(p_transfer, ''), '[^A-Za-z0-9]', '', 'g')); n bigint; d date; km int; txt text; kind text;
begin
  select * into k from bike_passes where code = c;
  if k.code is null or k.withdrawn_at is not null then return jsonb_build_object('error', 'FYF_NOT_FOUND'); end if;
  if k.owner_fails >= 10 and k.owner_fail_at > now() - interval '1 day' then return jsonb_build_object('error', 'FYF_RATE'); end if;
  if k.transfer_hash is null or encode(sha256(convert_to(t, 'UTF8')), 'hex') <> k.transfer_hash then
    update bike_passes set owner_fails = case when owner_fail_at > now() - interval '1 day' then owner_fails + 1 else 1 end, owner_fail_at = now() where code = c;
    return jsonb_build_object('error', 'FYF_BAD_TRANSFER');
  end if;
  if p_action = 'vis' then
    if p_value->>'v' not in ('public','shops') then return jsonb_build_object('error', 'FYF_BAD_DATA'); end if;
    update bike_passes set owner_vis = p_value->>'v', updated_at = now() where code = c;
  elsif p_action = 'stolen' then
    update bike_passes set owner_stolen = coalesce((p_value->>'v')::boolean, false), updated_at = now() where code = c;
    insert into bike_pass_entries(code, tenant_id, shop, kind, body, done_on, trust)
      values (c, null, 'Besitzer', case when coalesce((p_value->>'v')::boolean, false) then 'Diebstahl gemeldet' else 'Diebstahlmeldung aufgehoben' end,
              case when coalesce((p_value->>'v')::boolean, false) then 'Vom Besitzer als gestohlen gemeldet' else 'Vom Besitzer aufgehoben – Rad ist wieder da' end, current_date, 'self');
  elsif p_action = 'entry' then
    kind := trim(coalesce(p_value->>'kind', '')); txt := trim(coalesce(p_value->>'text', ''));
    km := nullif(p_value->>'km', '')::int; d := coalesce(nullif(p_value->>'date', '')::date, current_date);
    if length(txt) < 3 or length(txt) > 500 or length(kind) not between 2 and 40 or (km is not null and (km < 0 or km > 1000000)) or d > current_date + 1 or d < current_date - 7300 then return jsonb_build_object('error', 'FYF_BAD_DATA'); end if;
    if (select count(*) from bike_pass_entries where code = c and trust = 'self' and created_at > now() - interval '1 day') >= 20 then return jsonb_build_object('error', 'FYF_RATE'); end if;
    insert into bike_pass_entries(code, tenant_id, shop, kind, body, km, done_on, trust) values (c, null, 'Besitzer', kind, txt, km, d, 'self') returning id into n;
  elsif p_action <> 'check' then
    return jsonb_build_object('error', 'FYF_BAD_DATA');
  end if;
  select * into k from bike_passes where code = c;
  return jsonb_build_object('ok', true, 'visibility', coalesce(k.owner_vis, k.visibility), 'stolen', coalesce(k.owner_stolen, k.stolen), 'owner_no', k.owner_no);
exception when invalid_text_representation or datetime_field_overflow or numeric_value_out_of_range then
  return jsonb_build_object('error', 'FYF_BAD_DATA');
end $$;
revoke all on function pass_owner(text, text, text, jsonb) from public;
grant execute on function pass_owner(text, text, text, jsonb) to anon, authenticated;


-- ---------- Rad selbst registrieren (Besitzer, ohne Laden) ----------
-- Gibt Pass-Code und Übergabe-Code zurück. Eine bereits registrierte Rahmennummer wird abgelehnt (auch gegen das „Neuanmelden“ gestohlener Räder).
create or replace function pass_register(p_payload jsonb, p_fh text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare c text; t text;
begin
  if p_payload is null or jsonb_typeof(p_payload) <> 'object' or length(p_payload::text) > 6000 or length(coalesce(p_payload->'bike'->>'name', '')) not between 2 and 120 then return jsonb_build_object('error', 'FYF_BAD_DATA'); end if;
  if coalesce(p_fh, '') !~ '^[0-9a-f]{64}$' then return jsonb_build_object('error', 'FYF_BAD_DATA'); end if;
  if exists (select 1 from bike_passes where frame_hash = p_fh) then return jsonb_build_object('error', 'FYF_FRAME_EXISTS'); end if;
  if (select count(*) from bike_passes where tenant_id is null and created_at > now() - interval '1 day') >= 300 then return jsonb_build_object('error', 'FYF_RATE'); end if;
  c := fyf_pass_code(); t := fyf_transfer_code();
  insert into bike_passes(code, tenant_id, bike_ref, visibility, stolen, payload, frame_hash, transfer_hash)
    values (c, null, null, 'shops', false, (p_payload - 'fh') || jsonb_build_object('self', true, 'shop', jsonb_build_object('name', '')), p_fh, encode(sha256(convert_to(t, 'UTF8')), 'hex'));
  insert into bike_pass_entries(code, tenant_id, shop, kind, body, done_on, trust) values (c, null, 'Besitzer', 'Registrierung', 'Rad vom Besitzer registriert', current_date, 'self');
  return jsonb_build_object('code', c, 'transfer', t);
end $$;

-- ---------- Diebstahl-Abgleich bei der Annahme (nur Werkstätten) ----------
create or replace function frame_check(p_tenant uuid, p_fh text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare k record; sh text;
begin
  if not is_member(p_tenant) then raise exception 'FYF_DENIED'; end if;
  if coalesce(p_fh, '') !~ '^[0-9a-f]{64}$' then return jsonb_build_object('found', false); end if;
  if (select count(*) from audit_log where tenant_id = p_tenant and action = 'frame_check' and at > now() - interval '1 day') >= 300 then raise exception 'FYF_RATE'; end if;
  perform fyf_audit(p_tenant, 'frame_check', null);
  select * into k from bike_passes where frame_hash = p_fh and withdrawn_at is null order by coalesce(owner_stolen, stolen) desc, updated_at desc limit 1;
  if k.code is null then return jsonb_build_object('found', false); end if;
  select name into sh from tenants where id = k.tenant_id;
  if coalesce(k.owner_stolen, k.stolen) then
    perform fyf_audit(p_tenant, 'frame_check_stolen', jsonb_build_object('code', k.code));
    return jsonb_build_object('found', true, 'stolen', true, 'code', k.code, 'mine', is_member(k.tenant_id),
      'shop', coalesce(nullif(k.payload->'shop'->>'name', ''), sh, 'vom Besitzer registriert'), 'phone', k.payload->'shop'->>'phone');
  end if;
  return jsonb_build_object('found', true, 'stolen', false, 'mine', is_member(k.tenant_id));
end $$;
revoke all on function pass_register(jsonb, text) from public;
grant execute on function pass_register(jsonb, text) to anon, authenticated;
revoke all on function frame_check(uuid, text) from public, anon;
grant execute on function frame_check(uuid, text) to authenticated;

-- ===================== Stand der Datenbank (für die Prüfung in der App) =====================
create or replace function fyf_schema() returns int language sql immutable as $$ select 13 $$;
grant execute on function fyf_schema() to anon, authenticated;
