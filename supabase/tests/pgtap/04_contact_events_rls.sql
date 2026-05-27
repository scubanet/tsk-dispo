-- 04_contact_events_rls.sql
-- Verifiziert dass die contact_events_owner Policy aus Migration 0111
-- echte RLS-Isolation enforct: Owner sieht eigene Events, andere nicht.
-- Muss als superuser (postgres) gerunnt werden — direkter Insert in auth.users.

BEGIN;
SELECT plan(6);

-- Setup: zwei Test-User (User A und User B), je ein eigener Contact
-- und je ein Event auf dem eigenen Contact.
INSERT INTO auth.users (id, email)
  VALUES
    ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'a@test.dev'),
    ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'b@test.dev');

-- contacts.kind ist NOT NULL (Migration 0079), und contacts_person_fields_check
-- verlangt bei kind='person' ein last_name.
INSERT INTO public.contacts (id, kind, first_name, last_name)
  VALUES
    ('11111111-1111-1111-1111-111111111111', 'person', 'Alice', 'A'),
    ('22222222-2222-2222-2222-222222222222', 'person', 'Bob',   'B');

INSERT INTO public.contact_instructor (contact_id, auth_user_id)
  VALUES
    ('11111111-1111-1111-1111-111111111111', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
    ('22222222-2222-2222-2222-222222222222', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb');

INSERT INTO public.contact_events (contact_id, event_type, summary)
  VALUES
    ('11111111-1111-1111-1111-111111111111', 'note', 'Alice-Note'),
    ('22222222-2222-2222-2222-222222222222', 'note', 'Bob-Note');

-- Tests 1-3: Alice sieht nur ihr Event (USING-Klausel der Policy)
SET LOCAL role = authenticated;
SET LOCAL request.jwt.claims = '{"sub":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa","role":"authenticated"}';

SELECT is(
  (SELECT count(*) FROM public.contact_events WHERE summary = 'Alice-Note')::int,
  1, 'Alice sees her own event'
);

SELECT is(
  (SELECT count(*) FROM public.contact_events WHERE summary = 'Bob-Note')::int,
  0, 'Alice cannot see Bob event'
);

-- Sanity: Alice sieht genau 1 Event gesamt — beweist dass RLS tatsächlich
-- filtert, nicht nur die WHERE-Klausel der vorigen Tests.
SELECT is(
  (SELECT count(*) FROM public.contact_events)::int,
  1, 'Alice sees exactly 1 event total (RLS engaged, not just WHERE)'
);

-- Test 4: WITH CHECK enforced — Alice darf nicht in Bob's Contact inserten.
SELECT throws_ok(
  $$ INSERT INTO public.contact_events (contact_id, event_type, summary)
     VALUES ('22222222-2222-2222-2222-222222222222', 'note', 'sneaky-from-alice') $$,
  '42501',
  NULL,
  'Alice cannot INSERT event into Bob contact (WITH CHECK enforced)'
);

-- Tests 5+6: Bob sieht nur sein Event
SET LOCAL role = authenticated;
SET LOCAL request.jwt.claims = '{"sub":"bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb","role":"authenticated"}';

SELECT is(
  (SELECT count(*) FROM public.contact_events WHERE summary = 'Bob-Note')::int,
  1, 'Bob sees his own event'
);

SELECT is(
  (SELECT count(*) FROM public.contact_events WHERE summary = 'Alice-Note')::int,
  0, 'Bob cannot see Alice event'
);

SELECT * FROM finish();
ROLLBACK;
