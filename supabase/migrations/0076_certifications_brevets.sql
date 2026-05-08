-- 0076: cert-first data model
--
-- Replaces ad-hoc PADI-level fields with a single immutable `certifications`
-- table. Tier and teaching permits are derived in app code via
-- /lib/tier.ts and /lib/teaching-rules.ts.
--
-- This migration is destructive on test data only (per project owner).
-- It is idempotent: re-running it produces no duplicates.

-- ─────────────────── 1. New table: certifications ───────────────────

CREATE TABLE IF NOT EXISTS public.certifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  person_id UUID NOT NULL REFERENCES public.people(id) ON DELETE CASCADE,
  agency TEXT NOT NULL CHECK (agency IN ('PADI','SSI','CMAS','ANDI','TecRec','Other')),
  category TEXT NOT NULL CHECK (category IN ('diver','pro','specialty-teacher','additional')),
  code TEXT NOT NULL,
  number TEXT,                                       -- nullable for externs
  issued_at DATE NOT NULL,
  issued_by_person_id UUID REFERENCES public.instructors(id) ON DELETE SET NULL,
  issued_by_name TEXT,                               -- denormalized snapshot
  issued_by_pro_tier TEXT,                           -- denormalized at time of issue
  origin TEXT NOT NULL DEFAULT 'extern'
    CHECK (origin IN ('tsk-zurich','tsk-bern','extern','auto-with-owsi')),
  evidence JSONB,
  notes TEXT,
  invalidated_at TIMESTAMPTZ,
  invalidated_reason TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS certifications_person_id_idx ON public.certifications(person_id);
CREATE INDEX IF NOT EXISTS certifications_code_idx ON public.certifications(code);
CREATE INDEX IF NOT EXISTS certifications_category_idx ON public.certifications(category);
CREATE INDEX IF NOT EXISTS certifications_active_idx ON public.certifications(person_id)
  WHERE invalidated_at IS NULL;

COMMENT ON TABLE public.certifications IS
  'Cert-first model. Immutable audit records. Tier/canTeach are derived in app code.';
COMMENT ON COLUMN public.certifications.invalidated_at IS
  'Soft-delete. Brevet stays in record, ignored by canTeach()/deriveTier().';
COMMENT ON COLUMN public.certifications.origin IS
  'auto-with-owsi: Automatically created when an OWSI brevet is recorded (3 specialty teachers).';

-- ──────────────── 2. Migrate existing instructors.padi_level ────────────────
-- Idempotent: skip rows that already have a matching active pro cert.

INSERT INTO public.certifications (
  person_id, agency, category, code, number, issued_at, origin, notes
)
SELECT
  i.id,
  'PADI',
  'pro',
  CASE i.padi_level
    WHEN 'DM'        THEN 'DM'
    WHEN 'AI'        THEN 'OWSI'   -- AI no longer exists in cert-first model
    WHEN 'OWSI'      THEN 'OWSI'
    WHEN 'MSDT'      THEN 'OWSI'   -- MSDT collapses to OWSI in cert-first
    WHEN 'IDC Staff' THEN 'IDC_STAFF'
    WHEN 'MI'        THEN 'MI'
    WHEN 'CD'        THEN 'CD'
  END AS code,
  '—',                              -- placeholder — number can be set later
  COALESCE(i.created_at::date, '2024-01-01'::date),
  'extern',
  'Auto-migrated from instructors.padi_level on 2026-05-08'
FROM public.instructors i
WHERE i.padi_level IS NOT NULL
  AND i.padi_level NOT IN ('Shop Staff', 'Andere')
  AND NOT EXISTS (
    SELECT 1 FROM public.certifications c
    WHERE c.person_id = i.id
      AND c.category = 'pro'
      AND c.invalidated_at IS NULL
  );

-- ─────────────── 3. Migrate existing student_certifications ───────────────
-- Best-effort mapping based on the free-text `certification` field.
-- Anything we can't classify lands as 'additional' with origin 'extern'.

