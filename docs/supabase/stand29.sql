-- FYF – Stand 29 (21.11.2026): Käufer-Link auf Zeit (Punkt 11, Freigabe Dominik 21.11.2026, Plan docs/KAEUFER-LINK-PLAN.md).
-- Der Besitzer (mit Besitzer-Code) erzeugt einen Link, der 14 Tage lang nur die von Werkstätten eingetragene Geschichte zeigt –
-- ohne Belege, Preise, Fotos, Besitzerdaten und ohne selbst eingetragene Einträge. Der Pass selbst bleibt unverändert
-- (kann auf „nur Werkstätten“ bleiben). Zurückziehen jederzeit. Nur neue Tabelle und neue Funktionen.
create table if not exists pass_buyer_links (
  id bigserial primary key,
  code text not null references bike_passes(code) on delete cascade,
  token_hash text not null unique,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null,
  revoked_at timestamptz
);
create index if not exists pass_buyer_links_code on pass_buyer_links(code);
alter table pass_buyer_links enable row level security;   -- keine Policy: nur über die Funktionen

create or replace function buyer_link_create(p_code text, p_transfer text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare c text := upper(regexp_replace(coalesce(p_code, ''), '[^A-Za-z0-9]', '', 'g')); k bike_passes; tok text; a text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; b bytea; i int; ex timestamptz := now() + interval '14 days';
begin
  select * into k from bike_passes where code = c;
  if k.code is null or k.withdrawn_at is not null then return jsonb_build_object('error', 'FYF_NOT_FOUND'); end if;
  if not fyf_owner_ok(k, p_transfer) then return jsonb_build_object('error', 'FYF_BAD_TRANSFER'); end if;
  if (select count(*) from pass_buyer_links where code = c and created_at > now() - interval '1 day') >= 10 then return jsonb_build_object('error', 'FYF_RATE'); end if;
  update pass_buyer_links set revoked_at = now() where code = c and revoked_at is null;
  b := decode(replace(gen_random_uuid()::text, '-', '') || replace(gen_random_uuid()::text, '-', ''), 'hex'); tok := '';
  for i in 0..19 loop tok := tok || substr(a, (get_byte(b, i) % 32) + 1, 1); end loop;
  insert into pass_buyer_links(code, token_hash, expires_at) values (c, encode(sha256(convert_to(tok, 'UTF8')), 'hex'), ex);
  return jsonb_build_object('token', tok, 'expires_at', ex);
end $$;

create or replace function buyer_link_revoke(p_code text, p_transfer text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare c text := upper(regexp_replace(coalesce(p_code, ''), '[^A-Za-z0-9]', '', 'g')); k bike_passes; n int;
begin
  select * into k from bike_passes where code = c;
  if k.code is null then return jsonb_build_object('error', 'FYF_NOT_FOUND'); end if;
  if not fyf_owner_ok(k, p_transfer) then return jsonb_build_object('error', 'FYF_BAD_TRANSFER'); end if;
  update pass_buyer_links set revoked_at = now() where code = c and revoked_at is null and expires_at > now();
  get diagnostics n = row_count;
  return jsonb_build_object('ok', true, 'revoked', n);
end $$;

create or replace function buyer_link_status(p_code text, p_transfer text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare c text := upper(regexp_replace(coalesce(p_code, ''), '[^A-Za-z0-9]', '', 'g')); k bike_passes; ex timestamptz;
begin
  select * into k from bike_passes where code = c;
  if k.code is null then return jsonb_build_object('error', 'FYF_NOT_FOUND'); end if;
  if not fyf_owner_ok(k, p_transfer) then return jsonb_build_object('error', 'FYF_BAD_TRANSFER'); end if;
  select max(expires_at) into ex from pass_buyer_links where code = c and revoked_at is null and expires_at > now();
  return jsonb_build_object('active', ex is not null, 'expires_at', ex);
end $$;

-- Käufer liest mit dem Token: nur werkstattbestätigte Geschichte
create or replace function buyer_view(p_token text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare t text := upper(regexp_replace(coalesce(p_token, ''), '[^A-Za-z0-9]', '', 'g')); l pass_buyer_links; k bike_passes; sh text;
begin
  if length(t) <> 20 then return jsonb_build_object('error', 'FYF_NOT_FOUND'); end if;
  select * into l from pass_buyer_links where token_hash = encode(sha256(convert_to(t, 'UTF8')), 'hex');
  if l.id is null or l.revoked_at is not null or l.expires_at < now() then return jsonb_build_object('error', 'FYF_EXPIRED'); end if;
  select * into k from bike_passes where code = l.code;
  if k.code is null or k.withdrawn_at is not null then return jsonb_build_object('error', 'FYF_NOT_FOUND'); end if;
  select name into sh from tenants where id = k.tenant_id;
  return jsonb_build_object(
    'expires_at', l.expires_at,
    'stolen', coalesce(k.owner_stolen, k.stolen),
    'owner_no', k.owner_no, 'owner_since', k.owner_since, 'created_at', k.created_at,
    'shop', coalesce(nullif(k.payload->'shop'->>'name', ''), sh),
    'bike', jsonb_build_object('name', k.payload->'bike'->>'name', 'type', k.payload->'bike'->>'type', 'size', k.payload->'bike'->>'size',
                               'year', k.payload->'bike'->'year', 'km', k.payload->'bike'->'km', 'frame', k.payload->'bike'->>'frame'),
    'svc', coalesce((select jsonb_agg(jsonb_build_object('date', s->>'date', 'km', s->'km', 'title', s->>'title', 'parts', s->'parts', 'ins', s->'ins'))
                     from jsonb_array_elements(case when jsonb_typeof(k.payload->'svc') = 'array' then k.payload->'svc' else '[]'::jsonb end) s), '[]'::jsonb),
    'entries', coalesce((select jsonb_agg(jsonb_build_object('shop', e.shop, 'kind', e.kind, 'text', e.body, 'km', e.km, 'date', e.done_on, 'trust', e.trust) order by e.done_on desc, e.id desc)
                         from bike_pass_entries e where e.code = k.code and e.trust in ('verified', 'shop')), '[]'::jsonb));
end $$;

revoke all on function buyer_link_create(text, text), buyer_link_revoke(text, text), buyer_link_status(text, text), buyer_view(text) from public;
grant execute on function buyer_link_create(text, text), buyer_link_revoke(text, text), buyer_link_status(text, text), buyer_view(text) to anon, authenticated;
