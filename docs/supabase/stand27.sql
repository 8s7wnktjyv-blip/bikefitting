-- FYF – Stand 27 (21.11.2026): Kündigung eines Ladens (Freigabe Dominik 21.11.2026, Plan docs/KUENDIGUNG-PLAN.md).
-- Regel: Kündigt ein Laden, bleiben die Pass-Einträge erhalten. Der Laden sieht danach nichts mehr.
-- 1. Pässe schützen: Wird ein Laden gelöscht, bleibt jeder von ihm ausgestellte Pass mit allen Einträgen erhalten
--    (bisher löschte die Datenbank Pass und Einträge mit). Der Pass hat dann keinen ausstellenden Laden mehr.
-- 2. Kündigung als Status: tenant_close() (nur Plattform-Admin) schließt den Laden statt ihn zu löschen:
--    Mitgliedschaften, offene Einladungen und Kopplungscodes werden gesichert und entfernt → jede Rechteprüfung
--    (is_member, has_role, state_get, …) sagt „nein“. Öffentliches Profil aus, aktive Börsen-Angebote beendet.
--    Neue Mitgliedschaften in einem geschlossenen Laden sind gesperrt. Daten des Ladens bleiben auf dem Server
--    (Aufbewahrungspflicht, Wiederöffnung). tenant_reopen() stellt alles wieder her.
-- Mehrfach ausführen schadet nicht.

-- ---------- 1. Pässe bleiben, wenn ein Laden gelöscht wird ----------
do $$ begin
  if exists (select 1 from pg_constraint where conname = 'bike_passes_tenant_id_fkey' and confdeltype = 'c') then
    alter table bike_passes drop constraint bike_passes_tenant_id_fkey;
    alter table bike_passes add constraint bike_passes_tenant_id_fkey foreign key (tenant_id) references tenants(id) on delete set null;
  end if;
end $$;

-- ---------- 2. Laden schließen / wieder öffnen ----------
alter table tenants add column if not exists closed_at timestamptz;
alter table tenants add column if not exists closed_reason text;

create table if not exists tenant_closed_backup (
  tenant_id uuid primary key references tenants(id) on delete cascade,
  members jsonb not null default '[]'::jsonb,
  invites jsonb not null default '[]'::jsonb,
  was_published boolean not null default false,
  offers jsonb not null default '[]'::jsonb,
  closed_by uuid,
  closed_at timestamptz not null default now()
);
alter table tenant_closed_backup enable row level security;   -- keine Policy: nur über die Funktionen unten

create or replace function fyf_block_closed_member() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if exists (select 1 from tenants where id = new.tenant_id and closed_at is not null) then raise exception 'FYF_CLOSED'; end if;
  return new;
end $$;
drop trigger if exists memberships_block_closed on memberships;
create trigger memberships_block_closed before insert or update on memberships for each row execute function fyf_block_closed_member();
drop trigger if exists invitations_block_closed on invitations;
create trigger invitations_block_closed before insert or update on invitations for each row execute function fyf_block_closed_member();

