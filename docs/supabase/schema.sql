-- FYF – Fit your Frame · Datenbankschema für Supabase (Postgres)
-- STATUS: VORBEREITET, NICHT AUSGEFÜHRT. Kein Projekt angelegt, keine Kosten.
-- Vor dem Einsatz: Rechte und Datenschutz von einer Fachperson prüfen lassen.
--
-- Grundsätze
-- * Jeder Datensatz gehört genau einem Betrieb (tenant_id). Betriebe sehen nur ihre eigenen Daten.
-- * Rollen je Betrieb: admin, fitter, mitarbeiter (wie in der Demo unter Einstellungen → Rolle).
-- * Kunden sehen im Portal nur Inhalte, die der Fitter freigegeben hat (Tabelle portal_items).
-- * Fotos/Videos liegen im privaten Storage-Bucket "media" unter <tenant_id>/<customer_id>/<datei>.

create extension if not exists pgcrypto;

create table tenants (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  created_at timestamptz not null default now()
);

create table memberships (
  user_id uuid not null references auth.users(id) on delete cascade,
  tenant_id uuid not null references tenants(id) on delete cascade,
  role text not null check (role in ('admin','fitter','mitarbeiter')),
  primary key (user_id, tenant_id)
);

-- Hilfsfunktionen für die Rechteprüfung
create or replace function is_member(t uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from memberships m where m.user_id = auth.uid() and m.tenant_id = t);
$$;
create or replace function has_role(t uuid, roles text[]) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from memberships m where m.user_id = auth.uid() and m.tenant_id = t and m.role = any(roles));
$$;

create table customers (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id) on delete cascade,
  name text not null,
  email text, phone text, birth date, weight numeric, discipline text,
  hours numeric, km_year numeric, notes text,
  body jsonb not null default '{}'::jsonb,        -- Körpermaße, Kennzeichnung "geschätzt"
  consent jsonb,                                   -- Datum, Version, Gesundheit ja/nein, Fotos ja/nein
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table bikes (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id) on delete cascade,
  customer_id uuid not null references customers(id) on delete cascade,
  brand text, model text, type text, size text, year int, frame_no text, pedal text, saddle text,
  parts jsonb not null default '{}'::jsonb,       -- Komponenten
  geo jsonb,                                       -- Verweis auf Geometrie-Bibliothek
  km int
);

create table sessions (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id) on delete cascade,
  customer_id uuid not null references customers(id) on delete cascade,
  bike_id uuid references bikes(id) on delete set null,
  date date not null, type text, status text, fitter text,
  data jsonb not null default '{}'::jsonb,        -- anamnesis, check, ckNote, sitBone, before, after, changes, feedback, recs, tools, liveNotes …
  updated_at timestamptz not null default now()
);

create table sales (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id) on delete cascade,
  customer_id uuid references customers(id) on delete cascade,
  bike_id uuid references bikes(id) on delete set null,
  date date, items text, total numeric, status text
);

create table products (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id) on delete cascade,
  cat text not null, name text not null,
  price numeric, cost numeric,
  tech jsonb not null default '{}'::jsonb,        -- Breite, Gewölbe, System, Float … nur laut Hersteller
  src text                                         -- Quellenlink der Fachdaten
);

create table tools (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id) on delete cascade,
  name text not null, kind text, maker text, model text, method text,
  acc text, acc_src text, calibrated date, checked date
);

create table media (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id) on delete cascade,
  customer_id uuid not null references customers(id) on delete cascade,
  owner_type text not null check (owner_type in ('customer','bike','session')),
  owner_id uuid not null,
  storage_path text not null,                      -- Pfad im Bucket "media"
  kind text check (kind in ('image','video')), phase text, note text,
  created_at timestamptz not null default now()
);

