BEGIN;
SELECT plan(5);

-- Setup: two duplicate contacts with same email
INSERT INTO contacts (id, kind, first_name, last_name, primary_email)
VALUES
  ('a0000000-0000-0000-0000-000000000001', 'person', 'Sandra', 'Müller', 's@example.com'),
  ('a0000000-0000-0000-0000-000000000002', 'person', 'Sandra', 'Müller', 's@example.com');

-- 1. find_potential_duplicates returns the email match
SELECT set_has(
  $sub$ SELECT candidate_id FROM find_potential_duplicates(
    'a0000000-0000-0000-0000-000000000001'::uuid) $sub$,
  $exp$ VALUES ('a0000000-0000-0000-0000-000000000002'::uuid) $exp$,
  'find_potential_duplicates returns email match');

-- Setup for merge: instructor sidecar on loser, course assignment FK
INSERT INTO contact_instructor (contact_id) VALUES
  ('a0000000-0000-0000-0000-000000000002');

-- Add a course referencing the loser
INSERT INTO courses (id, title, start_date, status, type_id)
VALUES (
  'c0000000-0000-0000-0000-000000000001',
  'Merge-Test',
  '2026-05-09',
  'tentative',
  (SELECT id FROM course_types LIMIT 1)
);
INSERT INTO course_assignments (course_id, instructor_id, role)
VALUES (
  'c0000000-0000-0000-0000-000000000001',
  'a0000000-0000-0000-0000-000000000002',
  'haupt'
);

-- 2. Execute merge
SELECT merge_contacts(
  'a0000000-0000-0000-0000-000000000001'::uuid,
  'a0000000-0000-0000-0000-000000000002'::uuid
);

-- 3. assignment FK migrated
SELECT is(
  (SELECT instructor_id FROM course_assignments
   WHERE course_id = 'c0000000-0000-0000-0000-000000000001'),
  'a0000000-0000-0000-0000-000000000001'::uuid,
  'merge migrated assignment FK to winner');

-- 4. loser marked merged_into winner
SELECT is(
  (SELECT merged_into_id FROM contacts
   WHERE id = 'a0000000-0000-0000-0000-000000000002'),
  'a0000000-0000-0000-0000-000000000001'::uuid,
  'loser marked merged_into winner');

-- 5. loser archived
SELECT ok(
  (SELECT archived_at IS NOT NULL FROM contacts
   WHERE id = 'a0000000-0000-0000-0000-000000000002'),
  'loser archived');

-- 6. GDPR anonymize keeps id but clears PII
SELECT gdpr_anonymize_contact('a0000000-0000-0000-0000-000000000001'::uuid);
SELECT is(
  (SELECT primary_email FROM contacts
   WHERE id = 'a0000000-0000-0000-0000-000000000001'),
  NULL,
  'GDPR anonymize cleared primary_email');

SELECT * FROM finish();
ROLLBACK;
