-- CD-Rolle + erweiterte People-DB + Organizations
--
-- Dies ist Phase 1 der ATOLL × CD App Integration (siehe docs/superpowers/plans/2026-05-03-cd-integration.md).
--
-- WICHTIG: ALTER TYPE ADD VALUE muss separat (eigene Transaction) ausgeführt werden.
-- Daher Migration in 2 Teilen via SQL-Editor anwenden:
--   Teil A: ENUM erweitern  (Zeilen 1-20)
--   Teil B: Rest             (Zeilen ab 22)

-- ============================================================
-- Teil A: ENUM erweitern  (separat ausführen!)
-- ============================================================

ALTER TYPE app_role ADD VALUE IF NOT EXISTS 'cd';

-- ============================================================
-- Teil B: Helper-Functions, students-Erweiterung, organizations
-- ============================================================

-- Helper: ist die Person aktuell als CD eingeloggt?
CREATE OR REPLACE FUNCTION is_cd()
RETURNS BOOLEAN
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM instructors
    WHERE auth_user_id = auth.uid() AND role = 'cd'
  );
$$;

-- Erweitere is_owner_or_dispatcher: CD darf jetzt auch (CD ist superset).
-- Die existing Funktion bleibt — wir fügen 'cd' dazu.
CREATE OR REPLACE FUNCTION is_owner_or_dispatcher()
RETURNS BOOLEAN
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM instructors
    WHERE auth_user_id = auth.uid() AND role IN ('owner', 'dispatcher', 'cd')
  );
$$;

-- Erweitere is_dispatcher: CD ist Superset, darf alles was Dispatcher darf.
CREATE OR REPLACE FUNCTION is_dispatcher()
RETURNS BOOLEAN
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM instructors
    WHERE auth_user_id = auth.uid() AND role IN ('dispatcher', 'cd')
  );
$$;

GRANT EXECUTE ON FUNCTION is_cd() TO authenticated;
GRANT EXECUTE ON FUNCTION is_owner_or_dispatcher() TO authenticated;
GRANT EXECUTE ON FUNCTION is_dispatcher() TO authenticated;

-- ============================================================
-- organizations Tabelle (CRM v2)
-- ============================================================

CREATE TABLE IF NOT EXISTS organizations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name        TEXT NOT NULL,
  kind        TEXT,                                  -- 'dive_club', 'company', 'school', 'agency', etc.
  address     TEXT,
  postal_code TEXT,
  city        TEXT,
  country     TEXT,
  email       TEXT,
  phone       TEXT,
  website     TEXT,
  notes       TEXT,
  active      BOOLEAN NOT NULL DEFAULT true,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_orgs_name ON organizations(name);
CREATE INDEX IF NOT EXISTS idx_orgs_active ON organizations(active);

ALTER TABLE organizations ENABLE ROW LEVEL SECURITY;

-- CD-Modul: nur CD darf editieren/sehen, Owner darf lesen
CREATE POLICY orgs_cd_all       ON organizations FOR ALL    USING (is_cd());
CREATE POLICY orgs_owner_read   ON organizations FOR SELECT USING (is_owner());

-- ============================================================
-- students um CD-Felder erweitern
-- ============================================================

ALTER TABLE students
  ADD COLUMN IF NOT EXISTS address           TEXT NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS postal_code       TEXT NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS city              TEXT NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS country           TEXT NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS photo_url         TEXT,
  ADD COLUMN IF NOT EXISTS pipeline_stage    TEXT NOT NULL DEFAULT 'none',
  ADD COLUMN IF NOT EXISTS lead_source       TEXT NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS tags              TEXT[] NOT NULL DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS languages         TEXT[] NOT NULL DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS organization_id   UUID REFERENCES organizations(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS organization_role TEXT NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS stage_changed_on  TIMESTAMPTZ NOT NULL DEFAULT now(),
  ADD COLUMN IF NOT EXISTS is_candidate      BOOLEAN NOT NULL DEFAULT false;

CREATE INDEX IF NOT EXISTS idx_students_pipeline_stage ON students(pipeline_stage);
CREATE INDEX IF NOT EXISTS idx_students_is_candidate   ON students(is_candidate) WHERE is_candidate;
CREATE INDEX IF NOT EXISTS idx_students_organization   ON students(organization_id);

-- Pipeline-Stage Trigger: bei Änderung stage_changed_on aktualisieren
CREATE OR REPLACE FUNCTION sync_pipeline_stage_changed()
RETURNS TRIGGER AS $$
BEGIN
  IF OLD.pipeline_stage IS DISTINCT FROM NEW.pipeline_stage THEN
    NEW.stage_changed_on := now();
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_sync_pipeline_stage_changed ON students;
CREATE TRIGGER trg_sync_pipeline_stage_changed
  BEFORE UPDATE OF pipeline_stage ON students
  FOR EACH ROW EXECUTE FUNCTION sync_pipeline_stage_changed();

COMMENT ON COLUMN students.is_candidate IS
  'true wenn die Person als DM/IDC/SPEI-Kandidat verwaltet wird (CD-Modul).';
COMMENT ON COLUMN students.pipeline_stage IS
  'CRM-Pipeline-Stage. Werte: none, lead, qualified, opportunity, customer, lost.';
