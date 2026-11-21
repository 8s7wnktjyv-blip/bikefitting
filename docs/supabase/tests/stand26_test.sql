-- Test Stand 26: vier weitere Rollen vergebbar und auf dem Server gefiltert. Lokal mit Postgres 16 (Supabase-Nachbau).
-- Erwartung steht jeweils im Spaltennamen; alle Zeilen müssen „t“ zeigen, nur „anon“ endet mit „permission denied“.
\set ON_ERROR_STOP 0
insert into auth.users values
 ('11111111-1111-1111-1111-111111111126','a26@x.de'),('22222222-2222-2222-2222-222222222226','w26@x.de'),
 ('33333333-3333-3333-3333-333333333326','v26@x.de'),('44444444-4444-4444-4444-444444444426','b26@x.de'),
 ('55555555-5555-5555-5555-555555555526','fl26@x.de'),('66666666-6666-6666-6666-666666666626','m26@x.de') on conflict do nothing;
insert into tenants(id,name) values ('aaaaaaaa-0000-0000-0000-000000000026','Laden 26'),('aaaaaaaa-0000-0000-0000-00000000026b','Laden 26b') on conflict do nothing;
insert into memberships values ('11111111-1111-1111-1111-111111111126','aaaaaaaa-0000-0000-0000-000000000026','admin'),
 ('66666666-6666-6666-6666-666666666626','aaaaaaaa-0000-0000-0000-000000000026','mitarbeiter') on conflict do nothing;
delete from tenant_state where tenant_id in ('aaaaaaaa-0000-0000-0000-000000000026','aaaaaaaa-0000-0000-0000-00000000026b');
insert into tenant_state(tenant_id,version,data) values ('aaaaaaaa-0000-0000-0000-000000000026',5,
 '{"version":3,"customers":[{"id":"c1","name":"Erika","body":{"height":170}}],"workshop":[{"id":"W1"}],"invoices":[{"id":"i1","no":"RE-1","status":"offen"}],"payments":[{"id":"p1","amount":50}],"sales":[{"id":"s1"}],"suppliers":[{"id":"l1"}],"purchaseOrders":[{"id":"o1"}],"invSeq":7,"datev":{"k":1},"dunCfg":{"d":1}}');

set role authenticated;
-- Admin lädt alle vier neuen Rollen ein (vorher: FYF_BAD_ROLE)
select set_config('request.jwt.claim.sub','11111111-1111-1111-1111-111111111126',false);
select invite_member('aaaaaaaa-0000-0000-0000-000000000026','w26@x.de','werkstattleitung') is not null as einladung_werkstattleitung;
select invite_member('aaaaaaaa-0000-0000-0000-000000000026','v26@x.de','verkauf') is not null as einladung_verkauf;
select invite_member('aaaaaaaa-0000-0000-0000-000000000026','b26@x.de','buchhaltung') is not null as einladung_buchhaltung;
select invite_member('aaaaaaaa-0000-0000-0000-000000000026','fl26@x.de','filialleitung') is not null as einladung_filialleitung;
do $$ begin perform invite_member('aaaaaaaa-0000-0000-0000-000000000026','x26@x.de','chef'); raise notice 'FEHLER: unbekannte Rolle angenommen'; exception when others then raise notice 'ok_unbekannte_rolle_abgelehnt: %', sqlerrm; end $$;
-- Annehmen
select set_config('request.jwt.claim.sub','22222222-2222-2222-2222-222222222226',false); select accept_invites() is not null as angenommen_w;
select set_config('request.jwt.claim.sub','33333333-3333-3333-3333-333333333326',false); select accept_invites() is not null as angenommen_v;
select set_config('request.jwt.claim.sub','44444444-4444-4444-4444-444444444426',false); select accept_invites() is not null as angenommen_b;
select set_config('request.jwt.claim.sub','55555555-5555-5555-5555-555555555526',false); select accept_invites() is not null as angenommen_fl;

-- Werkstattleitung: kein Geld, aber Lager/Lieferanten; Körperdaten sichtbar
select set_config('request.jwt.claim.sub','22222222-2222-2222-2222-222222222226',false);
select not ((state_get('aaaaaaaa-0000-0000-0000-000000000026')->'data') ?| array['invoices','payments','sales','invSeq','datev','dunCfg']) as werkstattleitung_ohne_geld;
select (state_get('aaaaaaaa-0000-0000-0000-000000000026')->'data') ?& array['suppliers','purchaseOrders','workshop'] as werkstattleitung_sieht_lager;
select save_state('aaaaaaaa-0000-0000-0000-000000000026','{"version":3,"customers":[{"id":"c1","name":"Erika","body":{"height":170}}],"workshop":[{"id":"W1","status":"fertig"}],"suppliers":[{"id":"l1"},{"id":"l2"}],"purchaseOrders":[{"id":"o1"}],"sales":[{"id":"s2"}]}',5) = 6 as werkstattleitung_speichert;
reset role;
select data->'invoices'->0->>'no'='RE-1' and data->>'invSeq'='7' and data ? 'datev' and data ? 'dunCfg'
   and jsonb_array_length(data->'payments')=1 and jsonb_array_length(data->'sales')=2 and jsonb_array_length(data->'suppliers')=2
   and data->'workshop'->0->>'status'='fertig' as nach_werkstattleitung_nichts_verloren
 from tenant_state where tenant_id='aaaaaaaa-0000-0000-0000-000000000026';
