CREATE TABLE account_movements (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  instructor_id UUID NOT NULL REFERENCES instructors(id) ON DELETE RESTRICT,
  date DATE NOT NULL,
  amount_chf NUMERIC(10,2) NOT NULL,
  kind movement_kind NOT NULL,
  ref_assignment_id UUID REFERENCES course_assignments(id) ON DELETE SET NULL,
  description TEXT,
  breakdown_json JSONB,
  rate_version INT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES instructors(id),
  CHECK (amount_chf <> 0 OR kind = 'übertrag')
);

COMMENT ON TABLE account_movements IS
  'Immutable journal of saldo movements. Saldo = SUM(amount_chf) per instructor.';

CREATE INDEX idx_movements_instructor_date ON account_movements(instructor_id, date);
CREATE INDEX idx_movements_kind            ON account_movements(kind);
CREATE INDEX idx_movements_ref_assignment  ON account_movements(ref_assignment_id);

-- Enforce immutability: only INSERT and DELETE allowed (DELETE only via cascade)
CREATE OR REPLACE FUNCTION block_account_movement_update()
RETURNS TRIGGER AS $$
BEGIN
  RAISE EXCEPTION 'account_movements rows are immutable. Insert a correction row instead.';
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_block_movement_update
  BEFORE UPDATE ON account_movements
  FOR EACH ROW EXECUTE FUNCTION block_account_movement_update();
