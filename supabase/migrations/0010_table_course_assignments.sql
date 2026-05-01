CREATE TABLE course_assignments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  course_id     UUID NOT NULL REFERENCES courses(id)     ON DELETE CASCADE,
  instructor_id UUID NOT NULL REFERENCES instructors(id) ON DELETE RESTRICT,
  role assignment_role NOT NULL,
  confirmed BOOLEAN NOT NULL DEFAULT false,
  assigned_for_dates JSONB NOT NULL DEFAULT '[]'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (course_id, instructor_id, role),
  CHECK (jsonb_typeof(assigned_for_dates) = 'array')
);

COMMENT ON TABLE course_assignments IS 'Which instructor on which course in which role. assigned_for_dates can be empty array meaning "all dates of the course".';

CREATE INDEX idx_assignments_course     ON course_assignments(course_id);
CREATE INDEX idx_assignments_instructor ON course_assignments(instructor_id);

CREATE TRIGGER trg_assignments_updated_at
  BEFORE UPDATE ON course_assignments
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
