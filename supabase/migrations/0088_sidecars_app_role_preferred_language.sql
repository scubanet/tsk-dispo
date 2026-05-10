-- 0088: Sidecar-Felder für Phase J Etappe 2c.0
--
-- Ergänzt fehlende Felder in den contact_*-Sidecars, damit das Frontend
-- in Etappe 2c.1 von .from('instructors')/.from('people') auf
-- .from('contact_instructor')/.from('contact_student') wechseln kann
-- (Login-Pfad lib/auth.ts, useLanguage.ts).
--
-- Felder:
--   • contact_instructor.app_role          ← spiegelt instructors.role
--   • contact_instructor.preferred_language ← spiegelt instructors.preferred_language (0075)
--   • contact_student.preferred_language    ← spiegelt people.preferred_language    (0074)
--
-- Backfill: Werte aus den Legacy-Tabellen kopieren.
-- Forward-Sync: bestehende Trigger aus 0083 erweitern, dass die neuen
-- Felder mitgespiegelt werden (Legacy → Sidecar).
--
-- Reverse-Sync (Sidecar → Legacy) ist NICHT Teil dieser Migration.
-- Frontend-Code, der ab 2c.1 direkt auf den Sidecar schreibt, ist die
-- neue Source of Truth für diese Felder. Sync-Triggers werden in
-- Etappe 3 (0090+) komplett entfernt.

-- ────────────────────────────────────────────────────────────────────────────
-- 1. Spalten ergänzen
-- ────────────────────────────────────────────────────────────────────────────
ALTER TABLE public.contact_instructor
  ADD COLUMN IF NOT EXISTS app_role app_role NOT NULL DEFAULT 'instructor',
  ADD COLUMN IF NOT EXISTS preferred_language TEXT
    CHECK (preferred_language IS NULL OR preferred_language IN ('de', 'en'));

ALTER TABLE public.contact_student
  ADD COLUMN IF NOT EXISTS preferred_language TEXT
    CHECK (preferred_language IS NULL OR preferred_language IN ('de', 'en'));

COMMENT ON COLUMN public.contact_instructor.app_role IS
  'Permission-Level (admin/dispatcher/instructor/cd/owner). Spiegelt instructors.role bis Phase-J-Cleanup.';
COMMENT ON COLUMN public.contact_instructor.preferred_language IS
  'UI/Email/APNs-Sprache (de|en). Spiegelt instructors.preferred_language bis Phase-J-Cleanup.';
COMMENT ON COLUMN public.contact_student.preferred_language IS
  'UI-Sprache für Schüler ohne Instructor-Sidecar (de|en). Spiegelt people.preferred_language.';

-- ────────────────────────────────────────────────────────────────────────────
-- 2. Backfill aus Legacy-Tabellen
-- ────────────────────────────────────────────────────────────────────────────
UPDATE public.contact_instructor ci
SET app_role           = i.role,
    preferred_language = i.preferred_language
FROM public.instructors i
WHERE ci.contact_id = i.id;

UPDATE public.contact_student cs
SET preferred_language = p.preferred_language
FROM public.people p
WHERE cs.contact_id = p.id;

-- ────────────────────────────────────────────────────────────────────────────
-- 3. Forward-Sync-Trigger erweitern (instructors → contact_instructor)
-- ────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION sync_instructors_to_contacts()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    INSERT INTO public.contacts (
      id, kind, first_name, last_name,
      primary_email, phones, languages, roles, source, created_at, updated_at
    ) VALUES (
      NEW.id,
      'person',
      NULLIF(TRIM(NEW.first_name), ''),
      COALESCE(NULLIF(TRIM(NEW.last_name), ''), '-'),
      NEW.email,
      CASE WHEN NEW.phone IS NOT NULL AND NEW.phone <> ''
           THEN jsonb_build_array(jsonb_build_object('label','mobile','e164',NEW.phone,'primary',true))
           ELSE '[]'::jsonb END,
      '{}'::TEXT[],
      ARRAY['instructor', NEW.role::TEXT],
      'sync_from_legacy',
      now(), now()
    )
    ON CONFLICT (id) DO NOTHING;

    INSERT INTO public.contact_instructor (
      contact_id, auth_user_id, padi_pro_number, padi_level,
      account_balance, active, app_role, preferred_language, created_at, updated_at
    ) VALUES (
      NEW.id, NEW.auth_user_id, NEW.padi_nr, NEW.padi_level,
      NEW.opening_balance_chf, NEW.active, NEW.role, NEW.preferred_language,
      now(), now()
    )
    ON CONFLICT (contact_id) DO NOTHING;

  ELSIF TG_OP = 'UPDATE' THEN
    UPDATE public.contacts SET
      first_name    = NULLIF(TRIM(NEW.first_name), ''),
      last_name     = COALESCE(NULLIF(TRIM(NEW.last_name), ''), '-'),
      primary_email = NEW.email,
      phones        = CASE WHEN NEW.phone IS NOT NULL AND NEW.phone <> ''
                           THEN jsonb_build_array(jsonb_build_object('label','mobile','e164',NEW.phone,'primary',true))
                           ELSE '[]'::jsonb END,
      updated_at    = now()
    WHERE id = NEW.id;

    UPDATE public.contact_instructor SET
      auth_user_id       = NEW.auth_user_id,
      padi_pro_number    = NEW.padi_nr,
      padi_level         = NEW.padi_level,
      account_balance    = NEW.opening_balance_chf,
      active             = NEW.active,
      app_role           = NEW.role,
      preferred_language = NEW.preferred_language,
      updated_at         = now()
    WHERE contact_id = NEW.id;

  ELSIF TG_OP = 'DELETE' THEN
    DELETE FROM public.contact_instructor WHERE contact_id = OLD.id;
    DELETE FROM public.contacts           WHERE id = OLD.id;
  END IF;

  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- ────────────────────────────────────────────────────────────────────────────