set role authenticated;

-- Verkauf: Rechnungen sichtbar, DATEV/Mahnwesen nicht; darf neue Rechnung anlegen, alte nicht ändern
select set_config('request.jwt.claim.sub','33333333-3333-3333-3333-333333333326',false);
select (state_get('aaaaaaaa-0000-0000-0000-000000000026')->'data') ? 'invoices' and not ((state_get('aaaaaaaa-0000-0000-0000-000000000026')->'data') ?| array['datev','dunCfg']) as verkauf_sieht_rechnungen_ohne_datev;
select (state_get('aaaaaaaa-0000-0000-0000-000000000026')->'data') - 'datev' - 'dunCfg' as dv \gset
select save_state('aaaaaaaa-0000-0000-0000-000000000026', jsonb_set(:'dv'::jsonb,'{invoices}', (:'dv'::jsonb->'invoices') || '[{"id":"i2","no":"RE-2","status":"offen"}]'::jsonb), 6) = 7 as verkauf_legt_rechnung_an;
do $$ begin perform save_state('aaaaaaaa-0000-0000-0000-000000000026','{"version":3,"customers":[{"id":"c1","name":"Erika"}],"invoices":[{"id":"i1","no":"RE-1","status":"offen","total":1},{"id":"i2","no":"RE-2","status":"offen"}]}',7); raise notice 'FEHLER: Rechnung geändert'; exception when others then raise notice 'ok_verkauf_alte_rechnung_gesperrt: %', sqlerrm; end $$;
reset role;
select data ? 'datev' and data ? 'dunCfg' and jsonb_array_length(data->'invoices')=2 as nach_verkauf_datev_da
 from tenant_state where tenant_id='aaaaaaaa-0000-0000-0000-000000000026';
set role authenticated;

-- Buchhaltung und Filialleitung: alles sichtbar
select set_config('request.jwt.claim.sub','44444444-4444-4444-4444-444444444426',false);
select (state_get('aaaaaaaa-0000-0000-0000-000000000026')->'data') ?& array['invoices','payments','datev','dunCfg','invSeq'] as buchhaltung_sieht_alles;
select set_config('request.jwt.claim.sub','55555555-5555-5555-5555-555555555526',false);
select (state_get('aaaaaaaa-0000-0000-0000-000000000026')->'data') ?& array['invoices','payments','datev','suppliers'] as filialleitung_sieht_alles;
select count(*)=0 as filialleitung_liest_tabelle_nicht_direkt from tenant_state where tenant_id='aaaaaaaa-0000-0000-0000-000000000026';

-- Mitarbeiter: unverändert wie Stand 25
select set_config('request.jwt.claim.sub','66666666-6666-6666-6666-666666666626',false);
select not ((state_get('aaaaaaaa-0000-0000-0000-000000000026')->'data') ?| array['invoices','payments','sales','suppliers','purchaseOrders','invSeq']) as mitarbeiter_wie_bisher;

-- Admin ändert Rolle auf neue Rolle und zurück
select set_config('request.jwt.claim.sub','11111111-1111-1111-1111-111111111126',false);
select set_member_role('aaaaaaaa-0000-0000-0000-000000000026','66666666-6666-6666-6666-666666666626','verkauf');
select role='verkauf' as rolle_auf_verkauf from list_members('aaaaaaaa-0000-0000-0000-000000000026') where user_id='66666666-6666-6666-6666-666666666626';
select set_member_role('aaaaaaaa-0000-0000-0000-000000000026','66666666-6666-6666-6666-666666666626','mitarbeiter');
select role='mitarbeiter' as rolle_zurueck from list_members('aaaaaaaa-0000-0000-0000-000000000026') where user_id='66666666-6666-6666-6666-666666666626';
-- Nur Admin darf einladen
select set_config('request.jwt.claim.sub','55555555-5555-5555-5555-555555555526',false);
do $$ begin perform invite_member('aaaaaaaa-0000-0000-0000-000000000026','y26@x.de','verkauf'); raise notice 'FEHLER: Filialleitung lädt ein'; exception when others then raise notice 'ok_nur_admin_laedt_ein: %', sqlerrm; end $$;
reset role;

-- Ersten Stand legt keine Rolle mit verborgenen Teilen an
insert into memberships values ('22222222-2222-2222-2222-222222222226','aaaaaaaa-0000-0000-0000-00000000026b','werkstattleitung') on conflict do nothing;
set role authenticated;
select set_config('request.jwt.claim.sub','22222222-2222-2222-2222-222222222226',false);
do $$ begin perform save_state('aaaaaaaa-0000-0000-0000-00000000026b','{"version":3,"customers":[]}',0); raise notice 'FEHLER: erster Stand von Werkstattleitung'; exception when others then raise notice 'ok_erster_stand_gesperrt: %', sqlerrm; end $$;
set role anon;
select state_get('aaaaaaaa-0000-0000-0000-000000000026') as anon;
reset role;
