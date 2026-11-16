-- FYF – Stand 22 (16.11.2026): anonyme Nutzungszählung.
-- Gezählt wird nur: Tag, App, Ereignis (z. B. „tool_svc“), Anzahl. Keine Codes, keine Nutzer-IDs, keine IP-Adressen in der Tabelle.
-- Die Apps senden jedes Ereignis höchstens einmal pro Gerät und Tag. Lesen nur Plattform-Admins.
create table if not exists usage_daily (
  day date not null default current_date,
  app text not null check (app in ('pass','laden','finder')),
  event text not null check (event ~ '^[a-z0-9_]{2,40}$'),
  n int not null default 0,
  primary key (day, app, event)
);
alter table usage_daily enable row level security;
create or replace function usage_hit(p_app text, p_event text) returns void
language plpgsql security definer set search_path = public as $$
declare e text := lower(regexp_replace(coalesce(p_event, ''), '[^a-zA-Z0-9_]', '_', 'g'));
begin
  if coalesce(p_app, '') not in ('pass','laden','finder') or e !~ '^[a-z0-9_]{2,40}$' then return; end if;
  if (select count(*) from usage_daily where day = current_date) >= 400 and not exists (select 1 from usage_daily where day = current_date and app = p_app and event = e) then return; end if;
  insert into usage_daily(day, app, event, n) values (current_date, p_app, e, 1) on conflict (day, app, event) do update set n = usage_daily.n + 1;
  delete from usage_daily where day < current_date - 400;
end $$;
revoke all on function usage_hit(text, text) from public;
grant execute on function usage_hit(text, text) to anon, authenticated;
create or replace function usage_stats(p_days int) returns jsonb
language sql security definer set search_path = public stable as $$
  select case when is_platform_admin() then coalesce((select jsonb_agg(jsonb_build_object('app', app, 'event', event, 'n', s, 'days', d, 'today', t) order by app, s desc) from (
    select app, event, sum(n) as s, count(*) as d, sum(n) filter (where day = current_date) as t from usage_daily where day > current_date - greatest(1, least(coalesce(p_days, 30), 400)) group by app, event) x), '[]'::jsonb) else null end;
$$;
revoke all on function usage_stats(int) from public, anon;
grant execute on function usage_stats(int) to authenticated;
