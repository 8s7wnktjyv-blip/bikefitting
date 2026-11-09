-- FYF – Fit your Frame · Kostenvoranschlag per Link freigeben (Schritt 5)
-- Voraussetzung: start.sql, team.sql und netz.sql wurden schon ausgeführt.
-- Ausführen: Supabase → SQL Editor → diesen Text einfügen → Run. Mehrfach ausführen schadet nicht.
--
-- Was das macht
-- * Der Laden stellt einen Kostenvoranschlag als Link bereit (kva_publish). Der Link enthält einen zufälligen,
--   nicht erratbaren Schlüssel (32 Zeichen) und gilt 30 Tage.
-- * Der Kunde öffnet den Link ohne Konto, sieht Laden, Fahrrad und Positionen und tippt „Freigeben“ oder „Ablehnen“.
--   Eine Antwort ist nur einmal möglich.
-- * Im Link stehen keine Telefonnummer und keine E-Mail des Kunden.
-- * Die Antworten liest nur der Laden (RLS).

create table if not exists kva_links (
  token text primary key,
  tenant_id uuid not null references tenants(id) on delete cascade,
  wo_id text not null,
  payload jsonb not null,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '30 days',
  decision text check (decision in ('freigegeben','abgelehnt')),
  decided_at timestamptz,
  decided_name text,
  note text
);
create index if not exists kva_links_t on kva_links (tenant_id, created_at desc);
alter table kva_links enable row level security;
drop policy if exists kva_read on kva_links;
create policy kva_read on kva_links for select using (is_member(tenant_id));
grant select on kva_links to authenticated;

create or replace function kva_publish(p_tenant uuid, p_wo text, p_payload jsonb) returns text
language plpgsql security definer set search_path = public as $$
declare tk text := replace(gen_random_uuid()::text, '-', '');
begin
  if not is_member(p_tenant) then raise exception 'FYF_DENIED'; end if;
  if p_payload is null or jsonb_typeof(p_payload) <> 'object' or length(p_payload::text) > 20000 then raise exception 'FYF_BAD_DATA'; end if;
  delete from kva_links where tenant_id = p_tenant and wo_id = p_wo and decision is null;
  insert into kva_links(token, tenant_id, wo_id, payload) values (tk, p_tenant, left(p_wo, 60), p_payload);
  perform fyf_audit(p_tenant, 'kva_publish', jsonb_build_object('wo', p_wo));
  return tk;
end $$;

create or replace function kva_get(p_token text) returns table(payload jsonb, decision text, decided_at timestamptz, expired boolean)
language sql stable security definer set search_path = public as $$
  select k.payload, k.decision, k.decided_at, k.expires_at < now() from kva_links k where k.token = p_token and length(p_token) = 32 $$;

create or replace function kva_answer(p_token text, p_decision text, p_name text, p_note text default null) returns boolean
language plpgsql security definer set search_path = public as $$
declare k record;
begin
  if p_decision not in ('freigegeben','abgelehnt') then raise exception 'FYF_BAD_DATA'; end if;
  if length(trim(coalesce(p_name, ''))) < 2 or length(p_name) > 100 or length(coalesce(p_note, '')) > 1000 then raise exception 'FYF_BAD_DATA'; end if;
  select * into k from kva_links where token = p_token for update;
  if k.token is null or k.expires_at < now() then raise exception 'FYF_NOT_FOUND'; end if;
  if k.decision is not null then raise exception 'FYF_ALREADY'; end if;
  update kva_links set decision = p_decision, decided_at = now(), decided_name = trim(p_name), note = nullif(trim(coalesce(p_note, '')), '') where token = p_token;
  return true;
end $$;

revoke all on function kva_publish(uuid, text, jsonb) from public, anon;
grant execute on function kva_publish(uuid, text, jsonb) to authenticated;
grant execute on function kva_get(text), kva_answer(text, text, text, text) to anon, authenticated;
