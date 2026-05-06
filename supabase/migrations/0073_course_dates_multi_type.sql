-- course_dates: kombinierbare Tagestypen
--
-- Bisher war `type` ein einzelner Enum-Wert (theorie | pool | see). Realität:
-- ein Tag kann z.B. Theorie + Pool kombinieren. Drei Booleans erlauben das.
-- Das alte `type`-Feld bleibt als "Primary Type" für Backwards-Compat (Anzeige im
-- Calendar, Excel-Import etc.). Im Kurs-Edit-Sheet werden ab jetzt die Booleans
-- als Multi-Select genutzt.

ALTER TABLE course_dates
  ADD COLUMN IF NOT EXISTS has_theory BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS has_pool   BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS has_lake   BOOLEAN NOT NULL DEFAULT false;

-- Backfill aus existing type
UPDATE course_dates SET
  has_theory = (type = 'theorie'),
  has_pool   = (type = 'pool'),
  has_lake   = (type = 'see');

COMMENT ON COLUMN course_dates.has_theory IS 'Tag enthält Theorie-Block.';
COMMENT ON COLUMN course_dates.has_pool   IS 'Tag enthält Pool-Block (mit pool_location + pool_reserved).';
COMMENT ON COLUMN course_dates.has_lake   IS 'Tag enthält See/Freiwasser-Block.';
