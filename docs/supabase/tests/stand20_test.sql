-- Test Stand 20: Akku-Diebstahl (nur mit Übergabe-Code) und anonyme Laufleistungen (erst ab 5 je Modell/Teil). Lokal Postgres 16 am 16.11.2026 geprüft: falscher Code abgelehnt, Meldung/Aufheben wirkt, Statistik erst ab 5, Duplikat ignoriert.
\set ON_ERROR_STOP 1
insert into bike_passes(code, tenant_id, bike_ref, visibility, stolen, payload, transfer_hash) values ('TESTAK22', null, null, 'shops', false, '{"bike":{"name":"Test"}}', encode(sha256(convert_to('GEHEIM123', 'UTF8')), 'hex')) on conflict (code) do nothing;
set role anon;
select pass_battery_set('TESTAK22','FALSCH', repeat('a',64), true) as falscher_code;
select pass_battery_set('TESTAK22','GEHEIM123', repeat('a',64), true) as gemeldet;
select battery_check(repeat('a',64)) as check_gestohlen, battery_check(repeat('b',64)) as check_unbekannt;
select pass_battery_set('TESTAK22','GEHEIM123', repeat('a',64), false) as aufgehoben;
select battery_check(repeat('a',64)) as check_nach_aufheben;
select wear_submit('canyon grail cf','chain', 2400+i*100, md5('r'||i)) from generate_series(1,4) i;
select wear_stats('Canyon  Grail CF') as unter_5;
select wear_submit('canyon grail cf','chain', 3000, md5('r5'));
select wear_submit('canyon grail cf','chain', 3000, md5('r5')) as doppelt_ignoriert;
select wear_stats('canyon grail cf') as ab_5;
select wear_submit('x','chain', 10, md5('bad')) as ungueltig;
reset role;
delete from wear_stats where model='canyon grail cf'; delete from battery_flags where code='TESTAK22'; -- Pass-Einträge sind unveränderlich, Test-Pass bleibt
