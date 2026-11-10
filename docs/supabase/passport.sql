-- FYF – Fit your Frame · FYF Passport, Kern (Stand 11)
--
-- 1. Einträge im Fahrradpass sind unveränderlich. Korrekturen sind neue Einträge mit Verweis (corrects).
--    Jeder Eintrag hat Herkunft (Betrieb), Zeitstempel und Vertrauensstufe:
--      'verified' – eingetragen von einem geprüften Betrieb (tenants.verified), egal ob mit FYF-Abo
--      'shop'     – eingetragen von einem Betrieb, der noch nicht geprüft ist
--      'self'     – Selbstauskunft des Besitzers (folgt mit dem Besitzer-Konto)
--    receipt = Beleg vorhanden (folgt mit der Beleg-Ablage).
-- 2. Fahrradschein nach dem Fahrzeugbrief-Prinzip: Der QR-Aufkleber (Teil I) ist öffentlich.
--    Teil II ist eine Karte mit einem geheimen Übergabe-Code. Gespeichert wird nur sein Hash.
--    Wer Teil II vorlegt, kann den Pass in einer Werkstatt auf den neuen Besitzer bzw. die neue Werkstatt übertragen.
--    Danach gilt der alte Code nicht mehr. Namen von Besitzern werden nie gespeichert – nur die Nummer (1., 2., …).
-- 3. Ein Laden kann seinen Pass nicht mehr löschen, nur zurückziehen (nicht mehr öffentlich). Die Geschichte bleibt erhalten.

alter table bike_pass_entries add column if not exists trust text not null default 'shop';
alter table bike_pass_entries add column if not exists receipt boolean not null default false;
alter table bike_pass_entries add column if not exists ref text;
alter table bike_pass_entries add column if not exists corrects bigint references bike_pass_entries(id);
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'bike_pass_entries_trust_chk') then
    alter table bike_pass_entries add constraint bike_pass_entries_trust_chk check (trust in ('verified','shop','self'));
  end if;
end $$;
-- Löscht ein Betrieb sein Konto, bleiben seine Einträge in fremden Pässen erhalten (Name des Betriebs steht im Eintrag).
alter table bike_pass_entries alter column tenant_id drop not null;
do $$ begin
  if exists (select 1 from pg_constraint where conname = 'bike_pass_entries_tenant_id_fkey' and confdeltype = 'c') then
    alter table bike_pass_entries drop constraint bike_pass_entries_tenant_id_fkey;
    alter table bike_pass_entries add constraint bike_pass_entries_tenant_id_fkey foreign key (tenant_id) references tenants(id) on delete set null;
  end if;
end $$;
create unique index if not exists bike_pass_entries_ref on bike_pass_entries (code, tenant_id, ref) where ref is not null;

alter table bike_passes add column if not exists transfer_hash text;
alter table bike_passes add column if not exists owner_no int not null default 1;
alter table bike_passes add column if not exists owner_since date not null default current_date;
alter table bike_passes add column if not exists withdrawn_at timestamptz;
-- Was der Besitzer selbst (mit Teil II) eingestellt hat, gilt vor der Einstellung des Ladens – bis einer von beiden es wieder ändert.
alter table bike_passes add column if not exists owner_vis text check (owner_vis in ('public','shops'));
alter table bike_passes add column if not exists owner_stolen boolean;
-- Selbst registrierte Räder (ohne Laden): tenant_id/bike_ref leer, bis eine Werkstatt den Pass mit Teil II übernimmt.
alter table bike_passes alter column tenant_id drop not null;
alter table bike_passes alter column bike_ref drop not null;
-- Diebstahl-Abgleich: nur der Hash der Rahmennummer (nie die Nummer selbst)
alter table bike_passes add column if not exists frame_hash text check (frame_hash ~ '^[0-9a-f]{64}$');
create index if not exists bike_passes_fh on bike_passes (frame_hash) where frame_hash is not null;
alter table bike_passes add column if not exists owner_fails int not null default 0;
alter table bike_passes add column if not exists owner_fail_at timestamptz;

-- Räder, deren Pass an einen anderen Besitzer / eine andere Werkstatt übergeben wurde (der alte Laden darf nicht mehr schreiben)
create table if not exists bike_pass_moved (
  tenant_id uuid not null references tenants(id) on delete cascade,
  bike_ref text not null,
  code text not null references bike_passes(code) on delete cascade,
  moved_at timestamptz not null default now(),
  primary key (tenant_id, bike_ref)
);
alter table bike_pass_moved enable row level security;

