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
