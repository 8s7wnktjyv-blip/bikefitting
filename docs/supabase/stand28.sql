-- FYF – Stand 28 (21.11.2026): Auftragsstatus im Pass (Punkt 7, Freigabe 21.11.2026).
-- Der Besitzer (mit Besitzer-Code, pass_get_owner) sieht seine laufenden Werkstattaufträge schon seit Stand 18.
-- Lücke: „Wartet auf Teile“ kam nie an (das steht nur im Laden-Stand, nicht in work_orders.status).
-- Jetzt: fyf_pass_workshop liest diesen Merker zusätzlich aus dem Laden-Stand. Nur lesend, kein Tabellen-Umbau.
-- Weiterhin nur für den Besitzer sichtbar, ohne Preise.
create or replace function fyf_pass_workshop(c text) returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('shop', t.name, 'title', w.title,
           'status', case when w.status not in ('Übergeben','Storniert','Abholbereit') and exists (
                 select 1 from tenant_state s, jsonb_array_elements(case when jsonb_typeof(s.data->'workshop') = 'array' then s.data->'workshop' else '[]'::jsonb end) e
                 where s.tenant_id = w.tenant_id and e->>'id' = w.legacy_id and jsonb_typeof(e->'wait') = 'object')
               then 'Wartet auf Teile' else w.status end,
           'due', w.due, 'since', w.created_at, 'done', w.done_at, 'approval', w.status = 'Freigabe ausstehend') order by w.created_at desc), '[]'::jsonb)
    from work_orders w join bikes b on b.id = w.bike_id join tenants t on t.id = w.tenant_id
   where b.pass_code = c and w.status <> 'Storniert'
     and (w.done_at is null or w.done_at > now() - interval '14 days') and w.created_at > now() - interval '120 days';
$$;
revoke all on function fyf_pass_workshop(text) from public, anon, authenticated;
