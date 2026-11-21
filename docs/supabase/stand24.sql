-- FYF – Stand 24 (21.11.2026): Werkstatt-Bewertungen.
-- Regeln:
--  * Bewerten kann nur der Besitzer eines Fahrradpasses (Nachweis: Übergabe-Code), und nur einen Service,
--    den eine FYF-Werkstatt selbst in den Pass eingetragen hat (kein Eintrag „Besitzer“), höchstens 120 Tage alt.
--  * Eine Bewertung je Service-Eintrag, höchstens eine je Pass und Werkstatt in 180 Tagen.
--  * Öffentlich sind nur Sterne, Text, Monat und Antwort der Werkstatt – keine Namen, kein Pass-Code.
--  * Die Werkstatt kann antworten und eine Bewertung melden. Ausblenden kann nur die Plattform (nach Prüfung).
create table if not exists shop_reviews (
  id bigserial primary key,
  tenant_id uuid not null references tenants(id) on delete cascade,
  code text not null,
  entry_id bigint not null unique,
  stars int not null check (stars between 1 and 5),
  body text check (length(body) <= 600),
  created_at timestamptz not null default now(),
  reply text check (length(reply) <= 600),
  reply_at timestamptz,
  reported text check (length(reported) <= 300),
  hidden boolean not null default false
);
create index if not exists shop_reviews_t on shop_reviews (tenant_id, created_at desc);
alter table shop_reviews enable row level security;

-- Besitzer: bewerten
create or replace function review_submit(p_code text, p_transfer text, p_entry bigint, p_stars int, p_text text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare k bike_passes; c text := upper(regexp_replace(coalesce(p_code, ''), '[^A-Za-z0-9]', '', 'g')); e record; txt text := nullif(trim(coalesce(p_text, '')), ''); n bigint;
begin
  select * into k from bike_passes where code = c;
  if k.code is null or k.withdrawn_at is not null then return jsonb_build_object('error', 'FYF_NOT_FOUND'); end if;
  if not fyf_owner_ok(k, p_transfer) then return jsonb_build_object('error', 'FYF_BAD_TRANSFER'); end if;
  if p_stars is null or p_stars not between 1 and 5 or length(coalesce(txt, '')) > 600 then return jsonb_build_object('error', 'FYF_BAD_DATA'); end if;
  select * into e from bike_pass_entries where id = p_entry and code = c;
  if e.id is null or e.tenant_id is null or coalesce(e.trust, 'shop') = 'self' then return jsonb_build_object('error', 'FYF_NOT_SHOP'); end if;
  if e.done_on < current_date - 120 then return jsonb_build_object('error', 'FYF_TOO_OLD'); end if;
  if exists (select 1 from shop_reviews where entry_id = e.id) then return jsonb_build_object('error', 'FYF_DONE'); end if;
  if exists (select 1 from shop_reviews where code = c and tenant_id = e.tenant_id and created_at > now() - interval '180 days') then return jsonb_build_object('error', 'FYF_RATE'); end if;
  insert into shop_reviews(tenant_id, code, entry_id, stars, body) values (e.tenant_id, c, e.id, p_stars, txt) returning id into n;
  return jsonb_build_object('ok', true, 'id', n);
end $$;
revoke all on function review_submit(text, text, bigint, int, text) from public;
grant execute on function review_submit(text, text, bigint, int, text) to anon, authenticated;

-- Besitzer: welche Einträge sind schon bewertet?
create or replace function review_done(p_code text, p_transfer text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare k bike_passes; c text := upper(regexp_replace(coalesce(p_code, ''), '[^A-Za-z0-9]', '', 'g'));
begin
  select * into k from bike_passes where code = c;
  if k.code is null or not fyf_owner_ok(k, p_transfer) then return '[]'::jsonb; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('entry', entry_id, 'stars', stars, 'reply', case when hidden then null else reply end)) from shop_reviews where code = c), '[]'::jsonb);
end $$;
revoke all on function review_done(text, text) from public;
grant execute on function review_done(text, text) to anon, authenticated;

