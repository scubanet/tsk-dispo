-- CD-Modul: eLearning Progress + Intake Checklist
-- Aus CD App Models/ELearningProgress.swift + IntakeChecklist.swift

-- ============================================================
-- elearning_progress
-- ============================================================

CREATE TABLE IF NOT EXISTS elearning_progress (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id   UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
  course_code  TEXT NOT NULL,                          -- 'OWD', 'AOWD', 'DM', 'IDC', 'EFR', etc.
  status       TEXT NOT NULL DEFAULT 'started',        -- 'started', 'in_progress', 'completed'
  progress_pct INT,                                    -- 0-100, falls bekannt
  started_on   DATE,
  completed_on DATE,
  notes        TEXT,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_elearn_student ON elearning_progress(student_id);
CREATE INDEX IF NOT EXISTS idx_elearn_course  ON elearning_progress(course_code);

ALTER TABLE elearning_progress ENABLE ROW LEVEL SECURITY;
CREATE POLICY elearn_cd_all     ON elearning_progress FOR ALL    USING (is_cd());
CREATE POLICY elearn_owner_read ON elearning_progress FOR SELECT USING (is_owner());

-- ============================================================
-- intake_checklists (1:1 zu students)
-- ============================================================

CREATE TABLE IF NOT EXISTS intake_checklists (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id          UUID NOT NULL UNIQUE REFERENCES students(id) ON DELETE CASCADE,

  -- Medical Statement
  medical_received    BOOLEAN NOT NULL DEFAULT false,
  medical_signed      BOOLEAN NOT NULL DEFAULT false,
  medical_doctor_required BOOLEAN NOT NULL DEFAULT false,
  medical_doctor_signed   BOOLEAN NOT NULL DEFAULT false,
  medical_notes       TEXT,

  -- Logbook & Erfahrung
  logbook_seen        BOOLEAN NOT NULL DEFAULT false,
  logbook_dives_count INT,

  -- Identification
  id_seen             BOOLEAN NOT NULL DEFAULT false,
  id_kind             TEXT,                            -- 'passport', 'id_card', 'driving_license'

  -- Insurance
  insurance_proof     BOOLEAN NOT NULL DEFAULT false,
  insurance_provider  TEXT,
  insurance_valid_to  DATE,

  -- Liability Release / Standard Safe Diving Practices etc.
  liability_signed    BOOLEAN NOT NULL DEFAULT false,
  safe_diving_signed  BOOLEAN NOT NULL DEFAULT false,

  notes               TEXT,
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_intake_student ON intake_checklists(student_id);

ALTER TABLE intake_checklists ENABLE ROW LEVEL SECURITY;
CREATE POLICY intake_cd_all     ON intake_checklists FOR ALL    USING (is_cd());
CREATE POLICY intake_owner_read ON intake_checklists FOR SELECT USING (is_owner());

-- updated_at automatisch aktualisieren
CREATE OR REPLACE FUNCTION sync_intake_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_intake_updated_at ON intake_checklists;
CREATE TRIGGER trg_intake_updated_at
  BEFORE UPDATE ON intake_checklists
  FOR EACH ROW EXECUTE FUNCTION sync_intake_updated_at();

COMMENT ON TABLE intake_checklists IS
  'CD-Modul: Aufnahme-Checkliste pro Kandidat (Medical, Logbook, ID, Insurance, Releases).';
