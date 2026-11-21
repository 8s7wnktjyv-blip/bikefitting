-- Test Stand 25: Rechte auf dem Server. Lokal Postgres 16 am 21.11.2026: Mitarbeiter sieht kein Geld (Rechnungen, Zahlungen, Verkäufe, Lieferanten, Nummernkreis), sieht Körperdaten, liest Tabelle nicht direkt; speichert Auftrag+Kunde, Rechnung bleibt, alte Zahlung unverändert (p1=50), neue angehängt (p2=20); Fitter sieht alles; Admin darf Lieferanten löschen; anon gesperrt.
\set ON_ERROR_STOP 0
insert into auth.users values ('11111111-1111-1111-1111-111111111125','a25@x'),('22222222-2222-2222-2222-222222222225','m25@x'),('33333333-3333-3333-3333-333333333325','f25@x') on conflict do nothing;
insert into tenants(id,name) values ('aaaaaaaa-0000-0000-0000-000000000025','Laden 25') on conflict do nothing;
insert into memberships values ('11111111-1111-1111-1111-111111111125','aaaaaaaa-0000-0000-0000-000000000025','admin'),('22222222-2222-2222-2222-222222222225','aaaaaaaa-0000-0000-0000-000000000025','mitarbeiter'),('33333333-3333-3333-3333-333333333325','aaaaaaaa-0000-0000-0000-000000000025','fitter') on conflict do nothing;
delete from tenant_state where tenant_id='aaaaaaaa-0000-0000-0000-000000000025';
insert into tenant_state(tenant_id,version,data) values ('aaaaaaaa-0000-0000-0000-000000000025',5,
 '{"version":3,"customers":[{"id":"c1","name":"Erika","body":{"knee":"Arthrose"}}],"workshop":[{"id":"W1"}],"invoices":[{"id":"i1","no":"RE-1","status":"offen"}],"payments":[{"id":"p1","amount":50}],"sales":[{"id":"s1"}],"suppliers":[{"id":"l1"}],"invSeq":7}');
set role authenticated;
select set_config('request.jwt.claim.sub','22222222-2222-2222-2222-222222222225',false);
select (state_get('aaaaaaaa-0000-0000-0000-000000000025')->'data') ?| array['invoices','payments','sales','suppliers','invSeq'] as mitarbeiter_sieht_geld;
select (state_get('aaaaaaaa-0000-0000-0000-000000000025')->'data'->'customers'->0->'body'->>'knee') as mitarbeiter_sieht_koerperdaten;
select count(*) as mitarbeiter_direkt_lesen from tenant_state where tenant_id='aaaaaaaa-0000-0000-0000-000000000025';
select save_state('aaaaaaaa-0000-0000-0000-000000000025','{"version":3,"customers":[{"id":"c1","name":"Erika M."}],"workshop":[{"id":"W1","status":"fertig"}],"invoices":[],"payments":[{"id":"p1","amount":0},{"id":"p2","amount":20}]}',5) as mitarbeiter_speichert;
reset role;
select data->'invoices'->0->>'no' as rechnung_noch_da, (select string_agg(x->>'id'||'='||(x->>'amount'),',') from jsonb_array_elements(data->'payments') x) as zahlungen, data->>'invSeq' as invseq, jsonb_array_length(data->'suppliers') as lieferanten, data->'workshop'->0->>'status' as auftrag, data->'customers'->0->>'name' as kunde from tenant_state where tenant_id='aaaaaaaa-0000-0000-0000-000000000025';
set role authenticated;
select set_config('request.jwt.claim.sub','33333333-3333-3333-3333-333333333325',false);
select (state_get('aaaaaaaa-0000-0000-0000-000000000025')->'data') ? 'invoices' as fitter_sieht_rechnungen;
select count(*) as fitter_direkt_lesen from tenant_state where tenant_id='aaaaaaaa-0000-0000-0000-000000000025';
select set_config('request.jwt.claim.sub','11111111-1111-1111-1111-111111111125',false);
reset role;
select data - 'suppliers' as dneu from tenant_state where tenant_id='aaaaaaaa-0000-0000-0000-000000000025' \gset
set role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-1111-1111-111111111125',false);
select save_state('aaaaaaaa-0000-0000-0000-000000000025',:'dneu'::jsonb,6) as admin_speichert;
reset role;
select data ? 'suppliers' as lieferanten_noch_da_nach_admin_loeschung from tenant_state where tenant_id='aaaaaaaa-0000-0000-0000-000000000025';
set role anon;
select state_get('aaaaaaaa-0000-0000-0000-000000000025') as anon;
reset role;
