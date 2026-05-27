# Phase G — Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Datenmodell-Foundation für das Contacts-CRM-Redesign — neue Tabelle `contact_events`, Owner-Helper, unified View `v_contact_timeline`, Saved-Views-Tabelle, plus die TanStack-Query-Hooks. Keine UI-Änderungen in dieser Phase — nur das Fundament, auf dem Phasen 2-6 stehen.

**Architecture:** Hybrid event storage. User-geloggte Events (Notiz/Anruf/Mail/Meeting/Task/WhatsApp) leben in dedizierter `contact_events`-Tabelle. System-Events (Kurse, Saldo, Pipeline-Wechsel, Zertifikate, Skill-Checks, Card-Lead-Imports, Audit) bleiben in ihren Source-Tables. View `v_contact_timeline` unioniert beides für den Read-Pfad. RLS scoped per contact owner.

**Tech Stack:** Supabase Postgres (Migrations + RLS + PgTAP) · React 18 + TypeScript · TanStack Query · Vitest · libphonenumber-js (für Phone-Felder).

**Builds on:** [Spec 2026-05-27-contacts-crm-redesign.md](../specs/2026-05-27-contacts-crm-redesign.md)

---

## File Structure

**SQL-Migrationen** (numerisch, nach existierenden 0109; **erweitert nach Schema-Audit von Task 0**):
- `supabase/migrations/0110_contact_events.sql` — Tabelle + Indexe + RLS
- `supabase/migrations/0111_is_contact_owner.sql` — Helper-Function + RLS-Policy
- `supabase/migrations/0112_pipeline_stage_changes.sql` — **NEU** History-Tabelle + Trigger + Backfill aus `contact_audit_log`
- `supabase/migrations/0113_v_contact_balance.sql` — **NEU** Saldo-View für unified Contacts (Sibling zu `v_instructor_balance`)
- `supabase/migrations/0114_v_contact_timeline.sql` — UNION-View (war 0112; nach neuen Migrationen umnummeriert)
- `supabase/migrations/0115_contact_saved_views.sql` — Saved-Views-Tabelle + RLS (war 0113)

**PgTAP-Tests:**
- `supabase/tests/pgtap/04_contact_events_rls.sql` — RLS-Isolation auf `contact_events`
- `supabase/tests/pgtap/05_pipeline_stage_changes.sql` — Trigger fires + RLS-Visibility
- `supabase/tests/pgtap/06_v_contact_timeline.sql` — View-Korrektheit

**Web-App (TypeScript):**
- `apps/web/src/types/contactEvents.ts` — TypeScript-Types für Events
- `apps/web/src/lib/contactEventQueries.ts` — CRUD-Funktionen (Supabase-Calls)
- `apps/web/src/lib/__tests__/contactEventQueries.test.ts` — Vitest
- `apps/web/src/hooks/useContactTimeline.ts` — paginierter Contact-Feed
- `apps/web/src/hooks/__tests__/useContactTimeline.test.ts` — Vitest
- `apps/web/src/hooks/useGlobalActivity.ts` — globaler Aktivitäts-Feed
- `apps/web/src/hooks/useEventComposer.ts` — Mutations (insert/update/delete)
- `apps/web/src/hooks/useContactSavedViews.ts` — Saved-Views-CRUD

**Doku:**
- `docs/superpowers/plans/2026-05-27-phase-g-foundation-schema-audit-notes.md` — Output von Task 0

---

## Tasks

### Task 0: Schema-Audit (Verifikation, keine Code-Änderungen)

Bevor wir Migrationen schreiben, beantworten wir die sechs Phase-1-Schema-Audit-Fragen aus dem Spec §13. Output: ein kurzes Markdown-Dokument mit konkreten Antworten pro Frage.

**Files:**
- Create: `docs/superpowers/plans/2026-05-27-phase-g-foundation-schema-audit-notes.md`

- [ ] **Step 1: Verify `course_participants` ist die kanonische Tabelle für Kurs-Einschreibungen**

Run:
```bash
grep -n "CREATE TABLE.*course_participants" supabase/migrations/*.sql
grep -nE "course_participants.*REFERENCES" supabase/migrations/*.sql | head -20
grep -nE "ALTER TABLE.*course_participants" supabase/migrations/*.sql | head -20
```

Expected: Definition in `0027_students_and_participants.sql`. Notiere im Audit-Doc: aktuelle FK-Spalte (`student_id`? `contact_id`? nach Phase-F1-Migration umgebogen?) und welche Spalten für Timeline-Summary nötig sind (`course_id`, `created_at`).

- [ ] **Step 2: Pipeline-Stage-History — eigene Tabelle oder via Audit-Log?**

Run:
```bash
grep -n "sync_pipeline_stage_changed" supabase/migrations/*.sql
grep -rEn "CREATE TABLE.*(pipeline_history|pipeline_log|pipeline_stage_history)" supabase/migrations/
```

Expected: Trigger-Definition in `0048_cd_role_and_people_extend.sql`. Wenn keine dedizierte History-Tabelle existiert: notieren dass eine in Phase 1 mit angelegt werden muss (`pipeline_stage_changes` mit Spalten `contact_id, from_stage, to_stage, changed_at, changed_by`).

- [ ] **Step 3: Saldo-View für unified Contacts**

Run:
```bash
grep -n "CREATE.*VIEW.*balance" supabase/migrations/*.sql
grep -n "instructor_balance" supabase/migrations/*.sql | head -5
```

Expected: `instructor_balance` aus `0014_view_instructor_balance.sql`. Notieren ob nach Phase F1 bereits `contact_balance` existiert (parallel definiert) — falls nein, wird er in Task 5 (Migration 0113) gebaut.

- [ ] **Step 4: Intake-Checklist-Detail-Tabelle**

Run:
```bash
grep -n "CREATE TABLE.*intake" supabase/migrations/*.sql
grep -nA 30 "CREATE TABLE.*intake_checklists" supabase/migrations/0050_cd_elearning_and_intake.sql | head -40
```

Expected: `intake_checklists` plus ggf. eine Sub-Tabelle für Einzel-Checkpoints. Notieren: ob Checkpoints als Zeilen oder JSONB-Array gespeichert sind. Bestimmt UNION-SELECT-Struktur in Task 6 (View-Migration 0114).

- [ ] **Step 5: Audit-Log-Schema**

Run:
```bash
grep -nA 30 "CREATE TABLE.*audit_log" supabase/migrations/0079_contacts_schema.sql
```

Expected: Spalten-Layout. Notieren: welche Spalte hält den geänderten Feldnamen (`field`/`column_name`/`changed_field`?), wie heisst der vorher/nachher Werte-Schema. Bestimmt WHERE-Klausel für `role_change` und `audit_edit` Events.

- [ ] **Step 6: Owner-Helper existiert schon?**

Run:
```bash
grep -rn "CREATE OR REPLACE FUNCTION.*is_contact_owner\|CREATE FUNCTION.*is_contact_owner" supabase/migrations/
grep -rn "contact_instructor" supabase/migrations/ | head -10
```

Expected: Falls noch nicht vorhanden, in Task 2 neu anlegen. Falls vorhanden: Signatur kopieren und in Migration 0111 nur ggf. `GRANT EXECUTE` ergänzen.

- [ ] **Step 7: Audit-Doc schreiben**

Schreibe `docs/superpowers/plans/2026-05-27-phase-g-foundation-schema-audit-notes.md` mit den Antworten zu allen sechs Fragen oben (je 2-5 Zeilen Antwort, exact Spaltennamen).

- [ ] **Step 8: Commit**

```bash
cd ~/Desktop/Developer/Dispo
git add docs/superpowers/plans/2026-05-27-phase-g-foundation-schema-audit-notes.md
git commit -m 'docs(phase-g): schema audit notes — basis für migrations 0110-0115'
```

