-- 11_m4_trips.sql
-- M4 Trips: Brevet-Sperre blockt Buchung; volle Kapazität → Warteliste;
-- Storno eines festen Platzes rückt den ältesten Wartelistenplatz nach.
BEGIN;
SELECT plan(4);

-- Dispatcher im geseedeten Tenant tsk-zrh.
INSERT INTO auth.users (id, email) VALUES ('b0000000-0000-0000-0000-000000000001', 'm4@test.dev');
INSERT INTO public.contacts (id, kind, first_name, last_name)
  VALUES ('ba000000-0000-0000-0000-000000000001', 'person', 'Disp', 'Atcher');
INSERT INTO public.instructors (id, name, padi_level, initials, role, auth_user_id)
  VALUES ('ba000000-0000-0000-0000-000000000001', 'Disp', 'Instructor', 'DI', 'dispatcher',
          'b0000000-0000-0000-0000-000000000001');
INSERT INTO public.contact_instructor (contact_id, auth_user_id, tenant_id)
  VALUES ('ba000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001',
          (SELECT id FROM public.tenants WHERE slug = 'tsk-zrh'));

-- Tauchplatz mit Mindest-Level AOWD (rank 2)
INSERT INTO public.dive_sites (id, tenant_id, name, min_cert_rank)
SELECT 'b5000000-0000-0000-0000-000000000001', id, 'Tiefes Wrack', 2 FROM public.tenants WHERE slug = 'tsk-zrh';

-- Ausfahrt mit Kapazität 1, Spot verknüpft
INSERT INTO public.trip_departures (id, tenant_id, name, datetime, capacity)
SELECT 'bd000000-0000-0000-0000-000000000001', id, 'Wrack-Tour', now() + interval '7 days', 1
FROM public.tenants WHERE slug = 'tsk-zrh';
INSERT INTO public.trip_departure_sites (id, tenant_id, departure_id, site_id)
SELECT 'b6000000-0000-0000-0000-000000000001', id,
       'bd000000-0000-0000-0000-000000000001', 'b5000000-0000-0000-0000-000000000001'
FROM public.tenants WHERE slug = 'tsk-zrh';

-- Zwei Kunden
INSERT INTO public.contacts (id, kind, first_name, last_name) VALUES
  ('b1000000-0000-0000-0000-000000000001', 'person', 'Ann', 'A'),
  ('b2000000-0000-0000-0000-000000000001', 'person', 'Bob', 'B');

SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claims TO '{"sub":"b0000000-0000-0000-0000-000000000001","role":"authenticated"}';

-- 1) Brevet zu niedrig (OWD=1 < AOWD=2), kein Override → blockt
SELECT throws_ok(
  $$ SELECT public.trip_book('bd000000-0000-0000-0000-000000000001',
        'b1000000-0000-0000-0000-000000000001', 1, false) $$,
  'P0001', NULL, 'Brevet-Sperre blockt Buchung (cert_level_too_low)'
);

-- 2) Ausreichendes Brevet (rank 3) → fester Platz
SELECT public.trip_book('bd000000-0000-0000-0000-000000000001',
       'b1000000-0000-0000-0000-000000000001', 3, false);
SELECT is(
  (SELECT status FROM public.trip_bookings WHERE person_id = 'b1000000-0000-0000-0000-000000000001'),
  'booked', 'Ann gebucht (fester Platz)'
);

-- 3) Kapazität voll → Warteliste
SELECT public.trip_book('bd000000-0000-0000-0000-000000000001',
       'b2000000-0000-0000-0000-000000000001', 3, false);
SELECT is(
  (SELECT status FROM public.trip_bookings WHERE person_id = 'b2000000-0000-0000-0000-000000000001'),
  'waitlisted', 'Bob auf Warteliste (Kapazität voll)'
);

-- 4) Storno Ann → Bob rückt nach
SELECT public.trip_cancel_booking(
  (SELECT id FROM public.trip_bookings WHERE person_id = 'b1000000-0000-0000-0000-000000000001')
);
SELECT is(
  (SELECT status FROM public.trip_bookings WHERE person_id = 'b2000000-0000-0000-0000-000000000001'),
  'booked', 'Bob rückt nach Storno nach'
);

SELECT * FROM finish();
ROLLBACK;
