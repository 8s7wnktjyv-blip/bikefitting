-- Test Stand 27: Kündigung eines Ladens. Lokal mit Postgres 16 (Supabase-Nachbau). Alle Zeilen müssen „t“ zeigen;
-- NOTICE-Zeilen beginnen mit „ok_“, „FEHLER“ darf nicht vorkommen.
\set ON_ERROR_STOP 0
insert into auth.users values ('11111111-1111-1111-1111-111111111127','a27@x.de'),('22222222-2222-2222-2222-222222222227','m27@x.de'),
 ('33333333-3333-3333-3333-333333333327','p27@x.de'),('44444444-4444-4444-4444-444444444427','o27@x.de') on conflict do nothing;
insert into platform_admins values ('33333333-3333-3333-3333-333333333327') on conflict do nothing;
insert into tenants(id,name) values ('aaaaaaaa-0000-0000-0000-000000000027','Laden 27'),('aaaaaaaa-0000-0000-0000-00000000027b','Anderer Laden') on conflict do nothing;
insert into memberships values ('11111111-1111-1111-1111-111111111127','aaaaaaaa-0000-0000-0000-000000000027','admin',null),
 ('22222222-2222-2222-2222-222222222227','aaaaaaaa-0000-0000-0000-000000000027','mitarbeiter','Tablet'),
 ('44444444-4444-4444-4444-444444444427','aaaaaaaa-0000-0000-0000-00000000027b','admin',null) on conflict do nothing;
insert into tenant_state(tenant_id,version,data) values ('aaaaaaaa-0000-0000-0000-000000000027',1,'{"version":3,"customers":[{"id":"c1","name":"Erika"}]}') on conflict do nothing;
insert into dealer_profiles(tenant_id,slug,published,name) values ('aaaaaaaa-0000-0000-0000-000000000027','laden-27',true,'Laden 27') on conflict (tenant_id) do update set published=true;
insert into invitations(tenant_id,email,role) values ('aaaaaaaa-0000-0000-0000-000000000027','neu27@x.de','verkauf') on conflict do nothing;
insert into trade_offers(tenant_id,title,category,qty) values ('aaaaaaaa-0000-0000-0000-000000000027','Restposten Ketten','Antrieb',5);
insert into bike_passes(code,tenant_id,bike_ref,payload) values ('KQ2345AC','aaaaaaaa-0000-0000-0000-000000000027','b1','{"brand":"Cube"}') on conflict do nothing;
insert into bike_pass_entries(code,tenant_id,shop,kind,body) values ('KQ2345AC','aaaaaaaa-0000-0000-0000-000000000027','Laden 27','service','Inspektion'),
 ('KQ2345AC','aaaaaaaa-0000-0000-0000-00000000027b','Anderer Laden','service','Kette getauscht');

