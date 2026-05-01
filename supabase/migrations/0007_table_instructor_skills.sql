CREATE TABLE instructor_skills (
  instructor_id UUID NOT NULL REFERENCES instructors(id) ON DELETE CASCADE,
  skill_id      UUID NOT NULL REFERENCES skills(id)      ON DELETE CASCADE,
  granted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (instructor_id, skill_id)
);

COMMENT ON TABLE instructor_skills IS
  'Many-to-many between instructors and skills (replaces 35-column matrix in Excel).';

CREATE INDEX idx_iskills_instructor ON instructor_skills(instructor_id);
CREATE INDEX idx_iskills_skill      ON instructor_skills(skill_id);