---

### Task 1: Migration 0110 — `contact_events` Tabelle + Indexe + RLS-Enable

**Files:**
- Create: `supabase/migrations/0110_contact_events.sql`

- [ ] **Step 1: Migration-Datei schreiben**

```sql
-- 0110_contact_events.sql
-- ─────────────────────────────────────────────────────────────────
-- Phase G Foundation: dedizierte Tabelle für user-logged Events
-- (Notiz, Anruf, Mail-Zusammenfassung, Meeting, Task, WhatsApp-Log).
-- System-Events bleiben in ihren Source-Tables; die View
-- v_contact_timeline (Migration 0114) unioniert beides.
-- Spec: docs/superpowers/specs/2026-05-27-contacts-crm-redesign.md §8.1
-- ─────────────────────────────────────────────────────────────────

CREATE TABLE public.contact_events (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  contact_id   UUID NOT NULL REFERENCES public.contacts(id) ON DELETE CASCADE,
  event_type   TEXT NOT NULL CHECK (event_type IN (
    'note', 'call', 'email_external', 'meeting_past', 'task', 'whatsapp_log'
  )),
  occurred_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  actor_id     UUID REFERENCES public.contacts(id) ON DELETE SET NULL,
  summary      TEXT NOT NULL,
  body         TEXT,
  payload      JSONB,
  status       TEXT NOT NULL DEFAULT 'open'
    CHECK (status IN ('open', 'resolved', 'archived')),
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_contact_events_contact_occurred
  ON public.contact_events(contact_id, occurred_at DESC);

CREATE INDEX idx_contact_events_actor_occurred
  ON public.contact_events(actor_id, occurred_at DESC)
  WHERE actor_id IS NOT NULL;

CREATE INDEX idx_contact_events_open_tasks
  ON public.contact_events(contact_id, (payload->>'due_date'))
  WHERE event_type = 'task' AND status = 'open';

ALTER TABLE public.contact_events ENABLE ROW LEVEL SECURITY;

-- Note: RLS-Policy contact_events_owner kommt in Migration 0111 nachdem
-- is_contact_owner() Helper definiert ist.
```

- [ ] **Step 2: Lokal anwenden**

Run:
```bash
cd ~/Desktop/Developer/Dispo
supabase migration up
```

Expected: Migration 0110 ohne Fehler durchgelaufen. Optional verifizieren:
```bash
supabase db reset --linked  # falls Schema-Drift
```

- [ ] **Step 3: Smoke-Test in Supabase-Studio (oder psql)**

Run via Supabase-Dashboard SQL-Editor:
```sql
INSERT INTO public.contact_events (contact_id, event_type, summary, body)
VALUES ('00000000-0000-0000-0000-000000000000', 'note', 'test', 'hello');
```

Expected: Fehler **„violates foreign key constraint" auf contact_id** (weil 0000... kein echter Contact ist). Genau das ist gewünscht — beweist FK funktioniert.

Wieder löschen:
```sql
-- (kein DELETE nötig — Insert failed)
```

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/0110_contact_events.sql
git commit -m 'feat(db): contact_events table + indexes (Phase G Foundation)'
```

---

### Task 2: Migration 0111 — `is_contact_owner()` Helper + RLS-Policy

**Files:**
- Create: `supabase/migrations/0111_is_contact_owner.sql`

Wenn Task 0 Step 6 zeigte dass `is_contact_owner()` schon existiert, überspringe die Function-Definition und füge nur die Policy hinzu.

- [ ] **Step 1: Migration schreiben**

```sql
-- 0111_is_contact_owner.sql
-- ─────────────────────────────────────────────────────────────────
-- Phase G Foundation: Owner-Helper + RLS-Policy für contact_events.
-- Pattern analog zu is_card_owner aus Migration 0097.
-- ─────────────────────────────────────────────────────────────────

-- Helper: ist der eingeloggte User der "Owner" dieses Contacts?
-- Nach Phase F1 ist contact_instructor das Linking zwischen contacts.id
-- und auth.users.id.
CREATE OR REPLACE FUNCTION public.is_contact_owner(p_contact_id UUID)
RETURNS BOOLEAN
LANGUAGE SQL STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.contact_instructor
    WHERE contact_id = p_contact_id
      AND auth_user_id = auth.uid()
  );
$$;

GRANT EXECUTE ON FUNCTION public.is_contact_owner(UUID) TO authenticated;

-- RLS-Policy für contact_events: nur Owner liest/schreibt eigene Events.
CREATE POLICY contact_events_owner ON public.contact_events
  FOR ALL TO authenticated
  USING (public.is_contact_owner(contact_id))
  WITH CHECK (public.is_contact_owner(contact_id));
```

- [ ] **Step 2: Anwenden**

Run:
```bash
supabase migration up
```

Expected: ohne Fehler.

- [ ] **Step 3: Smoke-Test**

Im Supabase-Studio als eingeloggter Test-User (oder via SQL-Editor mit set request.jwt.claims):
```sql
SELECT public.is_contact_owner(
  (SELECT id FROM contacts LIMIT 1)
);
```

Expected: `true` für eigene Contacts, `false` für fremde.

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/0111_is_contact_owner.sql
git commit -m 'feat(db): is_contact_owner helper + RLS policy for contact_events'
```

---

### Task 3: PgTAP-Test für `contact_events`-RLS

**Files:**
- Create: `supabase/tests/pgtap/04_contact_events_rls.sql`

- [ ] **Step 1: Test schreiben**

```sql
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
```

- [ ] **Step 2: Test ausführen**

Run:
```bash
cd supabase/tests/pgtap && ./run.sh 04_contact_events_rls.sql
```

Expected: `ok 1 - Alice sees her own event` ... 6 ok. Falls eine fehlschlägt: zurück zu Migration 0111, RLS-Definition prüfen.

- [ ] **Step 3: Commit**

```bash
git add supabase/tests/pgtap/04_contact_events_rls.sql
git commit -m 'test(db): pgtap RLS isolation for contact_events'
```

---

### Task 4: Migration 0112 — `pipeline_stage_changes` Tabelle + Trigger + Backfill

Per Audit (§2): es gibt keine History-Tabelle für Pipeline-Stage-Wechsel. Der alte Trigger (gedroppt in 0092) und der neue Ersatz (0091) updaten nur `stage_changed_on`. Diese Migration baut eine eigene History-Tabelle, hängt einen Trigger an `contact_student` an, und backfillt aus `contact_audit_log`.

**Files:**
- Create: `supabase/migrations/0112_pipeline_stage_changes.sql`
- Create: `supabase/tests/pgtap/05_pipeline_stage_changes.sql`

- [ ] **Step 1: Migration schreiben**

