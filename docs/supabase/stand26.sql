-- FYF – Stand 26 (21.11.2026): Die vier weiteren Rollen sind jetzt vergebbar und auf dem Server gefiltert (Weg A).
-- Bisher: Werkstattleitung, Verkauf, Filialleitung und Buchhaltung gab es nur in der Tabelle memberships (plattform.sql),
-- Einladen und Rolle-Ändern ließen aber nur admin/fitter/mitarbeiter zu.
-- Jetzt:
--  * invite_member() und set_member_role() nehmen alle 7 Rollen an; die Einladungs-Tabelle ebenfalls.
--  * fyf_hidden_keys(): was der Server je Rolle NICHT ausliefert (state_get) und beim Speichern unverändert lässt (save_state):
--      mitarbeiter       – wie bisher: Rechnungen, Nummernkreis, Zahlungen, Verkäufe, Bestellungen, Lieferanten, DATEV, Mahnwesen
--      werkstattleitung  – Rechnungen, Nummernkreis, Zahlungen, Verkäufe, DATEV, Mahnwesen (Lager, Bestellungen, Lieferanten sichtbar)
--      verkauf           – DATEV, Mahnwesen (Rechnungen sichtbar, damit Neurad-Verkauf und Kasse gehen)
--      filialleitung, buchhaltung, fitter, admin – nichts verborgen
--  * Den ersten Datenstand eines Ladens legt nur eine Rolle ohne verborgene Teile an.
--  * Bestehende Rechnungen bleiben für alle Rollen unveränderlich (fyf_guard aus team.sql, unverändert).
-- Körper-/Gesundheitsdaten: werden in diesem Schritt für keine Rolle ausgeblendet (wie Entscheidung „Mitarbeiter sieht sie“).
-- Rückweg: fyf_hidden_keys() wie in stand25.sql zurücksetzen → neue Rollen sehen dann alles; Rollen bleiben vergebbar.

alter table invitations drop constraint if exists invitations_role_check;
alter table invitations add constraint invitations_role_check
  check (role in ('admin','fitter','mitarbeiter','werkstattleitung','verkauf','filialleitung','buchhaltung'));

create or replace function fyf_roles() returns text[] language sql immutable as $$
  select array['admin','fitter','mitarbeiter','werkstattleitung','verkauf','filialleitung','buchhaltung'];
$$;

create or replace function fyf_hidden_keys(p_role text) returns text[]
language sql immutable as $$
  select case p_role
    when 'mitarbeiter' then array['invoices','invSeq','payments','sales','purchaseOrders','suppliers','datev','dunCfg']
    when 'werkstattleitung' then array['invoices','invSeq','payments','sales','datev','dunCfg']
    when 'verkauf' then array['datev','dunCfg']
    else array[]::text[] end;
$$;

create or replace function invite_member(p_tenant uuid, p_email text, p_role text) returns uuid
language plpgsql security definer set search_path = public, auth as $$
declare e text := lower(trim(coalesce(p_email, ''))); i uuid;
begin
  if not has_role(p_tenant, array['admin']) then raise exception 'FYF_DENIED'; end if;
  if p_role is null or not (p_role = any(fyf_roles())) then raise exception 'FYF_BAD_ROLE'; end if;
  if e !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then raise exception 'FYF_BAD_EMAIL'; end if;
  if exists (select 1 from memberships m join auth.users u on u.id = m.user_id where m.tenant_id = p_tenant and lower(u.email) = e)
    then raise exception 'FYF_ALREADY_MEMBER'; end if;
  insert into invitations(tenant_id, email, role, invited_by) values (p_tenant, e, p_role, auth.uid())
    on conflict (tenant_id, email) do update set role = excluded.role, invited_by = excluded.invited_by, created_at = now(), accepted_at = null, accepted_by = null
    returning id into i;
  perform fyf_audit(p_tenant, 'invite', jsonb_build_object('email', e, 'role', p_role));
  return i;
end $$;

create or replace function set_member_role(p_tenant uuid, p_user uuid, p_role text) returns void
language plpgsql security definer set search_path = public as $$
declare old text;
begin
  if not has_role(p_tenant, array['admin']) then raise exception 'FYF_DENIED'; end if;
  if p_role is null or not (p_role = any(fyf_roles())) then raise exception 'FYF_BAD_ROLE'; end if;
  select role into old from memberships where tenant_id = p_tenant and user_id = p_user for update;
  if old is null then raise exception 'FYF_NOT_FOUND'; end if;
  if old = 'admin' and p_role <> 'admin' and (select count(*) from memberships where tenant_id = p_tenant and role = 'admin') <= 1
    then raise exception 'FYF_LAST_ADMIN'; end if;
  update memberships set role = p_role where tenant_id = p_tenant and user_id = p_user;
  perform fyf_audit(p_tenant, 'role', jsonb_build_object('user', p_user, 'from', old, 'to', p_role));
end $$;

-- save_state wie in stand25.sql; einzige Änderung: ersten Stand legt nur eine Rolle ohne verborgene Teile an.
create or replace function save_state(p_tenant uuid, p_data jsonb, p_expected int) returns int
language plpgsql security definer set search_path = public as $$
declare v int; r text; old jsonb; why text; d jsonb := p_data;
begin
  if auth.uid() is null then raise exception 'FYF_DENIED'; end if;
  select role into r from memberships where user_id = auth.uid() and tenant_id = p_tenant;
  if r is null then raise exception 'FYF_DENIED'; end if;
  if d is null or jsonb_typeof(d) <> 'object' then raise exception 'FYF_BAD_DATA'; end if;
  select version, data into v, old from tenant_state where tenant_id = p_tenant for update;
  if v is null then
    if coalesce(p_expected, 0) <> 0 then raise exception 'FYF_CONFLICT 0'; end if;
    if cardinality(fyf_hidden_keys(r)) > 0 then raise exception 'FYF_ROLE Den ersten Stand legt Admin oder Fitter an'; end if;
    insert into tenant_state(tenant_id, data, version, updated_by) values (p_tenant, d, 1, auth.uid());
    perform fyf_audit(p_tenant, 'save', jsonb_build_object('version', 1));
    return 1;
  end if;
  if p_expected is distinct from v then raise exception 'FYF_CONFLICT %', v; end if;
  d := fyf_merge_hidden(r, old, d);
  why := fyf_guard(r, old, d);
  if why is not null then raise exception 'FYF_ROLE %', why; end if;
  insert into tenant_state_history(tenant_id, version, data, saved_by)
    select tenant_id, version, data, updated_by from tenant_state where tenant_id = p_tenant;
  delete from tenant_state_history h where h.tenant_id = p_tenant
    and h.id not in (select id from tenant_state_history where tenant_id = p_tenant order by version desc limit 30);
  update tenant_state set data = d, version = v + 1, updated_at = now(), updated_by = auth.uid() where tenant_id = p_tenant;
  perform fyf_audit(p_tenant, 'save', jsonb_build_object('version', v + 1));
  return v + 1;
end $$;
revoke all on function save_state(uuid, jsonb, int) from public, anon;
grant execute on function save_state(uuid, jsonb, int) to authenticated;
revoke all on function invite_member(uuid, text, text) from public, anon;
grant execute on function invite_member(uuid, text, text) to authenticated;
revoke all on function set_member_role(uuid, uuid, text) from public, anon;
grant execute on function set_member_role(uuid, uuid, text) to authenticated;
