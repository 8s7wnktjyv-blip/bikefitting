-- FYF Plattform – Migration 01: relationaler Kern (ENTWURF, noch NICHT eingespielt)
-- Entscheidung vom 15.11.2026: Speicher „ein Datensatz je Laden“ (tenant_state) schrittweise auf Tabellen umstellen.
-- Regeln:
--  * Nur NEUE Tabellen und Funktionen. tenant_state, Pass-, Netzwerk- und alle bestehenden Tabellen bleiben unverändert.
--  * Jede Zeile hat tenant_id. Zugriff nur für Mitglieder des Ladens (RLS). Schreiben je nach Recht (has_perm).
--  * legacy_id = ID aus dem bisherigen Speicher, damit Doppelschreiben und Abgleich möglich sind.
--  * Einspielen erst nach Test im Testprojekt und Freigabe durch Dominik.

-- ---------- Rollen: bestehende 3 Rollen bleiben, 4 kommen dazu (Freigabe 15.11.2026) ----------
alter table memberships drop constraint if exists memberships_role_check;
alter table memberships add constraint memberships_role_check
  check (role in ('admin','fitter','mitarbeiter','werkstattleitung','verkauf','filialleitung','buchhaltung'));

create table if not exists role_permissions (
  role text not null,
  perm text not null,
  primary key (role, perm)
);
alter table role_permissions enable row level security;
drop policy if exists rp_read on role_permissions;
create policy rp_read on role_permissions for select using (auth.uid() is not null);

-- Startbelegung: admin darf alles (wird in has_perm geprüft), Rest nach Aufgabe
insert into role_permissions(role, perm) values
  ('fitter','kunden.schreiben'),('fitter','fitting.schreiben'),('fitter','gesundheit.lesen'),('fitter','werkstatt.schreiben'),('fitter','verkauf.schreiben'),
  ('mitarbeiter','kunden.schreiben'),('mitarbeiter','werkstatt.schreiben'),
  ('werkstattleitung','kunden.schreiben'),('werkstattleitung','werkstatt.schreiben'),('werkstattleitung','werkstatt.preise'),('werkstattleitung','lager.schreiben'),
  ('verkauf','kunden.schreiben'),('verkauf','verkauf.schreiben'),('verkauf','lager.schreiben'),
  ('filialleitung','kunden.schreiben'),('filialleitung','werkstatt.schreiben'),('filialleitung','werkstatt.preise'),('filialleitung','verkauf.schreiben'),('filialleitung','lager.schreiben'),('filialleitung','organisation.schreiben'),('filialleitung','auswertung.lesen'),
  ('buchhaltung','rechnung.lesen'),('buchhaltung','rechnung.schreiben'),('buchhaltung','auswertung.lesen')
on conflict do nothing;

create or replace function has_perm(t uuid, p text) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from memberships m
    where m.user_id = auth.uid() and m.tenant_id = t
      and (m.role = 'admin' or exists (select 1 from role_permissions r where r.role = m.role and r.perm = p))
  );
$$;

-- ---------- Standorte und Abo (Preis pro Standort, Freigabe 15.11.2026) ----------
create table if not exists locations (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id) on delete cascade,
  legacy_id text,
  name text not null,
  address text,
  active boolean not null default true,
  created_at timestamptz not null default now()
);
create table if not exists subscriptions (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id) on delete cascade,
  location_id uuid not null references locations(id) on delete cascade,
  plan text not null check (plan in ('standard','professional')),   -- 99 € / 149 € je Standort und Monat (netto, Stand Nov. 2026)
  valid_from date not null default current_date,
  valid_until date,
  ended_reason text,
  unique (location_id, valid_from)
);

-- ---------- Kunden (B) ----------
create table if not exists customers (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id) on delete cascade,
  legacy_id text,
  kind text not null default 'privat' check (kind in ('privat','firma')),
  name text not null,
  company text, vat_id text, leitweg_id text,
  email text, phone text, address jsonb,
  consent jsonb not null default '{}'::jsonb,          -- Einwilligungen inkl. Gesundheitsdaten (Art. 9 DSGVO)
  health jsonb,                                        -- Körper-/Beschwerdedaten, nur mit Recht gesundheit.lesen
  extra jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id, legacy_id)
);
create table if not exists customer_contacts (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id) on delete cascade,
  customer_id uuid not null references customers(id) on delete cascade,
  name text not null, role text, email text, phone text
);
create table if not exists followups (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id) on delete cascade,
  customer_id uuid references customers(id) on delete cascade,
  due date not null, text text not null, done_at timestamptz,
  assigned_to uuid references auth.users(id) on delete set null
);
-- Endkunden-Konto (Freigabe 15.11.2026): freiwillig, Pass bleibt ohne Konto nutzbar
create table if not exists customer_accounts (
  user_id uuid not null references auth.users(id) on delete cascade,
  tenant_id uuid not null references tenants(id) on delete cascade,
  customer_id uuid not null references customers(id) on delete cascade,
  linked_at timestamptz not null default now(),
  primary key (user_id, customer_id)
);

