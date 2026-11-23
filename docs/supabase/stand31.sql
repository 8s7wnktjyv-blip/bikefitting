-- FYF – Stand 31 (23.11.2026): Punkt 17 Stufe 2 + Punkt 18 (Freigabe Dominik 23.11.2026).
-- 1. Händlerfinder „Ist das Ihr Laden?“: Läden aus OpenStreetMap können „Eintrag übernehmen“ oder „Eintrag entfernen lassen“.
--    Anfragen landen in shop_claims. Schreiben für alle nur über shop_claim_submit() mit Grenzen, lesen nur Plattform-Admin.
--    Bestätigung macht Dominik von Hand (Rückruf unter der öffentlichen Nummer des Ladens). FYF versendet nichts.
--    Bestätigte „entfernen“-Anfragen blendet der Händlerfinder aus (shop_hidden_osm()).
-- 2. Pass „Wünsch dir was“: eigene Wünsche (max. 200 Zeichen, ohne Konto, keine Links/E-Mail/Telefon, max. 3 je Gerät und Tag).
--    Öffentlich sichtbar und abstimmbar erst nach Freigabe durch den Plattform-Admin.
-- Mehrfach ausführen schadet nicht.

-- ---------- 1. Läden: Eintrag übernehmen / entfernen lassen ----------
create table if not exists shop_claims (
  id bigserial primary key,
  osm_id text not null check (osm_id ~ '^[nwr][0-9]{1,12}$'),
  shop_name text not null check (char_length(shop_name) between 1 and 120),
  kind text not null check (kind in ('uebernehmen','entfernen')),
  contact_name text not null check (char_length(contact_name) between 2 and 100),
  contact text not null check (char_length(contact) between 5 and 120),
  note text check (note is null or char_length(note) <= 500),
  status text not null default 'offen' check (status in ('offen','bestaetigt','abgelehnt')),
  created_at timestamptz not null default now(),
  decided_at timestamptz,
  decided_by uuid
);
create index if not exists shop_claims_osm on shop_claims(osm_id, created_at);
alter table shop_claims enable row level security;   -- keine Policy: nur über die Funktionen unten
revoke all on shop_claims from anon, authenticated;

