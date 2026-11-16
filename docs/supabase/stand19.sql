-- FYF – Stand 19 (16.11.2026): Gebuchte freie Zeit sofort sperren.
-- Wählt jemand in der Händlersuche eine „freie Zeit“, wird sie beim Absenden aus den veröffentlichten Zeiten entfernt.
-- So kann dieselbe Uhrzeit nicht zweimal angefragt werden, auch bevor der Laden die App öffnet.
-- Format von preferred (aus finder.html): "Fr., 20.11.2026 09:00 (freie Zeit)". Mehrfach ausführen schadet nicht.

create or replace function fyf_slot_take() returns trigger
language plpgsql security definer set search_path = public as $$
declare m text[]; d text; t text;
begin
  begin
    if new.preferred is null or new.preferred not like '%(freie Zeit)%' then return new; end if;
    m := regexp_match(new.preferred, '(\d{2})\.(\d{2})\.(\d{4})\D+(\d{2}:\d{2})');
    if m is null then return new; end if;
    d := m[3] || '-' || m[2] || '-' || m[1]; t := m[4];
    update dealer_profiles p
       set slots = coalesce((
             select jsonb_agg(case when e->>'d' = d
                                   then jsonb_set(e, '{t}', coalesce((select jsonb_agg(x) from jsonb_array_elements(e->'t') x where x #>> '{}' <> t), '[]'::jsonb))
                                   else e end)
               from jsonb_array_elements(p.slots) e), '[]'::jsonb)
     where p.tenant_id = new.tenant_id and jsonb_typeof(p.slots) = 'array';
  exception when others then
    raise warning 'FYF Slot nicht gesperrt (%): %', sqlstate, sqlerrm;
  end;
  return new;
end $$;

drop trigger if exists fyf_slot_take_t on inquiries;
create trigger fyf_slot_take_t after insert on inquiries for each row execute function fyf_slot_take();
