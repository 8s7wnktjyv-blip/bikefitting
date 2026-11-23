-- Test Stand 31: Läden „Eintrag übernehmen/entfernen“ + eigene Wünsche. Lokal Postgres 16. Alle Zeilen „t“.
\set ON_ERROR_STOP 0
set role anon;
select (shop_claim_submit('n123456','Radhaus Test','uebernehmen','Max Muster','0911 123456','Bitte zurückrufen')->>'ok')='true' as anfrage_ok;
select (shop_claim_submit('x1','Radhaus','uebernehmen','Max Muster','0911 123456')->>'error')='FYF_BAD_ID' as falsche_id;
select (shop_claim_submit('n123456','Radhaus','hacken','Max Muster','0911 123456')->>'error')='FYF_BAD_KIND' as falsche_art;
select (shop_claim_submit('n123456','Radhaus','uebernehmen','M','0911')->>'error')='FYF_BAD_INPUT' as zu_kurz;
select (shop_claim_submit('n123456','Radhaus Test','entfernen','Max Muster','0911 123456')->>'ok')='true' as zweite_ok;
select (shop_claim_submit('n123456','Radhaus Test','entfernen','Max Muster','0911 123456')->>'ok')='true' as dritte_ok;
select (shop_claim_submit('n123456','Radhaus Test','entfernen','Max Muster','0911 123456')->>'error')='FYF_RATE' as vierte_gebremst;
-- Liste nur für Plattform-Admin (erwartet: permission denied)
select count(*) from shop_claims_list();
select count(*)=0 as noch_nichts_ausgeblendet from shop_hidden_osm();
-- direkt lesen gesperrt (erwartet: permission denied)
select count(*) from shop_claims;
reset role;
insert into auth.users(id) values ('bbbbbbbb-0000-0000-0000-000000000031') on conflict do nothing;
insert into platform_admins(user_id) values ('bbbbbbbb-0000-0000-0000-000000000031') on conflict do nothing;
select set_config('request.jwt.claim.sub','bbbbbbbb-0000-0000-0000-000000000031',false);
set role authenticated;
select (select count(*) from shop_claims_list())=3 as admin_sieht_liste;
select (shop_claim_decide((select id from shop_claims_list() where kind='entfernen' limit 1),'bestaetigt')->>'ok')='true' as admin_bestaetigt;
select array_agg(x)=array['n123456'] as entfernt_ausgeblendet from shop_hidden_osm() x;
reset role;
select set_config('request.jwt.claim.sub','',false);
set role anon;
-- anon darf nicht entscheiden (erwartet: permission denied)
select shop_claim_decide(1,'abgelehnt');
-- Wünsche
select wish_submit('Apple Wallet für den Pass','geraet-abc-123')->>'id' as wid \gset
select :'wid' <> '' as wunsch_ok;
select (wish_submit('Ruf mich an 0911 1234567','geraet-abc-123')->>'error')='FYF_PERSONAL' as telefon_abgelehnt;
select (wish_submit('Mail an max@test.de','geraet-abc-123')->>'error')='FYF_PERSONAL' as mail_abgelehnt;
select (wish_submit('siehe www.beispiel.de','geraet-abc-123')->>'error')='FYF_PERSONAL' as link_abgelehnt;
select (wish_submit('Ziel 10.000 km im Jahr 2026 anzeigen','geraet-abc-123')->>'ok')='true' as zahlen_erlaubt;
select (wish_submit('Dunkle Karte','geraet-abc-123')->>'ok')='true' as dritter_ok;
select (wish_submit('Noch einer','geraet-abc-123')->>'error')='FYF_RATE' as vierter_gebremst;
select (wish_submit('x','geraet-abc-123')->>'error')='FYF_BAD_INPUT' as zu_kurz_w;
select (wish_submit('Gute Idee','kurz')->>'error')='FYF_BAD_DEVICE' as geraet_pruefen;
select count(*)=0 as nichts_oeffentlich_vor_freigabe from wish_list_public();
select (wish_vote(:wid,'geraet-xyz-999')->>'error')='FYF_NOT_FOUND' as abstimmen_erst_nach_freigabe;
-- Admin-Liste und Tabelle für anon gesperrt (erwartet: permission denied)
select count(*) from wish_admin_list();
select count(*) from wish_ideas;
reset role;
select set_config('request.jwt.claim.sub','bbbbbbbb-0000-0000-0000-000000000031',false);
set role authenticated;
select (wish_admin_set(:wid,'neu',true)->>'ok')='true' as admin_gibt_frei;
reset role;
select set_config('request.jwt.claim.sub','',false);
set role anon;
select count(*)=1 and bool_and(body='Apple Wallet für den Pass') as oeffentlich_sichtbar from wish_list_public();
select (wish_vote((select id from wish_list_public() limit 1),'geraet-xyz-999')->>'votes')='1' as stimme_gezaehlt;
select (wish_vote((select id from wish_list_public() limit 1),'geraet-xyz-999')->>'votes')='1' as keine_doppelstimme;
reset role;
