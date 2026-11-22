-- Test Stand 30: Eine Rahmennummer = ein Pass. Lokal Postgres 16. Alle Zeilen „t“.
\set ON_ERROR_STOP 0
insert into tenants(id,name) values ('aaaaaaaa-0000-0000-0000-000000000030','Laden 30'),('aaaaaaaa-0000-0000-0000-000000000031','Laden 31') on conflict do nothing;
insert into auth.users(id) values ('bbbbbbbb-0000-0000-0000-000000000030') on conflict do nothing;
insert into memberships(user_id,tenant_id,role) values ('bbbbbbbb-0000-0000-0000-000000000030','aaaaaaaa-0000-0000-0000-000000000030','admin'),('bbbbbbbb-0000-0000-0000-000000000030','aaaaaaaa-0000-0000-0000-000000000031','admin') on conflict do nothing;
select set_config('request.jwt.claims','{"sub":"bbbbbbbb-0000-0000-0000-000000000030"}',false);
select set_config('request.jwt.claim.sub','bbbbbbbb-0000-0000-0000-000000000030',false);
\set fh '''3030303030303030303030303030303030303030303030303030303030303030'''
\set fh2 '''3131313131313131313131313131313131313131313131313131313131313131'''
-- Besitzer registriert selbst
select (pass_register('{"bike":{"name":"Canyon Test"}}', :fh)->>'code') is not null as besitzer_registriert;
select (pass_register('{"bike":{"name":"Canyon Test"}}', :fh)->>'error')='FYF_FRAME_EXISTS' as zweite_registrierung_abgelehnt;
-- Laden will für dieselbe Nummer einen neuen Pass anlegen
select pass_publish('aaaaaaaa-0000-0000-0000-000000000030','b30a',jsonb_build_object('bike',jsonb_build_object('name','Canyon Test'),'fh',:fh),'shops',false) as laden_doppelt;
select count(*)=1 as nur_ein_pass from bike_passes where frame_hash=:fh;
-- Laden legt Pass für neue Nummer an, zweiter Laden nicht
select pass_publish('aaaaaaaa-0000-0000-0000-000000000030','b30b',jsonb_build_object('bike',jsonb_build_object('name','Cube Test'),'fh',:fh2),'shops',false) is not null as laden_neu_ok;
select pass_publish('aaaaaaaa-0000-0000-0000-000000000030','b30b',jsonb_build_object('bike',jsonb_build_object('name','Cube Test 2'),'fh',:fh2),'shops',false) is not null as eigener_pass_aktualisieren_ok;
select pass_publish('aaaaaaaa-0000-0000-0000-000000000031','b31',jsonb_build_object('bike',jsonb_build_object('name','Cube Test'),'fh',:fh2),'shops',false) as zweiter_laden_doppelt;
select count(*)=1 as weiter_nur_ein_pass from bike_passes where frame_hash=:fh2;
-- Laden ohne Rahmennummer geht weiter
select pass_publish('aaaaaaaa-0000-0000-0000-000000000031','b31x',jsonb_build_object('bike',jsonb_build_object('name','Ohne Nummer')),'shops',false) is not null as ohne_nummer_ok;
-- Gleiches Rad selbst nachtragen geht nicht
select (pass_register('{"bike":{"name":"Cube Test"}}', :fh2)->>'error')='FYF_FRAME_EXISTS' as besitzer_nach_laden_abgelehnt;
-- Datenbank-Regel greift auch direkt
insert into bike_passes(code,tenant_id,bike_ref,visibility,payload,frame_hash) values ('ZZ3Z3ZZZ',null,null,'shops','{}',:fh);
select count(*)=1 as regel_haelt from bike_passes where frame_hash=:fh;
