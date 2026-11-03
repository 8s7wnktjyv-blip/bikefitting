-- FYF – Fit your Frame · Cloud-Speicher für Fotos und Videos (Schritt 2)
-- Voraussetzung: start.sql wurde schon ausgeführt.
-- Ausführen: Supabase → SQL Editor → diesen Text einfügen → Run. Mehrfach ausführen schadet nicht.
--
-- Was das macht
-- * Legt den privaten Speicher „media“ an (nicht öffentlich, max. 50 MB je Datei – Grenze im Free-Plan).
-- * Dateien liegen unter <Laden-ID>/<Datei-ID>. Zugriff nur für angemeldete Mitglieder dieses Ladens.
-- * Löschen dürfen nur Admin und Fitter (wie in der App).

insert into storage.buckets (id, name, public, file_size_limit)
values ('media', 'media', false, 52428800)
on conflict (id) do update set public = false, file_size_limit = 52428800;

create or replace function public.fyf_media_member(p_folder text) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from memberships m where m.user_id = auth.uid() and m.tenant_id::text = p_folder);
$$;

create or replace function public.fyf_media_can_delete(p_folder text) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from memberships m where m.user_id = auth.uid() and m.tenant_id::text = p_folder and m.role in ('admin','fitter'));
$$;

revoke all on function public.fyf_media_member(text) from public, anon;
revoke all on function public.fyf_media_can_delete(text) from public, anon;
grant execute on function public.fyf_media_member(text) to authenticated;
grant execute on function public.fyf_media_can_delete(text) to authenticated;

drop policy if exists fyf_media_read on storage.objects;
create policy fyf_media_read on storage.objects for select to authenticated
  using (bucket_id = 'media' and public.fyf_media_member((storage.foldername(name))[1]));

drop policy if exists fyf_media_insert on storage.objects;
create policy fyf_media_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'media' and public.fyf_media_member((storage.foldername(name))[1]));

drop policy if exists fyf_media_update on storage.objects;
create policy fyf_media_update on storage.objects for update to authenticated
  using (bucket_id = 'media' and public.fyf_media_member((storage.foldername(name))[1]))
  with check (bucket_id = 'media' and public.fyf_media_member((storage.foldername(name))[1]));

drop policy if exists fyf_media_delete on storage.objects;
create policy fyf_media_delete on storage.objects for delete to authenticated
  using (bucket_id = 'media' and public.fyf_media_can_delete((storage.foldername(name))[1]));
