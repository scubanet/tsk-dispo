-- 0083: Sync triggers — old tables (instructors/people/organizations) → contacts/sidecars
--
-- Pattern:
--   INSERT/UPDATE/DELETE on legacy table
--     → cascade to contacts (and the matching sidecar)
--   The role-sync trigger on the sidecar (sync_role_from_sidecar, from 0080)
--   takes care of contacts.roles[] automatically when sidecars are created/deleted.
--
-- Column-name notes vs. original spec:
--   - instructors.first_name / last_name exist (added in 0042); no standalone
--     `languages` column on instructors → synced as '{}'.
--   - people columns confirmed: birthday, languages, pipeline_stage, lead_source,
--     is_student, is_candidate, organization_id, notes.
--   - organizations.address is a single TEXT field (no split into street/city).
--
-- works_at relationship uniqueness:
--   contact_relationships has no UNIQUE constraint on (from,to,kind).
--   We add a partial unique index here so ON CONFLICT DO NOTHING works correctly.
--   This index is harmless to leave after Phase J (or can be dropped with the triggers).
--
-- These triggers and this index are intended to be DROPPED in Phase J after
-- the frontend has fully migrated to querying contacts directly.

-- ────────────────────────────────────────────────────────────────────────────
-- Partial unique index for works_at relationships (enables ON CONFLICT DO NOTHING)
-- ────────────────────────────────────────────────────────────────────────────
CREATE UNIQUE INDEX IF NOT EXISTS uniq_works_at
  ON public.contact_relationships(from_contact_id, to_contact_id, kind)
  WHERE kind = 'works_at';

