-- FYF – Stand 23 (16.11.2026): Kalender-Abo für iPhone, Google und Outlook.
-- Der Laden bekommt einen geheimen Link. Kalender-Apps rufen ihn regelmäßig ab und zeigen die Termine (S.appts) an.
-- Kein Login im Kalender nötig. Wer den Link hat, sieht die Termine – deshalb: Link nur ins eigene Gerät, bei Verdacht „neuer Link“.
-- Antwort ist eine .ics-Datei (text/calendar). Unbekannter Link → leerer Kalender (verrät nichts).
create table if not exists cal_feeds (
  tenant_id uuid primary key references tenants(id) on delete cascade,
  token text not null unique,
  names boolean not null default true,
  created_at timestamptz not null default now()
);
alter table cal_feeds enable row level security;

-- Link holen (Mitglied) oder neu erzeugen/abschalten (nur Admin). Gibt den Token zurück, '' wenn abgeschaltet.
create or replace function cal_feed_token(p_tenant uuid, p_action text default 'get', p_names boolean default null) returns text
language plpgsql security definer set search_path = public as $$
declare t text;
begin
  if not is_member(p_tenant) then raise exception 'FYF_DENIED'; end if;
  if p_action in ('renew','off') or p_names is not null then
    if not has_role(p_tenant, array['admin']) then raise exception 'FYF_DENIED'; end if;
  end if;
  if p_action = 'off' then delete from cal_feeds where tenant_id = p_tenant; return ''; end if;
  if p_action = 'renew' then delete from cal_feeds where tenant_id = p_tenant; end if;
  select token into t from cal_feeds where tenant_id = p_tenant;
  if t is null then
    t := replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', '');
    insert into cal_feeds(tenant_id, token, names) values (p_tenant, t, coalesce(p_names, true));
  elsif p_names is not null then
    update cal_feeds set names = p_names where tenant_id = p_tenant;
  end if;
  return t;
end $$;
revoke all on function cal_feed_token(uuid, text, boolean) from public, anon;
grant execute on function cal_feed_token(uuid, text, boolean) to authenticated;

create or replace function fyf_ics_txt(s text) returns text language sql immutable as $$
  select replace(replace(replace(replace(replace(coalesce(s, ''), '\', '\\'), ';', '\;'), ',', '\,'), chr(13), ''), chr(10), '\n');
$$;

-- PostgREST: Rückgabetyp "*/*" = Antwort in beliebigem Format, egal welchen Accept-Header die Kalender-App schickt.
do $$ begin create domain "*/*" as bytea; exception when duplicate_object then null; end $$;

create or replace function cal_feed(t text) returns "*/*"
language plpgsql security definer stable set search_path = public as $$
declare f record; d jsonb; a jsonb; c jsonb; out text; nm text; st timestamptz; dur int; shop text; sumtxt text; desctxt text;
begin
  perform set_config('response.headers', '[{"Content-Type":"text/calendar; charset=utf-8"},{"Content-Disposition":"inline; filename=\"fyf-termine.ics\""},{"Cache-Control":"no-store"}]', true);
  out := 'BEGIN:VCALENDAR' || chr(13) || chr(10) || 'VERSION:2.0' || chr(13) || chr(10) || 'PRODID:-//FYF Fit your Frame//Termine//DE' || chr(13) || chr(10)
      || 'CALSCALE:GREGORIAN' || chr(13) || chr(10) || 'METHOD:PUBLISH' || chr(13) || chr(10) || 'REFRESH-INTERVAL;VALUE=DURATION:PT15M' || chr(13) || chr(10)
      || 'X-PUBLISHED-TTL:PT15M' || chr(13) || chr(10);
  select * into f from cal_feeds where token = t and length(coalesce(t, '')) >= 32;
  if f.tenant_id is not null then
    select data into d from tenant_state where tenant_id = f.tenant_id;
    shop := coalesce(d #>> '{shop,name}', 'FYF');
    out := out || 'X-WR-CALNAME:' || fyf_ics_txt(shop || ' – Termine') || chr(13) || chr(10) || 'X-WR-TIMEZONE:Europe/Berlin' || chr(13) || chr(10);
    for a in select x from jsonb_array_elements(coalesce(d -> 'appts', '[]'::jsonb)) x
      where x ->> 'date' ~ '^\d{4}-\d{2}-\d{2}$' and (x ->> 'date')::date between current_date - 90 and current_date + 400 loop
      begin
        st := ((a ->> 'date') || ' ' || coalesce(nullif(a ->> 'start', ''), '09:00'))::timestamp at time zone 'Europe/Berlin';
      exception when others then continue; end;
      dur := greatest(5, least(1440, coalesce(nullif(a ->> 'dur', '')::numeric, 60)::int));
      nm := '';
      if f.names then
        select x into c from jsonb_array_elements(coalesce(d -> 'customers', '[]'::jsonb)) x where x ->> 'id' = a ->> 'customerId' limit 1;
        nm := coalesce(c ->> 'name', a ->> 'name', '');
      end if;
      sumtxt := coalesce(a ->> 'kind', 'Termin') || case when nm <> '' then ' · ' || nm else '' end;
      desctxt := concat_ws(chr(10),
        case when f.names then nullif(coalesce(c ->> 'phone', ''), '') end,
        case when f.names then nullif(coalesce(c ->> 'email', ''), '') end,
        case when f.names and c is null then nullif(a ->> 'contact', '') end,
        case when nullif(a ->> 'staff', '') is not null then 'Mitarbeiter: ' || (a ->> 'staff') end,
        case when f.names then nullif(a ->> 'note', '') end,
        'In FYF öffnen: Kalender');
      out := out || 'BEGIN:VEVENT' || chr(13) || chr(10)
        || 'UID:' || fyf_ics_txt(coalesce(a ->> 'id', md5(a::text))) || '@fyf' || chr(13) || chr(10)
        || 'DTSTAMP:' || to_char(now() at time zone 'UTC', 'YYYYMMDD"T"HH24MISS"Z"') || chr(13) || chr(10)
        || 'DTSTART:' || to_char(st at time zone 'UTC', 'YYYYMMDD"T"HH24MISS"Z"') || chr(13) || chr(10)
        || 'DTEND:' || to_char((st + make_interval(mins => dur)) at time zone 'UTC', 'YYYYMMDD"T"HH24MISS"Z"') || chr(13) || chr(10)
        || 'SUMMARY:' || fyf_ics_txt(left(sumtxt, 200)) || chr(13) || chr(10)
        || 'DESCRIPTION:' || fyf_ics_txt(left(desctxt, 800)) || chr(13) || chr(10)
        || case when coalesce(d #>> '{shop,addr}', '') <> '' then 'LOCATION:' || fyf_ics_txt(d #>> '{shop,addr}') || chr(13) || chr(10) else '' end
        || 'BEGIN:VALARM' || chr(13) || chr(10) || 'ACTION:DISPLAY' || chr(13) || chr(10) || 'DESCRIPTION:' || fyf_ics_txt(left(sumtxt, 200)) || chr(13) || chr(10)
        || 'TRIGGER:-PT30M' || chr(13) || chr(10) || 'END:VALARM' || chr(13) || chr(10)
        || 'END:VEVENT' || chr(13) || chr(10);
    end loop;
  end if;
  out := out || 'END:VCALENDAR' || chr(13) || chr(10);
  return convert_to(out, 'UTF8');
end $$;
revoke all on function cal_feed(text) from public;
grant execute on function cal_feed(text) to anon, authenticated;
