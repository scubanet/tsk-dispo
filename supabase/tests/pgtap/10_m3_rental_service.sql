-- 10_m3_rental_service.sql
-- M3 Verleih & Service: Checkout setzt 'out', Checkin 'available';
-- Wartungssperre bei der Ausgabe; Füll-Sperre bei abgelaufener Flaschenprüfung.
BEGIN;
SELECT plan(6);

-- Dispatcher im geseedeten Tenant tsk-zrh.
INSERT INTO auth.users (id, email) VALUES ('a0000000-0000-0000-0000-000000000001', 'm3@test.dev');
INSERT INTO public.contacts (id, kind, first_name, last_name)
  VALUES ('aa000000-0000-0000-0000-000000000001', 'person', 'Disp', 'Atcher');
INSERT INTO public.instructors (id, name, padi_level, initials, role, auth_user_id)
  VALUES ('aa000000-0000-0000-0000-000000000001', 'Disp', 'Instructor', 'DI', 'dispatcher',
          'a0000000-0000-0000-0000-000000000001');
INSERT INTO public.contact_instructor (contact_id, auth_user_id, tenant_id)
  VALUES ('aa000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001',
          (SELECT id FROM public.tenants WHERE slug = 'tsk-zrh'));

-- Kunde
INSERT INTO public.contacts (id, kind, first_name, last_name)
  VALUES ('ac000000-0000-0000-0000-000000000001', 'person', 'Mie', 'Ter');

-- Geräte: ok (Wartung künftig, keine Cert), wartungs-überfällig, Flasche mit abgelaufener Cert.
INSERT INTO public.rental_assets (id, tenant_id, asset_type, label, status, next_service_due, cert_due)
SELECT 'a1000000-0000-0000-0000-000000000001', id, 'regulator', 'Regler OK', 'available', current_date + 30, NULL
FROM public.tenants WHERE slug = 'tsk-zrh';
INSERT INTO public.rental_assets (id, tenant_id, asset_type, label, status, next_service_due)
SELECT 'a2000000-0000-0000-0000-000000000001', id, 'regulator', 'Regler überfällig', 'available', current_date - 1
FROM public.tenants WHERE slug = 'tsk-zrh';
INSERT INTO public.rental_assets (id, tenant_id, asset_type, label, status, cert_due)
SELECT 'a3000000-0000-0000-0000-000000000001', id, 'tank', 'Flasche TÜV abgelaufen', 'available', current_date - 1
FROM public.tenants WHERE slug = 'tsk-zrh';

SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claims TO '{"sub":"a0000000-0000-0000-0000-000000000001","role":"authenticated"}';

-- Checkout des OK-Geräts → Status 'out'
SELECT public.rental_checkout('ac000000-0000-0000-0000-000000000001',
       ARRAY['a1000000-0000-0000-0000-000000000001']::uuid[], NULL, 0);
SELECT is(
  (SELECT status FROM public.rental_assets WHERE id = 'a1000000-0000-0000-0000-000000000001'),
  'out', 'Gerät nach Checkout = out'
);

-- Checkin → zurück auf 'available'
SELECT public.rental_checkin((SELECT id FROM public.rental_agreements WHERE status = 'open' LIMIT 1));
SELECT is(
  (SELECT status FROM public.rental_assets WHERE id = 'a1000000-0000-0000-0000-000000000001'),
  'available', 'Gerät nach Checkin = available'
);

-- Wartungssperre: überfälliges Gerät kann nicht ausgegeben werden
SELECT throws_ok(
  $$ SELECT public.rental_checkout('ac000000-0000-0000-0000-000000000001',
        ARRAY['a2000000-0000-0000-0000-000000000001']::uuid[], NULL, 0) $$,
  'P0001', NULL, 'Wartungssperre blockt Ausgabe (asset_maintenance_overdue)'
);

-- Füll-Sperre: Flasche mit abgelaufener Prüfung darf nicht gefüllt werden
SELECT throws_ok(
  $$ SELECT public.fill_log_create('air', 200, true, 'a3000000-0000-0000-0000-000000000001') $$,
  'P0001', NULL, 'Cert-Sperre blockt Füllung (cylinder_cert_expired)'
);

-- Gültige Füllung (Gerät ohne Cert-Fälligkeit, Check bestanden)
SELECT lives_ok(
  $$ SELECT public.fill_log_create('air', 200, true, 'a1000000-0000-0000-0000-000000000001') $$,
  'gültige Füllung wird protokolliert'
);
SELECT is((SELECT count(*)::int FROM public.fill_logs), 1, 'genau ein Fülleintrag');

SELECT * FROM finish();
ROLLBACK;