-- Kundenportal: Zugang eines Endkunden und freigegebene Inhalte (Kopie zum Zeitpunkt der Freigabe)
create table portal_accounts (
  user_id uuid primary key references auth.users(id) on delete cascade,
  tenant_id uuid not null references tenants(id) on delete cascade,
  customer_id uuid not null references customers(id) on delete cascade
);
create table portal_items (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id) on delete cascade,
  customer_id uuid not null references customers(id) on delete cascade,
  session_id uuid references sessions(id) on delete cascade,
  kind text not null check (kind in ('report','recs','exercises','follow','media')),
  payload jsonb not null,
  released_by uuid references auth.users(id),
  released_at timestamptz not null default now()
);

create table audit_log (
  id bigserial primary key,
  tenant_id uuid not null references tenants(id) on delete cascade,
  user_id uuid, action text not null, ref uuid,
  at timestamptz not null default now()
);

-- Zeilenbasierte Sicherheit (RLS) für alle Tabellen
alter table tenants enable row level security;
alter table memberships enable row level security;
alter table customers enable row level security;
alter table bikes enable row level security;
alter table sessions enable row level security;
alter table sales enable row level security;
alter table products enable row level security;
alter table tools enable row level security;
alter table media enable row level security;
alter table portal_accounts enable row level security;
alter table portal_items enable row level security;
alter table audit_log enable row level security;

create policy tenant_read on tenants for select using (is_member(id));
create policy own_membership on memberships for select using (user_id = auth.uid() or has_role(tenant_id, array['admin']));
create policy admin_manage_members on memberships for all using (has_role(tenant_id, array['admin'])) with check (has_role(tenant_id, array['admin']));

-- Fachdaten: alle Mitglieder lesen und schreiben; löschen nur Admin
do $$ declare t text; begin
  foreach t in array array['customers','bikes','sessions','sales','media'] loop
    execute format('create policy %1$s_read on %1$s for select using (is_member(tenant_id))', t);
    execute format('create policy %1$s_insert on %1$s for insert with check (is_member(tenant_id))', t);
    execute format('create policy %1$s_update on %1$s for update using (is_member(tenant_id)) with check (is_member(tenant_id))', t);
    execute format('create policy %1$s_delete on %1$s for delete using (has_role(tenant_id, array[''admin'']))', t);
  end loop;
end $$;

-- Preise/Produkte und Messmittel: lesen alle, ändern nur Admin (Messmittel auch Fitter)
create policy products_read on products for select using (is_member(tenant_id));
create policy products_write on products for all using (has_role(tenant_id, array['admin'])) with check (has_role(tenant_id, array['admin']));
create policy tools_read on tools for select using (is_member(tenant_id));
create policy tools_write on tools for all using (has_role(tenant_id, array['admin','fitter'])) with check (has_role(tenant_id, array['admin','fitter']));

-- Portal: Fitter/Admin geben frei; der Kunde liest nur seine eigenen freigegebenen Inhalte
create policy portal_items_staff on portal_items for all using (has_role(tenant_id, array['admin','fitter'])) with check (has_role(tenant_id, array['admin','fitter']));
create policy portal_items_customer on portal_items for select using (
  exists (select 1 from portal_accounts pa where pa.user_id = auth.uid() and pa.customer_id = portal_items.customer_id)
);
create policy portal_accounts_self on portal_accounts for select using (user_id = auth.uid() or has_role(tenant_id, array['admin']));
create policy portal_accounts_admin on portal_accounts for all using (has_role(tenant_id, array['admin'])) with check (has_role(tenant_id, array['admin']));

-- Protokoll: lesen Admin, schreiben alle Mitglieder; nie ändern oder löschen
create policy audit_read on audit_log for select using (has_role(tenant_id, array['admin']));
create policy audit_insert on audit_log for insert with check (is_member(tenant_id));

-- Storage-Bucket "media" (privat): Pfad beginnt mit tenant_id
-- insert into storage.buckets (id, name, public) values ('media','media', false);
-- create policy media_files on storage.objects for all
--   using (bucket_id = 'media' and is_member((storage.foldername(name))[1]::uuid))
--   with check (bucket_id = 'media' and is_member((storage.foldername(name))[1]::uuid));
