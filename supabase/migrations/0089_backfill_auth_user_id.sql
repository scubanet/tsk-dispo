-- 0089: Hotfix-Backfill für contact_instructor.auth_user_id
--
-- Problem:
--   Migration 0082 (contacts_backfill) hat auth_user_id NICHT in den Sidecar
--   übernommen. Der 0083-Sync-Trigger setzt es nur bei INSERT/UPDATE auf
--   `instructors` — Bestandsdaten ohne nachfolgendes Update bleiben NULL.
--
-- Auswirkung:
--   Phase-J Etappe 2c.1 — lib/auth.ts liest aus contact_instructor mit
--   .eq('auth_user_id', sess.user.id). Bei NULL: Login fällt auf den
--   Default-Fallback (`role: instructor`, `name: email`) zurück.
--
-- Fix: für alle bestehenden Sidecar-Zeilen auth_user_id aus instructors
-- nachziehen. Idempotent (NULL → Wert kopieren, Wert → bleibt).

UPDATE public.contact_instructor ci
SET auth_user_id = i.auth_user_id
FROM public.instructors i
WHERE ci.contact_id = i.id
  AND ci.auth_user_id IS DISTINCT FROM i.auth_user_id;

-- Sicherheitsnetz: auch app_role und preferred_language nachziehen,
-- falls 0088-Backfill durch fehlende preferred_language-Spalten in der
-- Production-DB nicht vollständig durchgelaufen ist.
UPDATE public.contact_instructor ci
SET app_role           = i.role,
    preferred_language = i.preferred_language
FROM public.instructors i
WHERE ci.contact_id = i.id
  AND (ci.app_role           IS DISTINCT FROM i.role
    OR ci.preferred_language IS DISTINCT FROM i.preferred_language);

-- Auch student-Sidecar
UPDATE public.contact_student cs
SET preferred_language = p.preferred_language
FROM public.people p
WHERE cs.contact_id = p.id
  AND cs.preferred_language IS DISTINCT FROM p.preferred_language;

DO $$
DECLARE
  null_auth INT;
BEGIN
  SELECT COUNT(*) INTO null_auth
  FROM public.contact_instructor ci
  JOIN public.instructors i ON i.id = ci.contact_id
  WHERE ci.auth_user_id IS NULL AND i.auth_user_id IS NOT NULL;
  IF null_auth > 0 THEN
    RAISE NOTICE 'Warnung: % Sidecar-Zeilen haben weiterhin NULL auth_user_id trotz Legacy-Wert', null_auth;
  ELSE
    RAISE NOTICE 'Backfill OK — auth_user_id konsistent zwischen Legacy und Sidecar.';
  END IF;
END $$;
