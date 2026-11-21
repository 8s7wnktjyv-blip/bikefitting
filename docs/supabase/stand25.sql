-- FYF – Stand 25 (21.11.2026): Rechte auf dem Server (Weg A „Rollen-Filter“).
-- Problem bisher: Jedes Team-Mitglied konnte den kompletten Datenblock des Ladens lesen.
-- Jetzt:
--  * Lesen nur noch über state_get(). Die Rolle „mitarbeiter“ bekommt keine Rechnungen, Zahlungen, Verkäufe,
--    Bestellungen, Lieferanten, DATEV- und Mahn-Einstellungen. Körper-/Gesundheitsdaten der Kunden bleiben sichtbar
--    (Entscheidung Inhaber 21.11.2026).
--  * Direktes Lesen der Tabelle tenant_state nur noch für Admin und Fitter.
--  * save_state(): Für „mitarbeiter“ bleiben die verborgenen Teile auf dem Server unverändert. Neue Zahlungen und
--    Verkäufe (z. B. Kasse bei Abholung) werden angehängt, alte kann ein Mitarbeiter weder ändern noch löschen.
--  * Rückweg: fyf_hidden_keys() leer zurückgeben lassen → Verhalten wie vorher.
create or replace function fyf_hidden_keys(p_role text) returns text[]
language sql immutable as $$
  select case when p_role = 'mitarbeiter'
    then array['invoices','invSeq','payments','sales','purchaseOrders','suppliers','datev','dunCfg']
    else array[]::text[] end;
$$;
-- Teile, an die ein Mitarbeiter nur anhängen darf (Einträge mit neuer id)
create or replace function fyf_append_keys() returns text[] language sql immutable as $$ select array['payments','sales']; $$;

create or replace function state_get(p_tenant uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare r text; t tenant_state; h text[];
begin
  if auth.uid() is null then raise exception 'FYF_DENIED'; end if;
  select role into r from memberships where user_id = auth.uid() and tenant_id = p_tenant;
  if r is null then raise exception 'FYF_DENIED'; end if;
  select * into t from tenant_state where tenant_id = p_tenant;
  if t.tenant_id is null then return null; end if;
  h := fyf_hidden_keys(r);
  return jsonb_build_object('version', t.version, 'updated_at', t.updated_at, 'role', r, 'hidden', to_jsonb(h), 'data', t.data - h);
end $$;
revoke all on function state_get(uuid) from public, anon;
grant execute on function state_get(uuid) to authenticated;

-- Verborgene Teile aus dem alten Stand übernehmen; bei Anhäng-Teilen neue Einträge (neue id) ergänzen.
create or replace function fyf_merge_hidden(p_role text, p_old jsonb, p_new jsonb) returns jsonb
language plpgsql immutable as $$
declare k text; n jsonb := p_new; oldarr jsonb; add jsonb;
begin
  foreach k in array fyf_hidden_keys(p_role) loop
    if k = any(fyf_append_keys()) then
      oldarr := coalesce(p_old -> k, '[]'::jsonb);
      if jsonb_typeof(oldarr) <> 'array' then oldarr := '[]'::jsonb; end if;
      select coalesce(jsonb_agg(x), '[]'::jsonb) into add
        from jsonb_array_elements(case when jsonb_typeof(p_new -> k) = 'array' then p_new -> k else '[]'::jsonb end) x
        where x ? 'id' and not exists (select 1 from jsonb_array_elements(oldarr) o where o ->> 'id' = x ->> 'id');
      n := jsonb_set(n, array[k], add || oldarr);
    elsif p_old ? k then
      n := jsonb_set(n, array[k], p_old -> k);
    else
      n := n - k;
    end if;
  end loop;
  return n;
end $$;

create or replace function save_state(p_tenant uuid, p_data jsonb, p_expected int) returns int
language plpgsql security definer set search_path = public as $$
declare v int; r text; old jsonb; why text; d jsonb := p_data;
begin
  if auth.uid() is null then raise exception 'FYF_DENIED'; end if;
  select role into r from memberships where user_id = auth.uid() and tenant_id = p_tenant;
  if r is null then raise exception 'FYF_DENIED'; end if;
  if d is null or jsonb_typeof(d) <> 'object' then raise exception 'FYF_BAD_DATA'; end if;
  select version, data into v, old from tenant_state where tenant_id = p_tenant for update;
  if v is null then
    if coalesce(p_expected, 0) <> 0 then raise exception 'FYF_CONFLICT 0'; end if;
    if r = 'mitarbeiter' then raise exception 'FYF_ROLE Den ersten Stand legt Admin oder Fitter an'; end if;
    insert into tenant_state(tenant_id, data, version, updated_by) values (p_tenant, d, 1, auth.uid());
    perform fyf_audit(p_tenant, 'save', jsonb_build_object('version', 1));
    return 1;
  end if;
  if p_expected is distinct from v then raise exception 'FYF_CONFLICT %', v; end if;
  d := fyf_merge_hidden(r, old, d);
  why := fyf_guard(r, old, d);
  if why is not null then raise exception 'FYF_ROLE %', why; end if;
  insert into tenant_state_history(tenant_id, version, data, saved_by)
    select tenant_id, version, data, updated_by from tenant_state where tenant_id = p_tenant;
  delete from tenant_state_history h where h.tenant_id = p_tenant
    and h.id not in (select id from tenant_state_history where tenant_id = p_tenant order by version desc limit 30);
  update tenant_state set data = d, version = v + 1, updated_at = now(), updated_by = auth.uid() where tenant_id = p_tenant;
  perform fyf_audit(p_tenant, 'save', jsonb_build_object('version', v + 1));
  return v + 1;
end $$;
revoke all on function save_state(uuid, jsonb, int) from public, anon;
grant execute on function save_state(uuid, jsonb, int) to authenticated;

drop policy if exists state_read on tenant_state;
create policy state_read on tenant_state for select using (has_role(tenant_id, array['admin','fitter']));
