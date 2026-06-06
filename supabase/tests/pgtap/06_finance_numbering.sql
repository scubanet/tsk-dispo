-- 06_finance_numbering.sql
-- next_invoice_number(): pro Tenant monoton, lückenlos, korrekt formatiert
-- (<prefix>-YYYY-NNNNNN). Aufruf als authentifizierter Dispatcher.
BEGIN;
SELECT plan(4);

-- Dispatcher-User im geseedeten Tenant tsk-zrh.
INSERT INTO auth.users (id, email)
  VALUES ('60000000-0000-0000-0000-000000000001', 'disp@test.dev');
INSERT INTO public.contacts (id, kind, first_name, last_name)
  VALUES ('6a000000-0000-0000-0000-000000000001', 'person', 'Disp', 'Atcher');
INSERT INTO public.instructors (id, name, padi_level, initials, role, auth_user_id)
  VALUES ('6a000000-0000-0000-0000-000000000001', 'Disp', 'Instructor', 'DI', 'dispatcher',
          '60000000-0000-0000-0000-000000000001');
-- Phase J (0092) hat den instructors→contact_instructor-Sync entfernt; sidecar
-- mit tenant explizit anlegen (current_tenant_id() liest contact_instructor.tenant_id).
INSERT INTO public.contact_instructor (contact_id, auth_user_id, tenant_id)
  VALUES ('6a000000-0000-0000-0000-000000000001', '60000000-0000-0000-0000-000000000001',
          (SELECT id FROM public.tenants WHERE slug = 'tsk-zrh'));

-- Session des Dispatchers simulieren.
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claims TO '{"sub":"60000000-0000-0000-0000-000000000001","role":"authenticated"}';

SELECT matches(public.next_invoice_number(public.current_tenant_id()),
               '^R-[0-9]{4}-000001$', 'erste Nummer endet auf 000001');
SELECT matches(public.next_invoice_number(public.current_tenant_id()),
               '^R-[0-9]{4}-000002$', 'zweite Nummer 000002 (monoton)');
SELECT matches(public.next_invoice_number(public.current_tenant_id()),
               '^R-[0-9]{4}-000003$', 'dritte Nummer 000003 (lückenlos)');
SELECT is(
  (SELECT last_no FROM public.tenant_counters
    WHERE tenant_id = public.current_tenant_id()
      AND year = EXTRACT(YEAR FROM now())::int),
  3, 'tenant_counters.last_no = 3 nach drei Aufrufen'
);

SELECT * FROM finish();
ROLLBACK;
