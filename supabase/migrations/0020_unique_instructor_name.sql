-- Add UNIQUE constraint on instructors.name so the import wizard's
-- ON CONFLICT(name) upsert can match. Required for idempotent re-imports.
ALTER TABLE instructors
  ADD CONSTRAINT instructors_name_key UNIQUE (name);
