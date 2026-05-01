-- Add a column to store the Excel "Saldo CHF" at import time, separate from
-- the true opening_balance (Eröffnung from prior year). This allows the
-- saldo-diff view to compare against Excel's recorded final saldo,
-- not against the 2025 carryover.
ALTER TABLE instructors
  ADD COLUMN IF NOT EXISTS excel_saldo_chf NUMERIC(10,2) DEFAULT 0;

COMMENT ON COLUMN instructors.excel_saldo_chf IS
  'Snapshot of "Saldo CHF" column from the Excel import. Used only for diff reporting.';

-- Update v_saldo_diff to compare app_balance vs excel_saldo (col 7),
-- not vs opening_balance (col 3). Diff now means: "movements not yet
-- replayable in App" (e.g., Guru-Bezüge, manual corrections).
CREATE OR REPLACE VIEW v_saldo_diff AS
SELECT
  i.id AS instructor_id,
  i.name,
  b.balance_chf AS app_balance,
  i.excel_saldo_chf AS excel_saldo,
  b.balance_chf - i.excel_saldo_chf AS diff
FROM instructors i
LEFT JOIN v_instructor_balance b ON b.instructor_id = i.id
ORDER BY abs(b.balance_chf - i.excel_saldo_chf) DESC NULLS LAST;
