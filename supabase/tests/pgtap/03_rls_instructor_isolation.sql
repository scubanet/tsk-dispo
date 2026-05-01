-- Test: Lukas (instructor) sees only his own account_movements, not Annick's
BEGIN;
SELECT plan(2);

INSERT INTO instructors (id, name, padi_level, initials, role, auth_user_id)
VALUES
  ('cccc1111-1111-1111-1111-111111111111', 'Lukas',  'Instructor', 'LB', 'instructor',
    '99999999-9999-9999-9999-999999999991'),
  ('cccc2222-2222-2222-2222-222222222222', 'Annick', 'Instructor', 'AH', 'instructor',
    '99999999-9999-9999-9999-999999999992');

INSERT INTO account_movements (instructor_id, date, amount_chf, kind, description)
VALUES
  ('cccc1111-1111-1111-1111-111111111111', '2026-01-01', 100, 'übertrag', 'Lukas opening'),
  ('cccc2222-2222-2222-2222-222222222222', '2026-01-01', 200, 'übertrag', 'Annick opening');

-- Simulate Lukas's authenticated session
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claims TO '{"sub":"99999999-9999-9999-9999-999999999991","role":"authenticated"}';

SELECT is(
  (SELECT COUNT(*)::int FROM account_movements),
  1,
  'Lukas sees exactly 1 account_movement (his own)'
);

SELECT is(
  (SELECT description FROM account_movements LIMIT 1),
  'Lukas opening',
  'Lukas sees Lukas opening (not Annick opening)'
);

SELECT * FROM finish();
ROLLBACK;
