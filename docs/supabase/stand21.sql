-- FYF – Stand 21 (16.11.2026): Rechnungsarchiv (GoBD), Fehlerberichte, Rückrufliste in der Datenbank.
-- 1. invoice_archive: Jede Rechnung und jede Stornorechnung wird beim Erstellen unveränderbar abgelegt.
--    Kein Ändern, kein Löschen (Trigger). Jeder Eintrag enthält den Hash des vorherigen (Kette je Laden),
--    so fällt jede nachträgliche Manipulation bei der Prüfung auf. Nur Admin und Fitter dürfen ablegen.
-- 2. app_errors: Programmfehler aus den Apps (ohne Kundendaten, gekürzt, Rate-Limit). Lesen nur Plattform-Admins.
-- 3. recalls: Rückrufliste, gepflegt von Plattform-Admins in der App; jeder darf lesen.
-- Mehrfach ausführen schadet nicht.

create table if not exists invoice_archive (
  id bigserial primary key,
  tenant_id uuid not null references tenants(id) on delete restrict,
  inv_id text not null,
  inv_no text not null,
  kind text not null check (kind in ('rechnung','storno')),
  payload jsonb not null,
  xml text,
  prev_hash text,
  hash text not null,
  created_by uuid default auth.uid(),
  created_at timestamptz not null default now(),
  unique (tenant_id, inv_id)
);
alter table invoice_archive enable row level security;
create or replace function fyf_invoice_archive_lock() returns trigger language plpgsql as $$
begin raise exception 'FYF_LOCKED'; end $$;
drop trigger if exists invoice_archive_lock on invoice_archive;
create trigger invoice_archive_lock before update or delete on invoice_archive for each row execute function fyf_invoice_archive_lock();

