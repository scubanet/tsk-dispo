BEGIN;
SELECT plan(7);

-- All 6 contact tables should have RLS enabled
SELECT is(
  (SELECT relrowsecurity FROM pg_class WHERE relname = 'contacts'),
  true, 'RLS enabled on contacts');

SELECT is(
  (SELECT relrowsecurity FROM pg_class WHERE relname = 'contact_instructor'),
  true, 'RLS enabled on contact_instructor');

SELECT is(
  (SELECT relrowsecurity FROM pg_class WHERE relname = 'contact_student'),
  true, 'RLS enabled on contact_student');

SELECT is(
  (SELECT relrowsecurity FROM pg_class WHERE relname = 'contact_organization'),
  true, 'RLS enabled on contact_organization');

SELECT is(
  (SELECT relrowsecurity FROM pg_class WHERE relname = 'contact_relationships'),
  true, 'RLS enabled on contact_relationships');

SELECT is(
  (SELECT relrowsecurity FROM pg_class WHERE relname = 'contact_audit_log'),
  true, 'RLS enabled on contact_audit_log');

-- contacts should have 4 policies (select/insert/update/delete)
SELECT is(
  (SELECT count(*)::int FROM pg_policies WHERE tablename = 'contacts'),
  4, 'contacts has 4 RLS policies');

SELECT * FROM finish();
ROLLBACK;