-- Unveränderlich: kein Ändern, kein Löschen (außer automatisch, wenn ein ganzer Betrieb gelöscht wird)
create or replace function fyf_pass_entries_lock() returns trigger
language plpgsql as $$
begin
  if pg_trigger_depth() < 2 then raise exception 'FYF_LOCKED'; end if;
  return case when tg_op = 'DELETE' then old else new end;
end $$;
drop trigger if exists bike_pass_entries_lock on bike_pass_entries;
create trigger bike_pass_entries_lock before update or delete on bike_pass_entries for each row execute function fyf_pass_entries_lock();

create or replace function pass_entry(p_tenant uuid, p_code text, p_kind text, p_text text, p_km int, p_date date, p_ref text, p_corrects bigint) returns bigint
language plpgsql security definer set search_path = public as $$
declare k record; sh text; v boolean; n bigint;
begin
  if not is_member(p_tenant) then raise exception 'FYF_DENIED'; end if;
  select * into k from bike_passes where code = upper(coalesce(p_code, ''));
  if k.code is null then raise exception 'FYF_NOT_FOUND'; end if;
  if k.withdrawn_at is not null then raise exception 'FYF_WITHDRAWN'; end if;
  select name, verified into sh, v from tenants where id = p_tenant;
  if k.tenant_id is distinct from p_tenant and not coalesce(v, false) then raise exception 'FYF_NOT_VERIFIED'; end if;
  if p_ref is not null then
    if length(p_ref) > 60 then raise exception 'FYF_BAD_DATA'; end if;
    select id into n from bike_pass_entries where code = k.code and tenant_id = p_tenant and ref = p_ref;
    if n is not null then return n; end if;
  end if;
  if length(trim(coalesce(p_text, ''))) < 3 or length(p_text) > 500 or length(coalesce(p_kind, '')) not between 2 and 40 then raise exception 'FYF_BAD_DATA'; end if;
  if p_km is not null and (p_km < 0 or p_km > 1000000) then raise exception 'FYF_BAD_DATA'; end if;
  if p_date is not null and (p_date > current_date + 1 or p_date < current_date - 7300) then raise exception 'FYF_BAD_DATA'; end if;
  if p_corrects is not null and not exists (select 1 from bike_pass_entries where id = p_corrects and code = k.code) then raise exception 'FYF_BAD_DATA'; end if;
  if (select count(*) from bike_pass_entries where tenant_id = p_tenant and created_at > now() - interval '1 day') >= 500 then raise exception 'FYF_RATE'; end if;
  insert into bike_pass_entries(code, tenant_id, shop, kind, body, km, done_on, trust, ref, corrects)
    values (k.code, p_tenant, coalesce(sh, 'Werkstatt'), trim(p_kind), trim(p_text), p_km, coalesce(p_date, current_date), case when coalesce(v, false) then 'verified' else 'shop' end, p_ref, p_corrects)
    returning id into n;
  return n;
end $$;

-- Alte Funktion bleibt (App v.79), läuft jetzt über pass_entry
create or replace function pass_add(p_tenant uuid, p_code text, p_kind text, p_text text, p_km int, p_date date) returns bigint
language plpgsql security definer set search_path = public as $$
begin
  return pass_entry(p_tenant, p_code, p_kind, p_text, p_km, p_date, null, null);
end $$;

