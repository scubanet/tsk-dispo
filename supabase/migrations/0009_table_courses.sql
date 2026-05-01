CREATE TABLE courses (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  type_id UUID NOT NULL REFERENCES course_types(id),
  title TEXT NOT NULL,
  status course_status NOT NULL DEFAULT 'tentative',
  start_date DATE NOT NULL,
  additional_dates JSONB NOT NULL DEFAULT '[]'::jsonb,
  num_participants INT NOT NULL DEFAULT 0,
  location TEXT,
  info TEXT,
  notes TEXT,
  pool_booked BOOLEAN NOT NULL DEFAULT false,
  created_by UUID REFERENCES instructors(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (jsonb_typeof(additional_dates) = 'array'),
  CHECK (num_participants >= 0)
);

COMMENT ON TABLE courses IS
  'A planned course event. additional_dates is a JSON array of ISO date strings.';

CREATE INDEX idx_courses_start_date ON courses(start_date);
CREATE INDEX idx_courses_status     ON courses(status);
CREATE INDEX idx_courses_type       ON courses(type_id);

CREATE TRIGGER trg_courses_updated_at
  BEFORE UPDATE ON courses
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
