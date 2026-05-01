CREATE TABLE instructors (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  padi_nr TEXT,
  padi_level padi_level NOT NULL,
  email TEXT UNIQUE,
  phone TEXT,
  color TEXT NOT NULL DEFAULT '#0A84FF',
  initials TEXT NOT NULL,
  active BOOLEAN NOT NULL DEFAULT true,
  role app_role NOT NULL DEFAULT 'instructor',
  opening_balance_chf NUMERIC(10,2) NOT NULL DEFAULT 0,
  auth_user_id UUID UNIQUE REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (length(initials) BETWEEN 1 AND 4)
);

COMMENT ON TABLE instructors IS
  'TL/DM/Shop staff. auth_user_id is NULL until the person logs in.';

CREATE INDEX idx_instructors_active ON instructors(active);
CREATE INDEX idx_instructors_role   ON instructors(role);
CREATE INDEX idx_instructors_auth   ON instructors(auth_user_id);
CREATE INDEX idx_instructors_name   ON instructors(lower(name));

CREATE TRIGGER trg_instructors_updated_at
  BEFORE UPDATE ON instructors
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
