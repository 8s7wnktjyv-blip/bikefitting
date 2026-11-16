-- FYF – Stand 20 (16.11.2026): Akku-Diebstahl und anonyme Laufleistungen.
-- 1. Akku als gestohlen melden: nur der Besitzer (Übergabe-Code, Teil II). Gespeichert wird nur ein Prüfwert (SHA-256) der Akku-Seriennummer.
--    Jeder kann einen Prüfwert abfragen (Käufer, Werkstatt) und erfährt nur: gestohlen ja/nein.
-- 2. Laufleistungen beim Teiletausch (Modell, Teil, Kilometer), freiwillig und ohne Pass-Code. Auswertung erst ab 5 Rädern je Modell und Teil.
-- Mehrfach ausführen schadet nicht.

create table if not exists battery_flags (
  bat_hash text primary key check (bat_hash ~ '^[0-9a-f]{64}$'),
  code text not null references bike_passes(code) on delete cascade,
  stolen boolean not null default false,
  updated_at timestamptz not null default now()
);
alter table battery_flags enable row level security;

create or replace function pass_battery_set(p_code text, p_transfer text, p_bh text, p_stolen boolean) returns jsonb
language plpgsql security definer set search_path = public as $$
declare k bike_passes; c text := upper(regexp_replace(coalesce(p_code, ''), '[^A-Za-z0-9]', '', 'g'));
begin
  if coalesce(p_bh, '') !~ '^[0-9a-f]{64}$' then return jsonb_build_object('error', 'FYF_BAD_DATA'); end if;
  select * into k from bike_passes where code = c;
  if k.code is null or k.withdrawn_at is not null then return jsonb_build_object('error', 'FYF_NOT_FOUND'); end if;
  if not fyf_owner_ok(k, p_transfer) then return jsonb_build_object('error', 'FYF_BAD_TRANSFER'); end if;
  if exists (select 1 from battery_flags where bat_hash = p_bh and code <> c) then return jsonb_build_object('error', 'FYF_BAT_OTHER'); end if;
  insert into battery_flags(bat_hash, code, stolen) values (p_bh, c, coalesce(p_stolen, false))
    on conflict (bat_hash) do update set stolen = excluded.stolen, updated_at = now();
  insert into bike_pass_entries(code, tenant_id, shop, kind, body, done_on, trust)
    values (c, null, 'Besitzer', case when coalesce(p_stolen, false) then 'Diebstahl gemeldet' else 'Diebstahlmeldung aufgehoben' end,
            case when coalesce(p_stolen, false) then 'Akku vom Besitzer als gestohlen gemeldet' else 'Akku-Meldung aufgehoben' end, current_date, 'self');
  return jsonb_build_object('ok', true, 'stolen', coalesce(p_stolen, false));
end $$;
revoke all on function pass_battery_set(text, text, text, boolean) from public;
grant execute on function pass_battery_set(text, text, text, boolean) to anon, authenticated;

create or replace function battery_check(p_bh text) returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  if coalesce(p_bh, '') !~ '^[0-9a-f]{64}$' then return jsonb_build_object('error', 'FYF_BAD_DATA'); end if;
  return jsonb_build_object('stolen', exists (select 1 from battery_flags f join bike_passes p on p.code = f.code where f.bat_hash = p_bh and f.stolen and p.withdrawn_at is null));
end $$;
revoke all on function battery_check(text) from public;
grant execute on function battery_check(text) to anon, authenticated;

create table if not exists wear_stats (
  id bigserial primary key,
  model text not null check (length(model) between 3 and 60),
  part text not null check (part in ('chain','cassette','chainring','pads','rotors','tires')),
  km int not null check (km between 50 and 100000),
  ref text not null unique check (ref ~ '^[0-9a-f]{32}$'),
  created_at timestamptz not null default now()
);
create index if not exists wear_stats_mp on wear_stats (model, part);
alter table wear_stats enable row level security;

create or replace function wear_submit(p_model text, p_part text, p_km int, p_ref text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare m text := lower(regexp_replace(trim(coalesce(p_model, '')), '\s+', ' ', 'g'));
begin
  if length(m) not between 3 and 60 or coalesce(p_part, '') not in ('chain','cassette','chainring','pads','rotors','tires') or p_km is null or p_km not between 50 and 100000 or coalesce(p_ref, '') !~ '^[0-9a-f]{32}$' then
    return jsonb_build_object('error', 'FYF_BAD_DATA'); end if;
  if (select count(*) from wear_stats where created_at > now() - interval '1 hour') >= 500 then return jsonb_build_object('error', 'FYF_RATE'); end if;
  insert into wear_stats(model, part, km, ref) values (m, p_part, p_km, p_ref) on conflict (ref) do nothing;
  return jsonb_build_object('ok', true);
end $$;
revoke all on function wear_submit(text, text, int, text) from public;
grant execute on function wear_submit(text, text, int, text) to anon, authenticated;

-- Nur zusammengefasst und erst ab 5 Einträgen je Modell und Teil
create or replace function wear_stats(p_model text) returns jsonb
language sql security definer set search_path = public stable as $$
  select coalesce(jsonb_agg(jsonb_build_object('part', part, 'n', n, 'median', med, 'p25', p25, 'p75', p75)), '[]'::jsonb) from (
    select part, count(*) as n,
           round(percentile_cont(0.5) within group (order by km))::int as med,
           round(percentile_cont(0.25) within group (order by km))::int as p25,
           round(percentile_cont(0.75) within group (order by km))::int as p75
      from wear_stats where model = lower(regexp_replace(trim(coalesce(p_model, '')), '\s+', ' ', 'g'))
     group by part having count(*) >= 5) s;
$$;
revoke all on function wear_stats(text) from public;
grant execute on function wear_stats(text) to anon, authenticated;
