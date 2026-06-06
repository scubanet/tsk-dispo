-- 05_finance_immutability.sql
-- Phase-1 Finanzen: unveränderliche Journale lehnen UPDATE ab
-- (block_*_update-Trigger, RAISE EXCEPTION → SQLSTATE P0001).
-- Läuft als superuser (postgres) → RLS umgangen, direkte Inserts möglich.
BEGIN;
SELECT plan(3);

-- Kunde (contacts hat kein tenant); Tenant = geseedetes tsk-zrh.
INSERT INTO public.contacts (id, kind, first_name, last_name)
  VALUES ('f1000000-0000-0000-0000-000000000001', 'person', 'Imm', 'Test');

-- payments: einfügen erlaubt, UPDATE blockiert
INSERT INTO public.payments (id, tenant_id, contact_id, kind, method, amount, status)
SELECT 'f1aa0000-0000-0000-0000-000000000001', t.id,
       'f1000000-0000-0000-0000-000000000001', 'payment', 'cash', 100, 'settled'
FROM public.tenants t WHERE t.slug = 'tsk-zrh';

SELECT throws_ok(
  $$ UPDATE public.payments SET amount = 200
     WHERE id = 'f1aa0000-0000-0000-0000-000000000001' $$,
  'P0001', NULL, 'payments rows are immutable (UPDATE blocked)'
);

-- store_credit_entries
INSERT INTO public.store_credit_entries (id, tenant_id, contact_id, amount, reason)
SELECT 'f1bb0000-0000-0000-0000-000000000001', t.id,
       'f1000000-0000-0000-0000-000000000001', 50, 'gift'
FROM public.tenants t WHERE t.slug = 'tsk-zrh';

SELECT throws_ok(
  $$ UPDATE public.store_credit_entries SET amount = 99
     WHERE id = 'f1bb0000-0000-0000-0000-000000000001' $$,
  'P0001', NULL, 'store_credit_entries rows are immutable (UPDATE blocked)'
);

-- package_redemptions (braucht ein package_purchase)
INSERT INTO public.package_purchases (id, tenant_id, contact_id, units_total)
SELECT 'f1cc0000-0000-0000-0000-000000000001', t.id,
       'f1000000-0000-0000-0000-000000000001', 10
FROM public.tenants t WHERE t.slug = 'tsk-zrh';

INSERT INTO public.package_redemptions (id, tenant_id, package_purchase_id, units)
SELECT 'f1dd0000-0000-0000-0000-000000000001', t.id,
       'f1cc0000-0000-0000-0000-000000000001', 1
FROM public.tenants t WHERE t.slug = 'tsk-zrh';

SELECT throws_ok(
  $$ UPDATE public.package_redemptions SET units = 5
     WHERE id = 'f1dd0000-0000-0000-0000-000000000001' $$,
  'P0001', NULL, 'package_redemptions rows are immutable (UPDATE blocked)'
);

SELECT * FROM finish();
ROLLBACK;
