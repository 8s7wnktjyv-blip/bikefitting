-- FYF – Stand 18 (Freigabe Dominik 15.11.2026)
-- 1) Cloud-Sicherung für die Pass-App ohne E-Mail: Der Kunde bekommt einen Sicherungscode. Die Daten werden IM HANDY
--    damit verschlüsselt (AES-GCM). Der Server sieht nur verschlüsselten Text und einen Prüfwert – nie den Code.
-- 2) Werkstatt-Status im Pass: Der Besitzer (mit Teil-II-Code) sieht laufende Werkstattaufträge zu seinem Rad.
--    Nur Status, Titel, Termin und Laden – keine Preise, keine Mitarbeiternamen.
-- Mehrfach ausführen schadet nicht.

create table if not exists pass_vault (
  id_hash text primary key check (id_hash ~ '^[0-9a-f]{64}$'),
  blob text not null,
  size int not null,
  ver int not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table pass_vault enable row level security;   -- keine Policy: nur über die Funktionen unten
revoke all on pass_vault from anon, authenticated;

-- p_id = Prüfwert aus dem Handy (64 hex). Gespeichert wird nur sha256(p_id).
create or replace function vault_get(p_id text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v pass_vault; h text;
begin
  if p_id !~ '^[0-9a-f]{64}$' then return jsonb_build_object('error', 'FYF_BAD_ID'); end if;
  h := encode(sha256(convert_to(p_id, 'UTF8')), 'hex');
  select * into v from pass_vault where id_hash = h;
  if v.id_hash is null then return jsonb_build_object('error', 'FYF_NOT_FOUND'); end if;
  return jsonb_build_object('blob', v.blob, 'ver', v.ver, 'updated_at', v.updated_at);
end $$;

create or replace function vault_head(p_id text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v pass_vault; h text;
begin
  if p_id !~ '^[0-9a-f]{64}$' then return jsonb_build_object('error', 'FYF_BAD_ID'); end if;
  h := encode(sha256(convert_to(p_id, 'UTF8')), 'hex');
  select * into v from pass_vault where id_hash = h;
  if v.id_hash is null then return jsonb_build_object('error', 'FYF_NOT_FOUND'); end if;
  return jsonb_build_object('ver', v.ver, 'updated_at', v.updated_at, 'size', v.size);
end $$;

-- p_ver = Version, auf der das Handy aufbaut (0 = neu). Passt sie nicht, wurde inzwischen woanders gespeichert → FYF_CONFLICT.
create or replace function vault_put(p_id text, p_blob text, p_ver int) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v pass_vault; h text; n int := length(coalesce(p_blob, ''));
begin
  if p_id !~ '^[0-9a-f]{64}$' then return jsonb_build_object('error', 'FYF_BAD_ID'); end if;
  if n < 20 or n > 4000000 then return jsonb_build_object('error', 'FYF_TOO_BIG'); end if;
  if p_blob !~ '^v1\.[A-Za-z0-9+/=]+\.[A-Za-z0-9+/=]+$' then return jsonb_build_object('error', 'FYF_BAD_BLOB'); end if;
  h := encode(sha256(convert_to(p_id, 'UTF8')), 'hex');
  select * into v from pass_vault where id_hash = h for update;
  if v.id_hash is null then
    if (select coalesce(sum(size), 0) from pass_vault) > 400000000 then return jsonb_build_object('error', 'FYF_FULL'); end if;
    if (select count(*) from pass_vault where created_at > now() - interval '1 hour') > 300 then return jsonb_build_object('error', 'FYF_RATE'); end if;
    insert into pass_vault(id_hash, blob, size) values (h, p_blob, n);
    return jsonb_build_object('ver', 1, 'updated_at', now());
  end if;
  if coalesce(p_ver, 0) <> v.ver then return jsonb_build_object('error', 'FYF_CONFLICT', 'ver', v.ver, 'updated_at', v.updated_at); end if;
  update pass_vault set blob = p_blob, size = n, ver = v.ver + 1, updated_at = now() where id_hash = h;
  return jsonb_build_object('ver', v.ver + 1, 'updated_at', now());
end $$;

create or replace function vault_delete(p_id text) returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  if p_id !~ '^[0-9a-f]{64}$' then return jsonb_build_object('error', 'FYF_BAD_ID'); end if;
  delete from pass_vault where id_hash = encode(sha256(convert_to(p_id, 'UTF8')), 'hex');
  return jsonb_build_object('ok', true);
end $$;
revoke all on function vault_get(text), vault_head(text), vault_put(text, text, int), vault_delete(text) from public;
grant execute on function vault_get(text), vault_head(text), vault_put(text, text, int), vault_delete(text) to anon, authenticated;

-- Werkstattaufträge zu einem Pass (aus dem Spiegel work_orders/bikes, Stand 17)
create or replace function fyf_pass_workshop(c text) returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object('shop', t.name, 'title', w.title, 'status', w.status, 'due', w.due,
           'since', w.created_at, 'done', w.done_at, 'approval', w.status = 'Freigabe ausstehend') order by w.created_at desc), '[]'::jsonb)
    from work_orders w join bikes b on b.id = w.bike_id join tenants t on t.id = w.tenant_id
   where b.pass_code = c and w.status <> 'Storniert'
     and (w.done_at is null or w.done_at > now() - interval '14 days') and w.created_at > now() - interval '120 days';
$$;
revoke all on function fyf_pass_workshop(text) from public, anon, authenticated;

create or replace function pass_get_owner(p_code text, p_transfer text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare k record; c text := upper(regexp_replace(coalesce(p_code, ''), '[^A-Za-z0-9]', '', 'g')); t text := upper(regexp_replace(coalesce(p_transfer, ''), '[^A-Za-z0-9]', '', 'g')); sh text;
begin
  select * into k from bike_passes where code = c;
  if k.code is null or k.withdrawn_at is not null then return jsonb_build_object('error', 'FYF_NOT_FOUND'); end if;
  if k.owner_fails >= 10 and k.owner_fail_at > now() - interval '1 day' then return jsonb_build_object('error', 'FYF_RATE'); end if;
  if k.transfer_hash is null or encode(sha256(convert_to(t, 'UTF8')), 'hex') <> k.transfer_hash then
    update bike_passes set owner_fails = case when owner_fail_at > now() - interval '1 day' then owner_fails + 1 else 1 end, owner_fail_at = now() where code = c;
    return jsonb_build_object('error', 'FYF_BAD_TRANSFER');
  end if;
  select name into sh from tenants where id = k.tenant_id;
  return k.payload || jsonb_build_object('shop', coalesce(k.payload->'shop', '{}'::jsonb) || jsonb_build_object('name', coalesce(nullif(k.payload->'shop'->>'name', ''), sh)),
    'code', c, 'limited', false, 'owner_view', true, 'stolen', coalesce(k.owner_stolen, k.stolen), 'visibility', coalesce(k.owner_vis, k.visibility), 'updated_at', k.updated_at, 'created_at', k.created_at,
    'owner_no', k.owner_no, 'owner_since', k.owner_since, 'withdrawn', false, 'self', k.tenant_id is null,
    'entries', coalesce((select jsonb_agg(jsonb_build_object('id', e.id, 'shop', e.shop, 'kind', e.kind, 'text', e.body, 'km', e.km, 'date', e.done_on,
                           'trust', e.trust, 'receipt', e.receipt, 'corrects', e.corrects, 'at', e.created_at) order by e.done_on desc, e.id desc)
                         from bike_pass_entries e where e.code = c), '[]'::jsonb),
    'workshop', fyf_pass_workshop(c));
end $$;
revoke all on function pass_get_owner(text, text) from public;
grant execute on function pass_get_owner(text, text) to anon, authenticated;
