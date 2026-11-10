-- FYF – Fit your Frame · Live-Status für Werkstattaufträge und QR-Fahrradpass über alle Läden (Stand 10)
--
-- 1. Live-Status: Der Laden schickt dem Kunden einen Link. Der Kunde sieht, wo sein Rad steht
--    (Angenommen → In Arbeit → Abholbereit). Die App aktualisiert den Stand bei jedem Statuswechsel.
--    Zufälliger Schlüssel (32 Zeichen), gilt 90 Tage ab der letzten Änderung. Ohne Kunden-Konto.
-- 2. QR-Fahrradpass: Ein Aufkleber mit 8-stelligem Code am Rahmen. Der Laden stellt den Pass ein
--    (Fahrzeugdaten, Services, Teile, Gebrauchtrad-Check), ohne Name und Kontakt des Besitzers.
--    Sichtbarkeit wählt der Besitzer:
--      'public' – jeder, der den Code scannt, sieht den Pass (gut beim Verkauf)
--      'shops'  – voll sichtbar nur für geprüfte FYF-Läden und den ausstellenden Laden;
--                 alle anderen sehen nur, dass es einen Pass gibt, welcher Laden ihn führt und ob das Rad als gestohlen gemeldet ist.
--    Geprüfte FYF-Läden (tenants.verified) können Einträge ergänzen (z. B. „Kette getauscht“).
--    Der ausstellende Laden sieht diese Einträge und übernimmt sie in seinen Fahrradpass.

create table if not exists wo_status_links (
  token text primary key,
  tenant_id uuid not null references tenants(id) on delete cascade,
  wo_id text not null,
  payload jsonb not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  opened_at timestamptz,
  unique (tenant_id, wo_id)
);
alter table wo_status_links enable row level security;
drop policy if exists wo_status_read on wo_status_links;
create policy wo_status_read on wo_status_links for select using (is_member(tenant_id));
grant select on wo_status_links to authenticated;

create or replace function wo_status_publish(p_tenant uuid, p_wo text, p_payload jsonb) returns text
language plpgsql security definer set search_path = public as $$
declare tk text;
begin
  if not is_member(p_tenant) then raise exception 'FYF_DENIED'; end if;
  if p_payload is null or jsonb_typeof(p_payload) <> 'object' or length(p_payload::text) > 20000 or length(coalesce(p_wo, '')) not between 1 and 60 then raise exception 'FYF_BAD_DATA'; end if;
  insert into wo_status_links(token, tenant_id, wo_id, payload) values (replace(gen_random_uuid()::text, '-', ''), p_tenant, p_wo, p_payload)
    on conflict (tenant_id, wo_id) do update set payload = excluded.payload, updated_at = now()
    returning token into tk;
  return tk;
end $$;

