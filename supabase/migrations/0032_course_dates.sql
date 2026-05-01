-- course_dates: pro Kursdatum eine Klassifikation (Theorie / Pool / See)
-- und bei Pool-Tagen eine direkte Verbindung zum Pool.
--
-- Die bisherigen courses.start_date + courses.additional_dates bleiben
-- als "Übersicht" erhalten. course_dates ist die detaillierte Source-of-Truth
-- für (date, type, pool). Beim Anlegen/Ändern eines Kurses werden beide
-- parallel synchronisiert (Frontend-Verantwortung).

-- Type per Kursdatum
DO $$ BEGIN
  CREATE TYPE course_date_type AS ENUM ('theorie', 'pool', 'see');
EXCEPTION WHEN duplicate_object THEN null;
END $$;

CREATE TABLE IF NOT EXISTS course_dates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  course_id UUID NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
  date DATE NOT NULL,
  type course_date_type NOT NULL DEFAULT 'theorie',
  pool_location pool_location,
  time_from TIME,
  time_to TIME,
  note TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (pool_location IS NULL OR type = 'pool'),
  CHECK (time_to IS NULL OR time_from IS NULL OR time_to > time_from)
);

COMMENT ON TABLE course_dates IS
  'Per-Datum-Klassifikation eines Kurses (Theorie/Pool/See) inkl. Pool-Verknüpfung.';

CREATE UNIQUE INDEX IF NOT EXISTS idx_course_dates_course_date
  ON course_dates(course_id, date);
CREATE INDEX IF NOT EXISTS idx_course_dates_date
  ON course_dates(date);
CREATE INDEX IF NOT EXISTS idx_course_dates_pool
  ON course_dates(pool_location, date)
  WHERE pool_location IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_course_dates_type
  ON course_dates(type);

-- RLS: alle authentifizierten lesen, nur Dispatcher schreibt
ALTER TABLE course_dates ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS course_dates_read ON course_dates;
CREATE POLICY course_dates_read
  ON course_dates FOR SELECT
  USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS course_dates_dispatcher ON course_dates;
CREATE POLICY course_dates_dispatcher
  ON course_dates FOR ALL
  USING (is_dispatcher());

-- Backfill: für jeden bestehenden Kurs course_dates aus start_date + additional_dates erzeugen
INSERT INTO course_dates (course_id, date, type)
SELECT id, start_date, 'theorie'::course_date_type
FROM courses
ON CONFLICT (course_id, date) DO NOTHING;

INSERT INTO course_dates (course_id, date, type)
SELECT
  c.id,
  (ad.elem)::date,
  'theorie'::course_date_type
FROM courses c
CROSS JOIN LATERAL jsonb_array_elements_text(c.additional_dates) AS ad(elem)
WHERE jsonb_array_length(c.additional_dates) > 0
ON CONFLICT (course_id, date) DO NOTHING;