-- ---------- Fahrräder (Verknüpfung zum bestehenden Pass über pass_code) ----------
create table if not exists bikes (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id) on delete cascade,
  legacy_id text,
  customer_id uuid references customers(id) on delete set null,
  pass_code text,                                      -- = bike_passes.code (bestehend, unverändert)
  brand text, model text, type text, size text, year int, color text,
  frame_hash text,                                     -- nur Hash, wie im Pass
  km int,
  data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id, legacy_id)
);

-- ---------- Werkstatt (D) ----------
create table if not exists labor_items (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id) on delete cascade,
  legacy_id text, cat text, name text not null, price numeric(10,2) not null default 0, checklist text, sort int default 0
);
create table if not exists check_templates (
  tenant_id uuid not null references tenants(id) on delete cascade,
  name text not null, items text[] not null default '{}',
  primary key (tenant_id, name)
);
create table if not exists work_orders (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id) on delete cascade,
  location_id uuid references locations(id) on delete set null,
  legacy_id text,                                      -- z. B. WO-1042
  customer_id uuid references customers(id) on delete set null,
  bike_id uuid references bikes(id) on delete set null,
  title text not null, status text not null,
  due date, assigned_to uuid references auth.users(id) on delete set null, mechanic text,
  intake jsonb, approval jsonb, qc jsonb, lease jsonb,
  created_at timestamptz not null default now(), done_at timestamptz,
  unique (tenant_id, legacy_id)
);
create table if not exists work_order_items (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id) on delete cascade,
  work_order_id uuid not null references work_orders(id) on delete cascade,
  kind text not null check (kind in ('Arbeit','Teil')), text text not null,
  qty numeric(10,2) not null default 1, price numeric(10,2) not null default 0,
  item_id uuid, booked boolean not null default false, sort int default 0
);
create table if not exists work_order_checks (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id) on delete cascade,
  work_order_id uuid not null references work_orders(id) on delete cascade,
  text text not null, source text, ok boolean not null default false, done_at timestamptz, done_by uuid, sort int default 0
);
create table if not exists time_entries (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id) on delete cascade,
  work_order_id uuid references work_orders(id) on delete cascade,
  user_id uuid references auth.users(id) on delete set null,
  started_at timestamptz not null, ended_at timestamptz, hours numeric(6,2)
);

-- ---------- Warenwirtschaft (G) ----------
create table if not exists items (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id) on delete cascade,
  legacy_id text, sku text, ean text, name text not null, maker text, supplier text,
  buy numeric(10,2), sell numeric(10,2), min_stock numeric(10,2) default 0, serial_required boolean not null default false,
  unique (tenant_id, legacy_id)
);
create table if not exists stock_moves (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id) on delete cascade,
  item_id uuid not null references items(id) on delete cascade,
  location_id uuid references locations(id) on delete set null,
  qty numeric(10,2) not null, reason text not null, ref text,
  created_at timestamptz not null default now(), created_by uuid default auth.uid()
);
-- Bestand ergibt sich nur aus Buchungen (nie direkt änderbar)
create or replace view stock_levels with (security_invoker = true) as
  select tenant_id, item_id, location_id, sum(qty) as qty from stock_moves group by tenant_id, item_id, location_id;
create table if not exists purchase_orders (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id) on delete cascade,
  supplier text not null, status text not null default 'Entwurf' check (status in ('Entwurf','Bestellt','Teilweise geliefert','Geliefert','Storniert')),
  lines jsonb not null default '[]'::jsonb, created_at timestamptz not null default now()
);
create table if not exists serials (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id) on delete cascade,
  item_id uuid references items(id) on delete set null, serial text not null, status text not null default 'Lager',
  unique (tenant_id, serial)
);

