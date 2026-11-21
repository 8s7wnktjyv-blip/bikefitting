-- Test Stand 29: Käufer-Link. Lokal Postgres 16. Alle Zeilen „t“.
\set ON_ERROR_STOP 0
insert into tenants(id,name) values ('aaaaaaaa-0000-0000-0000-000000000029','Laden 29') on conflict do nothing;
insert into bike_passes(code,tenant_id,bike_ref,visibility,payload,transfer_hash) values ('KQ2345AE','aaaaaaaa-0000-0000-0000-000000000029','b29','shops',
 '{"bike":{"name":"Cube Attain","type":"Rennrad","km":4200},"svc":[{"date":"2026-05-01","title":"Inspektion","parts":["Kette"]}],"photo":"data:x","lease":{"provider":"JobRad"}}',
 encode(sha256(convert_to('TEIL2B','UTF8')),'hex')) on conflict do nothing;
insert into bike_pass_entries(code,tenant_id,shop,kind,body,trust) values ('KQ2345AE',null,'Anderer Laden','service','Bremsen entlüftet','verified'),('KQ2345AE',null,'Besitzer','service','Selbst geölt','self');
set role anon;
select (buyer_link_create('KQ2345AE','FALSCH')->>'error')='FYF_BAD_TRANSFER' as falscher_code_kein_link;
select buyer_link_create('KQ2345AE','TEIL2B')->>'token' as tok \gset
select length(:'tok')=20 as token_da;
select (buyer_view(:'tok')->'bike'->>'name')='Cube Attain' as kaeufer_sieht_rad;
select jsonb_array_length(buyer_view(:'tok')->'entries')=1 as nur_werkstatt_eintraege;
select jsonb_array_length(buyer_view(:'tok')->'svc')=1 as service_da;
select not (buyer_view(:'tok') ?| array['photo','lease','receipts']) and (buyer_view(:'tok'))::text !~ 'Selbst geölt' as nichts_privates;
select (pass_get('KQ2345AE')->>'limited')='true' as pass_bleibt_nur_werkstaetten;
select (buyer_link_status('KQ2345AE','TEIL2B')->>'active')='true' as status_aktiv;
select buyer_link_create('KQ2345AE','TEIL2B')->>'token' as tok2 \gset
select (buyer_view(:'tok')->>'error')='FYF_EXPIRED' as alter_link_ungueltig_nach_neuem;
select (buyer_link_revoke('KQ2345AE','TEIL2B')->>'revoked')='1' as zurueckgezogen;
select (buyer_view(:'tok2')->>'error')='FYF_EXPIRED' as nach_zurueckziehen_nichts;
reset role;
select buyer_link_create('KQ2345AE','TEIL2B')->>'token' as tok3 \gset
update pass_buyer_links set expires_at = now() - interval '1 minute' where code='KQ2345AE' and revoked_at is null;
set role anon;
select (buyer_view(:'tok3')->>'error')='FYF_EXPIRED' as abgelaufen_nichts;
select (buyer_view('AAAAAAAAAAAAAAAAAAAA')->>'error')='FYF_EXPIRED' as falscher_token_nichts;
-- Tabelle direkt lesen ist für anon gesperrt (erwartet: permission denied)
select count(*) from pass_buyer_links;
reset role;
