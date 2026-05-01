CREATE TABLE pool_bookings (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  date DATE NOT NULL,
  time_from TIME,
  time_to   TIME,
  location pool_location NOT NULL,
  course_id UUID REFERENCES courses(id) ON DELETE SET NULL,
  note TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (time_to IS NULL OR time_from IS NULL OR time_to > time_from)
);

COMMENT ON TABLE pool_bookings IS
  'Mooesli/Langnau pool slots. course_id NULL means slot is blocked but not yet linked.';

CREATE INDEX idx_pool_date_loc ON pool_bookings(date, location);
CREATE INDEX idx_pool_course   ON pool_bookings(course_id) WHERE course_id IS NOT NULL;
