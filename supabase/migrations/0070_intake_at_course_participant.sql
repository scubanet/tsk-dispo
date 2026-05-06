-- Phase 3: Intake-Checkliste an course_participants verankert
--
-- Ein Eintrag in intake_checklists kann jetzt entweder
--   * student_id (Legacy, generisch pro Schüler) ODER
--   * course_participant_id (neu, pro Kurs-Teilnahme)
--
-- gesetzt haben. Das course_participant_id-FK + UNIQUE-Index sind in Migration 0069
-- schon angelegt. Hier nur das NOT NULL auf student_id droppen.

ALTER TABLE intake_checklists
  ALTER COLUMN student_id DROP NOT NULL;

-- Sicherstellen dass wenigstens eines der beiden FK gesetzt ist
ALTER TABLE intake_checklists
  DROP CONSTRAINT IF EXISTS intake_has_subject;
ALTER TABLE intake_checklists
  ADD CONSTRAINT intake_has_subject
  CHECK (student_id IS NOT NULL OR course_participant_id IS NOT NULL);
