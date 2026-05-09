-- 0086: Retarget the few remaining FK constraints from legacy tables → contacts(id)
--
-- IMPORTANT: A pre-flight audit of pg_constraint revealed that only TWO FKs
-- still reference legacy tables:
--
--   1. certifications.issued_by_person_id_fkey  → instructors  (SET NULL)
--   2. students_organization_id_fkey            → organizations (SET NULL)
--
-- All other columns that "should" have FKs to instructors/people/organizations
-- (course_assignments.instructor_id, course_participants.student_id, etc.)
-- never had FK constraints in this project — the data matches referentially
-- but referential integrity is enforced by the application layer, not by
-- PostgreSQL. We're not adding FKs here; we just retarget what already exists.
--
-- UUIDs are preserved across all tables (legacy + contacts) so the retarget
-- requires no data movement. Sync triggers continue to keep contacts ↔
-- legacy tables in sync, so this migration is fully reversible.

-- ───────────────────────────────────────────────────────────────────────────
-- 1. certifications.issued_by_person_id  →  contacts(id)  (SET NULL)
-- ───────────────────────────────────────────────────────────────────────────
ALTER TABLE public.certifications
  DROP CONSTRAINT IF EXISTS certifications_issued_by_person_id_fkey;

ALTER TABLE public.certifications
  ADD  CONSTRAINT certifications_issued_by_person_id_fkey
  FOREIGN KEY (issued_by_person_id) REFERENCES public.contacts(id)
  ON DELETE SET NULL;

-- ───────────────────────────────────────────────────────────────────────────
-- 2. people.organization_id  →  contacts(id)  (SET NULL)
--
--    NB: the constraint is named "students_organization_id_fkey" historically
--    (table was renamed from students → people in 0069 but the constraint
--    name stayed). We preserve the existing name to avoid orphan-name
--    confusion.
-- ───────────────────────────────────────────────────────────────────────────
ALTER TABLE public.people
  DROP CONSTRAINT IF EXISTS students_organization_id_fkey;

ALTER TABLE public.people
  ADD  CONSTRAINT students_organization_id_fkey
  FOREIGN KEY (organization_id) REFERENCES public.contacts(id)
  ON DELETE SET NULL;

-- ───────────────────────────────────────────────────────────────────────────
-- Audit: verify both FKs now reference contacts
-- ───────────────────────────────────────────────────────────────────────────
DO $$
DECLARE
  v_count INT;
BEGIN
  SELECT count(*) INTO v_count
  FROM pg_constraint
  WHERE contype = 'f'
    AND confrelid::regclass::text IN ('instructors', 'people', 'organizations');

  IF v_count > 0 THEN
    RAISE WARNING '0086: % FK(s) still reference legacy tables — investigate', v_count;
  ELSE
    RAISE NOTICE '0086: all FKs successfully retargeted to contacts';
  END IF;
END $$;
