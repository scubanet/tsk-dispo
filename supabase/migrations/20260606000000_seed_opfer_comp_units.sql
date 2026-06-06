-- 20260606000000_seed_opfer_comp_units.sql
-- Aus 0047_assignment_roles_opfer_for_rescue.sql ausgelagert.
--
-- Grund: Der Seed verwendet den ENUM-Wert 'opfer', der in 0047 per
-- ALTER TYPE assignment_role ADD VALUE hinzugefügt wird. Postgres verbietet die
-- Verwendung eines neuen Enum-Werts in derselben Transaction (SQLSTATE 55P04).
-- Als eigene Migration läuft der Seed erst, nachdem das ALTER TYPE committet ist
-- → `supabase db reset` bleibt grün. Idempotent (ON CONFLICT).

INSERT INTO comp_units (course_type_id, role, theory_h, pool_h, lake_h)
SELECT id, 'opfer'::assignment_role, 0, 0, 1.5
FROM course_types
WHERE code = 'RESC'
ON CONFLICT (course_type_id, role) DO UPDATE
  SET theory_h = 0, pool_h = 0, lake_h = 1.5;