set role authenticated;
-- Nur Plattform-Admin darf schließen
select set_config('request.jwt.claim.sub','11111111-1111-1111-1111-111111111127',false);
do $$ begin perform tenant_close('aaaaaaaa-0000-0000-0000-000000000027','test'); raise notice 'FEHLER: Laden-Admin schließt'; exception when others then raise notice 'ok_nur_plattform_admin: %', sqlerrm; end $$;
select is_member('aaaaaaaa-0000-0000-0000-000000000027') as vorher_mitglied;
-- Plattform-Admin schließt
select set_config('request.jwt.claim.sub','33333333-3333-3333-3333-333333333327',false);
select tenant_close('aaaaaaaa-0000-0000-0000-000000000027','Kündigung zum 31.12.');
select count(*)=1 as in_liste_geschlossen from platform_closed() where id='aaaaaaaa-0000-0000-0000-000000000027';
-- Ehemaliger Admin und Mitarbeiter sehen nichts mehr
select set_config('request.jwt.claim.sub','11111111-1111-1111-1111-111111111127',false);
select not is_member('aaaaaaaa-0000-0000-0000-000000000027') as admin_kein_mitglied;
do $$ begin perform state_get('aaaaaaaa-0000-0000-0000-000000000027'); raise notice 'FEHLER: liest Stand'; exception when others then raise notice 'ok_state_get_gesperrt: %', sqlerrm; end $$;
do $$ begin perform save_state('aaaaaaaa-0000-0000-0000-000000000027','{"version":3,"customers":[]}',1); raise notice 'FEHLER: schreibt Stand'; exception when others then raise notice 'ok_save_state_gesperrt: %', sqlerrm; end $$;
do $$ begin perform pass_add('aaaaaaaa-0000-0000-0000-000000000027','KQ2345AC','service','x',null,null); raise notice 'FEHLER: Passeintrag'; exception when others then raise notice 'ok_passeintrag_gesperrt: %', sqlerrm; end $$;
select count(*)=0 as kein_direkter_zugriff from tenant_state where tenant_id='aaaaaaaa-0000-0000-0000-000000000027';
select name='Laden 27' as hinweis_geschlossen from my_closed_shop();
select set_config('request.jwt.claim.sub','22222222-2222-2222-2222-222222222227',false);
do $$ begin perform state_get('aaaaaaaa-0000-0000-0000-000000000027'); raise notice 'FEHLER: Mitarbeiter liest'; exception when others then raise notice 'ok_mitarbeiter_gesperrt: %', sqlerrm; end $$;
-- Öffentlich: Profil weg, Angebot beendet; Pass vollständig
set role anon;
select count(*)=0 as profil_nicht_oeffentlich from dealer_profiles where tenant_id='aaaaaaaa-0000-0000-0000-000000000027' and published;
reset role;
select (select count(*) from trade_offers where tenant_id='aaaaaaaa-0000-0000-0000-000000000027' and status='beendet')=1 as angebot_beendet,
       (select count(*) from bike_pass_entries where code='KQ2345AC')=2 as pass_eintraege_alle_da,
       (select count(*) from bike_passes where code='KQ2345AC')=1 as pass_da,
       (select count(*) from tenant_state where tenant_id='aaaaaaaa-0000-0000-0000-000000000027')=1 as daten_aufbewahrt;
-- Wiederbeitritt über Einladung/Kopplung gesperrt
do $$ begin insert into memberships values ('22222222-2222-2222-2222-222222222227','aaaaaaaa-0000-0000-0000-000000000027','admin',null); raise notice 'FEHLER: Beitritt'; exception when others then raise notice 'ok_beitritt_gesperrt: %', sqlerrm; end $$;
-- Anderer Laden unberührt
set role authenticated;
select set_config('request.jwt.claim.sub','44444444-4444-4444-4444-444444444427',false);
select is_member('aaaaaaaa-0000-0000-0000-00000000027b') as anderer_laden_normal;
-- Wieder öffnen
select set_config('request.jwt.claim.sub','33333333-3333-3333-3333-333333333327',false);
select tenant_reopen('aaaaaaaa-0000-0000-0000-000000000027')=2 as zwei_mitglieder_zurueck;
reset role;
select (select role from memberships where user_id='22222222-2222-2222-2222-222222222227')='mitarbeiter' as rolle_wie_vorher,
       (select published from dealer_profiles where tenant_id='aaaaaaaa-0000-0000-0000-000000000027') as profil_wieder_oeffentlich,
       (select status from trade_offers where tenant_id='aaaaaaaa-0000-0000-0000-000000000027' limit 1)='aktiv' as angebot_wieder_aktiv,
       (select count(*) from invitations where tenant_id='aaaaaaaa-0000-0000-0000-000000000027' and email='neu27@x.de')=1 as einladung_wieder_da;
set role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-1111-1111-111111111127',false);
select (state_get('aaaaaaaa-0000-0000-0000-000000000027')->'data'->'customers'->0->>'name')='Erika' as admin_liest_wieder;
reset role;
-- Laden löschen: Pass mit allen Einträgen bleibt
delete from tenant_state_history where tenant_id='aaaaaaaa-0000-0000-0000-000000000027';
delete from tenants where id='aaaaaaaa-0000-0000-0000-000000000027';
select (select count(*) from bike_passes where code='KQ2345AC' and tenant_id is null)=1 as pass_nach_loeschen_da,
       (select count(*) from bike_pass_entries where code='KQ2345AC')=2 as eintraege_nach_loeschen_da;
