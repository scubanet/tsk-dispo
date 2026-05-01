CREATE TABLE availability (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  instructor_id UUID NOT NULL REFERENCES instructors(id) ON DELETE CASCADE,
  from_date DATE NOT NULL,
  to_date   DATE NOT NULL,
  kind availability_kind NOT NULL,
  note TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (to_date >= from_date)
);

COMMENT ON TABLE availability IS
  'Vacation, illness, or explicit-available windows per instructor.';

CREATE INDEX idx_availability_instr_dates ON availability(instructor_id, from_date, to_date);