-- Öffentlich: Bewertungen eines veröffentlichten Ladens
create or replace function review_public(p_slug text) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'n', count(r.id), 'avg', round(avg(r.stars)::numeric, 1),
    'list', coalesce(jsonb_agg(jsonb_build_object('stars', r.stars, 'text', r.body, 'month', to_char(r.created_at, 'YYYY-MM'), 'reply', r.reply) order by r.created_at desc) filter (where r.id is not null), '[]'::jsonb))
  from dealer_profiles d left join shop_reviews r on r.tenant_id = d.tenant_id and not r.hidden
  where d.slug = lower(p_slug) and d.published;
$$;
revoke all on function review_public(text) from public;
grant execute on function review_public(text) to anon, authenticated;

-- Öffentlich: Übersicht für die Händlersuche (Durchschnitt erst ab 3 Bewertungen)
create or replace function review_stats() returns table(slug text, n int, avg numeric)
language sql stable security definer set search_path = public as $$
  select d.slug, count(r.id)::int, case when count(r.id) >= 3 then round(avg(r.stars)::numeric, 1) end
  from dealer_profiles d join shop_reviews r on r.tenant_id = d.tenant_id and not r.hidden
  where d.published group by d.slug;
$$;
revoke all on function review_stats() from public;
grant execute on function review_stats() to anon, authenticated;

-- Laden: eigene Bewertungen lesen, antworten, melden
create or replace function review_mine(p_tenant uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if not is_member(p_tenant) then raise exception 'FYF_DENIED'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id', id, 'stars', stars, 'text', body, 'at', created_at, 'reply', reply, 'reply_at', reply_at, 'reported', reported, 'hidden', hidden) order by created_at desc)
    from shop_reviews where tenant_id = p_tenant), '[]'::jsonb);
end $$;
revoke all on function review_mine(uuid) from public, anon;
grant execute on function review_mine(uuid) to authenticated;

create or replace function review_reply(p_tenant uuid, p_id bigint, p_text text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not has_role(p_tenant, array['admin','fitter']) then raise exception 'FYF_DENIED'; end if;
  if length(coalesce(p_text, '')) > 600 then raise exception 'FYF_BAD_DATA'; end if;
  update shop_reviews set reply = nullif(trim(p_text), ''), reply_at = now() where id = p_id and tenant_id = p_tenant;
end $$;
revoke all on function review_reply(uuid, bigint, text) from public, anon;
grant execute on function review_reply(uuid, bigint, text) to authenticated;

create or replace function review_report(p_tenant uuid, p_id bigint, p_reason text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not has_role(p_tenant, array['admin']) then raise exception 'FYF_DENIED'; end if;
  update shop_reviews set reported = left(coalesce(nullif(trim(p_reason), ''), 'gemeldet'), 300) where id = p_id and tenant_id = p_tenant;
end $$;
revoke all on function review_report(uuid, bigint, text) from public, anon;
grant execute on function review_report(uuid, bigint, text) to authenticated;

-- Plattform: gemeldete Bewertungen prüfen
create or replace function review_reported() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if not is_platform_admin() then raise exception 'FYF_DENIED'; end if;
  return coalesce((select jsonb_agg(jsonb_build_object('id', r.id, 'shop', d.name, 'stars', r.stars, 'text', r.body, 'reported', r.reported, 'hidden', r.hidden, 'at', r.created_at) order by r.created_at desc)
    from shop_reviews r left join dealer_profiles d on d.tenant_id = r.tenant_id where r.reported is not null), '[]'::jsonb);
end $$;
revoke all on function review_reported() from public, anon;
grant execute on function review_reported() to authenticated;

create or replace function review_moderate(p_id bigint, p_hide boolean) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not is_platform_admin() then raise exception 'FYF_DENIED'; end if;
  update shop_reviews set hidden = coalesce(p_hide, false), reported = case when p_hide then reported else null end where id = p_id;
end $$;
revoke all on function review_moderate(bigint, boolean) from public, anon;
grant execute on function review_moderate(bigint, boolean) to authenticated;
