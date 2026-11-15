-- FYF Plattform – Stand 17: Doppelschreiben (Freigabe Dominik 15.11.2026)
-- Bei jedem Speichern der bisherigen App (tenant_state) werden die neuen Tabellen automatisch mitgeschrieben.
-- Regeln:
--  * Quelle bleibt der bisherige Speicher. Die Tabellen sind ein Spiegel, bis umgeschaltet wird.
--  * Fehler beim Spiegeln dürfen das Speichern NIE verhindern (Ausnahmebehandlung, nur Warnung).
--  * Gesundheitsdaten (Körpercheck, Beschwerden) werden NICHT gespiegelt – Spalte health bleibt leer,
--    bis es ein Recht pro Spalte gibt (gesundheit.lesen).
--  * Ausgestellte Rechnungen werden nur ergänzt, nie geändert oder gelöscht.

-- Rechnungssperre: Verknüpfung zum Kunden darf beim Löschen eines Kunden entfallen, sonst nichts.
create or replace function invoices_lock() returns trigger language plpgsql as $$
begin
  if tg_op = 'UPDATE' and (to_jsonb(new) - 'customer_id') = (to_jsonb(old) - 'customer_id') then return new; end if;
  raise exception 'FYF_INVOICE_LOCKED';
end; $$;

create or replace function fyf_int(t text) returns int language sql immutable as $$
  select case when t ~ '^-?\d{1,9}(\.\d+)?$' then round(t::numeric)::int end $$;

