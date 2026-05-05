-- Intake-Checklist: IDC-Voraussetzungen erfassen
--
-- Quelle: PADI Course Director Manual — IDC Pre-Requisites
--   1. PADI AI / PADI Instructor / 6 Monate Tauchlehrer-Mitgliedschaft anderswo
--   2. Mind. 18 Jahre alt
--   3. Medical (max. 12 Monate, Arzt-Attest)
--   4. Brevetierter Taucher seit mind. 6 Monaten
--   5. EFR Primary + Secondary Care, max. 24 Monate (oder EFRI / oder HLW-Instructor anderer Org)
--   6. Kopien qualifizierender nicht-PADI Brevets

ALTER TABLE intake_checklists
  ADD COLUMN IF NOT EXISTS min_age_confirmed       BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS instructor_status       TEXT,                              -- 'assistant_instructor' | 'padi_instructor' | 'other_org_6m' | 'none'
  ADD COLUMN IF NOT EXISTS certified_diver_since   DATE,                               -- Punkt 4: muss ≥ 6 Monate her sein
  ADD COLUMN IF NOT EXISTS medical_signed_on       DATE,                               -- Punkt 3: Datum des Arzt-Attests
  ADD COLUMN IF NOT EXISTS efr_completed_on        DATE,                               -- Punkt 5: Datum EFR Primary+Secondary
  ADD COLUMN IF NOT EXISTS efr_kind                TEXT,                               -- 'primary_secondary' | 'efri' | 'hlw_instructor_other'
  ADD COLUMN IF NOT EXISTS non_padi_certs_seen     BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS non_padi_certs_notes    TEXT,                               -- z.B. "OWD/AOWD/Rescue/DM von SDI"
  ADD COLUMN IF NOT EXISTS checked_by_id           UUID REFERENCES instructors(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS checked_on              DATE;

COMMENT ON COLUMN intake_checklists.instructor_status IS
  'Eingangs-Status: assistant_instructor / padi_instructor / other_org_6m / none. Quelle: PADI IDC Pre-Req 1.';
COMMENT ON COLUMN intake_checklists.efr_kind IS
  'Erste-Hilfe-Qualifikation: primary_secondary (EFR-Kurs <24Mt), efri (gegenwärtig EFR Instructor), hlw_instructor_other (HLW-Instructor anderer Org).';
COMMENT ON COLUMN intake_checklists.certified_diver_since IS
  'Datum der ersten Brevetierung. PADI-IDC verlangt ≥ 6 Monate.';
