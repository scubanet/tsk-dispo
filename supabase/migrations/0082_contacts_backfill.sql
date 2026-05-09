-- 0082: Backfill contacts from instructors/people/organizations.
-- Preserves UUIDs so existing FK columns (course_assignments.instructor_id,
-- course_participants.person_id, etc.) automatically point at the new contacts.
--
-- Column-name notes (verified against actual migrations):
--   instructors: first_name + last_name columns exist (added in 0042)
--   instructors: padi_nr (not padi_number)
--   people:      birthday (not birth_date) — added in 0027
--   people:      no highest_brevet / intake_status / external_brevet_history /
--                candidate_target_level — those only exist in contact_student
--   organizations.kind is plain TEXT (not an enum)
--   role-sync triggers are AFTER INSERT OR DELETE on sidecar tables

-- 1. Disable role-sync triggers temporarily — we set roles[] directly.
ALTER TABLE public.contact_instructor   DISABLE TRIGGER trg_sync_instructor_role;
ALTER TABLE public.contact_student      DISABLE TRIGGER trg_sync_student_role;
ALTER TABLE public.contact_organization DISABLE TRIGGER trg_sync_organization_role;

-- ────────────────────────────────────────────────────────────────────────────
-- 2. instructors → contacts (kind='person', roles include 'instructor' + their app_role)
-- ────────────────────────────────────────────────────────────────────────────
INSERT INTO public.contacts (
  id, kind, first_name, last_name,
  primary_email, phones, languages, roles, source, created_at
)
SELECT
  i.id,
  'person'::contact_kind,
  -- first_name/last_name columns exist on instructors since migration 0042
  NULLIF(TRIM(i.first_name), '') AS first_name,
  COALESCE(NULLIF(TRIM(i.last_name), ''), '-') AS last_name,
  i.email,
  CASE WHEN i.phone IS NOT NULL AND i.phone <> ''
       THEN jsonb_build_array(jsonb_build_object('label','mobile','e164',i.phone,'primary',true))
       ELSE '[]'::jsonb END,
  '{}'::TEXT[],
  -- 'instructor' always present; also include their app_role unless it duplicates
  ARRAY(
    SELECT DISTINCT r FROM unnest(ARRAY['instructor', i.role::text]) AS r
  )::TEXT[],
  'legacy_migration',
  i.created_at
FROM public.instructors i
WHERE NOT EXISTS (SELECT 1 FROM public.contacts WHERE id = i.id);

-- instructors → contact_instructor sidecar
INSERT INTO public.contact_instructor (
  contact_id, auth_user_id, padi_pro_number, padi_level,
  account_balance, active, hire_date, created_at
)
SELECT
  i.id,
  i.auth_user_id,
  i.padi_nr,       -- column is padi_nr (not padi_number)
  i.padi_level,
  i.opening_balance_chf,
  i.active,
  NULL,            -- hire_date not available in legacy data
  i.created_at
FROM public.instructors i
WHERE NOT EXISTS (SELECT 1 FROM public.contact_instructor WHERE contact_id = i.id);

-- ────────────────────────────────────────────────────────────────────────────
-- 3. people → contacts (kind='person', roles ⊆ {'student','candidate'})
-- ────────────────────────────────────────────────────────────────────────────
INSERT INTO public.contacts (
  id, kind, first_name, last_name, birth_date,
  primary_email, phones, languages, roles, source, notes, created_at
)
SELECT
  p.id,
  'person'::contact_kind,
  NULLIF(TRIM(p.first_name), '') AS first_name,
  COALESCE(NULLIF(TRIM(p.last_name), ''), '-') AS last_name,
  p.birthday,      -- column is birthday (not birth_date) — maps to contacts.birth_date
  p.email,
  CASE WHEN p.phone IS NOT NULL AND p.phone <> ''
       THEN jsonb_build_array(jsonb_build_object('label','mobile','e164',p.phone,'primary',true))
       ELSE '[]'::jsonb END,
  COALESCE(p.languages, '{}'::TEXT[]),
  -- Build roles array: only include role if the corresponding flag is true
  ARRAY(
    SELECT r FROM (VALUES
      (CASE WHEN p.is_student   THEN 'student'   END),
      (CASE WHEN p.is_candidate THEN 'candidate' END)
    ) AS t(r) WHERE r IS NOT NULL
  )::TEXT[],
  'legacy_migration',
  p.notes,
  p.created_at