create or replace function pass_publish(p_tenant uuid, p_bike text, p_payload jsonb, p_visibility text, p_stolen boolean) returns text
language plpgsql security definer set search_path = public as $$
declare c text; fh text; pl jsonb;
begin
  if not is_member(p_tenant) then raise exception 'FYF_DENIED'; end if;
  if p_payload is null or jsonb_typeof(p_payload) <> 'object' or length(p_payload::text) > 40000 or length(coalesce(p_bike, '')) not between 1 and 60 then raise exception 'FYF_BAD_DATA'; end if;
  if p_visibility not in ('public','shops') then raise exception 'FYF_BAD_DATA'; end if;
  if exists (select 1 from bike_pass_moved where tenant_id = p_tenant and bike_ref = p_bike) then raise exception 'FYF_PASS_MOVED'; end if;
  fh := nullif(p_payload->>'fh', ''); if fh is not null and fh !~ '^[0-9a-f]{64}$' then raise exception 'FYF_BAD_DATA'; end if; pl := p_payload - 'fh';
  select code into c from bike_passes where tenant_id = p_tenant and bike_ref = p_bike;
  if c is null then
    if (select count(*) from bike_passes where tenant_id = p_tenant and created_at > now() - interval '1 day') >= 200 then raise exception 'FYF_RATE'; end if;
    c := fyf_pass_code();
    insert into bike_passes(code, tenant_id, bike_ref, visibility, stolen, payload, frame_hash) values (c, p_tenant, p_bike, p_visibility, coalesce(p_stolen, false), pl, fh);
    perform fyf_audit(p_tenant, 'pass_create', jsonb_build_object('bike', p_bike, 'code', c));
  else
    update bike_passes set payload = pl, frame_hash = coalesce(fh, frame_hash),
      owner_vis = case when p_visibility is distinct from visibility then null else owner_vis end,
      owner_stolen = case when coalesce(p_stolen, false) is distinct from stolen then null else owner_stolen end,
      visibility = p_visibility, stolen = coalesce(p_stolen, false), withdrawn_at = null, updated_at = now() where code = c;
  end if;
  return c;
end $$;