```sql
-- 0112_pipeline_stage_changes.sql
-- ─────────────────────────────────────────────────────────────────
-- Phase G Foundation: History-Tabelle für Pipeline-Stage-Wechsel.
-- Bisher wurden Stage-Changes nur in contact_audit_log gespiegelt
-- (JSON-Diff in changed_fields). Diese Tabelle macht sie explizit
-- abfragbar — wichtig für die v_contact_timeline View (Migration 0114).
-- Spec: §13 Q2, Audit-Doc §2.
-- ─────────────────────────────────────────────────────────────────

CREATE TABLE public.pipeline_stage_changes (
  id           BIGSERIAL PRIMARY KEY,
  contact_id   UUID NOT NULL REFERENCES public.contacts(id) ON DELETE CASCADE,
  from_stage   TEXT,
  to_stage     TEXT,
  changed_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  changed_by   UUID  -- nullable, no FK (audit pattern, contact_audit_log gleicher Stil)
);

CREATE INDEX idx_pipeline_stage_changes_contact_changed
  ON public.pipeline_stage_changes(contact_id, changed_at DESC);

ALTER TABLE public.pipeline_stage_changes ENABLE ROW LEVEL SECURITY;

CREATE POLICY pipeline_stage_changes_owner ON public.pipeline_stage_changes
  FOR SELECT TO authenticated
  USING (public.is_contact_owner(contact_id));

-- Trigger: schreibt eine Zeile pro Stage-Wechsel an contact_student.
-- Behält Side-Effect der bestehenden tg_contact_student_stage_changed
-- aus 0091 nicht — die feuert weiterhin separat und updated stage_changed_on.
CREATE OR REPLACE FUNCTION public.log_pipeline_stage_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF OLD.pipeline_stage IS DISTINCT FROM NEW.pipeline_stage THEN
    INSERT INTO public.pipeline_stage_changes (
      contact_id, from_stage, to_stage, changed_by
    ) VALUES (
      NEW.contact_id, OLD.pipeline_stage, NEW.pipeline_stage, auth.uid()
    );
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER tg_log_pipeline_stage_change
  AFTER UPDATE OF pipeline_stage ON public.contact_student
  FOR EACH ROW
  WHEN (OLD.pipeline_stage IS DISTINCT FROM NEW.pipeline_stage)
  EXECUTE FUNCTION public.log_pipeline_stage_change();

-- Backfill aus contact_audit_log: alle bisherigen Stage-Changes.
-- Pattern: table_name='contact_student', operation='UPDATE',
-- changed_fields ? 'pipeline_stage'.
INSERT INTO public.pipeline_stage_changes (contact_id, from_stage, to_stage, changed_at, changed_by)
SELECT
  cal.contact_id,
  cal.changed_fields->'pipeline_stage'->>'old' AS from_stage,
  cal.changed_fields->'pipeline_stage'->>'new' AS to_stage,
  cal.changed_at,
  cal.changed_by
FROM public.contact_audit_log cal
WHERE cal.table_name = 'contact_student'
  AND cal.operation  = 'UPDATE'
  AND cal.changed_fields ? 'pipeline_stage';
```

- [ ] **Step 2: Anwenden**

Run:
```bash
supabase migration up
```

Expected: Migration läuft ohne Fehler. Backfill-Zahl loggt automatisch (Postgres logged `INSERT 0 N`).

- [ ] **Step 3: Smoke-Test**

Im Supabase-Studio:
```sql
-- Wie viele historische Stage-Changes wurden backfilled?
SELECT count(*) FROM public.pipeline_stage_changes;

-- Beispiel-Zeilen anschauen
SELECT contact_id, from_stage, to_stage, changed_at
FROM public.pipeline_stage_changes
ORDER BY changed_at DESC LIMIT 10;

-- Trigger-Test: ändere eine Stage und prüfe ob neue Zeile entsteht
UPDATE public.contact_student
SET pipeline_stage = 'qualified'
WHERE contact_id = (SELECT contact_id FROM public.contact_student LIMIT 1)
  AND pipeline_stage != 'qualified';

SELECT * FROM public.pipeline_stage_changes ORDER BY changed_at DESC LIMIT 1;
-- Expected: gerade entstandene Zeile mit aktuellem timestamp
```

- [ ] **Step 4: PgTAP-Test**

```sql
-- 05_pipeline_stage_changes.sql
BEGIN;
SELECT plan(3);

INSERT INTO auth.users (id, email)
  VALUES ('dddddddd-dddd-dddd-dddd-dddddddddddd', 'd@test.dev');
INSERT INTO public.contacts (id, first_name)
  VALUES ('44444444-4444-4444-4444-444444444444', 'StageTest');
INSERT INTO public.contact_instructor (contact_id, auth_user_id)
  VALUES ('44444444-4444-4444-4444-444444444444', 'dddddddd-dddd-dddd-dddd-dddddddddddd');
INSERT INTO public.contact_student (contact_id, pipeline_stage)
  VALUES ('44444444-4444-4444-4444-444444444444', 'lead');

-- Test 1: Trigger feuert bei Stage-Wechsel
UPDATE public.contact_student
SET pipeline_stage = 'qualified'
WHERE contact_id = '44444444-4444-4444-4444-444444444444';

SELECT is(
  (SELECT count(*) FROM public.pipeline_stage_changes
   WHERE contact_id = '44444444-4444-4444-4444-444444444444')::int,
  1, 'trigger inserted one row after stage change'
);

-- Test 2: from/to_stage korrekt
SELECT is(
  (SELECT from_stage || '→' || to_stage FROM public.pipeline_stage_changes
   WHERE contact_id = '44444444-4444-4444-4444-444444444444'),
  'lead→qualified', 'from/to_stage captured correctly'
);

-- Test 3: RLS — Nicht-Owner sieht nichts
SET LOCAL request.jwt.claims = '{"sub":"00000000-0000-0000-0000-000000000099","role":"authenticated"}';
SET LOCAL role = authenticated;

SELECT is(
  (SELECT count(*) FROM public.pipeline_stage_changes
   WHERE contact_id = '44444444-4444-4444-4444-444444444444')::int,
  0, 'non-owner sees nothing via RLS'
);

SELECT * FROM finish();
ROLLBACK;
```

- [ ] **Step 5: Test ausführen**

Run:
```bash
cd supabase/tests/pgtap && ./run.sh 05_pipeline_stage_changes.sql
```

Expected: 3 ok.

- [ ] **Step 6: Commit**

```bash
git add supabase/migrations/0112_pipeline_stage_changes.sql supabase/tests/pgtap/05_pipeline_stage_changes.sql
git commit -m 'feat(db): pipeline_stage_changes history table + trigger + backfill'
```

---

### Task 5: Migration 0113 — `v_contact_balance` View

Per Audit (§3): `v_instructor_balance` existiert (legacy, Edge-Functions lesen noch davon), `v_contact_balance` nicht. Diese Migration baut den unified Saldo-View — `account_movements.instructor_id` ist UUID-identisch mit `contacts.id` (kein FK-Rewrite nötig).

**Files:**
- Create: `supabase/migrations/0113_v_contact_balance.sql`

- [ ] **Step 1: Migration schreiben**

```sql
-- 0113_v_contact_balance.sql
-- ─────────────────────────────────────────────────────────────────
-- Phase G Foundation: Saldo-View für unified Contacts.
-- Sibling zu v_instructor_balance (0014/0039) — Logik 1:1 portiert,
-- aber JOIN über contacts statt instructors. account_movements.instructor_id
-- speichert UUIDs die auch in contacts(id) leben (Phase F1 unified ID-Space).
-- Legacy v_instructor_balance bleibt vorerst — Edge-Functions lesen noch davon.
-- Spec: §5.2 Stat-Band "Saldo". Audit-Doc §3.
-- ─────────────────────────────────────────────────────────────────

CREATE OR REPLACE VIEW public.v_contact_balance AS
SELECT
  c.id                  AS contact_id,
  c.display_name,
  ci.padi_level,
  COALESCE(SUM(
    CASE
      WHEN am.ref_assignment_id IS NULL THEN am.amount_chf
      WHEN cr.status = 'completed'      THEN am.amount_chf
      ELSE 0
    END
  ), 0)::NUMERIC(10,2)  AS balance_chf,
  MAX(am.movement_date) AS last_movement_date,
  COUNT(am.id)          AS movement_count
FROM public.contacts c
JOIN public.contact_instructor ci ON ci.contact_id = c.id
LEFT JOIN public.account_movements  am ON am.instructor_id      = c.id
LEFT JOIN public.course_assignments ca ON ca.id                 = am.ref_assignment_id
LEFT JOIN public.courses            cr ON cr.id                 = ca.course_id
GROUP BY c.id, c.display_name, ci.padi_level;

ALTER VIEW public.v_contact_balance SET (security_invoker = on);
GRANT SELECT ON public.v_contact_balance TO authenticated;

-- v_instructor_balance bleibt unangetastet (legacy Edge-Functions).
-- Deprecation-Marker:
COMMENT ON VIEW public.v_instructor_balance IS
  'DEPRECATED — use v_contact_balance. Kept for legacy Edge-Functions still reading via instructor_id.';
```

