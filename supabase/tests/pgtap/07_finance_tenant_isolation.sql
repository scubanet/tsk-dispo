-- 07_finance_tenant_isolation.sql
-- Mandanten-Isolation: Dispatcher A (tsk-zrh) macht einen Verkauf; Dispatcher B
-- (zweiter Tenant) sieht weder die Rechnung noch die Zahlung. Beweist tenant-
-- scoped RLS auf invoices/payments via current_tenant_id().
BEGIN;
SELECT plan(5);

-- Zweiter Tenant
INSERT INTO public.tenants (id, slug, name)
  VALUES ('7e000000-0000-0000-0000-0000000000b1', 'test-b', 'Test B');

-- Dispatcher A (tsk-zrh)
INSERT INTO auth.users (id, email) VALUES ('70000000-0000-0000-0000-0000000000a1', 'a@test.dev');
INSERT INTO public.contacts (id, kind, first_name, last_name)
  VALUES ('7a000000-0000-0000-0000-0000000000a1', 'person', 'Disp', 'A');
INSERT INTO public.instructors (id, name, padi_level, initials, role, auth_user_id)
  VALUES ('7a000000-0000-0000-0000-0000000000a1', 'DispA', 'Instructor', 'DA', 'dispatcher',
          '70000000-0000-0000-0000-0000000000a1');
INSERT INTO public.contact_instructor (contact_id, auth_user_id, tenant_id)
  VALUES ('7a000000-0000-0000-0000-0000000000a1', '70000000-0000-0000-0000-0000000000a1',
          (SELECT id FROM public.tenants WHERE slug = 'tsk-zrh'));

-- Dispatcher B (test-b)
INSERT INTO auth.users (id, email) VALUES ('70000000-0000-0000-0000-0000000000b1', 'b@test.dev');
INSERT INTO public.contacts (id, kind, first_name, last_name)
  VALUES ('7a000000-0000-0000-0000-0000000000b1', 'person', 'Disp', 'B');
INSERT INTO public.instructors (id, name, padi_level, initials, role, auth_user_id)
  VALUES ('7a000000-0000-0000-0000-0000000000b1', 'DispB', 'Instructor', 'DB', 'dispatcher',
          '70000000-0000-0000-0000-0000000000b1');
INSERT INTO public.contact_instructor (contact_id, auth_user_id, tenant_id)
  VALUES ('7a000000-0000-0000-0000-0000000000b1', '70000000-0000-0000-0000-0000000000b1',
          '7e000000-0000-0000-0000-0000000000b1');

-- Kunde von A
INSERT INTO public.contacts (id, kind, first_name, last_name)
  VALUES ('7c000000-0000-0000-0000-0000000000a1', 'person', 'Cust', 'A');

-- A: Verkauf durchführen (Order → Rechnung → Zahlung in einem RPC)
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claims TO '{"sub":"70000000-0000-0000-0000-0000000000a1","role":"authenticated"}';

SELECT lives_ok(
  $$ SELECT public.pos_checkout('7c000000-0000-0000-0000-0000000000a1',
        '[{"description":"Maske","quantity":1,"unit_price":80}]'::jsonb, 'cash', true) $$,
  'A: pos_checkout erstellt Verkauf'
);
SELECT is((SELECT count(*)::int FROM public.invoices), 1, 'A sieht genau 1 Rechnung');
SELECT is((SELECT count(*)::int FROM public.payments), 1, 'A sieht genau 1 Zahlung');

-- B: anderer Tenant — sieht nichts davon
SET LOCAL request.jwt.claims TO '{"sub":"70000000-0000-0000-0000-0000000000b1","role":"authenticated"}';
SELECT is((SELECT count(*)::int FROM public.invoices), 0, 'B sieht 0 Rechnungen (Tenant-Isolation)');
SELECT is((SELECT count(*)::int FROM public.payments), 0, 'B sieht 0 Zahlungen (Tenant-Isolation)');

SELECT * FROM finish();
ROLLBACK;
