-- FYF – Fit your Frame · Kunden-Feedback über den Kundenportal-Link (Stand 8)
-- Der Kunde bewertet sein Fitting (0–10) und schreibt kurz, wie es sich fährt – ohne Konto, über seinen persönlichen Link.
-- Die App holt neue Rückmeldungen ab und hängt sie an das letzte Fitting des Kunden.

create table if not exists portal_feedback (
  id bigserial primary key,
  token text not null,
  tenant_id uuid not null references tenants(id) on delete cascade,
  customer_id text not null,
  score int not null check (score between 0 and 10),
  body text,
  created_at timestamptz not null default now(),
  imported boolean not null default false
);
create index if not exists portal_feedback_t on portal_feedback (tenant_id, imported);
alter table portal_feedback enable row level security;
drop policy if exists portal_feedback_read on portal_feedback;
create policy portal_feedback_read on portal_feedback for select using (is_member(tenant_id));

create or replace function portal_feedback_send(p_token text, p_score int, p_text text) returns boolean
language plpgsql security definer set search_path = public as $$
declare k record;
begin
  if length(coalesce(p_token, '')) <> 32 then return false; end if;
  select * into k from portal_links where token = p_token and not revoked and expires_at > now();
  if k.token is null then return false; end if;
  if p_score is null or p_score < 0 or p_score > 10 then raise exception 'FYF_BAD_DATA'; end if;
  if length(coalesce(p_text, '')) > 1500 then raise exception 'FYF_TOO_LONG'; end if;
  if (select count(*) from portal_feedback where token = p_token and created_at > now() - interval '1 day') >= 3 then raise exception 'FYF_RATE'; end if;
  insert into portal_feedback(token, tenant_id, customer_id, score, body) values (p_token, k.tenant_id, k.customer_id, p_score, nullif(trim(coalesce(p_text, '')), ''));
  return true;
end $$;

create or replace function portal_feedback_take(p_tenant uuid) returns setof portal_feedback
language plpgsql security definer set search_path = public as $$
begin
  if not is_member(p_tenant) then raise exception 'FYF_DENIED'; end if;
  return query update portal_feedback set imported = true where tenant_id = p_tenant and not imported returning *;
end $$;

revoke all on function portal_feedback_take(uuid) from public, anon;
grant execute on function portal_feedback_take(uuid) to authenticated;
grant execute on function portal_feedback_send(text, int, text) to anon, authenticated;