- [ ] **Step 2: Anwenden + smoke-test**

Run:
```bash
supabase migration up
```

Im Supabase-Studio:
```sql
-- Saldo-Tile-Quelle: zeigt View Daten für einen aktiven Instructor?
SELECT contact_id, display_name, balance_chf, last_movement_date, movement_count
FROM public.v_contact_balance
ORDER BY ABS(balance_chf) DESC
LIMIT 5;

-- Quervergleich mit Legacy (sollte deckungsgleich sein für instructors)
SELECT
  ib.instructor_id  AS legacy_id,
  ib.balance_chf    AS legacy_balance,
  cb.balance_chf    AS new_balance,
  ib.balance_chf - cb.balance_chf AS diff
FROM public.v_instructor_balance ib
JOIN public.v_contact_balance    cb ON cb.contact_id = ib.instructor_id
WHERE ABS(ib.balance_chf - cb.balance_chf) > 0.01;
```

Expected: zweite Query liefert 0 Zeilen (Salden stimmen überein).

- [ ] **Step 3: Commit**

```bash
git add supabase/migrations/0113_v_contact_balance.sql
git commit -m 'feat(db): v_contact_balance view (sibling to legacy v_instructor_balance)'
```

---

### Task 6: Migration 0114 — `v_contact_timeline` View (incremental)

Wir bauen den View **schrittweise**: zuerst nur mit `contact_events` (User-Logs), dann mit jedem System-Event-UNION dazu. Jeder Schritt einzeln testbar.

**Files:**
- Create: `supabase/migrations/0114_v_contact_timeline.sql`
- Create: `supabase/tests/pgtap/06_v_contact_timeline.sql`

- [ ] **Step 1: View-Skelett mit nur contact_events**

```sql
-- 0114_v_contact_timeline.sql (V1 — minimal)
-- ─────────────────────────────────────────────────────────────────
-- Phase G Foundation: unified read-side timeline view.
-- Erste Version: nur contact_events (User-Logs).
-- System-Event-UNIONs kommen schrittweise in den nächsten Steps dazu.
-- ─────────────────────────────────────────────────────────────────

CREATE OR REPLACE VIEW public.v_contact_timeline AS
SELECT
  e.id                  AS event_id,
  e.contact_id,
  e.event_type,
  e.occurred_at,
  e.actor_id            AS actor_contact_id,
  e.summary,
  e.body,
  e.payload,
  e.status,
  'contact_events'::text AS source_table,
  e.id                  AS source_id
FROM public.contact_events e;

ALTER VIEW public.v_contact_timeline SET (security_invoker = on);
GRANT SELECT ON public.v_contact_timeline TO authenticated;
```

- [ ] **Step 2: View anwenden + smoke-test**

Run:
```bash
supabase migration up
```

Im Supabase-Studio:
```sql
INSERT INTO public.contact_events (contact_id, event_type, summary)
SELECT id, 'note', 'view-test' FROM public.contacts LIMIT 1;

SELECT event_id, contact_id, event_type, source_table
FROM public.v_contact_timeline
WHERE summary = 'view-test';
-- → cleanup:
DELETE FROM public.contact_events WHERE summary = 'view-test';
```

Expected: 1 Zeile mit `source_table = 'contact_events'`.

- [ ] **Step 3: System-Event UNION — Kurs-Teilnahmen ergänzen**

Per Audit (§1): `course_participants.student_id` enthält `contacts(id)` (Spaltenname behielt `student_id` aus Legacy, FK wurde in 0092 auf `contacts(id)` retargeted).

Migration 0114 erweitern (CREATE OR REPLACE, also überschreiben):

```sql
CREATE OR REPLACE VIEW public.v_contact_timeline AS
-- User-logged events
SELECT
  e.id                  AS event_id,
  e.contact_id,
  e.event_type,
  e.occurred_at,
  e.actor_id            AS actor_contact_id,
  e.summary,
  e.body,
  e.payload,
  e.status,
  'contact_events'::text AS source_table,
  e.id                  AS source_id
FROM public.contact_events e

UNION ALL

-- System: course participations
-- cp.student_id zeigt auf contacts(id) (Spaltenname legacy, Inhalt unified)
SELECT
  cp.id                                   AS event_id,
  cp.student_id                           AS contact_id,
  'course_enrollment'::text               AS event_type,
  cp.enrolled_at                          AS occurred_at,
  NULL::uuid                              AS actor_contact_id,
  'Eingeschrieben in ' || c.code          AS summary,
  NULL::text                              AS body,
  jsonb_build_object(
    'course_id', cp.course_id,
    'course_code', c.code,
    'status', cp.status
  )                                       AS payload,
  'open'::text                            AS status,
  'course_participants'::text             AS source_table,
  cp.id                                   AS source_id
FROM public.course_participants cp
JOIN public.courses c ON c.id = cp.course_id;

ALTER VIEW public.v_contact_timeline SET (security_invoker = on);
GRANT SELECT ON public.v_contact_timeline TO authenticated;
```

Re-apply:
```bash
supabase migration up
```

Smoke-test im Studio:
```sql
SELECT event_type, count(*) FROM public.v_contact_timeline GROUP BY event_type;
```

Expected: `note: N`, `course_enrollment: M` (M = anzahl tatsächlicher Teilnahmen in deiner DB).

- [ ] **Step 4: System-Events einzeln ergänzen — konkrete Source-Tables nach Audit**

Pro Source-Table einen UNION-Block analog zu Step 3. Reihenfolge (Audit-§§ in Klammern):

1. **`certifications`** (Migration 0028) — Brevet-Erteilungen. event_type `certification_issued`, occurred_at via `certified_on`.
2. **`account_movements`** (Migration 0012) — Saldo-Bewegungen. event_type `saldo_movement`. `am.instructor_id` UUID matcht `contacts.id` (Audit §3).
3. **`pipeline_stage_changes`** (NEU in Migration 0112). event_type `pipeline_change`. Summary „<from_stage> → <to_stage>".
4. **`intake_checklists`** (Audit §4) — Coarse-Approach: ein Event pro Update der ganzen Checkliste, mit `updated_at` als `occurred_at`, `student_id` als `contact_id`, summary „Intake-Checkliste aktualisiert", payload mit allen booleschen Flags. Keine per-Checkpoint-Granularität bis audit_triggers extended sind.
5. **`padi_skill_records`** (Migration 0090) — Skill-Checks.
6. **`card_leads`** mit `imported_contact_id IS NOT NULL` (Migration 0105) — Lead-Imports. `imported_contact_id` als `contact_id`.
7. **`contact_audit_log`** (Audit §5 — Tabelle heisst `contact_audit_log`, NICHT `audit_log`!) gefiltert:
   - **Role-Changes:** `WHERE operation IN ('INSERT','DELETE') AND table_name IN ('contact_instructor','contact_student','contact_organization')`. Rolle abgeleitet aus `table_name`.
   - **PII-Edits:** `WHERE operation = 'UPDATE' AND table_name = 'contacts'`. Geänderte Felder aus `jsonb_object_keys(changed_fields)`.

Für jeden Block:
- Schreibe den UNION-SELECT
- Re-applye Migration
- Smoke-test mit `SELECT event_type, count(*) ... GROUP BY event_type`
- Verifiziere dass die Zahl plausibel ist

- [ ] **Step 5: PgTAP-Test für View-Korrektheit**