FROM public.people p
WHERE NOT EXISTS (SELECT 1 FROM public.contacts WHERE id = p.id);

-- people (students/candidates) → contact_student sidecar
-- Note: highest_brevet, intake_status, external_brevet_history, candidate_target_level
-- do NOT exist on the legacy people table — they are new fields in contact_student only.
-- Those columns will be NULL/default until populated by the application.
INSERT INTO public.contact_student (
  contact_id, pipeline_stage, lead_source,
  is_candidate, created_at
)
SELECT
  p.id,
  NULLIF(p.pipeline_stage, 'none'),  -- 'none' was the legacy default; store as NULL
  NULLIF(p.lead_source, ''),
  p.is_candidate,
  p.created_at
FROM public.people p
WHERE (p.is_student OR p.is_candidate)
  AND NOT EXISTS (SELECT 1 FROM public.contact_student WHERE contact_id = p.id);

-- ────────────────────────────────────────────────────────────────────────────
-- 4. organizations → contacts (kind='organization')
-- ────────────────────────────────────────────────────────────────────────────
INSERT INTO public.contacts (
  id, kind, legal_name, primary_email,
  addresses, languages, roles, source, notes, created_at
)
SELECT
  o.id,
  'organization'::contact_kind,
  o.name AS legal_name,
  o.email,
  CASE WHEN o.address IS NOT NULL AND o.address <> ''
       THEN jsonb_build_array(jsonb_build_object('label','main','street',o.address,'primary',true))
       ELSE '[]'::jsonb END,
  '{}'::TEXT[],
  ARRAY['organization_profile']::TEXT[],
  'legacy_migration',
  o.notes,
  o.created_at
FROM public.organizations o
WHERE NOT EXISTS (SELECT 1 FROM public.contacts WHERE id = o.id);

-- organizations → contact_organization sidecar
-- organizations.kind is plain TEXT (not an enum), direct copy is safe.
INSERT INTO public.contact_organization (
  contact_id, org_kind, created_at
)
SELECT
  o.id,
  COALESCE(o.kind, 'unknown'),  -- org_kind is NOT NULL; fall back if legacy kind is NULL
  o.created_at
FROM public.organizations o
WHERE NOT EXISTS (SELECT 1 FROM public.contact_organization WHERE contact_id = o.id);

-- ────────────────────────────────────────────────────────────────────────────
-- 5. people.organization_id → contact_relationships (works_at)
-- ────────────────────────────────────────────────────────────────────────────
INSERT INTO public.contact_relationships (
  from_contact_id, to_contact_id, kind, is_primary
)
SELECT p.id, p.organization_id, 'works_at', true
FROM public.people p
WHERE p.organization_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM public.contact_relationships
    WHERE from_contact_id = p.id
      AND to_contact_id   = p.organization_id
      AND kind            = 'works_at'
  );

-- ────────────────────────────────────────────────────────────────────────────
-- 6. Re-enable triggers
-- ────────────────────────────────────────────────────────────────────────────
ALTER TABLE public.contact_instructor   ENABLE TRIGGER trg_sync_instructor_role;
ALTER TABLE public.contact_student      ENABLE TRIGGER trg_sync_student_role;
ALTER TABLE public.contact_organization ENABLE TRIGGER trg_sync_organization_role;

-- ────────────────────────────────────────────────────────────────────────────
-- 7. Verify counts match (legacy total == contacts inserted by this migration)
-- ────────────────────────────────────────────────────────────────────────────
DO $$
DECLARE
  v_old_total INT;
  v_new_total INT;
BEGIN
  SELECT (SELECT count(*) FROM public.instructors)
       + (SELECT count(*) FROM public.people)
       + (SELECT count(*) FROM public.organizations)
  INTO v_old_total;

  SELECT count(*) FROM public.contacts WHERE source = 'legacy_migration'
  INTO v_new_total;

  IF v_old_total <> v_new_total THEN
    RAISE EXCEPTION '0082: Backfill count mismatch: legacy=% new=%', v_old_total, v_new_total;
  END IF;

  RAISE NOTICE '0082: Backfilled % contacts (matches legacy total of %)', v_new_total, v_old_total;
END $$;
