-- Test Stand 24: Werkstatt-Bewertungen. Lokal Postgres 16 am 21.11.2026: falscher Übergabe-Code, eigener Eintrag, zu alter Eintrag, fremder Pass, 6 Sterne und Doppelbewertung abgelehnt; zwei gültige Bewertungen; öffentlich Ø 4,5 ohne Namen; Durchschnitt in der Übersicht erst ab 3; anon liest Tabelle nicht; Mitarbeiter liest, darf nicht antworten; Admin antwortet und meldet; Laden darf nicht ausblenden.
\set ON_ERROR_STOP 0
insert into auth.users values ('11111111-1111-1111-1111-111111111124','a24@x'),('22222222-2222-2222-2222-222222222224','m24@x') on conflict do nothing;
insert into tenants(id,name) values ('aaaaaaaa-0000-0000-0000-000000000024','Laden 24') on conflict do nothing;
insert into memberships values ('11111111-1111-1111-1111-111111111124','aaaaaaaa-0000-0000-0000-000000000024','admin') on conflict do nothing;
insert into memberships values ('22222222-2222-2222-2222-222222222224','aaaaaaaa-0000-0000-0000-000000000024','mitarbeiter') on conflict do nothing;
insert into dealer_profiles(tenant_id,slug,published,name) values ('aaaaaaaa-0000-0000-0000-000000000024','laden-24',true,'Laden 24') on conflict (tenant_id) do update set published=true;
delete from shop_reviews where tenant_id='aaaaaaaa-0000-0000-0000-000000000024';
delete from bike_passes where code in ('RVWTEST2','RVWTEST3');
insert into bike_passes(code,tenant_id,bike_ref,payload,transfer_hash) values
 ('RVWTEST2','aaaaaaaa-0000-0000-0000-000000000024','b1','{}',encode(sha256(convert_to('GEHEIMCODE12','UTF8')),'hex')),
 ('RVWTEST3','aaaaaaaa-0000-0000-0000-000000000024','b2','{}',encode(sha256(convert_to('ANDERERCODE1','UTF8')),'hex'));
insert into bike_pass_entries(code,tenant_id,shop,kind,body,done_on,trust) values
 ('RVWTEST2','aaaaaaaa-0000-0000-0000-000000000024','Laden 24','Service','Inspektion',current_date-3,'shop'),
 ('RVWTEST2',null,'Besitzer','Service','selbst gemacht',current_date-1,'self'),
 ('RVWTEST2','aaaaaaaa-0000-0000-0000-000000000024','Laden 24','Service','alt',current_date-200,'shop'),
 ('RVWTEST3','aaaaaaaa-0000-0000-0000-000000000024','Laden 24','Service','Bremsen',current_date-2,'shop');
select id as e_shop from bike_pass_entries where code='RVWTEST2' and body='Inspektion' \gset
select id as e_self from bike_pass_entries where code='RVWTEST2' and body='selbst gemacht' \gset
select id as e_old from bike_pass_entries where code='RVWTEST2' and body='alt' \gset
select id as e_other from bike_pass_entries where code='RVWTEST3' \gset
set role anon;
select review_submit('RVWTEST2','FALSCH',:e_shop,5,'x')->>'error' as falscher_code;
select review_submit('RVWTEST2','GEHEIMCODE12',:e_self,5,'x')->>'error' as eigener_eintrag;
select review_submit('RVWTEST2','GEHEIMCODE12',:e_old,5,'x')->>'error' as zu_alt;
select review_submit('RVWTEST2','GEHEIMCODE12',:e_other,5,'x')->>'error' as fremder_pass;
select review_submit('RVWTEST2','GEHEIMCODE12',:e_shop,6,'x')->>'error' as sechs_sterne;
select review_submit('RVWTEST2','GEHEIMCODE12',:e_shop,4,'Schnell und freundlich')->>'ok' as bewertet;
select review_submit('RVWTEST2','GEHEIMCODE12',:e_shop,1,'nochmal')->>'error' as doppelt;
select review_submit('RVWTEST3','ANDERERCODE1',:e_other,5,'Top')->>'ok' as zweiter_pass;
select review_done('RVWTEST2','GEHEIMCODE12') as erledigt;
select review_public('laden-24') as oeffentlich;
select * from review_stats() where slug='laden-24';
select count(*) as anon_liest_tabelle from shop_reviews;
select review_mine('aaaaaaaa-0000-0000-0000-000000000024') as anon_darf_nicht;
reset role;
set role authenticated;
select set_config('request.jwt.claim.sub','22222222-2222-2222-2222-222222222224',false);
select jsonb_array_length(review_mine('aaaaaaaa-0000-0000-0000-000000000024')) as mitarbeiter_sieht;
select review_reply('aaaaaaaa-0000-0000-0000-000000000024',(select 1::bigint),'x') as mitarbeiter_antwort_verboten;
select set_config('request.jwt.claim.sub','11111111-1111-1111-1111-111111111124',false);
reset role;
select id as rid from shop_reviews where entry_id=:e_shop \gset
set role authenticated;
select review_reply('aaaaaaaa-0000-0000-0000-000000000024',:rid,'Danke!');
select review_report('aaaaaaaa-0000-0000-0000-000000000024',:rid,'Test');
select review_moderate(:rid,true) as laden_darf_nicht_ausblenden;
reset role;
set role anon;
select review_public('laden-24')->'list' as nach_antwort;
reset role;
