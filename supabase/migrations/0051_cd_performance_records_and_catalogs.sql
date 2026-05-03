-- CD-Modul: Performance Records + PADI PR Catalogs
-- Aus CD App Models/PerformanceRecord.swift + pr-catalogs/*.json

-- ============================================================
-- pr_catalogs (PADI Standards als JSON pro Course-Type × Sprache)
-- ============================================================

CREATE TABLE IF NOT EXISTS pr_catalogs (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  course_type  TEXT NOT NULL,                          -- 'DM', 'IDC', 'SPEI', 'EFRI'
  language     TEXT NOT NULL DEFAULT 'de',             -- 'de', 'en'
  version      TEXT NOT NULL,                          -- semver oder Date-String
  data         JSONB NOT NULL,                         -- ganzer Katalog (slots, skills, prereqs, scoreSchema)
  active       BOOLEAN NOT NULL DEFAULT true,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (course_type, language, version)
);

-- Nur ein aktiver Katalog pro (course_type, language)
CREATE UNIQUE INDEX IF NOT EXISTS idx_pr_catalogs_active
  ON pr_catalogs(course_type, language)
  WHERE active;

ALTER TABLE pr_catalogs ENABLE ROW LEVEL SECURITY;
-- Kataloge sind read-only für CD und Owner. Updates passieren via Migration/Seed.
CREATE POLICY catalog_cd_read    ON pr_catalogs FOR SELECT USING (is_cd());
CREATE POLICY catalog_owner_read ON pr_catalogs FOR SELECT USING (is_owner());
-- Edit nur via SQL/Migration durch Service-Role.

COMMENT ON TABLE pr_catalogs IS
  'PADI Performance-Requirement-Kataloge pro Course-Type × Sprache. Source: CD App pr-catalogs/*.json.';

-- ============================================================
-- performance_records
-- ============================================================
-- Ein PR-Eintrag pro (Kandidat, Kurs, PR-Code). Optional verknüpft mit Session.

CREATE TABLE IF NOT EXISTS performance_records (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id       UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
  course_id        UUID NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
  course_date_id   UUID REFERENCES course_dates(id) ON DELETE SET NULL,  -- optional: bei welchem Kurs-Tag abgehakt
  pr_code          TEXT NOT NULL,                      -- Match auf pr_catalogs.data → slots[].skills[].code
  status           TEXT NOT NULL DEFAULT 'not_started', -- 'not_started', 'in_progress', 'completed', 'remediation'
  score            INT,                                 -- 1-5 für Skill-Circuit, 0-100 für Prozent, NULL für Pass/Fail
  pass             BOOLEAN,                             -- für reine Pass/Fail-PRs
  assessed_on      DATE,
  assessed_by_id   UUID REFERENCES instructors(id) ON DELETE SET NULL,
  assessed_by_text TEXT,                                -- falls assessor nicht in instructors-Tabelle ist
  notes            TEXT,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now(),

  -- Ein PR pro Kandidat × Kurs × Code (Updates statt Duplikate).
  UNIQUE (student_id, course_id, pr_code)
);

CREATE INDEX IF NOT EXISTS idx_pr_student      ON performance_records(student_id);
CREATE INDEX IF NOT EXISTS idx_pr_course       ON performance_records(course_id);
CREATE INDEX IF NOT EXISTS idx_pr_status       ON performance_records(status);
CREATE INDEX IF NOT EXISTS idx_pr_assessed_on  ON performance_records(assessed_on DESC);

ALTER TABLE performance_records ENABLE ROW LEVEL SECURITY;
CREATE POLICY pr_cd_all     ON performance_records FOR ALL    USING (is_cd());
CREATE POLICY pr_owner_read ON performance_records FOR SELECT USING (is_owner());

-- updated_at trigger
CREATE OR REPLACE FUNCTION sync_pr_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_pr_updated_at ON performance_records;
CREATE TRIGGER trg_pr_updated_at
  BEFORE UPDATE ON performance_records
  FOR EACH ROW EXECUTE FUNCTION sync_pr_updated_at();

COMMENT ON TABLE performance_records IS
  'CD-Modul: PR-Check-Off pro (Kandidat × Kurs × PR-Code). Source: CD App Models/PerformanceRecord.swift.';
