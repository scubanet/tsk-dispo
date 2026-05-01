-- Test: AOWD haupt-instructor compensation = 14.5h × CHF 28 = CHF 406
BEGIN;
SELECT plan(3);

INSERT INTO instructors (id, name, padi_level, initials)
VALUES ('11111111-1111-1111-1111-111111111111', 'Test Inst', 'Instructor', 'TI');

INSERT INTO courses (id, type_id, title, status, start_date)
SELECT '22222222-2222-2222-2222-222222222222', id, 'AOWD Test', 'confirmed', '2026-05-01'
FROM course_types WHERE code = 'AOWD';

INSERT INTO course_assignments (course_id, instructor_id, role, confirmed)
VALUES ('22222222-2222-2222-2222-222222222222',
        '11111111-1111-1111-1111-111111111111',
        'haupt', true);

SELECT is(
  (SELECT COUNT(*)::int FROM account_movements
    WHERE instructor_id = '11111111-1111-1111-1111-111111111111'),
  1,
  'one account_movement created on assignment'
);

SELECT is(
  (SELECT amount_chf FROM account_movements
    WHERE instructor_id = '11111111-1111-1111-1111-111111111111'),
  406.00::numeric,
  'AOWD haupt-instructor amount = 14.5h × CHF 28 = CHF 406'
);

SELECT is(
  (SELECT (breakdown_json->>'total_h')::numeric FROM account_movements
    WHERE instructor_id = '11111111-1111-1111-1111-111111111111'),
  14.5::numeric,
  'breakdown_json.total_h = 14.5'
);

SELECT * FROM finish();
ROLLBACK;
