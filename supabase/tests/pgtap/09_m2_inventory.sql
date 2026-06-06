-- 09_m2_inventory.sql
-- M2 Retail: Wareneingang erhöht den Bestand, ein POS-Verkauf bucht den Abgang.
-- Beweist die Integration order_lines(item_type='product') → pos_fulfill →
-- inventory_movements → v_inventory_on_hand.
BEGIN;
SELECT plan(4);

-- Dispatcher im geseedeten Tenant tsk-zrh.
INSERT INTO auth.users (id, email) VALUES ('90000000-0000-0000-0000-000000000001', 'm2@test.dev');
INSERT INTO public.contacts (id, kind, first_name, last_name)
  VALUES ('9a000000-0000-0000-0000-000000000001', 'person', 'Disp', 'Atcher');
INSERT INTO public.instructors (id, name, padi_level, initials, role, auth_user_id)
  VALUES ('9a000000-0000-0000-0000-000000000001', 'Disp', 'Instructor', 'DI', 'dispatcher',
          '90000000-0000-0000-0000-000000000001');
INSERT INTO public.contact_instructor (contact_id, auth_user_id, tenant_id)
  VALUES ('9a000000-0000-0000-0000-000000000001', '90000000-0000-0000-0000-000000000001',
          (SELECT id FROM public.tenants WHERE slug = 'tsk-zrh'));

-- Produkt + Variante (nicht-serialisiert) im Tenant tsk-zrh.
INSERT INTO public.products (id, tenant_id, name)
SELECT '9b000000-0000-0000-0000-000000000001', id, 'Maske X' FROM public.tenants WHERE slug = 'tsk-zrh';
INSERT INTO public.product_variants (id, tenant_id, product_id, sku, price)
SELECT '9c000000-0000-0000-0000-000000000001', id, '9b000000-0000-0000-0000-000000000001', 'MSK-X', 80
FROM public.tenants WHERE slug = 'tsk-zrh';

-- Kunde
INSERT INTO public.contacts (id, kind, first_name, last_name)
  VALUES ('9d000000-0000-0000-0000-000000000001', 'person', 'Buy', 'Er');

SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claims TO '{"sub":"90000000-0000-0000-0000-000000000001","role":"authenticated"}';

-- Wareneingang: +5
SELECT public.inventory_adjust('9c000000-0000-0000-0000-000000000001', 5, 'receipt');
SELECT is(
  (SELECT on_hand FROM public.v_inventory_on_hand WHERE variant_id = '9c000000-0000-0000-0000-000000000001'),
  5::numeric, 'on_hand = 5 nach Wareneingang'
);

-- Verkauf von 2 Stück über den POS-Checkout
SELECT lives_ok(
  $$ SELECT public.pos_checkout('9d000000-0000-0000-0000-000000000001',
        '[{"item_type":"product","item_ref_id":"9c000000-0000-0000-0000-000000000001","description":"Maske X","quantity":2,"unit_price":80}]'::jsonb,
        'cash', true) $$,
  'POS-Verkauf von 2 Stück'
);

SELECT is(
  (SELECT on_hand FROM public.v_inventory_on_hand WHERE variant_id = '9c000000-0000-0000-0000-000000000001'),
  3::numeric, 'on_hand = 3 nach Verkauf (5 − 2)'
);

SELECT is(
  (SELECT count(*)::int FROM public.inventory_movements
    WHERE variant_id = '9c000000-0000-0000-0000-000000000001' AND reason = 'sale' AND qty = -2),
  1, 'ein Sale-Abgang von −2 gebucht'
);

SELECT * FROM finish();
ROLLBACK;
