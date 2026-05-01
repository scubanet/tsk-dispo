-- Recalc all assignment-based compensations with the current (simplified) rates.
--
-- Wirkung:
--   • Alle bestehenden 'vergütung'-Bewegungen die einen Assignment referenzieren
--     werden gelöscht und neu berechnet basierend auf den aktuellen comp_rates
--     und comp_units.
--   • 'übertrag' (Eröffnungssaldi) und 'korrektur' (manuelle Buchungen) bleiben
--     unangetastet.
--
-- Diese Operation ist normalerweise Buchhaltungs-Tabu (rückwirkende Änderung).
-- Hier explizit ein einmaliges Sweep auf User-Wunsch nach Tarif-Vereinheitlichung.

-- 1. Alte vergütung-Bewegungen löschen (alle, die zu einem Assignment gehören)
DELETE FROM account_movements
WHERE kind = 'vergütung' AND ref_assignment_id IS NOT NULL;

-- 2. Frische vergütung-Bewegungen aus den aktuellen Sätzen schreiben.
--    rate_version = 2 markiert sie als "nach Tarif-Vereinheitlichung 2026-05-01".
WITH recalc AS (
  SELECT
    ca.instructor_id,
    c.start_date AS d,
    c.title AS title,
    ca.id AS aid,
    calc_compensation(ca.id) AS breakdown
  FROM course_assignments ca
  JOIN courses c ON c.id = ca.course_id
)
INSERT INTO account_movements (
  instructor_id, date, amount_chf, kind,
  ref_assignment_id, description, breakdown_json, rate_version
)
SELECT
  instructor_id,
  d,
  (breakdown->>'amount_chf')::numeric,
  'vergütung',
  aid,
  title,
  breakdown,
  2
FROM recalc
WHERE (breakdown->>'amount_chf')::numeric <> 0;
