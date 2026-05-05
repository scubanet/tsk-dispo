-- Course-Participants: zertifizierender Instructor + Datum
--
-- Wenn ein Schüler im Kurs auf Status 'certified' gesetzt wird, soll erfasst werden,
-- WER ihn zertifiziert hat (Instructor) und WANN. Das ist Basis für die
-- Instructor-Statistik "Ausgestellte Zertifikate pro Level".

ALTER TABLE course_participants
  ADD COLUMN IF NOT EXISTS certified_by_instructor_id UUID REFERENCES instructors(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS certified_on DATE;

CREATE INDEX IF NOT EXISTS idx_cp_certified_by
  ON course_participants(certified_by_instructor_id)
  WHERE certified_by_instructor_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_cp_certified_on
  ON course_participants(certified_on DESC)
  WHERE certified_on IS NOT NULL;

COMMENT ON COLUMN course_participants.certified_by_instructor_id IS
  'Welcher Instructor hat den Schüler zertifiziert. Nur gefüllt wenn status=certified.';
COMMENT ON COLUMN course_participants.certified_on IS
  'Datum der Zertifizierung. Default = Tag des Status-Wechsels.';

-- Stats-View: pro Instructor × Course-Type-Code → Anzahl Zertifizierungen
CREATE OR REPLACE VIEW v_instructor_certifications_by_level AS
SELECT
  cp.certified_by_instructor_id AS instructor_id,
  ct.code  AS level_code,
  ct.label AS level_label,
  COUNT(*) AS count,
  MAX(cp.certified_on) AS most_recent
FROM course_participants cp
JOIN courses c ON c.id = cp.course_id
JOIN course_types ct ON ct.id = c.course_type_id
WHERE cp.status = 'certified'
  AND cp.certified_by_instructor_id IS NOT NULL
GROUP BY cp.certified_by_instructor_id, ct.code, ct.label;

COMMENT ON VIEW v_instructor_certifications_by_level IS
  'Stats: Anzahl ausgestellter Zertifikate pro Instructor × Level. Ein Eintrag pro (instructor, level).';

-- Re-grant SELECT auf View für authenticated (RLS auf base tables ist schon scharf)
GRANT SELECT ON v_instructor_certifications_by_level TO authenticated;