```sql
-- 06_v_contact_timeline.sql
BEGIN;
SELECT plan(4);

INSERT INTO auth.users (id, email) VALUES
  ('cccccccc-cccc-cccc-cccc-cccccccccccc', 'c@test.dev');
INSERT INTO public.contacts (id, first_name) VALUES
  ('33333333-3333-3333-3333-333333333333', 'TimelineTest');
INSERT INTO public.contact_instructor (contact_id, auth_user_id) VALUES
  ('33333333-3333-3333-3333-333333333333', 'cccccccc-cccc-cccc-cccc-cccccccccccc');

INSERT INTO public.contact_events (contact_id, event_type, summary, occurred_at)
VALUES
  ('33333333-3333-3333-3333-333333333333', 'note', 'older', '2026-01-01'),
  ('33333333-3333-3333-3333-333333333333', 'call', 'newer', '2026-05-01');

SET LOCAL request.jwt.claims = '{"sub":"cccccccc-cccc-cccc-cccc-cccccccccccc","role":"authenticated"}';
SET LOCAL role = authenticated;

-- Test 1: View liefert nur eigene Events
SELECT is(
  (SELECT count(*) FROM public.v_contact_timeline
   WHERE contact_id = '33333333-3333-3333-3333-333333333333')::int,
  2, 'two events visible for owner'
);

-- Test 2: ORDER BY occurred_at DESC liefert "newer" zuerst
SELECT is(
  (SELECT summary FROM public.v_contact_timeline
   WHERE contact_id = '33333333-3333-3333-3333-333333333333'
   ORDER BY occurred_at DESC LIMIT 1),
  'newer', 'newer event sorted first'
);

-- Test 3: source_table korrekt befüllt
SELECT is(
  (SELECT source_table FROM public.v_contact_timeline
   WHERE summary = 'older'),
  'contact_events', 'source_table flags origin correctly'
);

-- Test 4: security_invoker — Nicht-Owner sieht nix
RESET role;
SET LOCAL request.jwt.claims = '{"sub":"00000000-0000-0000-0000-000000000099","role":"authenticated"}';
SET LOCAL role = authenticated;

SELECT is(
  (SELECT count(*) FROM public.v_contact_timeline
   WHERE contact_id = '33333333-3333-3333-3333-333333333333')::int,
  0, 'non-owner sees nothing (security_invoker)'
);

SELECT * FROM finish();
ROLLBACK;
```

- [ ] **Step 6: Test ausführen**

Run:
```bash
cd supabase/tests/pgtap && ./run.sh 06_v_contact_timeline.sql
```

Expected: 4 ok.

- [ ] **Step 7: Commit**

```bash
git add supabase/migrations/0114_v_contact_timeline.sql supabase/tests/pgtap/06_v_contact_timeline.sql
git commit -m 'feat(db): v_contact_timeline view + pgtap correctness tests'
```

---

### Task 7: Migration 0115 — `contact_saved_views` Tabelle + RLS

**Files:**
- Create: `supabase/migrations/0115_contact_saved_views.sql`

- [ ] **Step 1: Migration schreiben**

```sql
-- 0115_contact_saved_views.sql
-- ─────────────────────────────────────────────────────────────────
-- Phase G Foundation: per-User-Custom-Views für AddressbookScreen.
-- Speichert Kombi aus Filter, sichtbaren Columns, Sort, Density.
-- Spec: §6.6
-- ─────────────────────────────────────────────────────────────────

CREATE TABLE public.contact_saved_views (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name        TEXT NOT NULL,
  filter      JSONB NOT NULL DEFAULT '{}'::jsonb,
  columns     JSONB NOT NULL DEFAULT '[]'::jsonb,
  sort        JSONB NOT NULL DEFAULT '[]'::jsonb,
  density     TEXT NOT NULL DEFAULT 'comfortable'
    CHECK (density IN ('compact', 'comfortable')),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_contact_saved_views_user
  ON public.contact_saved_views(user_id);

ALTER TABLE public.contact_saved_views ENABLE ROW LEVEL SECURITY;

CREATE POLICY contact_saved_views_owner ON public.contact_saved_views
  FOR ALL TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());
```

- [ ] **Step 2: Anwenden + smoke-test**

```bash
supabase migration up
```

Im Studio:
```sql
INSERT INTO public.contact_saved_views (user_id, name, filter, columns, sort)
VALUES (
  auth.uid(),
  'VIP-Kunden',
  '{"tags":["vip"]}'::jsonb,
  '["name","email","saldo","last_contact"]'::jsonb,
  '[{"col":"last_contact","dir":"desc"}]'::jsonb
);

SELECT name, filter, columns FROM public.contact_saved_views;
-- cleanup:
DELETE FROM public.contact_saved_views WHERE name = 'VIP-Kunden';
```

- [ ] **Step 3: Commit**

```bash
git add supabase/migrations/0115_contact_saved_views.sql
git commit -m 'feat(db): contact_saved_views table + RLS for user-custom list views'
```

---

### Task 8: TypeScript-Types für Events

**Files:**
- Create: `apps/web/src/types/contactEvents.ts`

- [ ] **Step 1: Types schreiben**

```ts
// apps/web/src/types/contactEvents.ts
// Spec: docs/superpowers/specs/2026-05-27-contacts-crm-redesign.md §4, §8

/** User-logged event types — landen in contact_events table. */
export type UserEventType =
  | 'note'
  | 'call'
  | 'email_external'
  | 'meeting_past'
  | 'task'
  | 'whatsapp_log'

/** System event types — gelesen aus Source-Tables via View. */
export type SystemEventType =
  | 'course_enrollment'
  | 'certification_issued'
  | 'saldo_movement'
  | 'pipeline_change'
  | 'intake_checkpoint'
  | 'skill_checked'
  | 'card_lead_imported'
  | 'role_change'
  | 'audit_edit'

export type EventType = UserEventType | SystemEventType

export type EventStatus = 'open' | 'resolved' | 'archived'

/** Eine Zeile aus v_contact_timeline. */
export interface TimelineEvent {
  event_id: string
  contact_id: string
  event_type: EventType
  occurred_at: string             // ISO timestamp
  actor_contact_id: string | null
  summary: string
  body: string | null
  payload: Record<string, unknown> | null
  status: EventStatus
  source_table: string
  source_id: string
}

/** Payload-Shapes pro User-Event-Typ. */
export interface NotePayload {}
export interface CallPayload {
  duration_min?: number
  direction?: 'outbound' | 'inbound'
}
export interface EmailExternalPayload {
  subject: string
  direction: 'sent' | 'received'
}
export interface MeetingPastPayload {
  duration_min?: number
  location?: string
}
export interface TaskPayload {
  due_date: string                // ISO date
  reminder_at?: string
  completed_at?: string | null
}
export interface WhatsAppLogPayload {
  direction: 'sent' | 'received'
}

/** Input für Composer-Insert. */
export type EventComposerInput =
  | { event_type: 'note'; summary: string; body?: string }
  | { event_type: 'call'; summary: string; body?: string; payload: CallPayload; occurred_at?: string }
  | { event_type: 'email_external'; summary: string; body?: string; payload: EmailExternalPayload; occurred_at?: string }
  | { event_type: 'meeting_past'; summary: string; body?: string; payload: MeetingPastPayload; occurred_at?: string }
  | { event_type: 'task'; summary: string; body?: string; payload: TaskPayload }
  | { event_type: 'whatsapp_log'; summary: string; body?: string; payload: WhatsAppLogPayload; occurred_at?: string }

/** Filter für useContactTimeline / useGlobalActivity. */
export interface TimelineFilter {
  event_types?: EventType[]
  channel?: ('email' | 'call' | 'whatsapp' | 'note' | 'meeting' | 'task')[]
  date_from?: string
  date_to?: string
  owner_scope?: 'me' | 'team'
}
```

- [ ] **Step 2: Typecheck**

Run:
```bash
cd apps/web && npx tsc --noEmit
```

Expected: exit 0, keine Errors.