-- ────────────────────────────────────────────────────────────────────────────
-- 1. instructors → contacts + contact_instructor
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
      -- contacts CHECK requires last_name NOT NULL for person; fall back to '-'
      COALESCE(NULLIF(TRIM(NEW.last_name), ''), '-'),
      NEW.email,
      CASE WHEN NEW.phone IS NOT NULL AND NEW.phone <> ''
           THEN jsonb_build_array(jsonb_build_object('label','mobile','e164',NEW.phone,'primary',true))
           ELSE '[]'::jsonb END,
      '{}'::TEXT[],
      -- seed roles array; sync_role_from_sidecar will add 'instructor' when sidecar inserted
      ARRAY['instructor', NEW.role::TEXT],
      'sync_from_legacy',
      now(), now()
    )
    ON CONFLICT (id) DO NOTHING;

    INSERT INTO public.contact_instructor (
      contact_id, auth_user_id, padi_pro_number, padi_level,
      account_balance, active, created_at, updated_at
    ) VALUES (
      NEW.id, NEW.auth_user_id, NEW.padi_nr, NEW.padi_level,
      NEW.opening_balance_chf, NEW.active, now(), now()
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
      auth_user_id    = NEW.auth_user_id,
      padi_pro_number = NEW.padi_nr,
      padi_level      = NEW.padi_level,
      account_balance = NEW.opening_balance_chf,
      active          = NEW.active,
      updated_at      = now()
    WHERE contact_id = NEW.id;

  ELSIF TG_OP = 'DELETE' THEN
    -- sidecar first (FK → contacts), then contact row
    DELETE FROM public.contact_instructor WHERE contact_id = OLD.id;
    DELETE FROM public.contacts           WHERE id = OLD.id;
  END IF;

  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_sync_instructors_to_contacts
  AFTER INSERT OR UPDATE OR DELETE ON public.instructors
  FOR EACH ROW EXECUTE FUNCTION sync_instructors_to_contacts();

-- ────────────────────────────────────────────────────────────────────────────
-- 2. people → contacts + contact_student (+ works_at relationship)
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
      -- Build roles[] from flags; sync_role_from_sidecar adds 'student' when sidecar inserted
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

    -- Only create contact_student sidecar when person is a student or candidate
    IF NEW.is_student OR NEW.is_candidate THEN
      INSERT INTO public.contact_student (
        contact_id, pipeline_stage, lead_source, is_candidate, created_at, updated_at
      ) VALUES (
        NEW.id,
        NULLIF(NEW.pipeline_stage, 'none'),
        NULLIF(NEW.lead_source, ''),
        NEW.is_candidate,
        now(), now()
      )
      ON CONFLICT (contact_id) DO NOTHING;
    END IF;

    -- works_at relationship (partial unique index handles idempotency)
    IF NEW.organization_id IS NOT NULL THEN
      INSERT INTO public.contact_relationships (from_contact_id, to_contact_id, kind, is_primary)
      VALUES (NEW.id, NEW.organization_id, 'works_at', true)
      ON CONFLICT (from_contact_id, to_contact_id, kind)
        WHERE kind = 'works_at'
      DO NOTHING;
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
      -- Merge: keep existing roles that are not student/candidate, then re-add from flags
      roles = ARRAY(
        SELECT r FROM (
          -- non-student/candidate roles already on this contact
          SELECT unnest(roles) AS r
          FROM public.contacts
          WHERE id = NEW.id
        ) existing
        WHERE r NOT IN ('student', 'candidate')
        UNION
        SELECT r FROM (VALUES
          (CASE WHEN NEW.is_student   THEN 'student'   END),
          (CASE WHEN NEW.is_candidate THEN 'candidate' END)
        ) AS t(r)
        WHERE r IS NOT NULL
      ),
      updated_at    = now()
    WHERE id = NEW.id;

    -- Upsert contact_student sidecar when student/candidate; remove when neither
    IF NEW.is_student OR NEW.is_candidate THEN
      INSERT INTO public.contact_student (contact_id, pipeline_stage, lead_source, is_candidate)
      VALUES (
        NEW.id,
        NULLIF(NEW.pipeline_stage, 'none'),
        NULLIF(NEW.lead_source, ''),
        NEW.is_candidate
      )
      ON CONFLICT (contact_id) DO UPDATE SET
        pipeline_stage = EXCLUDED.pipeline_stage,
        lead_source    = EXCLUDED.lead_source,
        is_candidate   = EXCLUDED.is_candidate,
        updated_at     = now();
    ELSE
      -- Person is no longer student/candidate: remove sidecar.
      -- The sync_role_from_sidecar DELETE trigger will strip 'student' from roles[].
      DELETE FROM public.contact_student WHERE contact_id = NEW.id;
    END IF;

    -- Sync works_at relationship if organization changed
    IF OLD.organization_id IS DISTINCT FROM NEW.organization_id THEN
      -- Remove old relationship (if any)
      IF OLD.organization_id IS NOT NULL THEN
        DELETE FROM public.contact_relationships
         WHERE from_contact_id = NEW.id
           AND to_contact_id   = OLD.organization_id
           AND kind            = 'works_at';
      END IF;
      -- Insert new relationship (if any)
      IF NEW.organization_id IS NOT NULL THEN
        INSERT INTO public.contact_relationships (from_contact_id, to_contact_id, kind, is_primary)
        VALUES (NEW.id, NEW.organization_id, 'works_at', true)
        ON CONFLICT (from_contact_id, to_contact_id, kind)
          WHERE kind = 'works_at'
        DO NOTHING;
      END IF;
    END IF;

  ELSIF TG_OP = 'DELETE' THEN
    DELETE FROM public.contact_student WHERE contact_id = OLD.id;
    DELETE FROM public.contact_relationships
     WHERE from_contact_id = OLD.id OR to_contact_id = OLD.id;
    DELETE FROM public.contacts WHERE id = OLD.id;
  END IF;

  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_sync_people_to_contacts
  AFTER INSERT OR UPDATE OR DELETE ON public.people
  FOR EACH ROW EXECUTE FUNCTION sync_people_to_contacts();

-- ────────────────────────────────────────────────────────────────────────────
-- 3. organizations → contacts + contact_organization
-- ────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION sync_organizations_to_contacts()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    INSERT INTO public.contacts (
      id, kind, legal_name, primary_email,
      addresses, languages, roles, source, notes, created_at, updated_at
    ) VALUES (
      NEW.id,
      'organization',
      NEW.name,
      NEW.email,
      CASE WHEN NEW.address IS NOT NULL AND NEW.address <> ''
           THEN jsonb_build_array(jsonb_build_object('label','main','street',NEW.address,'primary',true))
           ELSE '[]'::jsonb END,
      '{}'::TEXT[],
      -- sync_role_from_sidecar will add 'organization_profile' when sidecar inserted
      ARRAY['organization_profile'],
      'sync_from_legacy',
      NEW.notes,
      now(), now()
    )
    ON CONFLICT (id) DO NOTHING;

    INSERT INTO public.contact_organization (contact_id, org_kind, created_at, updated_at)
    VALUES (NEW.id, COALESCE(NEW.kind, 'unknown'), now(), now())
    ON CONFLICT (contact_id) DO NOTHING;

  ELSIF TG_OP = 'UPDATE' THEN
    UPDATE public.contacts SET
      legal_name    = NEW.name,
      primary_email = NEW.email,
      addresses     = CASE WHEN NEW.address IS NOT NULL AND NEW.address <> ''
                           THEN jsonb_build_array(jsonb_build_object('label','main','street',NEW.address,'primary',true))
                           ELSE '[]'::jsonb END,
      notes         = NEW.notes,
      updated_at    = now()
    WHERE id = NEW.id;

    UPDATE public.contact_organization SET
      org_kind   = COALESCE(NEW.kind, 'unknown'),
      updated_at = now()
    WHERE contact_id = NEW.id;

  ELSIF TG_OP = 'DELETE' THEN
    -- sidecar first, then contact
    DELETE FROM public.contact_organization WHERE contact_id = OLD.id;
    DELETE FROM public.contacts             WHERE id = OLD.id;
  END IF;

  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_sync_organizations_to_contacts
  AFTER INSERT OR UPDATE OR DELETE ON public.organizations
  FOR EACH ROW EXECUTE FUNCTION sync_organizations_to_contacts();

-- ────────────────────────────────────────────────────────────────────────────
-- Comments
-- ────────────────────────────────────────────────────────────────────────────
COMMENT ON FUNCTION sync_instructors_to_contacts   IS 'Phase C: keeps contacts/contact_instructor in sync with legacy instructors. Drop in Phase J.';
COMMENT ON FUNCTION sync_people_to_contacts        IS 'Phase C: keeps contacts/contact_student/contact_relationships in sync with legacy people. Drop in Phase J.';
COMMENT ON FUNCTION sync_organizations_to_contacts IS 'Phase C: keeps contacts/contact_organization in sync with legacy organizations. Drop in Phase J.';
COMMENT ON INDEX public.uniq_works_at              IS 'Phase C: partial unique index enabling ON CONFLICT DO NOTHING for works_at sync. Can be dropped with Phase J triggers.';