INSERT INTO public.certifications (
  person_id, agency, category, code, number, issued_at, origin, notes
)
SELECT
  sc.student_id,
  COALESCE(NULLIF(sc.issued_by, ''), 'PADI'),
  CASE
    WHEN sc.certification ILIKE '%scuba diver%' AND sc.certification NOT ILIKE '%master%' THEN 'diver'
    WHEN sc.certification ILIKE 'OWD%' OR sc.certification ILIKE '%open water diver%' THEN 'diver'
    WHEN sc.certification ILIKE 'AOWD%' OR sc.certification ILIKE '%advanced open water%' THEN 'diver'
    WHEN sc.certification ILIKE '%rescue%' THEN 'diver'
    WHEN sc.certification ILIKE '%master scuba diver%' THEN 'diver'
    WHEN sc.certification ILIKE '%efri%' OR sc.certification ILIKE '%efr%' THEN 'additional'
    ELSE 'additional'
  END,
  CASE
    WHEN sc.certification ILIKE '%scuba diver%' AND sc.certification NOT ILIKE '%master%' THEN 'SCUBA_DIVER'
    WHEN sc.certification ILIKE 'OWD%dry%' THEN 'OWD_DRY'
    WHEN sc.certification ILIKE 'OWD%' OR sc.certification ILIKE '%open water diver%' THEN 'OWD'
    WHEN sc.certification ILIKE 'AOWD%' OR sc.certification ILIKE '%advanced open water%' THEN 'AOWD'
    WHEN sc.certification ILIKE '%rescue%' THEN 'RESCUE_DIVER'
    WHEN sc.certification ILIKE '%master scuba diver%' THEN 'MASTER_SCUBA_DIVER'
    WHEN sc.certification ILIKE '%efri%' THEN 'EFRI'
    WHEN sc.certification ILIKE '%efr%' THEN 'EFR'
    ELSE sc.certification                              -- fallback: keep raw string
  END,
  COALESCE(NULLIF(sc.certificate_nr, ''), '—'),
  COALESCE(sc.issued_date, sc.created_at::date, '2024-01-01'::date),
  'extern',
  'Auto-migrated from student_certifications on 2026-05-08' ||
    CASE WHEN sc.notes IS NOT NULL THEN E'\n\n' || sc.notes ELSE '' END
FROM public.student_certifications sc
WHERE NOT EXISTS (
  SELECT 1 FROM public.certifications c
  WHERE c.person_id = sc.student_id
    AND c.notes LIKE 'Auto-migrated from student_certifications%'
);

-- ──────────────── 4. Auto-create 3 specialty teachers per OWSI ────────────────

INSERT INTO public.certifications (
  person_id, agency, category, code, number, issued_at, origin, notes
)
SELECT
  c.person_id,
  c.agency,
  'specialty-teacher',
  sp.code,
  '—',
  c.issued_at,
  'auto-with-owsi',
  'Auto-included with OWSI'
FROM public.certifications c
CROSS JOIN (VALUES
  ('SPEC_TEACHER_AWARE'),
  ('SPEC_TEACHER_DEBRIS'),
  ('SPEC_TEACHER_PPB')
) AS sp(code)
WHERE c.code = 'OWSI'
  AND c.invalidated_at IS NULL
  AND NOT EXISTS (
    SELECT 1 FROM public.certifications c2
    WHERE c2.person_id = c.person_id
      AND c2.code = sp.code
      AND c2.invalidated_at IS NULL
  );

-- ───────────────── 5. Backwards-compat view for legacy code ─────────────────
-- Surfaces the derived pro_tier from cert-first model for old queries.

CREATE OR REPLACE VIEW public.v_person_pro_tier AS
SELECT
  i.id AS person_id,
  i.name,
  COALESCE(
    (SELECT 'CD'        WHERE EXISTS (SELECT 1 FROM public.certifications WHERE person_id = i.id AND code = 'CD'        AND invalidated_at IS NULL)),
    (SELECT 'MI'        WHERE EXISTS (SELECT 1 FROM public.certifications WHERE person_id = i.id AND code = 'MI'        AND invalidated_at IS NULL)),
    (SELECT 'IDC Staff' WHERE EXISTS (SELECT 1 FROM public.certifications WHERE person_id = i.id AND code = 'IDC_STAFF' AND invalidated_at IS NULL)),
    (SELECT 'OWSI'      WHERE EXISTS (SELECT 1 FROM public.certifications WHERE person_id = i.id AND code = 'OWSI'      AND invalidated_at IS NULL)),
    (SELECT 'DM'        WHERE EXISTS (SELECT 1 FROM public.certifications WHERE person_id = i.id AND code = 'DM'        AND invalidated_at IS NULL))
  ) AS pro_tier
FROM public.instructors i;

COMMENT ON VIEW public.v_person_pro_tier IS
  'Derived pro tier per cert-first model. Use instead of legacy instructors.padi_level.';

-- ──────────────────── 6. RLS — same access as people table ────────────────────

ALTER TABLE public.certifications ENABLE ROW LEVEL SECURITY;

-- Dispatcher / CD / Owner can do everything
CREATE POLICY "certs_full_access_for_staff" ON public.certifications
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.instructors
      WHERE auth_user_id = auth.uid()
        AND role IN ('dispatcher', 'cd', 'owner')
    )
  );

-- Instructors can read their own certs
CREATE POLICY "certs_self_read" ON public.certifications
  FOR SELECT
  USING (
    person_id IN (SELECT id FROM public.instructors WHERE auth_user_id = auth.uid())
  );
