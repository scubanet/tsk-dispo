-- Add 'level' to students + a separate table for external certifications.

-- ============================================================
-- students.level — current diving level
-- ============================================================
ALTER TABLE students
  ADD COLUMN IF NOT EXISTS level TEXT NOT NULL DEFAULT 'Anfänger';

COMMENT ON COLUMN students.level IS
  'Aktueller Tauchschein-Level. Frei wählbar — typische Werte: Anfänger, Scuba Diver, OWD, AOWD, Rescue Diver, Master Scuba Diver, DM, AI, Instructor, MSDT, IDC Staff, MI, CD.';

-- ============================================================
-- student_certifications — frei eintragbare Tauchschein-History
-- (auch externe / historische Zertifikate, die nicht aus unseren Kursen stammen)
-- ============================================================
CREATE TABLE IF NOT EXISTS student_certifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id UUID NOT NULL REFERENCES students(id) ON DELETE CASCADE,
  certification TEXT NOT NULL,   -- z.B. "OWD", "AOWD", "Rescue Diver", "EFR Provider", "Nitrox"
  issued_date DATE,              -- wann ausgestellt
  issued_by TEXT,                -- "PADI", "SSI", "TSK ZRH", etc.
  certificate_nr TEXT,           -- Schein-Nr falls vorhanden
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE student_certifications IS 'Manuell eingetragene Zertifikate des Schülers — auch externe / historische, unabhängig davon ob der Kurs bei TSK stattfand.';

CREATE INDEX IF NOT EXISTS idx_student_certifications_student
  ON student_certifications(student_id);
CREATE INDEX IF NOT EXISTS idx_student_certifications_date
  ON student_certifications(issued_date DESC);

ALTER TABLE student_certifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY scertif_read_all
  ON student_certifications FOR SELECT
  USING (auth.uid() IS NOT NULL);

CREATE POLICY scertif_dispatcher_all
  ON student_certifications FOR ALL
  USING (is_dispatcher());
