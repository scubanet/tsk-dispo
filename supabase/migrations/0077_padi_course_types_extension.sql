-- 0077: PADI course types extension
--
-- Aligns the `course_types` catalog with the official PADI flowchart (2026):
--   * Diver brevets:  Adventure Diver, OWD Dry, AOWD Dry, Master Scuba Diver
--   * Programs:       Seal Team, Advanced Snorkeler
--   * Specialties:    Boat, DPV, DSMB, Full Face Mask, Underwater Naturalist,
--                     Fish ID, Public Safety, Shark Conservation, Coral Reef
--                     Conservation, Adaptive Support, Rebreather, Underwater
--                     Videographer, Wreck (student versions of existing SPEI_*)
--   * First Aid:      EFR Instructor Trainer
--
-- All inserts are idempotent (`ON CONFLICT (code) DO NOTHING`). The
-- `trg_ensure_comp_units` trigger auto-creates haupt/assist/dmt entries in
-- `comp_units` for every new row.
--
-- Hour values are sensible defaults — fine-tune via Settings → Kurspunkte.

-- ─────────────────────── Diver brevets / programs ───────────────────────

INSERT INTO course_types (code, label, theory_units, pool_units, lake_units, ratio_pool, ratio_lake, has_elearning, notes) VALUES
  ('ADV',          'Adventure Diver (3 Adventure Dives)',  1,   0,  6,    'N.A.', '4:1', true,
   'Stufe zwischen OWD und AOWD per PADI'),
  ('OWD_DRY',      'OWD eLearning + Dry Suit Bundle',      2,   12, 12,   '3:1',  '2:1', true,
   'OWD bundle including the Dry Suit specialty — common for cold-water Switzerland'),
  ('AOWD_DRY',     'AOWD + DAD + Dry Suit Bundle',         1.5, 0,  17,   'N.A.', '2:1', true,
   'AOWD bundle including the Dry Suit specialty — common for cold-water Switzerland'),
  ('MSD',          'Master Scuba Diver Recognition',       0,   0,  0,    'N.A.', 'N.A.', false,
   'Recognition (no scheduled sessions) — awarded after 5 specialties + Rescue + 50 dives'),
  ('SEAL',         'PADI Seal Team',                       0.5, 5,  0,    '4:1',  'N.A.', false,
   'Kids program (8+) — 5 AquaMissions in pool'),
  ('ADV_SKIN',     'Advanced Snorkeler',                   0.5, 2,  0,    '6:1',  'N.A.', false,
   'Snorkel-only follow-up to Discover Snorkeling')
ON CONFLICT (code) DO NOTHING;

-- ─────────────────────── Specialty courses (student-side) ───────────────────────
-- Defaults: 1h theory + 4h lake (typical PADI specialty unless noted).

INSERT INTO course_types (code, label, theory_units, pool_units, lake_units, ratio_pool, ratio_lake, has_elearning) VALUES
  ('SPEC_BOAT',         'Specialty: Boat Diver',                  1, 0, 4, 'N.A.', '4:1', false),
  ('SPEC_DPV',          'Specialty: Diver Propulsion Vehicle',    1, 0, 4, 'N.A.', '4:1', false),
  ('SPEC_DSMB',         'Specialty: Delayed Surface Marker Buoy', 1, 0, 4, 'N.A.', '4:1', false),
  ('SPEC_FFM',          'Specialty: Full Face Mask',              1, 0, 4, 'N.A.', '4:1', false),
  ('SPEC_NATURE',       'Specialty: Underwater Naturalist',       1, 0, 4, 'N.A.', '4:1', false),
  ('SPEC_FISH',         'Specialty: Fish Identification',         1, 0, 4, 'N.A.', '4:1', false),
  ('SPEC_PSD',          'Specialty: Public Safety Diver',         2, 0, 8, 'N.A.', '2:1', false),
  ('SPEC_SHARK',        'Specialty: AWARE Shark Conservation',    2, 0, 4, 'N.A.', '4:1', false),
  ('SPEC_CORAL',        'Specialty: Coral Reef Conservation',     2, 0, 0, 'N.A.', 'N.A.', false),
  ('SPEC_ADAPT',        'Specialty: Adaptive Support Diver',      2, 0, 0, 'N.A.', 'N.A.', false),
  ('SPEC_REBREATHER',   'Specialty: Rebreather Diver',            4, 4, 8, '4:1',  '2:1', true),
  ('SPEC_VIDEO',        'Specialty: Underwater Videographer',     1, 3, 4, '5:1',  '2:1', false),
  ('SPEC_WRECK',        'Specialty: Wreck Diver',                 2, 0, 8, 'N.A.', '2:1', true)
ON CONFLICT (code) DO NOTHING;

-- ─────────────────────── First Aid: EFR Instructor Trainer ───────────────────────

INSERT INTO course_types (code, label, theory_units, pool_units, lake_units, ratio_pool, ratio_lake, has_elearning, notes) VALUES
  ('EFR_IT', 'EFR Instructor Trainer', 16, 0, 0, 'N.A.', 'N.A.', false,
   'Trains existing EFR Instructors to evaluate new EFRIs — CD-only delivery')
ON CONFLICT (code) DO NOTHING;

-- ─────────────────────── Verification ───────────────────────
-- Counts how many of the new codes are now present (should be 20).
DO $$
DECLARE
  expected_codes TEXT[] := ARRAY[
    'ADV', 'OWD_DRY', 'AOWD_DRY', 'MSD', 'SEAL', 'ADV_SKIN',
    'SPEC_BOAT', 'SPEC_DPV', 'SPEC_DSMB', 'SPEC_FFM', 'SPEC_NATURE',
    'SPEC_FISH', 'SPEC_PSD', 'SPEC_SHARK', 'SPEC_CORAL', 'SPEC_ADAPT',
    'SPEC_REBREATHER', 'SPEC_VIDEO', 'SPEC_WRECK',
    'EFR_IT'
  ];
  found_count INT;
BEGIN
  SELECT COUNT(*) INTO found_count
  FROM course_types
  WHERE code = ANY(expected_codes);

  RAISE NOTICE '0077: % of % new course types are present', found_count, array_length(expected_codes, 1);
END $$;
