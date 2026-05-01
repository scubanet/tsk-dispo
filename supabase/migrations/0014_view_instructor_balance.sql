CREATE OR REPLACE VIEW v_instructor_balance AS
SELECT
  i.id AS instructor_id,
  i.name,
  i.padi_level,
  COALESCE(SUM(am.amount_chf), 0)::NUMERIC(10,2) AS balance_chf,
  MAX(am.date) AS last_movement_date,
  COUNT(am.id) AS movement_count
FROM instructors i
LEFT JOIN account_movements am ON am.instructor_id = i.id
GROUP BY i.id, i.name, i.padi_level;

COMMENT ON VIEW v_instructor_balance IS
  'Live saldo per instructor. Always derived, never stored.';
