-- FYF – Fit your Frame · Geräte per Code koppeln (Schritt 6)
-- Voraussetzung: start.sql und team.sql wurden schon ausgeführt.
-- Zusätzlich in Supabase einschalten: Authentication → Sign In / Providers → „Allow anonymous sign-ins“.
-- Ausführen: Supabase → SQL Editor → diesen Text einfügen → Run. Mehrfach ausführen schadet nicht.
--
-- Was das macht
-- * Ein angemeldetes Gerät erzeugt einen Kopplungscode (8 Zeichen, 10 Minuten gültig, nur einmal nutzbar).
-- * Das neue Gerät meldet sich ohne E-Mail als „Gerät“ an und löst den Code ein. Es wird Mitglied des Ladens
--   mit derselben Rolle wie das Gerät, das den Code erzeugt hat.
-- * Geräte erscheinen im Team als „Gerät: …“ und können vom Admin entfernt werden.
-- * Schutz: höchstens 5 falsche Versuche je Gerät in 10 Minuten. Falscher Code liefert null.

alter table memberships add column if not exists label text;

create table if not exists pair_codes (
  code text primary key,
  tenant_id uuid not null references tenants(id) on delete cascade,
  role text not null,
  created_by uuid,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '10 minutes',
  used_at timestamptz,
  used_by uuid
);
create table if not exists pair_attempts (user_id uuid not null, at timestamptz not null default now());
alter table pair_codes enable row level security;
alter table pair_attempts enable row level security;

create or replace function pair_create() returns text
language plpgsql security definer set search_path = public as $$
declare m record; a text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; b bytea := decode(replace(gen_random_uuid()::text, '-', ''), 'hex'); c text := ''; i int;
begin
  select tenant_id, role into m from memberships where user_id = auth.uid() limit 1;
  if m.tenant_id is null then raise exception 'FYF_DENIED'; end if;
  for i in 0..7 loop c := c || substr(a, (get_byte(b, i) % 32) + 1, 1); end loop;
  delete from pair_codes where created_by = auth.uid() and used_at is null;
  delete from pair_codes where expires_at < now() - interval '1 day';
  insert into pair_codes(code, tenant_id, role, created_by) values (c, m.tenant_id, m.role, auth.uid());
  perform fyf_audit(m.tenant_id, 'pair_create', jsonb_build_object('role', m.role));
  return c;
end $$;

create or replace function pair_redeem(p_code text, p_label text) returns uuid
language plpgsql security definer set search_path = public as $$
declare c text := upper(regexp_replace(coalesce(p_code, ''), '[^A-Za-z0-9]', '', 'g')); p record; t uuid;
begin
  if auth.uid() is null then raise exception 'FYF_DENIED'; end if;
  select tenant_id into t from memberships where user_id = auth.uid() limit 1;
  if t is not null then return t; end if;
  if (select count(*) from pair_attempts where user_id = auth.uid() and at > now() - interval '10 minutes') >= 5 then raise exception 'FYF_RATE'; end if;
  select * into p from pair_codes where code = c and used_at is null and expires_at > now() for update;
  if p.code is null then insert into pair_attempts(user_id) values (auth.uid()); return null; end if;  -- falscher Code: null (Versuch bleibt gezählt)
  insert into memberships(user_id, tenant_id, role, label) values (auth.uid(), p.tenant_id, p.role, left(coalesce(nullif(trim(p_label), ''), 'Gerät'), 40));
  update pair_codes set used_at = now(), used_by = auth.uid() where code = c;
  perform fyf_audit(p.tenant_id, 'pair_join', jsonb_build_object('role', p.role, 'label', p_label));
  return p.tenant_id;
end $$;

-- Team-Liste: Geräte ohne E-Mail mit ihrem Namen zeigen
create or replace function list_members(p_tenant uuid) returns table(user_id uuid, email text, role text, is_me boolean)
language sql stable security definer set search_path = public, auth as $$
  select m.user_id, coalesce(u.email::text, 'Gerät: ' || coalesce(m.label, 'ohne Namen')), m.role, m.user_id = auth.uid()
  from memberships m join auth.users u on u.id = m.user_id
  where m.tenant_id = p_tenant and is_member(p_tenant)
  order by (m.role = 'admin') desc, u.email nulls last;
$$;

revoke all on function pair_create() from public, anon;
revoke all on function pair_redeem(text, text) from public, anon;
grant execute on function pair_create(), pair_redeem(text, text) to authenticated;
