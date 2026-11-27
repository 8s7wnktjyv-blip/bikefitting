-- FYF – Stand 32 (26.11.2026): Marktplatz zeigt den Auftritt (Filiale/Marke) als Anbieter und ein Bild je Artikel.
-- Pläne: docs/FILIALEN-MARKEN-PLAN.md (Punkt 27), docs/MARKTPLATZ-PLAN.md (Punkt 28).
-- Einspielen: GitHub → Actions → „Datenbank aktualisieren“, oder Inhalt im Supabase-SQL-Editor ausführen.
-- Danach die App (Software) einmal speichern/veröffentlichen – der Trigger kopiert die Produkte neu.

-- 1) Spalten für Bild und Anbieter
alter table fyf_products add column if not exists img text;
alter table fyf_products add column if not exists seller text check (length(seller) <= 80);
alter table fyf_products add column if not exists seller_ref text check (length(seller_ref) <= 60);

-- 2) Trigger: Bild und Auftritt aus dem veröffentlichten Stand übernehmen
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
  insert into fyf_products select t, e->>'id', e->>'cat', left(e->>'name', 200), fyf_n(e->>'price'),
      coalesce((e->>'pub')::boolean, false), left(e->>'note', 300),
      left(nullif(e->>'img', ''), 300000),           -- verkleinertes JPEG als Daten-URL (max. 900 px, App begrenzt das)
      left(nullif(e->>'actName', ''), 80),            -- Anzeigename des Auftritts, z. B. „Cunuma bikeparts“
      left(nullif(e->>'act', ''), 60)                 -- Kennung des Auftritts (Filiale oder Marke)
    from jsonb_array_elements(coalesce(d->'products', '[]')) e where e->>'id' is not null on conflict do nothing;
  return new;
end $$;

drop trigger if exists fyf_project_t on tenant_state;
create trigger fyf_project_t after insert or update of data on tenant_state for each row execute function fyf_project();

-- 3) Öffentliche Produkte: Bild und Anbieter mit ausliefern
create or replace view public_products with (security_invoker = false) as
  select d.slug, p.id, p.cat, p.name, p.price, p.note, p.img, p.seller, p.seller_ref
  from fyf_products p join dealer_profiles d on d.tenant_id = p.tenant_id
  where p.pub and d.published and p.price is not null;
grant select on public_products to anon, authenticated;

-- 4) Bestehende Stände einmal neu kopieren (füllt Bild und Anbieter für vorhandene Artikel)
update tenant_state set data = data;

-- Hinweis: Die Pass-App liest die neuen Spalten erst, wenn sie sie abfragt – das tut sie mit
-- Ausweich-Abfrage (alte Spalten), solange dieser Stand fehlt. Nichts geht kaputt.