-- 4. Forward-Sync-Trigger erweitern (people → contact_student)
-- ────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION sync_people_to_contacts()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    INSERT INTO public.contacts (
      id, kind, first_name, last_name, birth_date,
      primary_email, phones, languages, roles, source, notes, created_at, updated_at
    ) VALUES (
      NEW.id,
      'person',
      NULLIF(TRIM(NEW.first_name), ''),
      COALESCE(NULLIF(TRIM(NEW.last_name), ''), '-'),
      NEW.birthday,
      NEW.email,
      CASE WHEN NEW.phone IS NOT NULL AND NEW.phone <> ''
           THEN jsonb_build_array(jsonb_build_object('label','mobile','e164',NEW.phone,'primary',true))
           ELSE '[]'::jsonb END,
      COALESCE(NEW.languages, '{}'::TEXT[]),
      ARRAY(
        SELECT r FROM (VALUES
          (CASE WHEN NEW.is_student   THEN 'student'   END),
          (CASE WHEN NEW.is_candidate THEN 'candidate' END)
        ) AS t(r)
        WHERE r IS NOT NULL
      ),
      'sync_from_legacy',
      NEW.notes,
      now(), now()
    )
    ON CONFLICT (id) DO NOTHING;

    IF NEW.is_student OR NEW.is_candidate THEN
      INSERT INTO public.contact_student (
        contact_id, pipeline_stage, lead_source, is_candidate,
        preferred_language, created_at, updated_at
      ) VALUES (
        NEW.id,
        NULLIF(NEW.pipeline_stage, 'none'),
        NULLIF(NEW.lead_source, ''),
        NEW.is_candidate,
        NEW.preferred_language,
        now(), now()
      )
      ON CONFLICT (contact_id) DO NOTHING;
    END IF;

    IF NEW.organization_id IS NOT NULL THEN
      INSERT INTO public.contact_relationships (from_contact_id, to_contact_id, kind, is_primary)
      VALUES (NEW.id, NEW.organization_id, 'works_at', true)
      ON CONFLICT DO NOTHING;
    END IF;

  ELSIF TG_OP = 'UPDATE' THEN
    UPDATE public.contacts SET
      first_name    = NULLIF(TRIM(NEW.first_name), ''),
      last_name     = COALESCE(NULLIF(TRIM(NEW.last_name), ''), '-'),
      birth_date    = NEW.birthday,
      primary_email = NEW.email,
      phones        = CASE WHEN NEW.phone IS NOT NULL AND NEW.phone <> ''
                           THEN jsonb_build_array(jsonb_build_object('label','mobile','e164',NEW.phone,'primary',true))
                           ELSE '[]'::jsonb END,
      languages     = COALESCE(NEW.languages, '{}'::TEXT[]),
      notes         = NEW.notes,
      updated_at    = now()
    WHERE id = NEW.id;

    UPDATE public.contact_student SET
      pipeline_stage     = NULLIF(NEW.pipeline_stage, 'none'),
      lead_source        = NULLIF(NEW.lead_source, ''),
      is_candidate       = NEW.is_candidate,
      preferred_language = NEW.preferred_language,
      updated_at         = now()
    WHERE contact_id = NEW.id;

    -- works_at relationship — recreate if organization changed
    IF NEW.organization_id IS DISTINCT FROM OLD.organization_id THEN
      DELETE FROM public.contact_relationships
        WHERE from_contact_id = NEW.id AND kind = 'works_at';
      IF NEW.organization_id IS NOT NULL THEN
        INSERT INTO public.contact_relationships (from_contact_id, to_contact_id, kind, is_primary)
        VALUES (NEW.id, NEW.organization_id, 'works_at', true)
        ON CONFLICT DO NOTHING;
      END IF;
    END IF;

  ELSIF TG_OP = 'DELETE' THEN
    DELETE FROM public.contact_student        WHERE contact_id = OLD.id;
    DELETE FROM public.contact_relationships  WHERE from_contact_id = OLD.id OR to_contact_id = OLD.id;
    DELETE FROM public.contacts               WHERE id = OLD.id;
  END IF;

  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- ────────────────────────────────────────────────────────────────────────────
-- 5. Sanity-Check
-- ────────────────────────────────────────────────────────────────────────────
DO $$
DECLARE
  drift_inst INT;
  drift_lang_inst INT;
  drift_lang_stud INT;
BEGIN
  SELECT COUNT(*) INTO drift_inst
  FROM public.contact_instructor ci
  JOIN public.instructors i ON i.id = ci.contact_id
  WHERE ci.app_role IS DISTINCT FROM i.role;

  SELECT COUNT(*) INTO drift_lang_inst
  FROM public.contact_instructor ci
  JOIN public.instructors i ON i.id = ci.contact_id
  WHERE ci.preferred_language IS DISTINCT FROM i.preferred_language;

  SELECT COUNT(*) INTO drift_lang_stud
  FROM public.contact_student cs
  JOIN public.people p ON p.id = cs.contact_id
  WHERE cs.preferred_language IS DISTINCT FROM p.preferred_language;

  IF drift_inst > 0 OR drift_lang_inst > 0 OR drift_lang_stud > 0 THEN
    RAISE NOTICE 'Backfill-Drift: app_role=% inst_lang=% stud_lang=%',
      drift_inst, drift_lang_inst, drift_lang_stud;
  ELSE
    RAISE NOTICE 'Backfill OK — alle Legacy-Werte in Sidecars gespiegelt.';
  END IF;
END $$;
