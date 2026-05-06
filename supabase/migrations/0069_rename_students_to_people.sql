-- Refactor: students → people (zentrale Adressverwaltung)
--
-- Phase-1-Schema-Migration:
--   1. Rename Tabelle students → people
--   2. Neuer Flag is_student (zusätzlich zu is_candidate)
--   3. intake_checklists hängt jetzt an course_participants statt students
--   4. Backwards-Compat-View "students" für noch nicht migrierten Code

-- ============================================================
-- 1. Tabellen-Rename
-- ============================================================

ALTER TABLE students RENAME TO people;

COMMENT ON TABLE people IS
  'Zentrale Personen-Tabelle (vormals students). Schüler, Kandidaten, Kontakte, Org-Mitglieder. Instructors haben eigene Tabelle (mit Saldo/Auth/Vergütung).';

-- ============================================================
-- 2. is_student Flag
-- ============================================================

ALTER TABLE people
  ADD COLUMN IF NOT EXISTS is_student BOOLEAN NOT NULL DEFAULT true;

-- Backfill: Personen ohne Kursteilnahme + ohne is_candidate → is_student=false (reine CRM-Kontakte)
UPDATE people p
   SET is_student = false
 WHERE NOT EXISTS (SELECT 1 FROM course_participants cp WHERE cp.student_id = p.id)
   AND p.is_candidate = false
   AND p.organization_id IS NOT NULL;  -- nur Org-Kontakte umflaggen, alles andere bleibt is_student=true

CREATE INDEX IF NOT EXISTS idx_people_is_student ON people(is_student) WHERE is_student;

COMMENT ON COLUMN people.is_student IS
  'Person ist (potentieller) Tauchschüler. is_candidate=true heisst zusätzlich Kandidat:in für CD-Kurs.';

-- ============================================================
-- 3. intake_checklists an course_participants
-- ============================================================

ALTER TABLE intake_checklists
  ADD COLUMN IF NOT EXISTS course_participant_id UUID REFERENCES course_participants(id) ON DELETE CASCADE;

-- UNIQUE pro course_participant (eine Checkliste pro Kurs-Teilnahme)
CREATE UNIQUE INDEX IF NOT EXISTS uq_intake_course_participant
  ON intake_checklists(course_participant_id)
  WHERE course_participant_id IS NOT NULL;

-- Existing student_id-Constraint von UNIQUE entfernen (war 1:1 zu students)
-- Wir behalten student_id-Spalte als Fallback/Legacy, aber das UNIQUE muss weg
ALTER TABLE intake_checklists DROP CONSTRAINT IF EXISTS intake_checklists_student_id_key;

COMMENT ON COLUMN intake_checklists.course_participant_id IS
  'Pro Kurs-Teilnahme eine eigene Intake-Checkliste. NULL für Legacy-Einträge auf Schüler-Ebene.';
COMMENT ON COLUMN intake_checklists.student_id IS
  'Legacy: 1:1 zum Schüler. Neue Einträge sollten course_participant_id verwenden.';

-- ============================================================
-- 4. Backwards-Compat View
-- ============================================================

-- View "students" zeigt auf people, damit nicht-migrierter Code weiter funktioniert.
-- Updatable weil simpler SELECT *.
CREATE OR REPLACE VIEW students AS SELECT * FROM people;

COMMENT ON VIEW students IS
  'Backwards-Compat-View für vor-Phase-1-Code. Wird in zukünftiger Migration entfernt sobald alle Aufrufer auf "people" umgestellt sind.';
