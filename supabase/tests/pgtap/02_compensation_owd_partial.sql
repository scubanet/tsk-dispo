-- Test: OWD course over 5 dates, instructor assigned to 2 dates only
-- Expected: 22h × (2/5) × 28 = 246.40
BEGIN;
SELECT plan(2);

INSERT INTO instructors (id, name, padi_level, initials)
  VALUES ('aaaa1111-1111-1111-1111-111111111111', 'Marjanka', 'Instructor', 'MA');

INSERT INTO courses (id, type_id, title, status, start_date, additional_dates)
SELECT 'bbbb2222-2222-2222-2222-222222222222',
       id,
       'OWD partial test',
       'confirmed',
       '2026-01-12',
       '["2026-01-17","2026-01-18","2026-01-24","2026-01-25"]'::jsonb
FROM course_types WHERE code = 'OWD';

INSERT INTO course_assignments (course_id, instructor_id, role, assigned_for_dates)
VALUES (
  'bbbb2222-2222-2222-2222-222222222222',
  'aaaa1111-1111-1111-1111-111111111111',
  'assist',
  '["2026-01-17","2026-01-18"]'::jsonb
);

SELECT is(
  (SELECT amount_chf FROM account_movements
    WHERE instructor_id = 'aaaa1111-1111-1111-1111-111111111111'),
  246.40::numeric,
  'OWD assist 2-of-5 dates Instructor = 22h × 0.4 × CHF 28 = CHF 246.40'
);

SELECT is(
  (SELECT (breakdown_json->>'share')::numeric FROM account_movements
    WHERE instructor_id = 'aaaa1111-1111-1111-1111-111111111111'),
  0.4000::numeric,
  'breakdown.share = 0.4'
);

SELECT * FROM finish();
ROLLBACK;
