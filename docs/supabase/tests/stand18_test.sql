-- Test für Stand 18 (Sicherung + Werkstatt-Status). Lokal mit Postgres 16 am 15.11.2026: Konflikt erkannt, nur Prüfwert gespeichert, Werkstatt nur mit Besitzer-Code.
\set ON_ERROR_STOP 1
set role anon;
select vault_put(repeat('a',64),'v1.QUJD.REVGR0hJSktMTU5PUA==',0) put1;
select vault_put(repeat('a',64),'v1.QUJD.REVGR0hJSktMTU5PUB==',0) conflict;
select vault_put(repeat('a',64),'v1.QUJD.REVGR0hJSktMTU5PUB==',1) put2;
select vault_get(repeat('a',64))->>'ver' ver, vault_head(repeat('b',64)) fremd, vault_put('xyz','v1.a.b',0) badid, vault_put(repeat('c',64),'<script>',0) badblob;
reset role;
select count(*) zeilen, (select id_hash<>repeat('a',64) from pass_vault) nur_hash from pass_vault;
insert into auth.users values ('11111111-1111-1111-1111-111111111111','a@x') on conflict do nothing;
insert into tenants(id,name) values ('aaaaaaaa-0000-0000-0000-000000000001','Laden A') on conflict do nothing;
insert into memberships values ('11111111-1111-1111-1111-111111111111','aaaaaaaa-0000-0000-0000-000000000001','admin') on conflict do nothing;
insert into bike_passes(code,tenant_id,bike_ref,payload,transfer_hash) values ('ABCDEFGH','aaaaaaaa-0000-0000-0000-000000000001','b1','{}',encode(sha256(convert_to('GEHEIM12','UTF8')),'hex')) on conflict do nothing;
select set_config('request.jwt.claim.sub','11111111-1111-1111-1111-111111111111',false);
set role authenticated;
select save_state('aaaaaaaa-0000-0000-0000-000000000001'::uuid, '{"customers":[{"id":"c1","name":"Lena"}],"bikes":[{"id":"b1","customerId":"c1","brand":"Canyon","model":"Grail","qr":{"code":"ABCDEFGH"}}],"workshop":[{"id":"WO-1","customerId":"c1","bikeId":"b1","title":"Inspektion","status":"In Arbeit","created":"2026-11-14","due":"2026-11-18","positions":[{"t":"Inspektion","price":89}]}]}'::jsonb, coalesce((select version from tenant_state where tenant_id='aaaaaaaa-0000-0000-0000-000000000001'),0));
reset role; set role anon;
select pass_get_owner('ABCDEFGH','GEHEIM12')->'workshop' werkstatt;
select pass_get_owner('ABCDEFGH','FALSCH')->>'error' falsch;
select pass_get('ABCDEFGH') ? 'workshop' oeffentlich_hat_werkstatt;
