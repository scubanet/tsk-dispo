-- Bezahlung vereinheitlicht auf zwei Sätze:
--   CHF 20/h — DM, AI, Shop Staff
--   CHF 28/h — OWSI, MSDT, IDC Staff, MI, CD
-- 'Andere' bleibt bei CHF 1/h (nominaler Eintrag).

-- Sicherstellen dass für alle aktiven Levels eine comp_rate existiert.
-- Cast nötig weil padi_level ein ENUM-Typ ist (nicht TEXT).
INSERT INTO comp_rates (level, hourly_rate_chf)
SELECT v.level::padi_level, v.rate
FROM (VALUES
  ('DM',         20.00),
  ('AI',         20.00),
  ('OWSI',       28.00),
  ('MSDT',       28.00),
  ('IDC Staff',  28.00),
  ('MI',         28.00),
  ('CD',         28.00),
  ('Shop Staff', 20.00),
  ('Andere',      1.00)
) AS v(level, rate)
WHERE NOT EXISTS (
  SELECT 1 FROM comp_rates cr
  WHERE cr.level = v.level::padi_level AND cr.valid_to IS NULL
);

-- Bestehende Sätze aktualisieren
UPDATE comp_rates
SET hourly_rate_chf = 20.00
WHERE level IN ('DM', 'AI', 'Shop Staff') AND valid_to IS NULL;

UPDATE comp_rates
SET hourly_rate_chf = 28.00
WHERE level IN ('OWSI', 'MSDT', 'IDC Staff', 'MI', 'CD') AND valid_to IS NULL;