- [ ] **Step 3: Commit**

```bash
git add apps/web/src/types/contactEvents.ts
git commit -m 'feat(types): contact event types for Phase G timeline'
```

---

### Task 9: `contactEventQueries.ts` — TDD-Vorgehen

**Files:**
- Create: `apps/web/src/lib/contactEventQueries.ts`
- Create: `apps/web/src/lib/__tests__/contactEventQueries.test.ts`

- [ ] **Step 1: Test schreiben (fail first)**

```ts
// apps/web/src/lib/__tests__/contactEventQueries.test.ts
import { describe, it, expect, vi, beforeEach } from 'vitest'
import {
  insertContactEvent,
  updateContactEvent,
  deleteContactEvent,
} from '../contactEventQueries'

// Mock Supabase
vi.mock('@/lib/supabase', () => ({
  supabase: {
    from: vi.fn(),
  },
}))

import { supabase } from '@/lib/supabase'

describe('contactEventQueries', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  describe('insertContactEvent', () => {
    it('inserts a note event with summary + body', async () => {
      const single = vi.fn().mockResolvedValue({ data: { id: 'ev-1' }, error: null })
      const select = vi.fn().mockReturnValue({ single })
      const insert = vi.fn().mockReturnValue({ select })
      vi.mocked(supabase.from).mockReturnValue({ insert } as never)

      const result = await insertContactEvent('contact-1', {
        event_type: 'note',
        summary: 'hello',
        body: 'longer body',
      })

      expect(supabase.from).toHaveBeenCalledWith('contact_events')
      expect(insert).toHaveBeenCalledWith({
        contact_id: 'contact-1',
        event_type: 'note',
        summary: 'hello',
        body: 'longer body',
      })
      expect(result).toEqual({ id: 'ev-1' })
    })

    it('throws on supabase error', async () => {
      const single = vi.fn().mockResolvedValue({
        data: null,
        error: { message: 'RLS denied' },
      })
      const select = vi.fn().mockReturnValue({ single })
      const insert = vi.fn().mockReturnValue({ select })
      vi.mocked(supabase.from).mockReturnValue({ insert } as never)

      await expect(
        insertContactEvent('contact-1', { event_type: 'note', summary: 'x' })
      ).rejects.toThrow('RLS denied')
    })
  })

  describe('updateContactEvent', () => {
    it('updates summary + body by id', async () => {
      const single = vi.fn().mockResolvedValue({ data: { id: 'ev-1' }, error: null })
      const select = vi.fn().mockReturnValue({ single })
      const eq = vi.fn().mockReturnValue({ select })
      const update = vi.fn().mockReturnValue({ eq })
      vi.mocked(supabase.from).mockReturnValue({ update } as never)

      await updateContactEvent('ev-1', { summary: 'updated' })

      expect(update).toHaveBeenCalledWith({ summary: 'updated' })
      expect(eq).toHaveBeenCalledWith('id', 'ev-1')
    })
  })

  describe('deleteContactEvent', () => {
    it('deletes by id', async () => {
      const eq = vi.fn().mockResolvedValue({ error: null })
      const del = vi.fn().mockReturnValue({ eq })
      vi.mocked(supabase.from).mockReturnValue({ delete: del } as never)

      await deleteContactEvent('ev-1')

      expect(del).toHaveBeenCalled()
      expect(eq).toHaveBeenCalledWith('id', 'ev-1')
    })
  })
})
```

- [ ] **Step 2: Test ausführen — soll failen**

Run:
```bash
cd apps/web && npx vitest run src/lib/__tests__/contactEventQueries.test.ts
```

Expected: FAIL — Module `../contactEventQueries` not found.

- [ ] **Step 3: Minimale Implementation**

```ts
// apps/web/src/lib/contactEventQueries.ts
import { supabase } from '@/lib/supabase'
import type { EventComposerInput, TimelineEvent } from '@/types/contactEvents'

/**
 * Insert a user-logged event for a contact.
 * RLS (contact_events_owner) gates access — Phase 1 stellt sicher dass
 * nur der Owner inserten kann.
 */
export async function insertContactEvent(
  contactId: string,
  input: EventComposerInput,
): Promise<{ id: string }> {
  const row = {
    contact_id: contactId,
    ...input,
  }
  const { data, error } = await supabase
    .from('contact_events')
    .insert(row)
    .select('id')
    .single()
  if (error) throw new Error(error.message)
  return data as { id: string }
}

/**
 * Update an existing event — Owner-RLS gilt.
 * Common updates: summary, body, status (open → resolved / archived).
 */
export async function updateContactEvent(
  eventId: string,
  patch: Partial<Pick<TimelineEvent, 'summary' | 'body' | 'status' | 'payload'>>,
): Promise<{ id: string }> {
  const { data, error } = await supabase
    .from('contact_events')
    .update(patch)
    .eq('id', eventId)
    .select('id')
    .single()
  if (error) throw new Error(error.message)
  return data as { id: string }
}

/**
 * Hard-delete an event. RLS scoped to owner.
 * Note: löscht nur user-logged Events (Tabelle contact_events) —
 * System-Events sind read-only über die View.
 */
export async function deleteContactEvent(eventId: string): Promise<void> {
  const { error } = await supabase
    .from('contact_events')
    .delete()
    .eq('id', eventId)
  if (error) throw new Error(error.message)
}
```

- [ ] **Step 4: Test grün**

Run:
```bash
cd apps/web && npx vitest run src/lib/__tests__/contactEventQueries.test.ts
```

Expected: PASS — 4 Tests ok.

- [ ] **Step 5: Commit**

```bash
git add apps/web/src/lib/contactEventQueries.ts apps/web/src/lib/__tests__/contactEventQueries.test.ts
git commit -m 'feat(web): contactEventQueries lib + unit tests'
```

---

### Task 10: `useContactTimeline` Hook mit TDD

**Files:**
- Create: `apps/web/src/hooks/useContactTimeline.ts`
- Create: `apps/web/src/hooks/__tests__/useContactTimeline.test.tsx`

- [ ] **Step 1: Test schreiben**

```tsx
// apps/web/src/hooks/__tests__/useContactTimeline.test.tsx
import { describe, it, expect, vi } from 'vitest'
import { renderHook, waitFor } from '@testing-library/react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { useContactTimeline } from '../useContactTimeline'

vi.mock('@/lib/supabase', () => {
  const limit = vi.fn().mockResolvedValue({
    data: [
      { event_id: 'a', contact_id: 'c1', event_type: 'note', occurred_at: '2026-05-01', summary: 'one', source_table: 'contact_events' },
    ],
    error: null,
  })
  const order2 = vi.fn().mockReturnValue({ limit })
  const order1 = vi.fn().mockReturnValue({ order: order2 })
  const eq = vi.fn().mockReturnValue({ order: order1 })
  const select = vi.fn().mockReturnValue({ eq })
  const from = vi.fn().mockReturnValue({ select })
  return { supabase: { from } }
})

function wrapper({ children }: { children: React.ReactNode }) {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } })
  return <QueryClientProvider client={qc}>{children}</QueryClientProvider>
}

describe('useContactTimeline', () => {
  it('fetches events for a contact ordered by occurred_at desc', async () => {
    const { result } = renderHook(() => useContactTimeline('c1'), { wrapper })
    await waitFor(() => expect(result.current.isSuccess).toBe(true))
    expect(result.current.data?.pages[0].length).toBe(1)
    expect(result.current.data?.pages[0][0].summary).toBe('one')
  })
})
```

- [ ] **Step 2: Test ausführen — soll failen**

Run:
```bash
cd apps/web && npx vitest run src/hooks/__tests__/useContactTimeline.test.tsx
```

Expected: FAIL — module not found.

- [ ] **Step 3: Hook implementieren**

