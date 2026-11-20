-- Test Stand 23: Kalender-Abo. Lokal Postgres 16 am 21.11.2026: Mitarbeiter holt Link (64 Zeichen), darf ihn nicht erneuern (FYF_DENIED); Link stabil; anon bekommt mit gültigem Link 2 Termine als .ics (10:30 Berlin = 09:30Z, Sonderzeichen maskiert, alter Termin ausgelassen), falscher Link = leerer Kalender, anon liest Tabelle nicht; „ohne Namen“ blendet Kundennamen aus.
\set ON_ERROR_STOP 0
insert into auth.users values ('11111111-1111-1111-1111-111111111123','a23@x'),('22222222-2222-2222-2222-222222222223','m23@x') on conflict do nothing;
insert into tenants(id,name) values ('aaaaaaaa-0000-0000-0000-000000000023','Laden 23') on conflict do nothing;
insert into memberships values ('11111111-1111-1111-1111-111111111123','aaaaaaaa-0000-0000-0000-000000000023','admin') on conflict do nothing;
insert into memberships values ('22222222-2222-2222-2222-222222222223','aaaaaaaa-0000-0000-0000-000000000023','mitarbeiter') on conflict do nothing;
insert into tenant_state(tenant_id,version,data) values ('aaaaaaaa-0000-0000-0000-000000000023',1,
 replace(replace('{"shop":{"name":"Testladen","addr":"Hauptstr. 1, Uttenreuth"},"customers":[{"id":"c1","name":"Erika Muster","phone":"0171 1234567"}],
   "appts":[{"id":"a1","kind":"Fitting","date":"D1","start":"10:30","dur":90,"customerId":"c1","note":"Knie, Rennrad"},{"id":"a2","kind":"Beratung","date":"D2","start":"09:00","dur":30,"name":"Max; Test, Komma"},{"id":"a3","kind":"Alt","date":"2000-01-01","start":"09:00"}]}','D1',(current_date+5)::text),'D2',(current_date+6)::text)::jsonb)
 on conflict (tenant_id) do update set data=excluded.data;
delete from cal_feeds where tenant_id='aaaaaaaa-0000-0000-0000-000000000023';
set role authenticated;
select set_config('request.jwt.claim.sub','22222222-2222-2222-2222-222222222223',false);
select length(cal_feed_token('aaaaaaaa-0000-0000-0000-000000000023','get')) as mitarbeiter_holt_link_laenge;
select cal_feed_token('aaaaaaaa-0000-0000-0000-000000000023','renew') as mitarbeiter_darf_nicht_erneuern;
select set_config('request.jwt.claim.sub','11111111-1111-1111-1111-111111111123',false);
select cal_feed_token('aaaaaaaa-0000-0000-0000-000000000023','get') = cal_feed_token('aaaaaaaa-0000-0000-0000-000000000023','get') as link_stabil;
reset role;
select token as tok from cal_feeds where tenant_id='aaaaaaaa-0000-0000-0000-000000000023' \gset
set role anon;
select convert_from(cal_feed(:'tok'),'UTF8') as ics;
select convert_from(cal_feed('falsch'),'UTF8') as ics_falscher_link;
select count(*) as anon_liest_tabelle from cal_feeds;
select cal_feed_token('aaaaaaaa-0000-0000-0000-000000000023','get') as anon_darf_kein_token;
reset role;
set role authenticated; select set_config('request.jwt.claim.sub','11111111-1111-1111-1111-111111111123',false);
select length(cal_feed_token('aaaaaaaa-0000-0000-0000-000000000023','get',false))>30 as ohne_namen_gesetzt;
reset role;
select token as tok from cal_feeds where tenant_id='aaaaaaaa-0000-0000-0000-000000000023' \gset
set role anon;
select position('Erika' in convert_from(cal_feed(:'tok'),'UTF8'))=0 as ohne_namen_ok;
reset role;