create or replace function invoice_archive_put(p_tenant uuid, p_inv_id text, p_no text, p_kind text, p_payload jsonb, p_xml text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare prev text; h text; ex record;
begin
  if not has_role(p_tenant, array['admin','fitter']) then raise exception 'FYF_DENIED'; end if;
  if coalesce(p_inv_id, '') = '' or length(p_inv_id) > 60 or coalesce(p_no, '') = '' or length(p_no) > 40 or p_kind not in ('rechnung','storno')
     or p_payload is null or jsonb_typeof(p_payload) <> 'object' or length(p_payload::text) > 200000 or length(coalesce(p_xml, '')) > 400000 then
    return jsonb_build_object('error', 'FYF_BAD_DATA'); end if;
  select * into ex from invoice_archive where tenant_id = p_tenant and inv_id = p_inv_id;
  if ex.id is not null then return jsonb_build_object('ok', true, 'hash', ex.hash, 'existing', true, 'same', ex.payload = p_payload); end if;
  perform pg_advisory_xact_lock(hashtext('fyf_inv_' || p_tenant::text));
  select hash into prev from invoice_archive where tenant_id = p_tenant order by id desc limit 1;
  h := encode(sha256(convert_to(coalesce(prev, '') || '|' || p_inv_id || '|' || p_no || '|' || p_kind || '|' || p_payload::text, 'UTF8')), 'hex');
  insert into invoice_archive(tenant_id, inv_id, inv_no, kind, payload, xml, prev_hash, hash) values (p_tenant, p_inv_id, p_no, p_kind, p_payload, nullif(p_xml, ''), prev, h);
  return jsonb_build_object('ok', true, 'hash', h);
end $$;
revoke all on function invoice_archive_put(uuid, text, text, text, jsonb, text) from public, anon;
grant execute on function invoice_archive_put(uuid, text, text, text, jsonb, text) to authenticated;

-- Prüfen: Kette vollständig und unverändert? Gibt Anzahl, ersten/letzten Eintrag und die erste Abweichung zurück.
create or replace function invoice_archive_verify(p_tenant uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare r record; prev text := null; n int := 0; bad text := null; first_no text; last_no text;
begin
  if not is_member(p_tenant) then raise exception 'FYF_DENIED'; end if;
  for r in select * from invoice_archive where tenant_id = p_tenant order by id loop
    n := n + 1; if first_no is null then first_no := r.inv_no; end if; last_no := r.inv_no;
    if coalesce(r.prev_hash, '') <> coalesce(prev, '') or r.hash <> encode(sha256(convert_to(coalesce(prev, '') || '|' || r.inv_id || '|' || r.inv_no || '|' || r.kind || '|' || r.payload::text, 'UTF8')), 'hex') then
      bad := r.inv_no; exit; end if;
    prev := r.hash;
  end loop;
  return jsonb_build_object('count', n, 'ok', bad is null, 'first', first_no, 'last', last_no, 'bad', bad);
end $$;
revoke all on function invoice_archive_verify(uuid) from public, anon;
grant execute on function invoice_archive_verify(uuid) to authenticated;

-- Export für Steuerberater / Betriebsprüfung (alle Rechnungen mit Hash)
create or replace function invoice_archive_export(p_tenant uuid, p_from date, p_to date) returns jsonb
language sql security definer set search_path = public stable as $$
  select case when is_member(p_tenant) then coalesce(jsonb_agg(jsonb_build_object('no', inv_no, 'kind', kind, 'created_at', created_at, 'hash', hash, 'prev_hash', prev_hash, 'payload', payload) order by id), '[]'::jsonb) else null end
    from invoice_archive where tenant_id = p_tenant and created_at::date between coalesce(p_from, '2000-01-01') and coalesce(p_to, '2999-12-31');
$$;
revoke all on function invoice_archive_export(uuid, date, date) from public, anon;
grant execute on function invoice_archive_export(uuid, date, date) to authenticated;

-- ---------- Fehlerberichte ----------
create table if not exists app_errors (
  id bigserial primary key,
  at timestamptz not null default now(),
  app text not null check (app in ('laden','pass','finder','status')),
  ver text check (length(ver) <= 40),
  msg text not null check (length(msg) <= 400),
  src text check (length(src) <= 300),
  ua text check (length(ua) <= 160),
  n int not null default 1
);
create index if not exists app_errors_at on app_errors (at desc);
alter table app_errors enable row level security;
create or replace function app_error_log(p_app text, p_ver text, p_msg text, p_src text, p_ua text) returns void
language plpgsql security definer set search_path = public as $$
declare m text := left(coalesce(p_msg, ''), 400); s text := left(coalesce(p_src, ''), 300);
begin
  if coalesce(p_app, '') not in ('laden','pass','finder','status') or length(m) < 3 then return; end if;
  if (select count(*) from app_errors where at > now() - interval '1 hour') >= 300 then return; end if;
  update app_errors set n = n + 1, at = now() where msg = m and coalesce(src, '') = s and app = p_app and coalesce(ver, '') = coalesce(left(p_ver, 40), '') and at > now() - interval '1 day';
  if not found then insert into app_errors(app, ver, msg, src, ua) values (p_app, left(p_ver, 40), m, s, left(coalesce(p_ua, ''), 160)); end if;
  delete from app_errors where at < now() - interval '90 days';
end $$;
revoke all on function app_error_log(text, text, text, text, text) from public;
grant execute on function app_error_log(text, text, text, text, text) to anon, authenticated;
create or replace function app_errors_list() returns jsonb
language sql security definer set search_path = public stable as $$
  select case when is_platform_admin() then coalesce((select jsonb_agg(to_jsonb(e) order by e.at desc) from (select * from app_errors order by at desc limit 200) e), '[]'::jsonb) else null end;
$$;
revoke all on function app_errors_list() from public, anon;
grant execute on function app_errors_list() to authenticated;

-- ---------- Rückrufliste ----------
create table if not exists recalls (
  id text primary key check (id ~ '^[a-z0-9-]{3,80}$'),
  data jsonb not null,
  active boolean not null default true,
  updated_at timestamptz not null default now()
);
alter table recalls enable row level security;
create or replace function recalls_list() returns jsonb
language sql security definer set search_path = public stable as $$
  select coalesce(jsonb_agg(data || jsonb_build_object('id', id) order by (data->>'date') desc), '[]'::jsonb) from recalls where active;
$$;
revoke all on function recalls_list() from public;
grant execute on function recalls_list() to anon, authenticated;
create or replace function recalls_put(p_id text, p_data jsonb, p_active boolean) returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  if not is_platform_admin() then raise exception 'FYF_DENIED'; end if;
  if coalesce(p_id, '') !~ '^[a-z0-9-]{3,80}$' or p_data is null or jsonb_typeof(p_data) <> 'object' or length(p_data::text) > 4000
     or coalesce(p_data->>'brand', '') = '' or coalesce(p_data->>'title', '') = '' or coalesce(p_data->>'url', '') !~ '^https://' then
    return jsonb_build_object('error', 'FYF_BAD_DATA'); end if;
  insert into recalls(id, data, active) values (p_id, p_data - 'id', coalesce(p_active, true))
    on conflict (id) do update set data = excluded.data, active = excluded.active, updated_at = now();
  return jsonb_build_object('ok', true);
end $$;
revoke all on function recalls_put(text, jsonb, boolean) from public, anon;
grant execute on function recalls_put(text, jsonb, boolean) to authenticated;