create or replace function fyf_mirror() returns trigger
language plpgsql security definer set search_path = public as $$
declare t uuid := new.tenant_id; d jsonb := new.data;
begin
  begin
    -- Kunden
    insert into customers(tenant_id, legacy_id, kind, name, company, vat_id, leitweg_id, email, phone, address, consent, extra, updated_at)
    select t, e->>'id',
           case when e->>'kind' = 'firma' or (coalesce(e->>'kind','') = '' and coalesce(e->'invAddr'->>'company','') <> '') then 'firma' else 'privat' end,
           coalesce(nullif(e->>'name',''), 'Ohne Namen'),
           coalesce(nullif(e->>'company',''), e->'invAddr'->>'company'),
           e->>'vatId', coalesce(nullif(e->>'leitweg',''), e->'invAddr'->>'ref'),
           e->>'email', e->>'phone',
           jsonb_strip_nulls(jsonb_build_object('text', e->>'address', 'street', e->'invAddr'->>'street', 'zip', e->'invAddr'->>'zip', 'city', e->'invAddr'->>'city')),
           jsonb_strip_nulls(jsonb_build_object('consent', e->'consent', 'info', e->'consentInfo')),
           jsonb_strip_nulls(jsonb_build_object('since', e->>'since', 'discipline', e->>'discipline', 'tags', e->'tags')),
           now()
      from jsonb_array_elements(coalesce(d->'customers','[]')) e where e->>'id' is not null
    on conflict (tenant_id, legacy_id) do update set kind = excluded.kind, name = excluded.name, company = excluded.company, vat_id = excluded.vat_id,
      leitweg_id = excluded.leitweg_id, email = excluded.email, phone = excluded.phone, address = excluded.address, consent = excluded.consent,
      extra = excluded.extra, updated_at = now();
    delete from customers c where c.tenant_id = t and c.legacy_id is not null
      and not exists (select 1 from jsonb_array_elements(coalesce(d->'customers','[]')) e where e->>'id' = c.legacy_id);

    delete from customer_contacts where tenant_id = t;
    insert into customer_contacts(tenant_id, customer_id, name, role, email, phone)
    select t, c.id, coalesce(nullif(p->>'name',''), '–'), p->>'role', p->>'email', p->>'phone'
      from jsonb_array_elements(coalesce(d->'customers','[]')) e
      join customers c on c.tenant_id = t and c.legacy_id = e->>'id'
      cross join lateral jsonb_array_elements(case when jsonb_typeof(e->'contacts') = 'array' then e->'contacts' else '[]'::jsonb end) p;

    delete from followups where tenant_id = t;
    insert into followups(tenant_id, customer_id, due, text, done_at)
    select t, c.id, fyf_d(w->>'due'), left(coalesce(w->>'text',''), 160), case when fyf_d(w->>'done') is not null then fyf_d(w->>'done')::timestamptz end
      from jsonb_array_elements(coalesce(d->'customers','[]')) e
      join customers c on c.tenant_id = t and c.legacy_id = e->>'id'
      cross join lateral jsonb_array_elements(case when jsonb_typeof(e->'wv') = 'array' then e->'wv' else '[]'::jsonb end) w
     where fyf_d(w->>'due') is not null;

    -- Fahrräder
    insert into bikes(tenant_id, legacy_id, customer_id, pass_code, brand, model, type, size, year, color, km, data, updated_at)
    select t, e->>'id', c.id, e->'qr'->>'code', e->>'brand', e->>'model', e->>'type', e->>'size', fyf_int(e->>'year'), e->>'color', fyf_int(e->>'km'),
           jsonb_strip_nulls(jsonb_build_object('parts', e->'parts', 'saddle', e->>'saddle', 'pedal', e->>'pedal', 'lease', e->'lease', 'purchase', e->'purchase')), now()
      from jsonb_array_elements(coalesce(d->'bikes','[]')) e
      left join customers c on c.tenant_id = t and c.legacy_id = e->>'customerId'
     where e->>'id' is not null
    on conflict (tenant_id, legacy_id) do update set customer_id = excluded.customer_id, pass_code = excluded.pass_code, brand = excluded.brand, model = excluded.model,
      type = excluded.type, size = excluded.size, year = excluded.year, color = excluded.color, km = excluded.km, data = excluded.data, updated_at = now();
    delete from bikes b where b.tenant_id = t and b.legacy_id is not null
      and not exists (select 1 from jsonb_array_elements(coalesce(d->'bikes','[]')) e where e->>'id' = b.legacy_id);

    -- Werkstatt
    insert into work_orders(tenant_id, legacy_id, customer_id, bike_id, title, status, due, mechanic, intake, approval, qc, lease, created_at, done_at)
    select t, e->>'id', c.id, b.id, coalesce(nullif(e->>'title',''), 'Werkstattauftrag'), coalesce(nullif(e->>'status',''), 'Angenommen'), fyf_d(e->>'due'), e->>'mechanic',
           e->'intake', e->'approval', e->'qc', e->'lease', coalesce(fyf_d(e->>'created')::timestamptz, now()), fyf_d(e->>'doneAt')::timestamptz
      from jsonb_array_elements(coalesce(d->'workshop','[]')) e
      left join customers c on c.tenant_id = t and c.legacy_id = e->>'customerId'
      left join bikes b on b.tenant_id = t and b.legacy_id = e->>'bikeId'
     where e->>'id' is not null
    on conflict (tenant_id, legacy_id) do update set customer_id = excluded.customer_id, bike_id = excluded.bike_id, title = excluded.title, status = excluded.status,
      due = excluded.due, mechanic = excluded.mechanic, intake = excluded.intake, approval = excluded.approval, qc = excluded.qc, lease = excluded.lease, done_at = excluded.done_at;
    delete from work_orders w where w.tenant_id = t and w.legacy_id is not null
      and not exists (select 1 from jsonb_array_elements(coalesce(d->'workshop','[]')) e where e->>'id' = w.legacy_id);

    delete from work_order_items where tenant_id = t;
    insert into work_order_items(tenant_id, work_order_id, kind, text, qty, price, booked, sort)
    select t, w.id, case when p->>'kind' = 'Teil' then 'Teil' else 'Arbeit' end, left(coalesce(p->>'t',''), 200),
           coalesce(fyf_n(p->>'qty'), 1), coalesce(fyf_n(p->>'price'), 0), coalesce((p->>'booked')::boolean, false), (o - 1)::int
      from jsonb_array_elements(coalesce(d->'workshop','[]')) e
      join work_orders w on w.tenant_id = t and w.legacy_id = e->>'id'
      cross join lateral jsonb_array_elements(case when jsonb_typeof(e->'positions') = 'array' then e->'positions' else '[]'::jsonb end) with ordinality as x(p, o);

    delete from work_order_checks where tenant_id = t;
    insert into work_order_checks(tenant_id, work_order_id, text, source, ok, sort)
    select t, w.id, left(coalesce(k->>'t',''), 200), k->>'src', coalesce((k->>'ok')::boolean, false), (o - 1)::int
      from jsonb_array_elements(coalesce(d->'workshop','[]')) e
      join work_orders w on w.tenant_id = t and w.legacy_id = e->>'id'
      cross join lateral jsonb_array_elements(case when jsonb_typeof(e->'checklist') = 'array' then e->'checklist' else '[]'::jsonb end) with ordinality as x(k, o);

    -- Preisliste und Checklisten
    delete from labor_items where tenant_id = t;
    insert into labor_items(tenant_id, legacy_id, cat, name, price, checklist, sort)
    select t, e->>'id', e->>'cat', left(coalesce(e->>'name',''), 120), coalesce(fyf_n(e->>'price'), 0), nullif(e->>'tpl',''), (o - 1)::int
      from jsonb_array_elements(case when jsonb_typeof(d->'labor') = 'array' then d->'labor' else '[]'::jsonb end) with ordinality as x(e, o);
    delete from check_templates where tenant_id = t;
    insert into check_templates(tenant_id, name, items)
    select t, k, array(select jsonb_array_elements_text(v))
      from jsonb_each(case when jsonb_typeof(d->'checkTpl') = 'object' then d->'checkTpl' else '{}'::jsonb end) as y(k, v)
     where jsonb_typeof(v) = 'array';

    -- Rechnungen: nur neue ergänzen (ausgestellt = unveränderlich)
    insert into invoices(tenant_id, legacy_id, number, kind, customer_id, issued_at, data)
    select t, e->>'id', e->>'no', case when e->>'type' = 'storno' then 'Storno' else 'Rechnung' end, c.id, fyf_d(e->>'date'), e
      from jsonb_array_elements(coalesce(d->'invoices','[]')) e
      left join customers c on c.tenant_id = t and c.legacy_id = e->>'customerId'
     where coalesce(e->>'no','') <> '' and fyf_d(e->>'date') is not null
    on conflict (tenant_id, number) do nothing;
  exception when others then
    raise warning 'FYF Spiegel übersprungen (%): %', sqlstate, sqlerrm;
  end;
  return new;
end $$;

drop trigger if exists fyf_mirror_t on tenant_state;
create trigger fyf_mirror_t after insert or update of data on tenant_state for each row execute function fyf_mirror();

-- Einmal für alle vorhandenen Läden spiegeln (ändert tenant_state nicht)
do $$ declare r record; begin
  for r in select tenant_id, data from tenant_state loop
    update tenant_state set data = data where tenant_id = r.tenant_id;
  end loop;
end $$;
