-- Test für Migration 01 (lokal mit Postgres 16 ausgeführt am 15.11.2026: alle 4 Prüfungen wie erwartet)
-- Voraussetzung: Hilfsschema auth wie in Supabase, alles.sql und 20270101_01_plattform_kern.sql eingespielt.
grant usage on schema public to authenticated; grant select,insert,update,delete on all tables in schema public to authenticated; grant usage,select on all sequences in schema public to authenticated;
insert into auth.users values ('11111111-1111-1111-1111-111111111111','a@x'),('22222222-2222-2222-2222-222222222222','m@x'),('33333333-3333-3333-3333-333333333333','b@x');
insert into tenants(id,name) values ('aaaaaaaa-0000-0000-0000-000000000001','Laden A'),('bbbbbbbb-0000-0000-0000-000000000002','Laden B');
insert into memberships values ('11111111-1111-1111-1111-111111111111','aaaaaaaa-0000-0000-0000-000000000001','admin'),('22222222-2222-2222-2222-222222222222','aaaaaaaa-0000-0000-0000-000000000001','mitarbeiter'),('33333333-3333-3333-3333-333333333333','bbbbbbbb-0000-0000-0000-000000000002','admin');
insert into memberships values ('22222222-2222-2222-2222-222222222222','bbbbbbbb-0000-0000-0000-000000000002','buchhaltung');
set role authenticated;
-- Mitarbeiter (u2) in Laden A
select set_config('request.jwt.claim.sub','22222222-2222-2222-2222-222222222222',false);
insert into customers(tenant_id,name) values ('aaaaaaaa-0000-0000-0000-000000000001','Kunde von Mitarbeiter');
\echo '1 Mitarbeiter legt Kunde an: ok'
insert into labor_items(tenant_id,name,price) values ('aaaaaaaa-0000-0000-0000-000000000001','Bremse',29);
\echo '2 (erwartet Fehler oben) Mitarbeiter darf Preise nicht'
select count(*) as mitarbeiter_sieht_rechnungen from invoices;
-- Admin A
select set_config('request.jwt.claim.sub','11111111-1111-1111-1111-111111111111',false);
insert into labor_items(tenant_id,name,price) values ('aaaaaaaa-0000-0000-0000-000000000001','Bremse entlüften',29.9);
insert into invoices(tenant_id,number,issued_at,data) values ('aaaaaaaa-0000-0000-0000-000000000001','2027-0001',current_date,'{}');
select count(*) as admin_sieht_rechnungen from invoices;
update invoices set number='X' where number='2027-0001';
\echo '3 (erwartet FYF_INVOICE_LOCKED oben)'
insert into items(id,tenant_id,name) values ('cccccccc-0000-0000-0000-000000000001','aaaaaaaa-0000-0000-0000-000000000001','Kette');
insert into stock_moves(tenant_id,item_id,qty,reason) values ('aaaaaaaa-0000-0000-0000-000000000001','cccccccc-0000-0000-0000-000000000001',10,'Wareneingang'),('aaaaaaaa-0000-0000-0000-000000000001','cccccccc-0000-0000-0000-000000000001',-3,'Werkstatt');
select qty as bestand_kette from stock_levels;
-- Admin B sieht nichts von A
select set_config('request.jwt.claim.sub','33333333-3333-3333-3333-333333333333',false);
select (select count(*) from customers) as b_kunden_von_a, (select count(*) from labor_items) as b_preise_von_a, (select count(*) from stock_levels) as b_bestand_von_a;
insert into customers(tenant_id,name) values ('aaaaaaaa-0000-0000-0000-000000000001','Einbruch');
\echo '4 (erwartet Fehler oben) fremder Laden darf nicht schreiben'
reset role;
select count(*) as kunden_gesamt from customers;
