-- Migrate existing PADI level values to new naming.
-- Must run AFTER 0029 (new enum values added).
--
-- Old → New mapping:
--   'Instructor'       → 'OWSI'
--   'Staff Instructor' → 'OWSI'  (oder MSDT/MI/CD je nach individueller Person — manuell anpassen)
--   'Andere Funktion'  → 'Andere'
--
-- 'DM' und 'Shop Staff' bleiben unverändert.

UPDATE instructors SET padi_level = 'OWSI'
WHERE padi_level IN ('Instructor', 'Staff Instructor');

UPDATE instructors SET padi_level = 'Andere'
WHERE padi_level = 'Andere Funktion';

UPDATE comp_rates SET level = 'OWSI'
WHERE level IN ('Instructor', 'Staff Instructor');

UPDATE comp_rates SET level = 'Andere'
WHERE level = 'Andere Funktion';

-- Default-Stundensätze für die neuen Levels.
-- Werte sind editierbar in Settings (sobald Comp-Units-UI gebaut ist) oder per SQL.
INSERT INTO comp_rates (level, hourly_rate_chf)
SELECT 'AI', 24.00
WHERE NOT EXISTS (SELECT 1 FROM comp_rates WHERE level = 'AI' AND valid_to IS NULL);

INSERT INTO comp_rates (level, hourly_rate_chf)
SELECT 'MSDT', 30.00
WHERE NOT EXISTS (SELECT 1 FROM comp_rates WHERE level = 'MSDT' AND valid_to IS NULL);

INSERT INTO comp_rates (level, hourly_rate_chf)
SELECT 'MI', 32.00
WHERE NOT EXISTS (SELECT 1 FROM comp_rates WHERE level = 'MI' AND valid_to IS NULL);

INSERT INTO comp_rates (level, hourly_rate_chf)
SELECT 'CD', 35.00
WHERE NOT EXISTS (SELECT 1 FROM comp_rates WHERE level = 'CD' AND valid_to IS NULL);
