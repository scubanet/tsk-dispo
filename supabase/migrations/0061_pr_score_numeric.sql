-- performance_records.score von INT → NUMERIC(5,2)
--
-- Decimal-Lehrproben (KD/CW/OW im IDC) brauchen Werte wie 3.42 oder 4.65.
-- Die alte INT-Spalte hätte diese auf 3 / 4 abgeschnitten.
-- NUMERIC(5,2) erlaubt -999.99 bis 999.99 — passt für score1to5 (1.00-5.00),
-- score1to5_decimal (1.00-5.00) und percent (0-100).

ALTER TABLE performance_records
  ALTER COLUMN score TYPE NUMERIC(5,2)
  USING score::NUMERIC(5,2);

COMMENT ON COLUMN performance_records.score IS
  '1.00-5.00 für Skill-Circuit/Lehrproben (auch decimal), 0-100 für Prozent, NULL für Pass/Fail.';