-- ---------- Verkauf (F) ----------
create table if not exists invoices (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id) on delete cascade,
  legacy_id text, number text not null, kind text not null default 'Rechnung' check (kind in ('Rechnung','Gutschrift','Storno')),
  customer_id uuid references customers(id) on delete set null,
  issued_at date not null, data jsonb not null,           -- vollständige Rechnung wie ausgestellt
  corrects uuid references invoices(id),
  created_at timestamptz not null default now(),
  unique (tenant_id, number)
);
-- Ausgestellte Rechnungen sind unveränderlich (GoBD). Korrektur nur per Storno/Gutschrift.
create or replace function invoices_lock() returns trigger language plpgsql as $$
begin raise exception 'FYF_INVOICE_LOCKED'; end; $$;
drop trigger if exists invoices_no_update on invoices;
create trigger invoices_no_update before update or delete on invoices for each row execute function invoices_lock();
create table if not exists payments (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id) on delete cascade,
  invoice_id uuid not null references invoices(id) on delete restrict,
  amount numeric(10,2) not null, method text, paid_at date not null default current_date
);
create table if not exists reservations (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references tenants(id) on delete cascade,
  item_id uuid references items(id) on delete cascade, customer_id uuid references customers(id) on delete cascade,
  qty numeric(10,2) not null default 1, until date, note text
);

-- ---------- Zugriffsprotokoll Fahrraddaten (C) ----------
create table if not exists bike_access_log (
  id bigserial primary key,
  pass_code text not null, tenant_id uuid, user_id uuid default auth.uid(),
  action text not null, at timestamptz not null default now()
);

-- ---------- Zeilen-Sicherheit: Lesen = Mitglied; Schreiben = Recht ----------
do $$
declare t record;
begin
  for t in select * from (values
    ('locations','organisation.schreiben'),('subscriptions','abo.verwalten'),('customers','kunden.schreiben'),('customer_contacts','kunden.schreiben'),
    ('followups','kunden.schreiben'),('bikes','kunden.schreiben'),('labor_items','werkstatt.preise'),('check_templates','werkstatt.preise'),
    ('work_orders','werkstatt.schreiben'),('work_order_items','werkstatt.schreiben'),('work_order_checks','werkstatt.schreiben'),('time_entries','werkstatt.schreiben'),
    ('items','lager.schreiben'),('stock_moves','lager.schreiben'),('purchase_orders','lager.schreiben'),('serials','lager.schreiben'),
    ('invoices','rechnung.schreiben'),('payments','rechnung.schreiben'),('reservations','verkauf.schreiben')
  ) as v(tbl, perm) loop
    execute format('alter table %I enable row level security', t.tbl);
    execute format('drop policy if exists r_%1$s on %1$I', t.tbl);
    execute format('create policy r_%1$s on %1$I for select using (is_member(tenant_id))', t.tbl);
    execute format('drop policy if exists i_%1$s on %1$I', t.tbl);
    execute format('create policy i_%1$s on %1$I for insert with check (has_perm(tenant_id, %2$L))', t.tbl, t.perm);
    execute format('drop policy if exists u_%1$s on %1$I', t.tbl);
    execute format('create policy u_%1$s on %1$I for update using (has_perm(tenant_id, %2$L)) with check (has_perm(tenant_id, %2$L))', t.tbl, t.perm);
    execute format('drop policy if exists d_%1$s on %1$I', t.tbl);
    execute format('create policy d_%1$s on %1$I for delete using (has_perm(tenant_id, %2$L))', t.tbl, t.perm);
  end loop;
end $$;
-- Rechnungen und Zahlungen nur für Rollen mit Rechnungsrecht lesbar (nicht für jeden Mitarbeiter)
drop policy if exists r_invoices on invoices;
create policy r_invoices on invoices for select using (has_perm(tenant_id, 'rechnung.lesen') or has_perm(tenant_id, 'rechnung.schreiben') or has_perm(tenant_id, 'verkauf.schreiben'));
-- Endkunden-Konten: Kunde sieht nur seine Verknüpfung
alter table customer_accounts enable row level security;
drop policy if exists ca_own on customer_accounts;
create policy ca_own on customer_accounts for select using (user_id = auth.uid() or has_perm(tenant_id, 'kunden.schreiben'));
-- Zugriffsprotokoll: nur lesen für Admin des Ladens, schreiben nur über Server-Funktionen
alter table bike_access_log enable row level security;
drop policy if exists bal_read on bike_access_log;
create policy bal_read on bike_access_log for select using (tenant_id is not null and has_role(tenant_id, array['admin']));

-- Indizes
create index if not exists customers_tenant on customers(tenant_id);
create index if not exists bikes_tenant on bikes(tenant_id);
create index if not exists bikes_pass on bikes(pass_code);
create index if not exists wo_tenant_status on work_orders(tenant_id, status);
create index if not exists woi_wo on work_order_items(work_order_id);
create index if not exists woc_wo on work_order_checks(work_order_id);
create index if not exists moves_item on stock_moves(tenant_id, item_id);
create index if not exists inv_tenant on invoices(tenant_id, issued_at);
