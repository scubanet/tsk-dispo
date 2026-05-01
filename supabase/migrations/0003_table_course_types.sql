CREATE TABLE course_types (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  code TEXT NOT NULL UNIQUE,
  label TEXT NOT NULL,
  theory_units NUMERIC(5,2) NOT NULL DEFAULT 0,
  pool_units   NUMERIC(5,2) NOT NULL DEFAULT 0,
  lake_units   NUMERIC(5,2) NOT NULL DEFAULT 0,
  ratio_pool   TEXT,
  ratio_lake   TEXT,
  has_elearning BOOLEAN NOT NULL DEFAULT false,
  notes TEXT,
  active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE course_types IS
  'Catalog of course types with their unit-hour breakdown. ' ||
  'Sourced initially from Excel "3 (Kurs-)Entschädigungen".';

-- Seed: derived from Excel "3 (Kurs-)Entschädigungen"
-- Note: total hours are derived (theory + pool + lake) where applicable.
INSERT INTO course_types (code, label, theory_units, pool_units, lake_units, ratio_pool, ratio_lake, has_elearning) VALUES
  ('AOWD',         'AOWD + DAD',                       1.5, 0,  13,   'N.A.', '2:1', true),
  ('BUBB',         'Bubblemaker',                      0.5, 3,  0,    '6:1',  'N.A.', false),
  ('DM',           'Divemaster',                       5,   12, 12,   '5:1',  '4:1', true),
  ('DLD',          'DLD pro Tag',                      0,   0,  2.5,  'N.A.', '2:1', false),
  ('DSD',          'DSD',                              0.5, 3,  0,    '3:1',  'N.A.', true),
  ('EFR',          'EFR',                              4.5, 0,  0,    'N.A.', 'N.A.', true),
  ('EFRI',         'EFR Instructor',                   12,  0,  0,    'N.A.', 'N.A.', false),
  ('BFD',          'Basic Freediver',                  2,   5,  0,    '6:1',  'N.A.', true),
  ('FREE',         'Freediving',                       1,   0,  6,    'N.A.', '4:1', true),
  ('ADVFD',        'Advanced Freediver',               2,   5,  5,    '4:2',  '4:2', true),
  ('OWD',          'OWD eLearning',                    2,   10, 10,   '3:1',  '2:1', true),
  ('REAC',         'Reactivate inkl. See',             0,   3,  2,    '2:1',  'N.A.', true),
  ('RESC',         'Rescue',                           3,   3,  12,   'N.A.', '3:1', true),
  ('SPEC_ALT',     'Specialty: Altitude/Bergsee',      1,   0,  5,    'N.A.', '2:1', false),
  ('SPEC_DEEP',    'Specialty: Deep/Tieftauchen',      1,   0,  10,   'N.A.', '2:1', true),
  ('SPEC_DRIFT',   'Specialty: Drift Diver',           1,   0,  4,    'N.A.', '2:1', false),
  ('DRY',          'Specialty: Dry',                   1,   0,  4,    'N.A.', '2:1', false),
  ('SPEC_EQ',      'Specialty: Equipment',             2,   0,  0,    'N.A.', 'N.A.', false),
  ('SPEC_ICE',     'Specialty: Ice Diving',            1,   0,  4,    'N.A.', '2:1', false),
  ('SPEC_NAVI',    'Specialty: Navigation',            1,   0,  4,    'N.A.', '2:1', false),
  ('SPEC_NIGHT',   'Specialty: Night Diver',           1,   0,  4,    'N.A.', '2:1', false),
  ('EAN',          'Specialty: Nitrox (EAN)',          2,   0,  0,    'N.A.', 'N.A.', true),
  ('SPEC_RIVER',   'Specialty: River & Current',       1,   0,  4,    'N.A.', '4:1', false),
  ('SIDE',         'Specialty: Sidemount',             1,   0,  4,    'N.A.', '2:1', false),
  ('SPEC_SEARCH',  'Specialty: Suchen & Bergen',       1,   0,  4,    'N.A.', '2:1', false),
  ('PPB',          'Specialty: Tarieren Perfektion',   1,   0,  4,    'N.A.', '2:1', false),
  ('SPEC_FOTO',    'Specialty: UW Foto',               1,   3,  4,    '5:1',  '2:1', false),
  ('SELF',         'Specialty: Self Reliant',          1,   0,  4,    'N.A.', '2:1', false),
  ('DAD',          'Specialty: Dive Against Debris',   1,   0,  4,    'N.A.', '2:1', false),
  ('MBP',          'Specialty: MBP',                   1,   0,  4,    'N.A.', '2:1', false),
  ('EOP',          'EOP',                              1,   0,  0,    'N.A.', 'N.A.', false),
  ('SKIN',         'Schnorchelkurs',                   0.5, 1,  0,    'N.A.', 'N.A.', false),
  ('SONST',        'Sonstige Einsätze',                0,   0,  0,    'N.A.', 'N.A.', false);

CREATE INDEX idx_course_types_active ON course_types(active);
