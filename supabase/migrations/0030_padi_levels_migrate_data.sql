-- Migrate existing PADI level values to new naming.
-- Must run AFTER 0029 (new enum values added).
--
-- Old → New mapping:
--   'Instructor'       → 'OWSI'
--   'Staff Instructor' → 'OWSI' (archiviert, da Duplikat)
--   'Andere Funktion'  → 'Andere'
--
-- 'DM' und 'Shop Staff' bleiben unverändert.

-- ============================================================
-- comp_rates: erst Duplikate archivieren, dann umbenennen
-- ============================================================

-- Schritt 1: 'Staff Instructor' archivieren (würde sonst mit 'Instructor' → 'OWSI' kollidieren)
UPDATE comp_rates
SET valid_to = CURRENT_DATE
WHERE level = 'Staff Instructor' AND valid_to IS NULL;

-- Schritt 2: 'Instructor' → 'OWSI' (jetzt sicher kein Konflikt)
-- Falls 'OWSI' schon existiert (z.B. aus früherem Teil-Apply), 'Instructor' nur archivieren
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM comp_rates WHERE level = 'OWSI' AND valid_to IS NULL) THEN
    UPDATE comp_rates SET valid_to = CURRENT_DATE
    WHERE level = 'Instructor' AND valid_to IS NULL;
  ELSE
    UPDATE comp_rates SET level = 'OWSI'
    WHERE level = 'Instructor' AND valid_to IS NULL;
  END IF;
END $$;

-- Schritt 3: 'Andere Funktion' → 'Andere' (gleiches Muster)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM comp_rates WHERE level = 'Andere' AND valid_to IS NULL) THEN
    UPDATE comp_rates SET valid_to = CURRENT_DATE
    WHERE level = 'Andere Funktion' AND valid_to IS NULL;
  ELSE
    UPDATE comp_rates SET level = 'Andere'
    WHERE level = 'Andere Funktion' AND valid_to IS NULL;
  END IF;
END $$;

-- ============================================================
-- instructors: Daten umbenennen
-- ============================================================
UPDATE instructors SET padi_level = 'OWSI'
WHERE padi_level IN ('Instructor', 'Staff Instructor');

UPDATE instructors SET padi_level = 'Andere'
WHERE padi_level = 'Andere Funktion';

-- ============================================================
-- Default-Stundensätze für die neuen Levels
-- (editierbar in Supabase SQL oder später via Settings-UI)
-- ============================================================
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