create or replace function tenant_close(p_tenant uuid, p_reason text) returns void
language plpgsql security definer set search_path = public as $$
declare m jsonb; i jsonb; pub boolean; o jsonb;
begin
  if not is_platform_admin() then raise exception 'FYF_DENIED'; end if;
  if not exists (select 1 from tenants where id = p_tenant) then raise exception 'FYF_NOT_FOUND'; end if;
  if (select closed_at from tenants where id = p_tenant) is not null then raise exception 'FYF_ALREADY_CLOSED'; end if;
  select coalesce(jsonb_agg(jsonb_build_object('user_id', user_id, 'role', role, 'label', label)), '[]'::jsonb) into m from memberships where tenant_id = p_tenant;
  select coalesce(jsonb_agg(jsonb_build_object('email', email, 'role', role)), '[]'::jsonb) into i from invitations where tenant_id = p_tenant and accepted_at is null;
  select coalesce(published, false) into pub from dealer_profiles where tenant_id = p_tenant;
  select coalesce(jsonb_agg(jsonb_build_object('id', id, 'status', status)), '[]'::jsonb) into o from trade_offers where tenant_id = p_tenant and status in ('aktiv','reserviert');
  insert into tenant_closed_backup(tenant_id, members, invites, was_published, offers, closed_by, closed_at)
    values (p_tenant, m, i, coalesce(pub, false), o, auth.uid(), now())
    on conflict (tenant_id) do update set members = excluded.members, invites = excluded.invites, was_published = excluded.was_published,
      offers = excluded.offers, closed_by = excluded.closed_by, closed_at = excluded.closed_at;
  update tenants set closed_at = now(), closed_reason = left(nullif(trim(coalesce(p_reason, '')), ''), 300) where id = p_tenant;
  delete from memberships where tenant_id = p_tenant;
  delete from invitations where tenant_id = p_tenant and accepted_at is null;
  delete from pair_codes where tenant_id = p_tenant and used_at is null;
  update dealer_profiles set published = false where tenant_id = p_tenant;
  update trade_offers set status = 'beendet' where tenant_id = p_tenant and status in ('aktiv','reserviert');
  perform fyf_audit(p_tenant, 'tenant_close', jsonb_build_object('members', jsonb_array_length(m), 'reason', p_reason));
end $$;

create or replace function tenant_reopen(p_tenant uuid) returns int
language plpgsql security definer set search_path = public as $$
declare b tenant_closed_backup; x jsonb; n int := 0;
begin
  if not is_platform_admin() then raise exception 'FYF_DENIED'; end if;
  if (select closed_at from tenants where id = p_tenant) is null then raise exception 'FYF_NOT_CLOSED'; end if;
  select * into b from tenant_closed_backup where tenant_id = p_tenant;
  update tenants set closed_at = null, closed_reason = null where id = p_tenant;
  if b.tenant_id is not null then
    for x in select * from jsonb_array_elements(b.members) loop
      -- eine Person gehört zu genau einem Laden: ist sie inzwischen woanders, bleibt sie dort
      if not exists (select 1 from memberships where user_id = (x->>'user_id')::uuid) and exists (select 1 from auth.users where id = (x->>'user_id')::uuid) then
        insert into memberships(user_id, tenant_id, role, label) values ((x->>'user_id')::uuid, p_tenant, x->>'role', x->>'label'); n := n + 1;
      end if;
    end loop;
    for x in select * from jsonb_array_elements(b.invites) loop
      insert into invitations(tenant_id, email, role) values (p_tenant, x->>'email', x->>'role') on conflict (tenant_id, email) do nothing;
    end loop;
    if b.was_published then update dealer_profiles set published = true where tenant_id = p_tenant; end if;
    for x in select * from jsonb_array_elements(b.offers) loop
      update trade_offers set status = x->>'status' where id = (x->>'id')::uuid and status = 'beendet';
    end loop;
    delete from tenant_closed_backup where tenant_id = p_tenant;
  end if;
  perform fyf_audit(p_tenant, 'tenant_reopen', jsonb_build_object('members', n));
  return n;
end $$;

-- Für die Plattform-Verwaltung: welche Läden sind geschlossen
create or replace function platform_closed() returns table(id uuid, closed_at timestamptz, closed_reason text)
language sql stable security definer set search_path = public as $$
  select t.id, t.closed_at, t.closed_reason from tenants t where t.closed_at is not null and is_platform_admin() $$;

-- Für die App: War ich Mitglied eines Ladens, der geschlossen wurde?
create or replace function my_closed_shop() returns table(name text, closed_at timestamptz)
language sql stable security definer set search_path = public as $$
  select t.name, t.closed_at from tenant_closed_backup b join tenants t on t.id = b.tenant_id
  where t.closed_at is not null and b.members @> jsonb_build_array(jsonb_build_object('user_id', auth.uid()::text))
  order by t.closed_at desc limit 1 $$;

revoke all on function tenant_close(uuid, text), tenant_reopen(uuid), platform_closed(), my_closed_shop() from public, anon;
grant execute on function tenant_close(uuid, text), tenant_reopen(uuid), platform_closed(), my_closed_shop() to authenticated;
revoke all on function fyf_block_closed_member() from public, anon, authenticated;
