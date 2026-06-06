-- 20260606000300_seed_walk_in_contact.sql
-- Laufkundschaft-Sammelkontakt fuer den Theken-POS. pos_checkout verlangt eine
-- contact_id; Barverkaeufe ohne Kundenkonto werden auf diesen Kontakt gebucht.
-- Markiert per Tag 'walk_in'; das Frontend loest die ID darueber auf. Idempotent
-- (legt nur an, wenn noch keiner existiert). contacts ist aktuell effektiv
-- single-tenant (TSK) -> ein Eintrag genuegt.
INSERT INTO public.contacts (kind, first_name, last_name, tags, source)
SELECT 'person', 'Laufkundschaft', '(Theke)', ARRAY['walk_in'], 'pos_seed'
WHERE NOT EXISTS (SELECT 1 FROM public.contacts WHERE 'walk_in' = ANY(tags));
