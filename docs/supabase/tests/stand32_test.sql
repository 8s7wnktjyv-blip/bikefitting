-- Test für Stand 32 (Marktplatz: Bild und Anbieter je Artikel)
-- Lokal mit Postgres 16 prüfen, z. B.:
--   createdb fyf_test && psql -d fyf_test -f docs/supabase/alles.sql -f docs/supabase/tests/stand32_test.sql
-- Erwartet: alle Prüfungen melden ok, kein Fehler.

-- 1) Spalten vorhanden
do $$ begin
  if not exists (select 1 from information_schema.columns where table_name = 'fyf_products' and column_name = 'img') then
    raise exception 'Spalte fyf_products.img fehlt';
  end if;
  if not exists (select 1 from information_schema.columns where table_name = 'fyf_products' and column_name = 'seller') then
    raise exception 'Spalte fyf_products.seller fehlt';
  end if;
  raise notice 'ok 1: Spalten img und seller vorhanden';
end $$;

-- 2) Öffentliche Ansicht liefert img, seller, seller_ref
do $$ begin
  if not exists (select 1 from information_schema.columns where table_name = 'public_products' and column_name = 'img') then
    raise exception 'public_products.img fehlt';
  end if;
  if not exists (select 1 from information_schema.columns where table_name = 'public_products' and column_name = 'seller') then
    raise exception 'public_products.seller fehlt';
  end if;
  raise notice 'ok 2: public_products mit img und seller';
end $$;

-- 3) Trigger übernimmt Bild und Auftritt aus dem Stand
do $$
declare t uuid; n integer;
begin
  insert into auth.users (id, email) values (gen_random_uuid(), 'stand32@test.local') returning id into t;
  insert into tenants (id, name) values (t, 'Testladen Stand 32') on conflict (id) do nothing;
  insert into dealer_profiles (tenant_id, slug, published, name)
    values (t, 'stand32-test', true, 'Testladen Stand 32') on conflict (tenant_id) do update set published = true;
  insert into tenant_state (tenant_id, data) values (t, jsonb_build_object('products', jsonb_build_array(
      jsonb_build_object('id','m1','cat','Laufräder','name','g50 Carbol Laufradsatz','price',790,'pub',true,
        'note','Marke: Cunima bikeparts · Gewicht 1420 g','img','data:image/jpeg;base64,AAAA','actName','Cunima bikeparts','act','loc:1'))))
    on conflict (tenant_id) do update set data = excluded.data;
  select count(*) into n from public_products where slug = 'stand32-test' and seller = 'Cunima bikeparts' and img is not null;
  if n <> 1 then raise exception 'Produkt mit Bild und Anbieter fehlt in public_products (%)', n; end if;
  raise notice 'ok 3: Bild und Anbieter kommen im Marktplatz an';
  delete from tenants where id = t;
end $$;
