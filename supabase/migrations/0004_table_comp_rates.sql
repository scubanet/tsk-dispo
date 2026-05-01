CREATE TABLE comp_rates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  level padi_level NOT NULL,
  hourly_rate_chf NUMERIC(8,2) NOT NULL,
  valid_from DATE NOT NULL DEFAULT '2026-01-01',
  valid_to   DATE,
  rate_version INT NOT NULL DEFAULT 1,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (valid_to IS NULL OR valid_to > valid_from)
);

COMMENT ON TABLE comp_rates IS 'CHF/h per PADI level with versioning for retro-safety';

-- Only one active row per level at a time
CREATE UNIQUE INDEX idx_comp_rates_active_level
  ON comp_rates(level)
  WHERE valid_to IS NULL;

-- Seed from Excel "9 Einstellungen"
INSERT INTO comp_rates (level, hourly_rate_chf) VALUES
  ('Instructor',       28.00),
  ('Staff Instructor', 28.00),
  ('DM',               20.00),
  ('Shop Staff',       20.00),
  ('Andere Funktion',   1.00);

-- Helper to fetch the currently-active rate for a level
CREATE OR REPLACE FUNCTION current_rate(p_level padi_level)
RETURNS NUMERIC AS $$
  SELECT hourly_rate_chf
  FROM comp_rates
  WHERE level = p_level AND valid_to IS NULL
  LIMIT 1
$$ LANGUAGE SQL STABLE;
