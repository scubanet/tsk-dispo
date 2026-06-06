-- 12_pos_walk_in_discount.sql
-- (a) Laufkundschaft-Sammelkontakt (Tag walk_in) existiert (Seed-Migration 20260606000300).
-- (b) pos_checkout wendet discount_pct an: Rechnungstotal = Netto nach Rabatt.
-- (c) order_lines.discount_pct wird festgehalten.
BEGIN;
SELECT plan(4);

-- Dispatcher im geseedeten Tenant tsk-zrh (Muster wie 09_m2_inventory).
INSERT INTO auth.users (id, email) VALUES ('c0000000-0000-0000-0000-0000000000d1', 'pos@test.dev');
INSERT INTO public.contacts (id, kind, first_name, last_name)
  VALUES ('ca000000-0000-0000-0000-0000000000d1', 'person', 'Pos', 'Disp');
INSERT INTO public.instructors (id, name, padi_level, initials, role, auth_user_id)
  VALUES ('ca000000-0000-0000-0000-0000000000d1', 'PosDisp', 'OWSI', 'PD', 'dispatcher',
          'c0000000-0000-0000-0000-0000000000d1');
INSERT INTO public.contact_instructor (contact_id, auth_user_id, tenant_id)
  VALUES ('ca000000-0000-0000-0000-0000000000d1', 'c0000000-0000-0000-0000-0000000000d1',
          (SELECT id FROM public.tenants WHERE slug = 'tsk-zrh'));

-- Produkt + Variante (Preis 100) im Tenant tsk-zrh.
INSERT INTO public.products (id, tenant_id, name)
SELECT 'cb000000-0000-0000-0000-0000000000d1', id, 'Rabatt-Maske' FROM public.tenants WHERE slug = 'tsk-zrh';
INSERT INTO public.product_variants (id, tenant_id, product_id, sku, price)
SELECT 'cc000000-0000-0000-0000-0000000000d1', id, 'cb000000-0000-0000-0000-0000000000d1', 'RAB-1', 100
FROM public.tenants WHERE slug = 'tsk-zrh';

-- Kunde für die Rechnung.
INSERT INTO public.contacts (id, kind, first_name, last_name)
  VALUES ('cd000000-0000-0000-0000-0000000000d1', 'person', 'Rab', 'Att');

SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claims TO '{"sub":"c0000000-0000-0000-0000-0000000000d1","role":"authenticated"}';

-- (a) Laufkundschaft-Kontakt existiert (aus der Seed-Migration).
SELECT is(
  (SELECT count(*)::int FROM public.contacts WHERE 'walk_in' = ANY(tags)),
  1, 'genau ein Laufkundschaft-Kontakt mit Tag walk_in'
);

-- (b)+(c) Verkauf 1x CHF 100 mit 25% Rabatt -> Total CHF 75, discount_pct festgehalten.
SELECT lives_ok(
  $$ SELECT public.pos_checkout('cd000000-0000-0000-0000-0000000000d1',
       '[{"item_type":"product","item_ref_id":"cc000000-0000-0000-0000-0000000000d1","description":"Rabatt-Maske","quantity":1,"unit_price":100,"discount_pct":25}]'::jsonb,
       'cash', true) $$,
  'pos_checkout mit Rabatt laeuft'
);
SELECT is(
  (SELECT total FROM public.invoices
    WHERE contact_id = 'cd000000-0000-0000-0000-0000000000d1' ORDER BY created_at DESC LIMIT 1),
  75.00::numeric, 'Rechnungstotal = 100 - 25% = 75'
);
SELECT is(
  (SELECT ol.discount_pct FROM public.order_lines ol
     JOIN public.orders o ON o.id = ol.order_id
    WHERE o.contact_id = 'cd000000-0000-0000-0000-0000000000d1' ORDER BY ol.created_at DESC LIMIT 1),
  25.00::numeric, 'order_lines.discount_pct = 25 festgehalten'
);

SELECT * FROM finish();
ROLLBACK;