create or replace function shop_claim_submit(p_osm text, p_name text, p_kind text, p_contact_name text, p_contact text, p_note text default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_id bigint;
begin
  p_osm := lower(btrim(coalesce(p_osm,''))); p_name := btrim(coalesce(p_name,'')); p_contact_name := btrim(coalesce(p_contact_name,''));
  p_contact := btrim(coalesce(p_contact,'')); p_note := nullif(btrim(coalesce(p_note,'')),'');
  if p_osm !~ '^[nwr][0-9]{1,12}$' then return jsonb_build_object('error','FYF_BAD_ID'); end if;
  if p_kind not in ('uebernehmen','entfernen') then return jsonb_build_object('error','FYF_BAD_KIND'); end if;
  if char_length(p_name) not between 1 and 120 or char_length(p_contact_name) not between 2 and 100
     or char_length(p_contact) not between 5 and 120 or char_length(coalesce(p_note,'')) > 500 then return jsonb_build_object('error','FYF_BAD_INPUT'); end if;
  if (select count(*) from shop_claims where osm_id = p_osm and created_at > now() - interval '1 hour') >= 3
     or (select count(*) from shop_claims where created_at > now() - interval '1 hour') >= 200 then return jsonb_build_object('error','FYF_RATE'); end if;
  insert into shop_claims(osm_id, shop_name, kind, contact_name, contact, note) values (p_osm, p_name, p_kind, p_contact_name, p_contact, p_note) returning id into v_id;
  return jsonb_build_object('ok', true, 'id', v_id);
end $$;

create or replace function shop_claims_list() returns setof shop_claims
language sql stable security definer set search_path = public as $$
  select * from shop_claims where is_platform_admin() order by (status = 'offen') desc, created_at desc limit 500 $$;

create or replace function shop_claim_decide(p_id bigint, p_status text) returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  if not is_platform_admin() then raise exception 'FYF_DENIED'; end if;
  if p_status not in ('offen','bestaetigt','abgelehnt') then return jsonb_build_object('error','FYF_BAD_INPUT'); end if;
  update shop_claims set status = p_status, decided_at = case when p_status = 'offen' then null else now() end, decided_by = auth.uid() where id = p_id;
  if not found then return jsonb_build_object('error','FYF_NOT_FOUND'); end if;
  return jsonb_build_object('ok', true);
end $$;

-- Öffentlich: nur die OSM-Kennungen bestätigter „entfernen“-Anfragen (keine Namen, keine Kontakte)
create or replace function shop_hidden_osm() returns setof text
language sql stable security definer set search_path = public as $$
  select distinct osm_id from shop_claims where kind = 'entfernen' and status = 'bestaetigt' $$;

revoke all on function shop_claim_submit(text,text,text,text,text,text) from public;
revoke all on function shop_claims_list() from public;
revoke all on function shop_claim_decide(bigint,text) from public;
revoke all on function shop_hidden_osm() from public;
grant execute on function shop_claim_submit(text,text,text,text,text,text) to anon, authenticated;
grant execute on function shop_hidden_osm() to anon, authenticated;
grant execute on function shop_claims_list() to authenticated;
grant execute on function shop_claim_decide(bigint,text) to authenticated;

-- ---------- 2. „Wünsch dir was“: eigene Wünsche ----------
create table if not exists wish_ideas (
  id bigserial primary key,
  body text not null check (char_length(body) between 3 and 200),
  device text not null check (device ~ '^[A-Za-z0-9_-]{8,64}$'),
  status text not null default 'neu' check (status in ('neu','uebernommen','abgelehnt')),
  public boolean not null default false,
  votes int not null default 0,
  created_at timestamptz not null default now(),
  decided_at timestamptz
);
create index if not exists wish_ideas_device on wish_ideas(device, created_at);
create table if not exists wish_votes (
  wish_id bigint not null references wish_ideas(id) on delete cascade,
  device text not null check (device ~ '^[A-Za-z0-9_-]{8,64}$'),
  created_at timestamptz not null default now(),
  primary key (wish_id, device)
);
alter table wish_ideas enable row level security;
alter table wish_votes enable row level security;
revoke all on wish_ideas, wish_votes from anon, authenticated;

create or replace function wish_submit(p_body text, p_device text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_id bigint;
begin
  p_body := regexp_replace(btrim(coalesce(p_body,'')), '\s+', ' ', 'g'); p_device := btrim(coalesce(p_device,''));
  if p_device !~ '^[A-Za-z0-9_-]{8,64}$' then return jsonb_build_object('error','FYF_BAD_DEVICE'); end if;
  if char_length(p_body) not between 3 and 200 then return jsonb_build_object('error','FYF_BAD_INPUT'); end if;
  -- keine persönlichen Daten: Links, E-Mail-Adressen, Telefonnummern (7+ Ziffern)
  if p_body ~* '(https?://|www\.|[a-z0-9-]+\.(de|com|net|org|at|ch|eu|io|info|shop)\M)' or p_body ~ '[^\s@]+@[^\s@]+\.[^\s@]+'
     or exists (select 1 from regexp_matches(p_body, '(\+?[0-9][0-9 /().-]{5,}[0-9])', 'g') m where char_length(regexp_replace(m[1], '[^0-9]', '', 'g')) >= 7) then return jsonb_build_object('error','FYF_PERSONAL'); end if;
  if (select count(*) from wish_ideas where device = p_device and created_at > now() - interval '1 day') >= 3 then return jsonb_build_object('error','FYF_RATE'); end if;
  if (select count(*) from wish_ideas where created_at > now() - interval '1 hour') >= 300 then return jsonb_build_object('error','FYF_RATE'); end if;
  insert into wish_ideas(body, device) values (p_body, p_device) returning id into v_id;
  return jsonb_build_object('ok', true, 'id', v_id);
end $$;

-- Öffentlich: nur freigegebene Wünsche, ohne Gerätekennung
create or replace function wish_list_public() returns table(id bigint, body text, votes int, status text)
language sql stable security definer set search_path = public as $$
  select w.id, w.body, w.votes, w.status from wish_ideas w where w.public and w.status <> 'abgelehnt' order by w.votes desc, w.id desc limit 50 $$;

create or replace function wish_vote(p_id bigint, p_device text) returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  if coalesce(p_device,'') !~ '^[A-Za-z0-9_-]{8,64}$' then return jsonb_build_object('error','FYF_BAD_DEVICE'); end if;
  if not exists (select 1 from wish_ideas where id = p_id and public and status <> 'abgelehnt') then return jsonb_build_object('error','FYF_NOT_FOUND'); end if;
  if (select count(*) from wish_votes where device = p_device and created_at > now() - interval '1 day') >= 30 then return jsonb_build_object('error','FYF_RATE'); end if;
  insert into wish_votes(wish_id, device) values (p_id, p_device) on conflict do nothing;
  if found then update wish_ideas set votes = votes + 1 where id = p_id; end if;
  return jsonb_build_object('ok', true, 'votes', (select votes from wish_ideas where id = p_id));
end $$;

create or replace function wish_admin_list() returns table(id bigint, body text, status text, public boolean, votes int, created_at timestamptz)
language sql stable security definer set search_path = public as $$
  select w.id, w.body, w.status, w.public, w.votes, w.created_at from wish_ideas w where is_platform_admin() order by (w.status = 'neu') desc, w.created_at desc limit 500 $$;

create or replace function wish_admin_set(p_id bigint, p_status text, p_public boolean) returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  if not is_platform_admin() then raise exception 'FYF_DENIED'; end if;
  if p_status not in ('neu','uebernommen','abgelehnt') then return jsonb_build_object('error','FYF_BAD_INPUT'); end if;
  update wish_ideas set status = p_status, public = coalesce(p_public, false) and p_status <> 'abgelehnt', decided_at = now() where id = p_id;
  if not found then return jsonb_build_object('error','FYF_NOT_FOUND'); end if;
  return jsonb_build_object('ok', true);
end $$;

revoke all on function wish_submit(text,text) from public;
revoke all on function wish_list_public() from public;
revoke all on function wish_vote(bigint,text) from public;
revoke all on function wish_admin_list() from public;
revoke all on function wish_admin_set(bigint,text,boolean) from public;
grant execute on function wish_submit(text,text) to anon, authenticated;
grant execute on function wish_list_public() to anon, authenticated;
grant execute on function wish_vote(bigint,text) to anon, authenticated;
grant execute on function wish_admin_list() to authenticated;
grant execute on function wish_admin_set(bigint,text,boolean) to authenticated;
