-- Vorname / Nachname als separate Spalten für instructors + students.
--
-- Strategie: first_name + last_name werden zu Source-of-Truth. `name` bleibt
-- als reguläre Spalte erhalten und wird per Trigger automatisch aus first/last
-- berechnet — so brechen keine bestehenden Queries, Views oder Reports.
--
-- Backwards-compat:
--   • Alter Code der INSERT (name) macht: Trigger splittet name → first/last
--   • Neuer Code der INSERT (first_name, last_name) macht: Trigger setzt name
--   • UPDATE: wer first/last setzt, kriegt name neu berechnet
--             wer name setzt (nur ohne first/last), kriegt first/last gesplittet
--
-- Naming-Edge-Cases (best effort beim Backfill):
--   • "Hans Müller"           → first="Hans", last="Müller"
--   • "Hans Peter Müller"     → first="Hans", last="Peter Müller"
--   • "Cher"                  → first="Cher", last=""
--   • "Hans-Peter Müller"     → first="Hans-Peter", last="Müller"

-- =============================================================
-- Helper Function (shared zwischen instructors + students)
-- =============================================================

CREATE OR REPLACE FUNCTION sync_first_last_name()
RETURNS TRIGGER AS $$
BEGIN
  -- Fall 1: first/last wurden gesetzt → name aus diesen ableiten (source of truth)
  IF (NEW.first_name IS NOT NULL AND NEW.first_name <> '')
     OR (NEW.last_name IS NOT NULL AND NEW.last_name <> '') THEN
    NEW.name := TRIM(BOTH ' ' FROM
                     COALESCE(NEW.first_name, '') || ' ' || COALESCE(NEW.last_name, ''));

  -- Fall 2: nur name wurde gesetzt → in first/last splitten
  ELSIF NEW.name IS NOT NULL AND NEW.name <> '' THEN
    NEW.first_name := split_part(TRIM(NEW.name), ' ', 1);
    NEW.last_name  := COALESCE(
      NULLIF(TRIM(substring(TRIM(NEW.name) from position(' ' in TRIM(NEW.name)) + 1)), ''),
      ''
    );
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION sync_first_last_name() IS
  'Hält first_name + last_name + name in Sync. Source-of-Truth ist first/last sobald gesetzt.';

-- =============================================================
-- INSTRUCTORS
-- =============================================================

ALTER TABLE instructors
  ADD COLUMN IF NOT EXISTS first_name TEXT NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS last_name  TEXT NOT NULL DEFAULT '';

-- Backfill aus existing name (best-effort split)
UPDATE instructors
SET first_name = split_part(TRIM(name), ' ', 1),
    last_name  = COALESCE(
      NULLIF(TRIM(substring(TRIM(name) from position(' ' in TRIM(name)) + 1)), ''),
      ''
    )
WHERE first_name = '' AND name IS NOT NULL;

-- Trigger anhängen
DROP TRIGGER IF EXISTS trg_sync_instructor_name ON instructors;
CREATE TRIGGER trg_sync_instructor_name
  BEFORE INSERT OR UPDATE OF first_name, last_name, name ON instructors
  FOR EACH ROW EXECUTE FUNCTION sync_first_last_name();

-- =============================================================
-- STUDENTS
-- =============================================================

ALTER TABLE students
  ADD COLUMN IF NOT EXISTS first_name TEXT NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS last_name  TEXT NOT NULL DEFAULT '';

UPDATE students
SET first_name = split_part(TRIM(name), ' ', 1),
    last_name  = COALESCE(
      NULLIF(TRIM(substring(TRIM(name) from position(' ' in TRIM(name)) + 1)), ''),
      ''
    )
WHERE first_name = '' AND name IS NOT NULL;

DROP TRIGGER IF EXISTS trg_sync_student_name ON students;
CREATE TRIGGER trg_sync_student_name
  BEFORE INSERT OR UPDATE OF first_name, last_name, name ON students
  FOR EACH ROW EXECUTE FUNCTION sync_first_last_name();

-- =============================================================
-- Indexes für Suche nach Vor-/Nachname
-- =============================================================

CREATE INDEX IF NOT EXISTS idx_instructors_last_name ON instructors(last_name);
CREATE INDEX IF NOT EXISTS idx_students_last_name    ON students(last_name);
