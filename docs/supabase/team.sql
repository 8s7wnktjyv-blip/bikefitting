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
