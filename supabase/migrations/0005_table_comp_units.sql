CREATE TABLE comp_units (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  course_type_id UUID NOT NULL REFERENCES course_types(id) ON DELETE CASCADE,
  role assignment_role NOT NULL,
  theory_h NUMERIC(5,2) NOT NULL DEFAULT 0,
  pool_h   NUMERIC(5,2) NOT NULL DEFAULT 0,
  lake_h   NUMERIC(5,2) NOT NULL DEFAULT 0,
  total_h  NUMERIC(5,2) GENERATED ALWAYS AS (theory_h + pool_h + lake_h) STORED,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (course_type_id, role)
);

COMMENT ON TABLE comp_units IS
  'Hours per course type × role. Editable when TSK changes the comp model.';

-- Seed: derive default per-role hours from course_types defaults.
INSERT INTO comp_units (course_type_id, role, theory_h, pool_h, lake_h)
SELECT id, 'haupt'::assignment_role,  theory_units, pool_units, lake_units FROM course_types;

INSERT INTO comp_units (course_type_id, role, theory_h, pool_h, lake_h)
SELECT id, 'assist'::assignment_role, theory_units, pool_units, lake_units FROM course_types;

INSERT INTO comp_units (course_type_id, role, theory_h, pool_h, lake_h)
SELECT id, 'dmt'::assignment_role,    theory_units, pool_units, lake_units FROM course_types;

CREATE INDEX idx_comp_units_lookup ON comp_units(course_type_id, role);
