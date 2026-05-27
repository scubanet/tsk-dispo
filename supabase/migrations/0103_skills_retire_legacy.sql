-- 0103: Retire legacy / no-longer-current Specialty rows.
--
-- The four codes below correspond to specialties PADI has either retired
-- or rolled into other programs, and which the team no longer tracks:
--
--   • spec_scuba_magician — added in 0102, removed: not an active offering.
--   • spec_oxygen_fa      — added in 0102, removed: covered by `eop`
--                           (Emergency Oxygen Provider) under modern PADI
--                           naming, no separate course needed.
--   • spec_multilevel     — added in 0102, removed: retired by PADI.
--   • spec_medic          — original 0002 seed; "Specialty: Medic First
--                           Aid" is no longer issued under PADI.
--
-- `instructor_skills` has ON DELETE CASCADE on skill_id (see 0007), so any
-- prior assignments will be cleaned up automatically. DELETE is idempotent
-- — re-running this migration on an already-clean DB is a no-op.

DELETE FROM public.skills
WHERE code IN (
  'spec_scuba_magician',
  'spec_oxygen_fa',
  'spec_multilevel',
  'spec_medic'
);
