-- 0130_realtime_contact_events.sql
-- contact_events in die Realtime-Publication aufnehmen, damit das Kontakt-Detail
-- die Timeline live aktualisiert — vor allem eingehende Nachrichten, die
-- serverseitig per Webhook (comms-inbound) eingefügt werden und die der Client
-- sonst erst nach Reload sieht.
-- RLS (contact_events_owner / is_contact_owner) gilt weiterhin: Realtime liefert
-- einem Client nur Zeilen, die er per SELECT-Policy sehen darf.
alter publication supabase_realtime add table public.contact_events;
