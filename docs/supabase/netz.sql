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
