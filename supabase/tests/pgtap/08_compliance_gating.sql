-- 08_compliance_gating.sql
-- check_compliance() sperrt 'course_enroll', bis die Pflicht-Checks gesetzt sind.
-- Nutzt die in Migration 7 geseedeten requirement_types + gates für tsk-zrh
-- (medical, liability, safe_diving — alle blocking).
BEGIN;
SELECT plan(3);

INSERT INTO auth.users (id, email) VALUES ('80000000-0000-0000-0000-000000000001', 'cd@test.dev');
INSERT INTO public.contacts (id, kind, first_name, last_name)
  VALUES ('8a000000-0000-0000-0000-000000000001', 'person', 'Disp', 'Atcher');
INSERT INTO public.instructors (id, name, padi_level, initials, role, auth_user_id)
  VALUES ('8a000000-0000-0000-0000-000000000001', 'Disp', 'Instructor', 'DI', 'dispatcher',
          '80000000-0000-0000-0000-000000000001');
INSERT INTO public.contact_instructor (contact_id, auth_user_id, tenant_id)
  VALUES ('8a000000-0000-0000-0000-000000000001', '80000000-0000-0000-0000-000000000001',
          (SELECT id FROM public.tenants WHERE slug = 'tsk-zrh'));

-- Einzuschreibender Schüler
INSERT INTO public.contacts (id, kind, first_name, last_name)
  VALUES ('8c000000-0000-0000-0000-000000000001', 'person', 'Stud', 'Ent');

SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claims TO '{"sub":"80000000-0000-0000-0000-000000000001","role":"authenticated"}';

-- Anfangs: 3 blockende Pflicht-Checks fehlen
SELECT is(
  (SELECT count(*)::int
     FROM public.check_compliance('8c000000-0000-0000-0000-000000000001', 'course_enroll')
    WHERE state <> 'ok' AND blocking),
  3, '3 blockende Checks fehlen vor Erfassung'
);

-- Medical setzen → nur noch 2 offen
SELECT public.compliance_set('8c000000-0000-0000-0000-000000000001', 'medical');
SELECT is(
  (SELECT count(*)::int
     FROM public.check_compliance('8c000000-0000-0000-0000-000000000001', 'course_enroll')
    WHERE state <> 'ok' AND blocking),
  2, 'nach Medical noch 2 offen'
);

-- Rest setzen → alle Gates erfüllt
SELECT public.compliance_set('8c000000-0000-0000-0000-000000000001', 'liability');
SELECT public.compliance_set('8c000000-0000-0000-0000-000000000001', 'safe_diving');
SELECT is(
  (SELECT count(*)::int
     FROM public.check_compliance('8c000000-0000-0000-0000-000000000001', 'course_enroll')
    WHERE state <> 'ok' AND blocking),
  0, 'alle Pflicht-Checks erfüllt → keine Sperre'
);

SELECT * FROM finish();
ROLLBACK;
