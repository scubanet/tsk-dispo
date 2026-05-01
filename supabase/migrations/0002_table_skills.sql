CREATE TABLE skills (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  code TEXT NOT NULL UNIQUE,
  label TEXT NOT NULL,
  category TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE skills IS 'PADI specialties and instructor qualifications';

-- Seed: extracted from Excel "4 SkillMatrix" header row
INSERT INTO skills (code, label, category) VALUES
  ('dsd_leader',       'DSD Leader',                'Leadership'),
  ('efr_instr',        'EFR Instructor',            'Leadership'),
  ('efr_train',        'EFR Instructor Trainer',    'Leadership'),
  ('efr_airborne',     'EFR Airborne Pathogens',    'Specialty'),
  ('eop',              'EOP',                       'Specialty'),
  ('spec_dry',         'Specialty: Dry',            'Specialty'),
  ('spec_nitrox',      'Specialty: Nitrox (EAN)',   'Specialty'),
  ('spec_dive_fish',   'Specialty: Dive Against Debris', 'Specialty'),
  ('spec_adaptive',    'Specialty: Adaptive Diver', 'Specialty'),
  ('spec_altitude',    'Specialty: Altitude/Bergsee', 'Specialty'),
  ('spec_aware_shark', 'Specialty: Aware Shark',    'Specialty'),
  ('spec_aware_fish',  'Specialty: Aware Fish ID',  'Specialty'),
  ('spec_aware_coral', 'Specialty: Aware Coral',    'Specialty'),
  ('spec_boat',        'Specialty: Boat Diver',     'Specialty'),
  ('spec_deep',        'Specialty: Deep/Tieftauchen', 'Specialty'),
  ('spec_drift',       'Specialty: Drift Diver',    'Specialty'),
  ('spec_dsmb',        'Specialty: DSMB',           'Specialty'),
  ('spec_equipment',   'Specialty: Equipment Spec.', 'Specialty'),
  ('spec_foto',        'Specialty: UW Foto',        'Specialty'),
  ('spec_ice',         'Specialty: Ice Diving',     'Specialty'),
  ('spec_medic',       'Specialty: Medic First Aid', 'Specialty'),
  ('spec_navi',        'Specialty: Navigation',     'Specialty'),
  ('spec_night',       'Specialty: Night Diver',    'Specialty'),
  ('spec_ppb',         'Specialty: Tarieren in Perfektion (PPB)', 'Specialty'),
  ('spec_river',       'Specialty: River & Current', 'Specialty'),
  ('spec_scooter',     'Specialty: Scooter',        'Specialty'),
  ('spec_search',      'Specialty: Suchen & Bergen', 'Specialty'),
  ('spec_self',        'Specialty: Self Reliant',   'Specialty'),
  ('spec_side',        'Specialty: Sidemount',      'Specialty'),
  ('spec_wreck',       'Specialty: Wreck',          'Specialty'),
  ('tec40',            'Tec40',                     'Tec'),
  ('tec45',            'Tec45',                     'Tec'),
  ('tec50',            'Tec50',                     'Tec'),
  ('tec_gasblend',     'TecRec Gasblender',         'Tec');

CREATE INDEX idx_skills_category ON skills(category);
