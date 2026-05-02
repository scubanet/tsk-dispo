-- Saldo-Berechnung: nur Vergütungen aus 'completed' Kursen einrechnen.
--
-- Bisher: jeder Vergütungs-Movement zählt sofort beim Anlegen des Assignments.
-- Neu:    Vergütungs-Movements zählen erst, wenn der Kurs auf 'completed' steht.
-- Übertrag und Korrektur sind unberührt (haben keine ref_assignment_id).
--
-- Effekt:
--   • Saldo-Anzeige (TL/DM-Liste, Detail, Mein Saldo) ist konservativer:
--     was noch nicht abgeschlossen ist, wird nicht aufaddiert.
--   • Sobald ein Kurs auf 'completed' wechselt, werden seine Vergütungen
--     im Saldo sichtbar.
--   • Account-Movements selbst bleiben in der Tabelle — wir filtern nur
--     in der View, kein Datenverlust.

CREATE OR REPLACE VIEW v_instructor_balance AS
SELECT
  i.id AS instructor_id,
  i.name,
  i.padi_level,
  COALESCE(SUM(
    CASE
      WHEN am.ref_assignment_id IS NULL THEN am.amount_chf
      WHEN c.status = 'completed' THEN am.amount_chf
      ELSE 0
    END
  ), 0)::NUMERIC(10,2) AS balance_chf,
  MAX(
    CASE
      WHEN am.ref_assignment_id IS NULL THEN am.date
      WHEN c.status = 'completed' THEN am.date
      ELSE NULL
    END
  ) AS last_movement_date,
  COUNT(
    CASE
      WHEN am.ref_assignment_id IS NULL THEN am.id
      WHEN c.status = 'completed' THEN am.id
      ELSE NULL
    END
  ) AS movement_count
FROM instructors i
LEFT JOIN account_movements am ON am.instructor_id = i.id
LEFT JOIN course_assignments ca ON ca.id = am.ref_assignment_id
LEFT JOIN courses c ON c.id = ca.course_id
GROUP BY i.id, i.name, i.padi_level;

COMMENT ON VIEW v_instructor_balance IS
  'Live saldo per instructor. Vergütungen zählen nur, wenn der Kurs auf completed steht. Übertrag und Korrektur immer.';
