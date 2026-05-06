-- course_dates: Pool-Reservierungs-Flag pro Kurs-Datum
--
-- Zusätzlich zum pool_location (welcher Pool) brauchen wir den Status, ob der
-- Pool für diesen Tag bereits reserviert/gebucht ist.

ALTER TABLE course_dates
  ADD COLUMN IF NOT EXISTS pool_reserved BOOLEAN NOT NULL DEFAULT false;

COMMENT ON COLUMN course_dates.pool_reserved IS
  'Pool für diesen Kurs-Tag ist bereits reserviert/gebucht. Default false.';