-- „Löschen“ zieht den Pass nur zurück: nicht mehr sichtbar, keine neuen Einträge, Geschichte bleibt.
create or replace function pass_delete(p_tenant uuid, p_bike text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not is_member(p_tenant) then raise exception 'FYF_DENIED'; end if;
  update bike_passes set withdrawn_at = now(), updated_at = now() where tenant_id = p_tenant and bike_ref = p_bike;
  perform fyf_audit(p_tenant, 'pass_withdraw', jsonb_build_object('bike', p_bike));
end $$;

create or replace function fyf_transfer_code() returns text
language plpgsql volatile set search_path = public as $$
declare a text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; b bytea := decode(md5(gen_random_uuid()::text) || md5(gen_random_uuid()::text), 'hex'); c text := ''; i int;
begin
  for i in 0..11 loop c := c || substr(a, 1 + (get_byte(b, i) % 32), 1); end loop;
  return c;
end $$;

-- Neuer Übergabe-Code (Teil II). Gilt ab sofort; eine früher gedruckte Karte wird ungültig.
create or replace function pass_transfer_new(p_tenant uuid, p_bike text) returns text
language plpgsql security definer set search_path = public as $$
declare c text; t text;
begin
  if not is_member(p_tenant) then raise exception 'FYF_DENIED'; end if;
  select code into c from bike_passes where tenant_id = p_tenant and bike_ref = p_bike and withdrawn_at is null;
  if c is null then raise exception 'FYF_NOT_FOUND'; end if;
  t := fyf_transfer_code();
  update bike_passes set transfer_hash = encode(sha256(convert_to(t, 'UTF8')), 'hex'), updated_at = now() where code = c;
  perform fyf_audit(p_tenant, 'pass_transfer_new', jsonb_build_object('code', c));
  return t;
end $$;

-- Besitzerwechsel / Werkstattwechsel mit Teil II. Der Pass hängt danach an p_bike des Ladens p_tenant.
create or replace function pass_handover(p_tenant uuid, p_code text, p_transfer text, p_bike text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare k record; t text := upper(regexp_replace(coalesce(p_transfer, ''), '[^A-Za-z0-9]', '', 'g')); nt text; sh text; v boolean;
begin
  if not is_member(p_tenant) then raise exception 'FYF_DENIED'; end if;
  if length(coalesce(p_bike, '')) not between 1 and 60 then raise exception 'FYF_BAD_DATA'; end if;
  if (select count(*) from audit_log where tenant_id = p_tenant and action = 'pass_handover_fail' and at > now() - interval '1 day') >= 20 then raise exception 'FYF_RATE'; end if;
  select * into k from bike_passes where code = upper(coalesce(p_code, ''));
  if k.code is null then raise exception 'FYF_NOT_FOUND'; end if;
  if k.withdrawn_at is not null then raise exception 'FYF_WITHDRAWN'; end if;
  -- Ein als gestohlen gemeldetes Rad kann nicht übergeben werden (sonst ließe sich die Meldung „waschen“).
  if coalesce(k.owner_stolen, k.stolen) then raise exception 'FYF_STOLEN'; end if;
  if k.transfer_hash is null or encode(sha256(convert_to(t, 'UTF8')), 'hex') <> k.transfer_hash then
    perform fyf_audit(p_tenant, 'pass_handover_fail', jsonb_build_object('code', k.code));
    return jsonb_build_object('error', 'FYF_BAD_TRANSFER'); -- kein raise, damit der Fehlversuch gezählt bleibt
  end if;
  if (k.tenant_id is distinct from p_tenant or k.bike_ref is distinct from p_bike) and exists (select 1 from bike_passes where tenant_id = p_tenant and bike_ref = p_bike) then raise exception 'FYF_BIKE_HAS_PASS'; end if;
  if k.tenant_id is not null and (k.tenant_id <> p_tenant or k.bike_ref <> p_bike) then
    insert into bike_pass_moved(tenant_id, bike_ref, code) values (k.tenant_id, k.bike_ref, k.code) on conflict (tenant_id, bike_ref) do update set code = excluded.code, moved_at = now();
    delete from bike_pass_moved where tenant_id = p_tenant and bike_ref = p_bike;
  end if;
  nt := fyf_transfer_code();
  update bike_passes set tenant_id = p_tenant, bike_ref = p_bike, owner_no = owner_no + 1, owner_since = current_date,
    transfer_hash = encode(sha256(convert_to(nt, 'UTF8')), 'hex'), owner_vis = null, owner_stolen = null, updated_at = now() where code = k.code;
  select name, verified into sh, v from tenants where id = p_tenant;
  insert into bike_pass_entries(code, tenant_id, shop, kind, body, done_on, trust)
    values (k.code, p_tenant, coalesce(sh, 'Werkstatt'), 'Besitzerwechsel', 'Besitzer ' || (k.owner_no + 1) || ' übernimmt das Rad (Übergabe-Code geprüft)', current_date, case when coalesce(v, false) then 'verified' else 'shop' end);
  perform fyf_audit(p_tenant, 'pass_handover', jsonb_build_object('code', k.code, 'owner_no', k.owner_no + 1));
  return jsonb_build_object('code', k.code, 'transfer', nt, 'owner_no', k.owner_no + 1, 'payload', k.payload, 'was_stolen', false);
end $$;

create or replace function pass_get(p_code text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare k record; c text := upper(regexp_replace(coalesce(p_code, ''), '[^A-Za-z0-9]', '', 'g')); full_view boolean; sh text;
begin
  if c !~ '^[A-HJ-NP-Z2-9]{8}$' then return null; end if;
  select * into k from bike_passes where code = c;
  if k.code is null then return null; end if;
  select name into sh from tenants where id = k.tenant_id;
  k.stolen := coalesce(k.owner_stolen, k.stolen); k.visibility := coalesce(k.owner_vis, k.visibility);
  if k.withdrawn_at is not null and not is_member(k.tenant_id) then
    return jsonb_build_object('code', c, 'limited', true, 'withdrawn', true, 'stolen', k.stolen, 'bike', jsonb_build_object('name', k.payload->'bike'->>'name'),
      'shop', jsonb_build_object('name', coalesce(nullif(k.payload->'shop'->>'name', ''), sh), 'phone', k.payload->'shop'->>'phone'));
  end if;
  full_view := k.visibility = 'public' or is_member(k.tenant_id) or my_verified_tenant() is not null;
  if not full_view then
    return jsonb_build_object('code', c, 'limited', true, 'stolen', k.stolen, 'owner_no', k.owner_no, 'self', k.tenant_id is null,
      'bike', jsonb_build_object('name', k.payload->'bike'->>'name'),
      'shop', jsonb_build_object('name', coalesce(nullif(k.payload->'shop'->>'name', ''), sh), 'phone', k.payload->'shop'->>'phone'));
  end if;
  return k.payload || jsonb_build_object('shop', coalesce(k.payload->'shop', '{}'::jsonb) || jsonb_build_object('name', coalesce(nullif(k.payload->'shop'->>'name', ''), sh)),
    'code', c, 'limited', false, 'stolen', k.stolen, 'visibility', k.visibility, 'updated_at', k.updated_at, 'created_at', k.created_at,
    'owner_no', k.owner_no, 'owner_since', k.owner_since, 'withdrawn', k.withdrawn_at is not null, 'has_transfer', k.transfer_hash is not null,
    'mine', is_member(k.tenant_id),
    'entries', coalesce((select jsonb_agg(jsonb_build_object('id', e.id, 'shop', e.shop, 'kind', e.kind, 'text', e.body, 'km', e.km, 'date', e.done_on,
                           'trust', e.trust, 'receipt', e.receipt, 'corrects', e.corrects, 'at', e.created_at) order by e.done_on desc, e.id desc)
                         from bike_pass_entries e where e.code = c), '[]'::jsonb));
end $$;

revoke all on function fyf_pass_entries_lock() from public, anon, authenticated;
revoke all on function fyf_transfer_code() from public, anon, authenticated;
revoke all on function pass_entry(uuid, text, text, text, int, date, text, bigint) from public, anon;
revoke all on function pass_transfer_new(uuid, text) from public, anon;
revoke all on function pass_handover(uuid, text, text, text) from public, anon;
grant execute on function pass_entry(uuid, text, text, text, int, date, text, bigint), pass_transfer_new(uuid, text), pass_handover(uuid, text, text, text) to authenticated;
grant execute on function pass_get(text) to anon, authenticated;


-- ---------- Besitzer-Funktionen mit Teil II (ohne Konto) ----------
-- Wer den Übergabe-Code kennt, ist der Besitzer: Sichtbarkeit wählen, Diebstahl melden/aufheben, Selbstauskunft eintragen.
-- Nach 10 falschen Codes pro Pass und Tag ist für 24 Stunden Schluss.
create or replace function pass_owner(p_code text, p_transfer text, p_action text, p_value jsonb) returns jsonb
language plpgsql security definer set search_path = public as $$
declare k record; c text := upper(regexp_replace(coalesce(p_code, ''), '[^A-Za-z0-9]', '', 'g')); t text := upper(regexp_replace(coalesce(p_transfer, ''), '[^A-Za-z0-9]', '', 'g')); n bigint; d date; km int; txt text; kind text;
begin
  select * into k from bike_passes where code = c;
  if k.code is null or k.withdrawn_at is not null then return jsonb_build_object('error', 'FYF_NOT_FOUND'); end if;
  if k.owner_fails >= 10 and k.owner_fail_at > now() - interval '1 day' then return jsonb_build_object('error', 'FYF_RATE'); end if;
  if k.transfer_hash is null or encode(sha256(convert_to(t, 'UTF8')), 'hex') <> k.transfer_hash then
    update bike_passes set owner_fails = case when owner_fail_at > now() - interval '1 day' then owner_fails + 1 else 1 end, owner_fail_at = now() where code = c;
    return jsonb_build_object('error', 'FYF_BAD_TRANSFER');
  end if;
  if p_action = 'vis' then
    if p_value->>'v' not in ('public','shops') then return jsonb_build_object('error', 'FYF_BAD_DATA'); end if;
    update bike_passes set owner_vis = p_value->>'v', updated_at = now() where code = c;
  elsif p_action = 'stolen' then
    update bike_passes set owner_stolen = coalesce((p_value->>'v')::boolean, false), updated_at = now() where code = c;
    insert into bike_pass_entries(code, tenant_id, shop, kind, body, done_on, trust)
      values (c, null, 'Besitzer', case when coalesce((p_value->>'v')::boolean, false) then 'Diebstahl gemeldet' else 'Diebstahlmeldung aufgehoben' end,
              case when coalesce((p_value->>'v')::boolean, false) then 'Vom Besitzer als gestohlen gemeldet' else 'Vom Besitzer aufgehoben – Rad ist wieder da' end, current_date, 'self');
  elsif p_action = 'entry' then
    kind := trim(coalesce(p_value->>'kind', '')); txt := trim(coalesce(p_value->>'text', ''));
    km := nullif(p_value->>'km', '')::int; d := coalesce(nullif(p_value->>'date', '')::date, current_date);
    if length(txt) < 3 or length(txt) > 500 or length(kind) not between 2 and 40 or (km is not null and (km < 0 or km > 1000000)) or d > current_date + 1 or d < current_date - 7300 then return jsonb_build_object('error', 'FYF_BAD_DATA'); end if;
    if (select count(*) from bike_pass_entries where code = c and trust = 'self' and created_at > now() - interval '1 day') >= 20 then return jsonb_build_object('error', 'FYF_RATE'); end if;
    insert into bike_pass_entries(code, tenant_id, shop, kind, body, km, done_on, trust) values (c, null, 'Besitzer', kind, txt, km, d, 'self') returning id into n;
  elsif p_action <> 'check' then
    return jsonb_build_object('error', 'FYF_BAD_DATA');
  end if;
  select * into k from bike_passes where code = c;
  return jsonb_build_object('ok', true, 'visibility', coalesce(k.owner_vis, k.visibility), 'stolen', coalesce(k.owner_stolen, k.stolen), 'owner_no', k.owner_no);
exception when invalid_text_representation or datetime_field_overflow or numeric_value_out_of_range then
  return jsonb_build_object('error', 'FYF_BAD_DATA');
end $$;
revoke all on function pass_owner(text, text, text, jsonb) from public;
grant execute on function pass_owner(text, text, text, jsonb) to anon, authenticated;


-- ---------- Rad selbst registrieren (Besitzer, ohne Laden) ----------
-- Gibt Pass-Code und Übergabe-Code zurück. Eine bereits registrierte Rahmennummer wird abgelehnt (auch gegen das „Neuanmelden“ gestohlener Räder).
create or replace function pass_register(p_payload jsonb, p_fh text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare c text; t text;
begin
  if p_payload is null or jsonb_typeof(p_payload) <> 'object' or length(p_payload::text) > 6000 or length(coalesce(p_payload->'bike'->>'name', '')) not between 2 and 120 then return jsonb_build_object('error', 'FYF_BAD_DATA'); end if;
  if coalesce(p_fh, '') !~ '^[0-9a-f]{64}$' then return jsonb_build_object('error', 'FYF_BAD_DATA'); end if;
  if exists (select 1 from bike_passes where frame_hash = p_fh) then return jsonb_build_object('error', 'FYF_FRAME_EXISTS'); end if;
  if (select count(*) from bike_passes where tenant_id is null and created_at > now() - interval '1 day') >= 300 then return jsonb_build_object('error', 'FYF_RATE'); end if;
  c := fyf_pass_code(); t := fyf_transfer_code();
  insert into bike_passes(code, tenant_id, bike_ref, visibility, stolen, payload, frame_hash, transfer_hash)
    values (c, null, null, 'shops', false, (p_payload - 'fh') || jsonb_build_object('self', true, 'shop', jsonb_build_object('name', '')), p_fh, encode(sha256(convert_to(t, 'UTF8')), 'hex'));
  insert into bike_pass_entries(code, tenant_id, shop, kind, body, done_on, trust) values (c, null, 'Besitzer', 'Registrierung', 'Rad vom Besitzer registriert', current_date, 'self');
  return jsonb_build_object('code', c, 'transfer', t);
end $$;

-- ---------- Diebstahl-Abgleich bei der Annahme (nur Werkstätten) ----------
create or replace function frame_check(p_tenant uuid, p_fh text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare k record; sh text;
begin
  if not is_member(p_tenant) then raise exception 'FYF_DENIED'; end if;
  if coalesce(p_fh, '') !~ '^[0-9a-f]{64}$' then return jsonb_build_object('found', false); end if;
  if (select count(*) from audit_log where tenant_id = p_tenant and action = 'frame_check' and at > now() - interval '1 day') >= 300 then raise exception 'FYF_RATE'; end if;
  perform fyf_audit(p_tenant, 'frame_check', null);
  select * into k from bike_passes where frame_hash = p_fh and withdrawn_at is null order by coalesce(owner_stolen, stolen) desc, updated_at desc limit 1;
  if k.code is null then return jsonb_build_object('found', false); end if;
  select name into sh from tenants where id = k.tenant_id;
  if coalesce(k.owner_stolen, k.stolen) then
    perform fyf_audit(p_tenant, 'frame_check_stolen', jsonb_build_object('code', k.code));
    return jsonb_build_object('found', true, 'stolen', true, 'code', k.code, 'mine', is_member(k.tenant_id),
      'shop', coalesce(nullif(k.payload->'shop'->>'name', ''), sh, 'vom Besitzer registriert'), 'phone', k.payload->'shop'->>'phone');
  end if;
  return jsonb_build_object('found', true, 'stolen', false, 'mine', is_member(k.tenant_id));
end $$;
revoke all on function pass_register(jsonb, text) from public;
grant execute on function pass_register(jsonb, text) to anon, authenticated;
revoke all on function frame_check(uuid, text) from public, anon;
grant execute on function frame_check(uuid, text) to authenticated;
