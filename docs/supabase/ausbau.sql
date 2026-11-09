-- FYF – Fit your Frame · Terminwünsche und Kundenportal per Link (Schritt 7)
-- Voraussetzung: start.sql, team.sql, netz.sql wurden schon ausgeführt.
-- Ausführen: Supabase → SQL Editor → diesen Text einfügen → Run. Mehrfach ausführen schadet nicht.
--
-- Was das macht
-- 1. Anfragen bekommen einen Wunschtermin (Feld „preferred“). Die öffentliche Seite schickt ihn mit.
-- 2. Kundenportal per persönlichem Link: Der Laden stellt für einen Kunden eine Übersicht bereit
--    (Fahrräder, Einstellungen, Fitting-Ergebnisse, Empfehlungen, nächste Termine). Zufälliger Schlüssel,
--    180 Tage gültig, jederzeit widerrufbar. Ohne Kunden-Konto.

alter table inquiries add column if not exists preferred text;

drop function if exists submit_inquiry(text, text, text, text, text, text, text);
create or replace function submit_inquiry(p_slug text, p_topic text, p_name text, p_contact text, p_message text, p_product text default null, p_hp text default '', p_pref text default null) returns boolean
language plpgsql security definer set search_path = public as $$
declare t uuid; c text := lower(trim(coalesce(p_contact, '')));
begin
  if coalesce(p_hp, '') <> '' then return true; end if;
  select tenant_id into t from dealer_profiles where slug = p_slug and published;
  if t is null then raise exception 'FYF_NOT_FOUND'; end if;
  if length(trim(coalesce(p_name, ''))) < 2 or length(c) < 5 or length(trim(coalesce(p_message, ''))) < 5 then raise exception 'FYF_BAD_DATA'; end if;
  if length(p_name) > 100 or length(c) > 120 or length(p_message) > 2000 or length(coalesce(p_topic, '')) > 60 or length(coalesce(p_pref, '')) > 200 then raise exception 'FYF_TOO_LONG'; end if;
  if (select count(*) from inquiries where tenant_id = t and created_at > now() - interval '1 hour') >= 20 then raise exception 'FYF_RATE'; end if;
  if (select count(*) from inquiries where tenant_id = t and lower(contact) = c and created_at > now() - interval '1 day') >= 3 then raise exception 'FYF_RATE'; end if;
  insert into inquiries(tenant_id, topic, product_id, name, contact, message, preferred)
    values (t, coalesce(nullif(trim(p_topic), ''), 'Allgemein'), left(p_product, 60), trim(p_name), trim(p_contact), trim(p_message), nullif(trim(coalesce(p_pref, '')), ''));
  return true;
end $$;
grant execute on function submit_inquiry(text, text, text, text, text, text, text, text) to anon, authenticated;

create table if not exists portal_links (
  token text primary key,
  tenant_id uuid not null references tenants(id) on delete cascade,
  customer_id text not null,
  payload jsonb not null,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '180 days',
  revoked boolean not null default false,
  opened_at timestamptz
);
create index if not exists portal_links_t on portal_links (tenant_id, customer_id);
alter table portal_links enable row level security;
drop policy if exists portal_read on portal_links;
create policy portal_read on portal_links for select using (is_member(tenant_id));
grant select on portal_links to authenticated;

create or replace function portal_publish(p_tenant uuid, p_customer text, p_payload jsonb) returns text
language plpgsql security definer set search_path = public as $$
declare tk text := replace(gen_random_uuid()::text, '-', '');
begin
  if not is_member(p_tenant) then raise exception 'FYF_DENIED'; end if;
  if p_payload is null or jsonb_typeof(p_payload) <> 'object' or length(p_payload::text) > 60000 then raise exception 'FYF_BAD_DATA'; end if;
  update portal_links set revoked = true where tenant_id = p_tenant and customer_id = p_customer and not revoked;
  insert into portal_links(token, tenant_id, customer_id, payload) values (tk, p_tenant, left(p_customer, 60), p_payload);
  perform fyf_audit(p_tenant, 'portal_publish', jsonb_build_object('customer', p_customer));
  return tk;
end $$;

create or replace function portal_revoke(p_tenant uuid, p_customer text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not is_member(p_tenant) then raise exception 'FYF_DENIED'; end if;
  update portal_links set revoked = true where tenant_id = p_tenant and customer_id = p_customer and not revoked;
  perform fyf_audit(p_tenant, 'portal_revoke', jsonb_build_object('customer', p_customer));
end $$;

create or replace function portal_get(p_token text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare k record;
begin
  if length(coalesce(p_token, '')) <> 32 then return null; end if;
  select * into k from portal_links where token = p_token and not revoked and expires_at > now();
  if k.token is null then return null; end if;
  if k.opened_at is null then update portal_links set opened_at = now() where token = p_token; end if;
  return k.payload;
end $$;

revoke all on function portal_publish(uuid, text, jsonb) from public, anon;
revoke all on function portal_revoke(uuid, text) from public, anon;
grant execute on function portal_publish(uuid, text, jsonb), portal_revoke(uuid, text) to authenticated;
grant execute on function portal_get(text) to anon, authenticated;
