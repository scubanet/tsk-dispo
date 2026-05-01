-- Students (Tauchschüler) and their participation in courses.

-- Status enum for participation
DO $$ BEGIN
  CREATE TYPE participant_status AS ENUM ('enrolled', 'certified', 'dropped');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

-- ============================================================
-- students
-- ============================================================
CREATE TABLE IF NOT EXISTS students (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  email TEXT,
  phone TEXT,
  birthday DATE,
  padi_nr TEXT,
  notes TEXT,
  active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE students IS 'Tauchschüler / Kursteilnehmer. Loggen sich nicht selbst ein (verwaltet vom Dispatcher).';

CREATE INDEX IF NOT EXISTS idx_students_name_lower ON students(lower(name));
CREATE INDEX IF NOT EXISTS idx_students_active ON students(active);
CREATE INDEX IF NOT EXISTS idx_students_email ON students(lower(email));

DROP TRIGGER IF EXISTS trg_students_updated_at ON students;
CREATE TRIGGER trg_students_updated_at
  BEFORE UPDATE ON students
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ============================================================
-- course_participants (M:N — Schüler ↔ Kurs)
-- ============================================================
CREATE TABLE IF NOT EXISTS course_participants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  course_id  UUID NOT NULL REFERENCES courses(id)  ON DELETE CASCADE,
  student_id UUID NOT NULL REFERENCES students(id) ON DELETE RESTRICT,
  status participant_status NOT NULL DEFAULT 'enrolled',
  enrolled_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  certificate_nr TEXT,
  notes TEXT,
  UNIQUE (course_id, student_id)
);

COMMENT ON TABLE course_participants IS 'Welche Schüler nehmen an welchem Kurs teil. Status: enrolled / certified / dropped.';

CREATE INDEX IF NOT EXISTS idx_course_participants_course   ON course_participants(course_id);
CREATE INDEX IF NOT EXISTS idx_course_participants_student  ON course_participants(student_id);
CREATE INDEX IF NOT EXISTS idx_course_participants_status   ON course_participants(status);

-- ============================================================
-- RLS — students sind privat, nur Dispatcher schreibt
-- Lesen: alle authentifizierten Nutzer (Instructors müssen sehen wer im Kurs ist)
-- ============================================================
ALTER TABLE students            ENABLE ROW LEVEL SECURITY;
ALTER TABLE course_participants ENABLE ROW LEVEL SECURITY;

CREATE POLICY students_read_all
  ON students FOR SELECT
  USING (auth.uid() IS NOT NULL);

CREATE POLICY students_dispatcher_all
  ON students FOR ALL
  USING (is_dispatcher());

CREATE POLICY participants_read_all
  ON course_participants FOR SELECT
  USING (auth.uid() IS NOT NULL);

CREATE POLICY participants_dispatcher_all
  ON course_participants FOR ALL
  USING (is_dispatcher());

-- ============================================================
-- View: aggregierte Teilnehmerzahl pro Kurs
-- ============================================================
CREATE OR REPLACE VIEW v_course_participant_count AS
SELECT
  course_id,
  COUNT(*) FILTER (WHERE status = 'enrolled')  AS enrolled_count,
  COUNT(*) FILTER (WHERE status = 'certified') AS certified_count,
  COUNT(*) FILTER (WHERE status = 'dropped')   AS dropped_count,
  COUNT(*) AS total_count
FROM course_participants
GROUP BY course_id;
