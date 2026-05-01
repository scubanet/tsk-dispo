-- Helper view: surface saldo-discrepancies for the last import.
-- Excel opening_balance lives on instructors; live balance comes from the view.
-- Diff highlights where manual Excel adjustments diverge from auto-calc.
CREATE OR REPLACE VIEW v_saldo_diff AS
SELECT
  i.id AS instructor_id,
  i.name,
  b.balance_chf AS app_balance,
  i.opening_balance_chf AS excel_opening,
  b.balance_chf - i.opening_balance_chf AS diff
FROM instructors i
LEFT JOIN v_instructor_balance b ON b.instructor_id = i.id
ORDER BY abs(b.balance_chf - i.opening_balance_chf) DESC NULLS LAST;
