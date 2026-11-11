-- FYF – Stand 14: Fundmeldungen zu gestohlenen Rädern + Rahmennummer-Abgleich für Käufer
-- Wer den QR-Code an einem als gestohlen gemeldeten Rad scannt, kann „Ich habe dieses Rad gesehen“ melden (anonym, optional mit Standort).
-- Nur der Besitzer (Code von Karte Teil II) oder die betreuende Werkstatt sieht die Meldungen.
-- Mehrfach ausführen schadet nicht.

create table if not exists bike_pass_seen (
  id bigserial primary key,
  code text not null references bike_passes(code) on delete cascade,
  at timestamptz not null default now(),
  note text check (note is null or length(note) <= 300),
  lat numeric(8,5) check (lat is null or lat between -90 and 90),
  lon numeric(8,5) check (lon is null or lon between -180 and 180),
  acc int check (acc is null or acc between 0 and 100000)
);
create index if not exists bike_pass_seen_code on bike_pass_seen(code, at desc);
alter table bike_pass_seen enable row level security;
revoke all on bike_pass_seen from anon, authenticated;

-- Fundmeldung abgeben (jeder, ohne Konto) – nur für Räder, die gerade als gestohlen gemeldet sind
create or replace function pass_seen_add(p_code text, p_note text, p_lat numeric, p_lon numeric, p_acc int) returns jsonb
language plpgsql security definer set search_path = public as $$
declare k record; c text := upper(regexp_replace(coalesce(p_code, ''), '[^A-Za-z0-9]', '', 'g')); n text := nullif(trim(coalesce(p_note, '')), '');
begin
  select * into k from bike_passes where code = c;
  if k.code is null or k.withdrawn_at is not null then return jsonb_build_object('error', 'FYF_NOT_FOUND'); end if;
  if not coalesce(k.owner_stolen, k.stolen) then return jsonb_build_object('error', 'FYF_NOT_STOLEN'); end if;
  if n is not null and length(n) > 300 then return jsonb_build_object('error', 'FYF_BAD_DATA'); end if;
  if (p_lat is null) <> (p_lon is null) or (p_lat is not null and (p_lat not between -90 and 90 or p_lon not between -180 and 180)) then return jsonb_build_object('error', 'FYF_BAD_DATA'); end if;
  if (select count(*) from bike_pass_seen where code = c and at > now() - interval '1 hour') >= 10 then return jsonb_build_object('error', 'FYF_RATE'); end if;
  if (select count(*) from bike_pass_seen where at > now() - interval '1 hour') >= 500 then return jsonb_build_object('error', 'FYF_RATE'); end if;
  insert into bike_pass_seen(code, note, lat, lon, acc) values (c, n, round(p_lat, 5), round(p_lon, 5), case when p_acc is null then null else least(greatest(p_acc, 0), 100000) end);
  return jsonb_build_object('ok', true);
end $$;

-- Fundmeldungen lesen: Besitzer mit Teil II oder die Werkstatt, die den Pass führt
create or replace function pass_seen_list(p_code text, p_transfer text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare k record; c text := upper(regexp_replace(coalesce(p_code, ''), '[^A-Za-z0-9]', '', 'g')); t text := upper(regexp_replace(coalesce(p_transfer, ''), '[^A-Za-z0-9]', '', 'g'));
begin
  select * into k from bike_passes where code = c;
  if k.code is null then return jsonb_build_object('error', 'FYF_NOT_FOUND'); end if;
  if not (k.tenant_id is not null and is_member(k.tenant_id)) then
    if k.owner_fails >= 10 and k.owner_fail_at > now() - interval '1 day' then return jsonb_build_object('error', 'FYF_RATE'); end if;
    if k.transfer_hash is null or encode(sha256(convert_to(t, 'UTF8')), 'hex') <> k.transfer_hash then
      update bike_passes set owner_fails = case when owner_fail_at > now() - interval '1 day' then owner_fails + 1 else 1 end, owner_fail_at = now() where code = c;
      return jsonb_build_object('error', 'FYF_BAD_TRANSFER');
    end if;
  end if;
  return jsonb_build_object('ok', true, 'stolen', coalesce(k.owner_stolen, k.stolen),
    'seen', coalesce((select jsonb_agg(jsonb_build_object('at', s.at, 'note', s.note, 'lat', s.lat, 'lon', s.lon, 'acc', s.acc) order by s.at desc)
                      from (select * from bike_pass_seen where code = c order by at desc limit 50) s), '[]'::jsonb));
end $$;

-- Käufer prüft: Passt die Rahmennummer am Rad zum Pass? (Nummer wird nur als Hash übertragen, nichts wird gespeichert)
create or replace function pass_frame_match(p_code text, p_fh text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare k record; c text := upper(regexp_replace(coalesce(p_code, ''), '[^A-Za-z0-9]', '', 'g'));
begin
  if coalesce(p_fh, '') !~ '^[0-9a-f]{64}$' then return jsonb_build_object('error', 'FYF_BAD_DATA'); end if;
  select * into k from bike_passes where code = c;
  if k.code is null then return jsonb_build_object('error', 'FYF_NOT_FOUND'); end if;
  if k.frame_hash is null then return jsonb_build_object('known', false); end if;
  return jsonb_build_object('known', true, 'match', k.frame_hash = p_fh);
end $$;

revoke all on function pass_seen_add(text, text, numeric, numeric, int) from public;
revoke all on function pass_seen_list(text, text) from public;
revoke all on function pass_frame_match(text, text) from public;
grant execute on function pass_seen_add(text, text, numeric, numeric, int), pass_seen_list(text, text), pass_frame_match(text, text) to anon, authenticated;