```ts
// apps/web/src/hooks/useContactTimeline.ts
import { useInfiniteQuery } from '@tanstack/react-query'
import { supabase } from '@/lib/supabase'
import type { TimelineEvent, TimelineFilter } from '@/types/contactEvents'

const PAGE_SIZE = 50

interface PageCursor {
  occurred_at: string
  event_id: string
}

/**
 * Paginated timeline für einen Contact.
 * Liest aus v_contact_timeline (Migration 0114) — vereint contact_events
 * und alle System-Event-Source-Tables.
 *
 * Pagination: cursor auf (occurred_at, event_id) — stable bei concurrent inserts.
 */
export function useContactTimeline(contactId: string, filter?: TimelineFilter) {
  return useInfiniteQuery<TimelineEvent[], Error, { pages: TimelineEvent[][]; pageParams: (PageCursor | undefined)[] }, [string, string, TimelineFilter | undefined], PageCursor | undefined>({
    queryKey: ['contact-timeline', contactId, filter],
    initialPageParam: undefined,
    queryFn: async ({ pageParam }) => {
      let q = supabase
        .from('v_contact_timeline')
        .select('*')
        .eq('contact_id', contactId)
        .order('occurred_at', { ascending: false })
        .order('event_id', { ascending: false })
        .limit(PAGE_SIZE)

      if (filter?.event_types?.length) {
        q = q.in('event_type', filter.event_types)
      }
      if (filter?.date_from) {
        q = q.gte('occurred_at', filter.date_from)
      }
      if (filter?.date_to) {
        q = q.lte('occurred_at', filter.date_to)
      }
      if (pageParam) {
        // Cursor: (occurred_at, event_id) strict less-than (DESC sort)
        q = q.or(
          `occurred_at.lt.${pageParam.occurred_at},and(occurred_at.eq.${pageParam.occurred_at},event_id.lt.${pageParam.event_id})`
        )
      }

      const { data, error } = await q
      if (error) throw new Error(error.message)
      return (data ?? []) as TimelineEvent[]
    },
    getNextPageParam: (lastPage) => {
      const last = lastPage.at(-1)
      if (!last || lastPage.length < PAGE_SIZE) return undefined
      return { occurred_at: last.occurred_at, event_id: last.event_id }
    },
    enabled: !!contactId,
  })
}
```

- [ ] **Step 4: Test grün**

Run:
```bash
cd apps/web && npx vitest run src/hooks/__tests__/useContactTimeline.test.tsx
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add apps/web/src/hooks/useContactTimeline.ts apps/web/src/hooks/__tests__/useContactTimeline.test.tsx
git commit -m 'feat(web): useContactTimeline hook with cursor pagination'
```

---

### Task 11: `useEventComposer` Hook (Mutations)

**Files:**
- Create: `apps/web/src/hooks/useEventComposer.ts`

- [ ] **Step 1: Hook schreiben**

```ts
// apps/web/src/hooks/useEventComposer.ts
import { useMutation, useQueryClient } from '@tanstack/react-query'
import {
  deleteContactEvent,
  insertContactEvent,
  updateContactEvent,
} from '@/lib/contactEventQueries'
import type { EventComposerInput, TimelineEvent } from '@/types/contactEvents'

/**
 * Insert a new event for a contact + invalidate timeline.
 * Optimistic update der ersten Timeline-Seite damit die Karte sofort erscheint.
 */
export function useInsertContactEvent(contactId: string) {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: (input: EventComposerInput) => insertContactEvent(contactId, input),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['contact-timeline', contactId] })
      qc.invalidateQueries({ queryKey: ['global-activity'] })
    },
  })
}

/**
 * Update event — z.B. Task auf resolved setzen, Note korrigieren.
 */
export function useUpdateContactEvent(contactId: string) {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: ({ eventId, patch }: {
      eventId: string
      patch: Partial<Pick<TimelineEvent, 'summary' | 'body' | 'status' | 'payload'>>
    }) => updateContactEvent(eventId, patch),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['contact-timeline', contactId] })
      qc.invalidateQueries({ queryKey: ['global-activity'] })
    },
  })
}

/**
 * Delete event — RLS sorgt für owner-only. Optimistic remove + rollback bei Fehler.
 */
export function useDeleteContactEvent(contactId: string) {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: (eventId: string) => deleteContactEvent(eventId),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['contact-timeline', contactId] })
      qc.invalidateQueries({ queryKey: ['global-activity'] })
    },
  })
}
```

- [ ] **Step 2: Typecheck**

Run:
```bash
cd apps/web && npx tsc --noEmit
```

Expected: exit 0.

- [ ] **Step 3: Commit**

```bash
git add apps/web/src/hooks/useEventComposer.ts
git commit -m 'feat(web): useEventComposer mutations (insert/update/delete)'
```

---

### Task 12: `useGlobalActivity` Hook

**Files:**
- Create: `apps/web/src/hooks/useGlobalActivity.ts`

- [ ] **Step 1: Hook schreiben**

```ts
// apps/web/src/hooks/useGlobalActivity.ts
import { useInfiniteQuery } from '@tanstack/react-query'
import { supabase } from '@/lib/supabase'
import type { TimelineEvent, TimelineFilter } from '@/types/contactEvents'

const PAGE_SIZE = 50

interface PageCursor {
  occurred_at: string
  event_id: string
}

/**
 * Globaler Activity-Feed über alle Contacts.
 * RLS sorgt dafür dass nur eigene Contacts in den Ergebnissen landen.
 * Spec: §7 Aktivität-Screen.
 */
export function useGlobalActivity(filter?: TimelineFilter) {
  return useInfiniteQuery<TimelineEvent[], Error, { pages: TimelineEvent[][]; pageParams: (PageCursor | undefined)[] }, [string, TimelineFilter | undefined], PageCursor | undefined>({
    queryKey: ['global-activity', filter],
    initialPageParam: undefined,
    queryFn: async ({ pageParam }) => {
      let q = supabase
        .from('v_contact_timeline')
        .select('*')
        .order('occurred_at', { ascending: false })
        .order('event_id', { ascending: false })
        .limit(PAGE_SIZE)

      if (filter?.event_types?.length) {
        q = q.in('event_type', filter.event_types)
      }
      if (filter?.date_from) {
        q = q.gte('occurred_at', filter.date_from)
      }
      if (filter?.date_to) {
        q = q.lte('occurred_at', filter.date_to)
      }
      if (pageParam) {
        q = q.or(
          `occurred_at.lt.${pageParam.occurred_at},and(occurred_at.eq.${pageParam.occurred_at},event_id.lt.${pageParam.event_id})`
        )
      }

      const { data, error } = await q
      if (error) throw new Error(error.message)
      return (data ?? []) as TimelineEvent[]
    },
    getNextPageParam: (lastPage) => {
      const last = lastPage.at(-1)
      if (!last || lastPage.length < PAGE_SIZE) return undefined
      return { occurred_at: last.occurred_at, event_id: last.event_id }
    },
  })
}
```

- [ ] **Step 2: Typecheck**

Run:
```bash
cd apps/web && npx tsc --noEmit
```

Expected: exit 0.

- [ ] **Step 3: Commit**

```bash
git add apps/web/src/hooks/useGlobalActivity.ts
git commit -m 'feat(web): useGlobalActivity hook for /aktivitaet screen'
```

---

### Task 13: `useContactSavedViews` Hook

**Files:**
- Create: `apps/web/src/hooks/useContactSavedViews.ts`

- [ ] **Step 1: Types ergänzen**

In `apps/web/src/types/contactEvents.ts` am Ende anhängen:

