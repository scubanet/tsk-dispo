BEGIN;
SELECT plan(6);

-- Setup: create a contact row
INSERT INTO contacts (id, kind, first_name, last_name)
VALUES ('11111111-1111-1111-1111-111111111111', 'person', 'Test', 'User');

-- 1. Audit on INSERT into contacts
SELECT is(
  (SELECT count(*)::int FROM contact_audit_log
   WHERE contact_id = '11111111-1111-1111-1111-111111111111'
     AND operation = 'INSERT' AND table_name = 'contacts'),
  1, 'INSERT logged');

-- 2. updated_at advances on UPDATE (must be > created_at after a slight delay)
PERFORM pg_sleep(0.01);
UPDATE contacts SET notes = 'foo'
 WHERE id = '11111111-1111-1111-1111-111111111111';
SELECT ok(
  (SELECT updated_at > created_at FROM contacts
   WHERE id = '11111111-1111-1111-1111-111111111111'),
  'updated_at trigger advances');

-- 3. Role auto-added when instructor sidecar inserted
INSERT INTO contact_instructor (contact_id)
VALUES ('11111111-1111-1111-1111-111111111111');
SELECT is(
  (SELECT 'instructor' = ANY(roles) FROM contacts
   WHERE id = '11111111-1111-1111-1111-111111111111'),
  true, 'instructor role auto-added on sidecar INSERT');

-- 4. Audit on sidecar INSERT
SELECT is(
  (SELECT count(*)::int FROM contact_audit_log
   WHERE contact_id = '11111111-1111-1111-1111-111111111111'
     AND table_name = 'contact_instructor' AND operation = 'INSERT'),
  1, 'sidecar INSERT logged');

-- 5. Role removed on sidecar DELETE
DELETE FROM contact_instructor
 WHERE contact_id = '11111111-1111-1111-1111-111111111111';
SELECT is(
  (SELECT 'instructor' = ANY(roles) FROM contacts
   WHERE id = '11111111-1111-1111-1111-111111111111'),
  false, 'instructor role auto-removed on sidecar DELETE');

-- 6. UPDATE diff captured in changed_fields
UPDATE contacts SET first_name = 'Changed'
 WHERE id = '11111111-1111-1111-1111-111111111111';
SELECT is(
  (SELECT changed_fields->'first_name'->>'new'
   FROM contact_audit_log
   WHERE contact_id = '11111111-1111-1111-1111-111111111111'
     AND operation = 'UPDATE'
     AND table_name = 'contacts'
     AND changed_fields ? 'first_name'
   ORDER BY changed_at DESC LIMIT 1),
  'Changed', 'UPDATE diff captured in changed_fields');

SELECT * FROM finish();
ROLLBACK;
