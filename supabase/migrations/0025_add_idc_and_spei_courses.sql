-- Add IDC + Specialty Instructor (SPEI) course types.
-- Also: install a trigger that auto-creates comp_units rows (haupt/assist/dmt)
-- whenever a new course_type is inserted, so the comp engine has them ready.

-- ============================================================
-- Trigger: auto-create comp_units on new course_type
-- ============================================================
CREATE OR REPLACE FUNCTION ensure_comp_units_for_type()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO comp_units (course_type_id, role, theory_h, pool_h, lake_h)
  VALUES
    (NEW.id, 'haupt'::assignment_role,  NEW.theory_units, NEW.pool_units, NEW.lake_units),
    (NEW.id, 'assist'::assignment_role, NEW.theory_units, NEW.pool_units, NEW.lake_units),
    (NEW.id, 'dmt'::assignment_role,    NEW.theory_units, NEW.pool_units, NEW.lake_units)
  ON CONFLICT (course_type_id, role) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_ensure_comp_units ON course_types;
CREATE TRIGGER trg_ensure_comp_units
  AFTER INSERT ON course_types
  FOR EACH ROW EXECUTE FUNCTION ensure_comp_units_for_type();

COMMENT ON FUNCTION ensure_comp_units_for_type IS
  'Whenever a course_type is inserted, automatically create the 3 comp_units rows for haupt/assist/dmt.';

-- ============================================================
-- IDC — Instructor Development Course
-- ============================================================
INSERT INTO course_types (code, label, theory_units, pool_units, lake_units, ratio_pool, ratio_lake, has_elearning, notes) VALUES
  ('IDC', 'IDC — Instructor Development Course', 30, 12, 12, 'gemäss PADI', 'gemäss PADI', true,
   'Stunden sind Default-Werte und sollten je nach IDC-Programm angepasst werden')
ON CONFLICT (code) DO NOTHING;

-- ============================================================
-- SPEI — Specialty Instructor courses
-- Default: 8h Theorie. "Tauchpraktische" SPEIs zusätzlich 4h See.
-- "Theoretische" SPEIs nur 8h Theorie.
-- Werte können in Settings/SQL angepasst werden.
-- ============================================================

-- Tauchpraktische SPEIs (Theorie 8h + See 4h)
INSERT INTO course_types (code, label, theory_units, pool_units, lake_units, ratio_pool, ratio_lake, has_elearning) VALUES
  ('SPEI_WRECK',          'SPEI Wreck',                            8, 0, 4, 'N.A.', 'gemäss PADI', false),
  ('SPEI_NAV',            'SPEI Underwater Navigator',             8, 0, 4, 'N.A.', 'gemäss PADI', false),
  ('SPEI_SR',             'SPEI Search & Recovery',                8, 0, 4, 'N.A.', 'gemäss PADI', false),
  ('SPEI_NIGHT',          'SPEI Night',                            8, 0, 4, 'N.A.', 'gemäss PADI', false),
  ('SPEI_ICE',            'SPEI Ice',                              8, 0, 4, 'N.A.', 'gemäss PADI', false),
  ('SPEI_DRIFT',          'SPEI Drift',                            8, 0, 4, 'N.A.', 'gemäss PADI', false),
  ('SPEI_DEEP',           'SPEI Deep',                             8, 0, 4, 'N.A.', 'gemäss PADI', false),
  ('SPEI_ALT',            'SPEI Altitude',                         8, 0, 4, 'N.A.', 'gemäss PADI', false),
  ('SPEI_BOAT',           'SPEI Boat',                             8, 0, 4, 'N.A.', 'gemäss PADI', false),
  ('SPEI_VIDEO',          'SPEI Underwater Videographer',          8, 0, 4, 'N.A.', 'gemäss PADI', false),
  ('SPEI_PHOTO',          'SPEI Digital Underwater Photography',   8, 0, 4, 'N.A.', 'gemäss PADI', false),
  ('SPEI_DPV',            'SPEI Diver Propulsion Vehicle',         8, 0, 4, 'N.A.', 'gemäss PADI', false),
  ('SPEI_DRY',            'SPEI Dry Suit',                         8, 0, 4, 'N.A.', 'gemäss PADI', false),
  ('SPEI_DSMB',           'SPEI Delayed Surface Marker Buoy',      8, 0, 4, 'N.A.', 'gemäss PADI', false),
  ('SPEI_FFM',            'SPEI Full Face Mask',                   8, 0, 4, 'N.A.', 'gemäss PADI', false)
ON CONFLICT (code) DO NOTHING;

-- Theoretische SPEIs (nur 8h Theorie)
INSERT INTO course_types (code, label, theory_units, pool_units, lake_units, ratio_pool, ratio_lake, has_elearning) VALUES
  ('SPEI_AWARE_WHALE',    'SPEI Project AWARE Whale Shark Awareness', 8, 0, 0, 'N.A.', 'N.A.', false),
  ('SPEI_NATURE',         'SPEI Underwater Naturalist',               8, 0, 0, 'N.A.', 'N.A.', false),
  ('SPEI_EQ',             'SPEI Equipment Specialist',                8, 0, 0, 'N.A.', 'N.A.', false),
  ('SPEI_FISH',           'SPEI Fish Identification',                 8, 0, 0, 'N.A.', 'N.A.', false),
  ('SPEI_EAN',            'SPEI Enriched Air',                        8, 0, 0, 'N.A.', 'N.A.', false),
  ('SPEI_O2',             'SPEI Emergency Oxygen Provider',           8, 0, 0, 'N.A.', 'N.A.', false),
  ('SPEI_AWARE_SHARK',    'SPEI AWARE Shark and Ray Conservation',    8, 0, 0, 'N.A.', 'N.A.', false),
  ('SPEI_AWARE_CORAL',    'SPEI AWARE Coral Reef Conservation',       8, 0, 0, 'N.A.', 'N.A.', false)
ON CONFLICT (code) DO NOTHING;
