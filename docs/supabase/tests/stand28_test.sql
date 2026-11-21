-- Test Stand 28: Besitzer sieht „Wartet auf Teile“ und danach wieder den echten Status. Lokal Postgres 16. Alle Zeilen „t“.
\set ON_ERROR_STOP 0
insert into tenants(id,name) values ('aaaaaaaa-0000-0000-0000-000000000028','Laden 28') on conflict do nothing;
insert into bike_passes(code,tenant_id,bike_ref,payload,transfer_hash) values ('KQ2345AD','aaaaaaaa-0000-0000-0000-000000000028','b28','{"bike":{"name":"Cube"}}',encode(sha256(convert_to('TEIL2CODE','UTF8')),'hex')) on conflict do nothing;
delete from tenant_state where tenant_id='aaaaaaaa-0000-0000-0000-000000000028';
insert into tenant_state(tenant_id,version,data) values ('aaaaaaaa-0000-0000-0000-000000000028',1,'{"version":3,"customers":[{"id":"c28","name":"Erika"}],"bikes":[{"id":"b28","customerId":"c28","brand":"Cube","model":"Attain","qr":{"code":"KQ2345AD"}}],"workshop":[{"id":"WO-28","customerId":"c28","bikeId":"b28","title":"Inspektion","status":"In Arbeit","created":"2026-11-21","wait":{"at":"2026-11-21","note":"Kette"},"positions":[{"t":"Kette","price":49.9}]}]}');
set role anon;
select (pass_get_owner('KQ2345AD','TEIL2CODE')->'workshop'->0->>'status')='Wartet auf Teile' as besitzer_sieht_wartet_auf_teile;
select (pass_get_owner('KQ2345AD','TEIL2CODE')->'workshop')::text !~ '49' as keine_preise;
select (pass_get('KQ2345AD')->'workshop') is null as oeffentlich_kein_status;
reset role;
update tenant_state set data = jsonb_set(data,'{workshop,0}', (data->'workshop'->0) - 'wait'), version=2 where tenant_id='aaaaaaaa-0000-0000-0000-000000000028';
set role anon;
select (pass_get_owner('KQ2345AD','TEIL2CODE')->'workshop'->0->>'status')='In Arbeit' as nach_teile_da_in_arbeit;
reset role;
update tenant_state set data = jsonb_set(data,'{workshop,0,status}','"Abholbereit"'), version=3 where tenant_id='aaaaaaaa-0000-0000-0000-000000000028';
set role anon;
select (pass_get_owner('KQ2345AD','TEIL2CODE')->'workshop'->0->>'status')='Abholbereit' as abholbereit;
select (pass_get_owner('KQ2345AD','FALSCH')->>'error')='FYF_BAD_TRANSFER' as falscher_code_nichts;
reset role;