```ts
/** Persisted user-custom view aus contact_saved_views Tabelle. */
export interface ContactSavedView {
  id: string
  user_id: string
  name: string
  filter: Record<string, unknown>
  columns: string[]
  sort: Array<{ col: string; dir: 'asc' | 'desc' }>
  density: 'compact' | 'comfortable'
  created_at: string
}

export interface SavedViewInput {
  name: string
  filter: Record<string, unknown>
  columns: string[]
  sort: Array<{ col: string; dir: 'asc' | 'desc' }>
  density: 'compact' | 'comfortable'
}
```

- [ ] **Step 2: Hook schreiben**

```ts
// apps/web/src/hooks/useContactSavedViews.ts
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { supabase } from '@/lib/supabase'
import type { ContactSavedView, SavedViewInput } from '@/types/contactEvents'

const QK = ['contact-saved-views']

/** Liste aller eigenen Saved Views (RLS scoped auf user_id). */
export function useContactSavedViews() {
  return useQuery({
    queryKey: QK,
    queryFn: async (): Promise<ContactSavedView[]> => {
      const { data, error } = await supabase
        .from('contact_saved_views')
        .select('*')
        .order('created_at', { ascending: false })
      if (error) throw new Error(error.message)
      return (data ?? []) as ContactSavedView[]
    },
  })
}

/** View speichern. user_id wird via RLS-WITH-CHECK aus auth.uid() validiert. */
export function useCreateSavedView() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: async (input: SavedViewInput): Promise<ContactSavedView> => {
      const { data: { user } } = await supabase.auth.getUser()
      if (!user) throw new Error('not authenticated')
      const { data, error } = await supabase
        .from('contact_saved_views')
        .insert({ ...input, user_id: user.id })
        .select('*')
        .single()
      if (error) throw new Error(error.message)
      return data as ContactSavedView
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: QK }),
  })
}

/** View löschen. */
export function useDeleteSavedView() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: async (viewId: string): Promise<void> => {
      const { error } = await supabase
        .from('contact_saved_views')
        .delete()
        .eq('id', viewId)
      if (error) throw new Error(error.message)
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: QK }),
  })
}
```

- [ ] **Step 3: Typecheck**

Run:
```bash
cd apps/web && npx tsc --noEmit
```

Expected: exit 0.

- [ ] **Step 4: Commit**

```bash
git add apps/web/src/hooks/useContactSavedViews.ts apps/web/src/types/contactEvents.ts
git commit -m 'feat(web): useContactSavedViews CRUD hook + types'
```

---

### Task 14: End-to-End Smoke-Test der Foundation

Manueller Smoke-Test via Dev-Server. Verifiziert dass alle Pieces zusammenpassen, bevor wir Phase 2 starten.

- [ ] **Step 1: Dev-Server starten**

Run:
```bash
cd ~/Desktop/Developer/Dispo/apps/web
npm run dev
```

Expected: Vite läuft auf `http://localhost:5173` ohne Build-Errors.

- [ ] **Step 2: Temporäre Test-Komponente**

Lege temporär an: `apps/web/src/screens/_phase-g-smoke.tsx` (wird in Phase 6 wieder gelöscht):

```tsx
import { useContactTimeline } from '@/hooks/useContactTimeline'
import { useInsertContactEvent } from '@/hooks/useEventComposer'

export function PhaseGSmoke() {
  const CONTACT_ID = 'PASTE-EINE-ECHTE-CONTACT-ID-AUS-DEINER-DB-HIER'
  const timeline = useContactTimeline(CONTACT_ID)
  const insert = useInsertContactEvent(CONTACT_ID)

  return (
    <div style={{ padding: 20 }}>
      <h2>Phase G Smoke</h2>
      <button onClick={() => insert.mutate({ event_type: 'note', summary: 'smoke test ' + new Date().toISOString() })}>
        Add Note
      </button>
      <pre style={{ marginTop: 20 }}>
        {JSON.stringify(timeline.data?.pages.flat() ?? timeline.error?.message ?? 'loading', null, 2)}
      </pre>
    </div>
  )
}
```

Route temporär in `App.tsx`:
```tsx
import { PhaseGSmoke } from './screens/_phase-g-smoke'
// ...
<Route path="/phase-g-smoke" element={<PhaseGSmoke />} />
```

- [ ] **Step 3: Browser-Test**

In Safari (Production-relevant) und Chrome:
- Login als gewöhnlicher Test-User
- Navigiere zu `/phase-g-smoke`
- Klicke „Add Note" ein paar Mal
- Verifiziere: Events erscheinen im `<pre>` mit `event_type: 'note'`, korrekter `contact_id`, neueste oben
- Refresh: Events bleiben da

Expected:
- Keine RLS-Errors in DevTools-Network
- Keine 4xx/5xx in Console
- Daten laden in <500ms

- [ ] **Step 4: Smoke-Test rückgängig (Test-Datei + Route entfernen NICHT committen, bleiben lokal)**

```bash
rm apps/web/src/screens/_phase-g-smoke.tsx
# App.tsx route-eintrag manuell wieder rausnehmen
```

- [ ] **Step 5: Final-Verification grün?**

Run alles zusammen:
```bash
cd ~/Desktop/Developer/Dispo
npm run typecheck --workspace apps/web 2>&1 | tail -3
cd apps/web && npx vitest run --reporter=dot 2>&1 | tail -5
cd ~/Desktop/Developer/Dispo/supabase/tests/pgtap && ./run.sh
```

Expected:
- TypeScript: exit 0
- Vitest: 109+ tests passed (107 alte + 2 neue aus Phase G)
- PgTAP: alle ok

---

### Task 15: Phase 1 abschliessen — Branch mergen + Folge-Plan andeuten

- [ ] **Step 1: Branch (falls Feature-Branch verwendet) auf main mergen**

```bash
cd ~/Desktop/Developer/Dispo
git checkout main
git merge --no-ff phase-g-foundation -m 'Merge branch "phase-g-foundation" — Datenmodell + Hooks (no UI yet)'
git push origin main
```

Falls direkt auf main gearbeitet wurde: nur `git push origin main`.

- [ ] **Step 2: Memory aktualisieren**

(Claude erinnert sich nach der Session): Memory-Eintrag `project_atoll.md` ergänzen um „Phase G Foundation (Migrationen 0110-0115, Hooks, Types) durch — Phasen 2-6 folgen".

- [ ] **Step 3: Plan-Datei für Phase 2 anstossen**

Wenn bereit: `superpowers:writing-plans` wieder aufrufen mit Scope „Phase 2 — Detail-Panel Timeline + Composer". Verweist auf dieselbe Spec.

---

## Verification Gates (zusammengefasst)

| Gate | Wie geprüft |
|---|---|
| Migrationen anwendbar | `supabase migration up` ohne Fehler |
| RLS isoliert (contact_events) | PgTAP `04_contact_events_rls.sql` 6/6 ok |
| Pipeline-Trigger + RLS | PgTAP `05_pipeline_stage_changes.sql` 3/3 ok |
| Saldo-Views deckungsgleich | Manuelle Cross-Query `v_instructor_balance ↔ v_contact_balance` 0 Diff-Zeilen |
| Timeline-View liefert korrekt | PgTAP `06_v_contact_timeline.sql` 4/4 ok |
| TypeScript clean | `npx tsc --noEmit` exit 0 |
| Unit-Tests grün | `npx vitest run` 109+ passed |
| End-to-End live | Browser-Smoke-Test in Safari + Chrome |

---

## Was bewusst NICHT in Phase 1 ist

- Keine UI-Änderungen — ContactDetailPanel und AddressbookScreen bleiben unverändert
- Keine `crm_v2`-Feature-Flag-Infrastruktur — kommt in Phase 2 Step 1
- Keine bestehenden Tab-Komponenten löschen (`ActivityTab` etc.) — erst Phase 6
- Kein `ActivityScreen` — erst Phase 5
- Keine Inline-Edit-Infrastruktur — erst Phase 3

Diese Phase ist reines Backend-Fundament + Read/Write-API über Hooks.
