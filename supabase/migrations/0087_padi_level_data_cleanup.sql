-- 0087: Daten-Cleanup für padi_level
--
-- Hintergrund:
--   Migration 0001 legte 5 Werte an: 'Instructor', 'Staff Instructor', 'DM',
--   'Shop Staff', 'Andere Funktion'.
--   Migration 0029 ergänzte die granulareren PADI-Profi-Stufen:
--   'AI', 'OWSI', 'MSDT', 'MI', 'CD' und ein generisches 'Andere'.
--   Migration 0033 ergänzte 'IDC Staff'.
--
-- Sauberer Ziel-Set für die App:
--   DM, AI, OWSI, MSDT, IDC Staff, MI, CD, Shop Staff, Andere Funktion
--
-- Mapping der Legacy-/Doppel-Werte:
--   'Instructor'       → 'OWSI'              (Standard-Instructor-Level)
--   'Staff Instructor' → 'IDC Staff'         (granulareres Pendant)
--   'Andere'           → 'Andere Funktion'   (existierte parallel — vereinheitlichen)
--
-- Hinweis: Postgres erlaubt kein DROP VALUE auf einem Enum ohne Recreate.
-- Wir lassen die Legacy-Enum-Werte in der DB-Definition — sind nach dem
-- UPDATE einfach nicht mehr in den Daten referenziert. Saubereres
-- Enum-Recreate könnte später als separate Migration laufen.

-- ────────────────────────────────────────────────────────────────────────────
-- contact_instructor.padi_level
-- ────────────────────────────────────────────────────────────────────────────
UPDATE public.contact_instructor SET padi_level = 'OWSI'
  WHERE padi_level = 'Instructor';

UPDATE public.contact_instructor SET padi_level = 'IDC Staff'
  WHERE padi_level = 'Staff Instructor';

UPDATE public.contact_instructor SET padi_level = 'Andere Funktion'
  WHERE padi_level = 'Andere';

-- ────────────────────────────────────────────────────────────────────────────
-- instructors (Legacy-Tabelle, durch Sync-Trigger an contact_instructor gekoppelt
-- — direkt updaten ist sicher, der Trigger spiegelt die Werte)
-- ────────────────────────────────────────────────────────────────────────────
UPDATE public.instructors SET padi_level = 'OWSI'
  WHERE padi_level = 'Instructor';

UPDATE public.instructors SET padi_level = 'IDC Staff'
  WHERE padi_level = 'Staff Instructor';

UPDATE public.instructors SET padi_level = 'Andere Funktion'
  WHERE padi_level = 'Andere';

-- ────────────────────────────────────────────────────────────────────────────
-- contact_student.candidate_target_level (gleicher Enum-Typ)
-- ────────────────────────────────────────────────────────────────────────────
UPDATE public.contact_student SET candidate_target_level = 'OWSI'
  WHERE candidate_target_level = 'Instructor';

UPDATE public.contact_student SET candidate_target_level = 'IDC Staff'
  WHERE candidate_target_level = 'Staff Instructor';

UPDATE public.contact_student SET candidate_target_level = 'Andere Funktion'
  WHERE candidate_target_level = 'Andere';

-- ────────────────────────────────────────────────────────────────────────────
-- comp_rates.level (referenziert padi_level)
-- ────────────────────────────────────────────────────────────────────────────
UPDATE public.comp_rates SET level = 'OWSI'
  WHERE level = 'Instructor';

UPDATE public.comp_rates SET level = 'IDC Staff'
  WHERE level = 'Staff Instructor';

UPDATE public.comp_rates SET level = 'Andere Funktion'
  WHERE level = 'Andere';

-- ────────────────────────────────────────────────────────────────────────────
-- Sanity-Check (optional — als ASSERT würde es die Migration abbrechen wenn
-- ungemappte Werte übrig bleiben; hier als RAISE NOTICE für Soft-Live)
-- ────────────────────────────────────────────────────────────────────────────
DO $$
DECLARE
  legacy_count INT;
BEGIN
  SELECT COUNT(*) INTO legacy_count
  FROM public.contact_instructor
  WHERE padi_level IN ('Instructor', 'Staff Instructor', 'Andere');
  IF legacy_count > 0 THEN
    RAISE NOTICE 'Warnung: % contact_instructor-Zeilen haben noch Legacy-padi_level', legacy_count;
  END IF;
END $$;
