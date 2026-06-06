-- 06_v_contact_timeline.sql
-- Verifiziert dass v_contact_timeline (Migration 0114) korrekt liefert:
-- - Events des Contacts sind sichtbar
-- - Sortierung respektiert occurred_at DESC am Call-Site
-- - source_table flag korrekt
-- - security_invoker filtert Non-Owner aus
-- Muss als superuser gerunnt werden — direkter auth.users Insert.

BEGIN;
SELECT plan(4);

INSERT INTO auth.users (id, email) VALUES
  ('cccccccc-cccc-cccc-cccc-cccccccccccc', 'c@test.dev');
INSERT INTO public.contacts (id, kind, first_name, last_name) VALUES
  ('33333333-3333-3333-3333-333333333333', 'person', 'TimelineTest', 'T');
INSERT INTO public.contact_instructor (contact_id, auth_user_id) VALUES
  ('33333333-3333-3333-3333-333333333333', 'cccccccc-cccc-cccc-cccc-cccccccccccc');

INSERT INTO public.contact_events (contact_id, event_type, summary, occurred_at)
VALUES
  ('33333333-3333-3333-3333-333333333333', 'note', 'older', '2026-01-01'),
  ('33333333-3333-3333-3333-333333333333', 'call', 'newer', '2026-05-01');

SET LOCAL role = authenticated;
SET LOCAL request.jwt.claims = '{"sub":"cccccccc-cccc-cccc-cccc-cccccccccccc","role":"authenticated"}';

-- Test 1: View liefert nur eigene Events (security_invoker erbt contact_events RLS)
SELECT is(
  (SELECT count(*) FROM public.v_contact_timeline
   WHERE contact_id = '33333333-3333-3333-3333-333333333333' AND source_table = 'contact_events')::int,
  2, 'two events visible for owner'
);

-- Test 2: ORDER BY occurred_at DESC am Call-Site liefert "newer" zuerst
SELECT is(
  (SELECT summary FROM public.v_contact_timeline
   WHERE contact_id = '33333333-3333-3333-3333-333333333333' AND source_table = 'contact_events'
   ORDER BY occurred_at DESC LIMIT 1),
  'newer', 'newer event sorted first when caller orders by occurred_at DESC'
);

-- Test 3: source_table korrekt befüllt für user-logged events
SELECT is(
  (SELECT source_table FROM public.v_contact_timeline
   WHERE summary = 'older'),
  'contact_events', 'source_table flags origin correctly'
);

-- Test 4: security_invoker — Nicht-Owner sieht nix
RESET role;
SET LOCAL role = authenticated;
SET LOCAL request.jwt.claims = '{"sub":"00000000-0000-0000-0000-000000000099","role":"authenticated"}';

SELECT is(
  (SELECT count(*) FROM public.v_contact_timeline
   WHERE contact_id = '33333333-3333-3333-3333-333333333333' AND source_table = 'contact_events')::int,
  0, 'non-owner sees nothing (security_invoker enforces contact_events RLS)'
);

SELECT * FROM finish();
ROLLBACK;
