-- Test Stand 19: angefragte freie Zeit wird aus dealer_profiles.slots entfernt (lokal Postgres 16, 16.11.2026: 09:00 am 20.11. entfernt, Wunschtermin ohne „freie Zeit“ ändert nichts).
\set ON_ERROR_STOP 1
insert into tenants(id,name) values ('aaaaaaaa-0000-0000-0000-000000000001','Laden A') on conflict do nothing;
insert into dealer_profiles(tenant_id,slug,name,published,slots) values ('aaaaaaaa-0000-0000-0000-000000000001','laden-a','Laden A',true,'[{"d":"2026-11-20","t":["09:00","10:00"]},{"d":"2026-11-21","t":["09:00"]}]') on conflict (tenant_id) do update set slots=excluded.slots, published=true;
set role anon;
select submit_inquiry('laden-a','Werkstatt','Test','t@x.de','Hallo',null,'','Fr., 20.11.2026 09:00 (freie Zeit)');
select submit_inquiry('laden-a','Werkstatt','Test2','t@x.de','Hallo',null,'','Sa., 21.11.2026 14:00');
reset role;
select slots from dealer_profiles where slug='laden-a';
