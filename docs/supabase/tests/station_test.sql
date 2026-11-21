-- Test station.sql (lokal Postgres 16, 20.11.2026, mit nachgebautem auth-Schema).
-- Prüft: Mitglied darf senden/lesen/übernehmen, Fremder nicht, nur Name+Maße der Kunden, Größenlimit.
\set ON_ERROR_STOP 1
insert into auth.users(id, email) values ('00000000-0000-0000-0000-00000000000a', 'laden@example.com'), ('00000000-0000-0000-0000-00000000000b', null), ('00000000-0000-0000-0000-00000000000c', 'fremd@example.com');
insert into tenants(id, name) values ('10000000-0000-0000-0000-000000000001', 'Testladen'), ('10000000-0000-0000-0000-000000000002', 'Anderer');
insert into memberships(user_id, tenant_id, role) values ('00000000-0000-0000-0000-00000000000a', '10000000-0000-0000-0000-000000000001', 'admin'),
  ('00000000-0000-0000-0000-00000000000b', '10000000-0000-0000-0000-000000000001', 'admin'), ('00000000-0000-0000-0000-00000000000c', '10000000-0000-0000-0000-000000000002', 'admin');
insert into tenant_state(tenant_id, data) values ('10000000-0000-0000-0000-000000000001',
  '{"customers":[{"id":"c1","name":"Lena Hoffmann","email":"lena@example.com","phone":"0151","body":{"height":172,"inseam":81.5}},{"id":"c2","name":"Markus","body":{"height":null}},{"id":"","name":"leer"},{"name":"ohne id"}]}');

set role authenticated;
-- Tab5 (Gerät b) holt Kunden: nur id, name, height, inseam – keine E-Mail/Telefon
select set_config('test.uid', '00000000-0000-0000-0000-00000000000b', false);
select * from station_customers('10000000-0000-0000-0000-000000000001');
-- Tab5 sendet
select station_push('10000000-0000-0000-0000-000000000001', '{"v":1,"src":"tab5","before":{"saddleHeight":728},"after":{"saddleHeight":736}}') > 0 as gesendet;
-- falsche Daten
do $$ begin perform station_push('10000000-0000-0000-0000-000000000001', '[1,2]'); raise exception 'hätte scheitern müssen'; exception when others then if sqlerrm <> 'FYF_BAD_DATA' then raise; end if; end $$;
do $$ begin perform station_push('10000000-0000-0000-0000-000000000001', jsonb_build_object('x', repeat('a', 65000))); raise exception 'hätte scheitern müssen'; exception when others then if sqlerrm <> 'FYF_BAD_DATA' then raise; end if; end $$;
-- Fremder Laden darf weder senden noch lesen noch Kunden sehen
select set_config('test.uid', '00000000-0000-0000-0000-00000000000c', false);
do $$ begin perform station_push('10000000-0000-0000-0000-000000000001', '{}'); raise exception 'hätte scheitern müssen'; exception when others then if sqlerrm <> 'FYF_DENIED' then raise; end if; end $$;
select count(*) as fremd_sieht_eintraege from station_list('10000000-0000-0000-0000-000000000001');
select count(*) as fremd_sieht_kunden from station_customers('10000000-0000-0000-0000-000000000001');
-- direkter Tabellenzugriff gesperrt
do $$ begin perform 1 from station_inbox; raise exception 'hätte scheitern müssen'; exception when insufficient_privilege then null; end $$;
-- FYF-App (a) liest und übernimmt
select set_config('test.uid', '00000000-0000-0000-0000-00000000000a', false);
select payload->'after'->>'saddleHeight' as nachher from station_list('10000000-0000-0000-0000-000000000001');
select station_take('10000000-0000-0000-0000-000000000001', (select id from station_list('10000000-0000-0000-0000-000000000001') limit 1));
select count(*) as offen_nach_uebernahme from station_list('10000000-0000-0000-0000-000000000001');
reset role;
-- anon darf gar nichts
set role anon;
do $$ begin perform station_list('10000000-0000-0000-0000-000000000001'); raise exception 'hätte scheitern müssen'; exception when insufficient_privilege then null; end $$;
reset role;
select 'station_test fertig' as ergebnis;