create or replace function wo_status_revoke(p_tenant uuid, p_wo text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not is_member(p_tenant) then raise exception 'FYF_DENIED'; end if;
  delete from wo_status_links where tenant_id = p_tenant and wo_id = p_wo;
end $$;

create or replace function wo_status_get(p_token text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare k record;
begin
  if length(coalesce(p_token, '')) <> 32 then return null; end if;
  select * into k from wo_status_links where token = p_token and updated_at > now() - interval '90 days';
  if k.token is null then return null; end if;
  if k.opened_at is null then update wo_status_links set opened_at = now() where token = p_token; end if;
  return k.payload || jsonb_build_object('updated_at', k.updated_at);
end $$;

revoke all on function wo_status_publish(uuid, text, jsonb) from public, anon;
revoke all on function wo_status_revoke(uuid, text) from public, anon;
grant execute on function wo_status_publish(uuid, text, jsonb), wo_status_revoke(uuid, text) to authenticated;
grant execute on function wo_status_get(text) to anon, authenticated;

-- ---------- QR-Fahrradpass ----------
create table if not exists bike_passes (
  code text primary key check (code ~ '^[A-HJ-NP-Z2-9]{8}$'),
  tenant_id uuid not null references tenants(id) on delete cascade,
  bike_ref text not null,
  visibility text not null default 'shops' check (visibility in ('public','shops')),
  stolen boolean not null default false,
  payload jsonb not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id, bike_ref)
);
create table if not exists bike_pass_entries (
  id bigserial primary key,
  code text not null references bike_passes(code) on delete cascade,
  tenant_id uuid not null references tenants(id) on delete cascade,
  shop text not null,
  kind text not null,
  body text not null,
  km int,
  done_on date not null default current_date,
  created_at timestamptz not null default now()
);
create index if not exists bike_pass_entries_c on bike_pass_entries (code, created_at);
-- Kein direkter Zugriff: nur über die Funktionen unten.
alter table bike_passes enable row level security;
alter table bike_pass_entries enable row level security;

create or replace function fyf_pass_code() returns text
language plpgsql volatile set search_path = public as $$
declare a text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; b bytea; c text; i int;
begin
  loop
    b := decode(md5(gen_random_uuid()::text || clock_timestamp()::text), 'hex'); c := '';
    for i in 0..7 loop c := c || substr(a, 1 + (get_byte(b, i) % 32), 1); end loop;
    exit when not exists (select 1 from bike_passes where code = c);
  end loop;
  return c;
end $$;

create or replace function pass_publish(p_tenant uuid, p_bike text, p_payload jsonb, p_visibility text, p_stolen boolean) returns text
language plpgsql security definer set search_path = public as $$
declare c text;
begin
  if not is_member(p_tenant) then raise exception 'FYF_DENIED'; end if;
  if p_payload is null or jsonb_typeof(p_payload) <> 'object' or length(p_payload::text) > 40000 or length(coalesce(p_bike, '')) not between 1 and 60 then raise exception 'FYF_BAD_DATA'; end if;
  if p_visibility not in ('public','shops') then raise exception 'FYF_BAD_DATA'; end if;
  select code into c from bike_passes where tenant_id = p_tenant and bike_ref = p_bike;
  if c is null then
    if (select count(*) from bike_passes where tenant_id = p_tenant and created_at > now() - interval '1 day') >= 200 then raise exception 'FYF_RATE'; end if;
    c := fyf_pass_code();
    insert into bike_passes(code, tenant_id, bike_ref, visibility, stolen, payload) values (c, p_tenant, p_bike, p_visibility, coalesce(p_stolen, false), p_payload);
    perform fyf_audit(p_tenant, 'pass_create', jsonb_build_object('bike', p_bike, 'code', c));
  else
    update bike_passes set payload = p_payload, visibility = p_visibility, stolen = coalesce(p_stolen, false), updated_at = now() where code = c;
  end if;
  return c;
end $$;

create or replace function pass_delete(p_tenant uuid, p_bike text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not is_member(p_tenant) then raise exception 'FYF_DENIED'; end if;
  delete from bike_passes where tenant_id = p_tenant and bike_ref = p_bike;
  perform fyf_audit(p_tenant, 'pass_delete', jsonb_build_object('bike', p_bike));
end $$;

create or replace function pass_get(p_code text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare k record; c text := upper(regexp_replace(coalesce(p_code, ''), '[^A-Za-z0-9]', '', 'g')); full_view boolean; sh text;
begin
  if c !~ '^[A-HJ-NP-Z2-9]{8}$' then return null; end if;
  select * into k from bike_passes where code = c;
  if k.code is null then return null; end if;
  select name into sh from tenants where id = k.tenant_id;
  full_view := k.visibility = 'public' or is_member(k.tenant_id) or my_verified_tenant() is not null;
  if not full_view then
    return jsonb_build_object('code', c, 'limited', true, 'stolen', k.stolen,
      'bike', jsonb_build_object('name', k.payload->'bike'->>'name'),
      'shop', jsonb_build_object('name', coalesce(nullif(k.payload->'shop'->>'name', ''), sh), 'phone', k.payload->'shop'->>'phone'));
  end if;
  return k.payload || jsonb_build_object('shop', coalesce(k.payload->'shop', '{}'::jsonb) || jsonb_build_object('name', coalesce(nullif(k.payload->'shop'->>'name', ''), sh)), 'code', c, 'limited', false, 'stolen', k.stolen, 'visibility', k.visibility, 'updated_at', k.updated_at,
    'mine', is_member(k.tenant_id),
    'entries', coalesce((select jsonb_agg(jsonb_build_object('id', e.id, 'shop', e.shop, 'kind', e.kind, 'text', e.body, 'km', e.km, 'date', e.done_on) order by e.done_on desc, e.id desc)
                         from bike_pass_entries e where e.code = c), '[]'::jsonb));
end $$;

create or replace function pass_add(p_tenant uuid, p_code text, p_kind text, p_text text, p_km int, p_date date) returns bigint
language plpgsql security definer set search_path = public as $$
declare k record; sh text; v boolean; n bigint;
begin
  if not is_member(p_tenant) then raise exception 'FYF_DENIED'; end if;
  select * into k from bike_passes where code = upper(coalesce(p_code, ''));
  if k.code is null then raise exception 'FYF_NOT_FOUND'; end if;
  select name, verified into sh, v from tenants where id = p_tenant;
  if k.tenant_id <> p_tenant and not coalesce(v, false) then raise exception 'FYF_NOT_VERIFIED'; end if;
  if length(trim(coalesce(p_text, ''))) < 3 or length(p_text) > 500 or length(coalesce(p_kind, '')) not between 2 and 40 then raise exception 'FYF_BAD_DATA'; end if;
  if p_km is not null and (p_km < 0 or p_km > 1000000) then raise exception 'FYF_BAD_DATA'; end if;
  if p_date is not null and (p_date > current_date + 1 or p_date < current_date - 3650) then raise exception 'FYF_BAD_DATA'; end if;
  if (select count(*) from bike_pass_entries where tenant_id = p_tenant and created_at > now() - interval '1 day') >= 100 then raise exception 'FYF_RATE'; end if;
  insert into bike_pass_entries(code, tenant_id, shop, kind, body, km, done_on) values (k.code, p_tenant, coalesce(sh, 'Werkstatt'), trim(p_kind), trim(p_text), p_km, coalesce(p_date, current_date)) returning id into n;
  perform fyf_audit(p_tenant, 'pass_add', jsonb_build_object('code', k.code));
  return n;
end $$;

revoke all on function fyf_pass_code() from public, anon, authenticated;
revoke all on function pass_publish(uuid, text, jsonb, text, boolean) from public, anon;
revoke all on function pass_delete(uuid, text) from public, anon;
revoke all on function pass_add(uuid, text, text, text, int, date) from public, anon;
grant execute on function pass_publish(uuid, text, jsonb, text, boolean), pass_delete(uuid, text), pass_add(uuid, text, text, text, int, date) to authenticated;
grant execute on function pass_get(text) to anon, authenticated;

-- ---------- Partner-Seite: welche FYF-Funktionen ein Laden anbietet ----------
-- Die App meldet automatisch, was der Laden wirklich nutzt (z. B. 'fitting', 'pass', 'status', 'usedcheck').
-- Die Händlersuche zeigt das als Abzeichen und Filter.
alter table dealer_profiles add column if not exists features text[] not null default '{}';

create or replace function profile_features(p_tenant uuid, p_features text[]) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not is_member(p_tenant) then raise exception 'FYF_DENIED'; end if;
  if coalesce(array_length(p_features, 1), 0) > 12 or exists (select 1 from unnest(coalesce(p_features, '{}')) f where f !~ '^[a-z]{2,20}$') then raise exception 'FYF_BAD_DATA'; end if;
  update dealer_profiles set features = coalesce(p_features, '{}') where tenant_id = p_tenant;
end $$;
revoke all on function profile_features(uuid, text[]) from public, anon;
grant execute on function profile_features(uuid, text[]) to authenticated;
