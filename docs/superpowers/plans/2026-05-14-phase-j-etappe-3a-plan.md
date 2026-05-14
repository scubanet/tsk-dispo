# Phase J Etappe 3a — Studenten-Modell Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Schüler-CRUD (StudentEditSheet + fetchStudents) vom Legacy-`people`-Pfad auf `contacts` + `contact_student` + `contact_relationships` cutovern. Migration 0091 ergänzt fehlende Sidecar-Spalten und stellt das `student_upsert`-RPC für atomare Writes bereit. `padi_nr`-Eingabefeld wird aus StudentEditSheet entfernt (Pro-Domain, nicht Student-Domain).

**Architecture:** Eine Migration 0091 (Spalten + Backfill + Trigger + RPC). Drei Frontend-Files (`StudentEditSheet.tsx`, `lib/contactQueries.ts`, `lib/queries.ts`). Branch `phase-j-etappe-3a-students`. Smoke-Test im Vercel-Preview vor Merge.

**Tech Stack:** Supabase Postgres + PL/pgSQL, React 18 + TypeScript, Supabase JS Client.

**Spec:** `docs/superpowers/specs/2026-05-14-phase-j-etappe-3-design.md`

**Pre-Requisite — Sandbox kann nicht selbst committen:** Alle `git`-Commands werden als Copy-Paste-Block für Dominik ausgegeben.

---

## File Structure

**Neue Dateien:**
- `supabase/migrations/0091_phase_j_etappe_3a_sidecars.sql` — Spalten (`contact_student.level/photo_url/organization_role/stage_changed_on`, `contact_instructor.initials`), Backfill aus Legacy, Sync-Trigger-Erweiterung, `tg_contact_student_stage_changed`-Trigger, `student_upsert`-RPC.

**Modifizierte Dateien:**
- `apps/web/src/lib/contactQueries.ts` — neuer Helper `listStudents()` analog `listActiveInstructors`.
- `apps/web/src/lib/queries.ts` — `fetchStudents()` → Wrapper auf `listStudents` (Backward-Compatible-Shape).
- `apps/web/src/screens/StudentEditSheet.tsx` — `padi_nr`-Feld + State entfernen, useEffect-Read auf `getContactWithSidecars` umstellen, `save()` auf `student_upsert`-RPC, `deleteStudent()` auf `contacts.delete` (CASCADE).

---

## Task 1: Branch erstellen + Pre-Flight Drift-Check

**Files:** keine.

- [ ] **Step 1: Branch erstellen**

Copy-Paste für Dominik:
```bash
cd /Users/dominik/Desktop/Developer/Dispo
git checkout -b phase-j-etappe-3a-students
```

- [ ] **Step 2: Drift-Check im Supabase Studio (SQL Editor) ausführen**

Dominik führt diese vier Queries aus:

```sql
-- 1. people → contacts Drift seit 10.05.
SELECT p.id, p.first_name, p.last_name, p.created_at
FROM people p LEFT JOIN contacts c ON c.id = p.id
WHERE p.created_at > '2026-05-10' AND c.id IS NULL;

-- 2. instructors → contacts Drift seit 10.05.
SELECT i.id, i.name, i.created_at
FROM instructors i LEFT JOIN contacts c ON c.id = i.id
WHERE i.created_at > '2026-05-10' AND c.id IS NULL;

-- 3. organizations → contacts Drift seit 10.05.
SELECT o.id, o.name, o.created_at
FROM organizations o LEFT JOIN contacts c ON c.id = o.id
WHERE o.created_at > '2026-05-10' AND c.id IS NULL;

-- 4. Sync-Triggers aktiv?
SELECT tgname, tgenabled
FROM pg_trigger
WHERE tgname LIKE '%sync_%_to_contacts%'
ORDER BY tgname;
```

Expected: Queries 1–3 leer. Query 4: alle Triggers haben `tgenabled = 'O'` (origin = enabled).

- [ ] **Step 3: Bei Drift — manueller Backfill, dann erneut prüfen**

Wenn Query 1 Treffer hat:
```sql
INSERT INTO contacts (id, kind, first_name, last_name, birth_date, primary_email, ...)
SELECT id, 'person', first_name, last_name, birthday, email, ... FROM people
WHERE id IN (<gefundene IDs>);
```
Analog für 2/3. Triggers ENABLE bei Bedarf: `ALTER TABLE people ENABLE TRIGGER trg_sync_people_to_contacts;`

Erst weitermachen, wenn Step 2 alles grün.

---

## Task 2: Migration 0091 — File anlegen + Schema-Erweiterung

**Files:**
- Create: `supabase/migrations/0091_phase_j_etappe_3a_sidecars.sql`

- [ ] **Step 1: Migration-File mit Header + Spalten-Adds schreiben**

```sql
-- 0091: Phase J Etappe 3a — Sidecar-Spalten für StudentEditSheet-Cutover
--
-- Ergänzt fehlende Spalten in contact_student + contact_instructor, sodass
-- der Frontend-Cutover von .from('people') auf .from('contacts') + Sidecars
-- alle bisherigen UI-Felder unterbringt.
--
-- Neue Spalten:
--   • contact_student.level             ← people.level (free-text)
--   • contact_student.photo_url         ← people.photo_url
--   • contact_student.organization_role ← people.organization_role
--   • contact_student.stage_changed_on  ← (neu, Trigger-gesetzt)
--   • contact_instructor.initials       ← instructors.initials (Stretch für 3b)
--
-- Nicht ergänzt: contact_student.padi_pro_number — Schüler bis Rescue haben
-- keine fixe PADI-Nummer, sondern wechselnde Zertifikat-Nummern pro Karte
-- (→ student_certifications.certificate_nr). Pro-Nummern leben weiter auf
-- contact_instructor.padi_pro_number.
--
-- Backfill: idempotent, IS DISTINCT FROM, kein BEGIN/COMMIT (Studio committed
-- per Statement; partial application wäre tolerierbar).

-- ────────────────────────────────────────────────────────────────────────────
-- 1. Spalten ergänzen
-- ────────────────────────────────────────────────────────────────────────────
ALTER TABLE public.contact_student
  ADD COLUMN IF NOT EXISTS level             TEXT,
  ADD COLUMN IF NOT EXISTS photo_url         TEXT,
  ADD COLUMN IF NOT EXISTS organization_role TEXT,
  ADD COLUMN IF NOT EXISTS stage_changed_on  TIMESTAMPTZ;

ALTER TABLE public.contact_instructor
  ADD COLUMN IF NOT EXISTS initials TEXT;

COMMENT ON COLUMN public.contact_student.level IS
  'Aktueller Tauchgang-Level (free-text, UI validiert gegen LEVELS-Konstante).';
COMMENT ON COLUMN public.contact_student.photo_url IS
  'Profilbild-URL.';
COMMENT ON COLUMN public.contact_student.organization_role IS
  'Rolle innerhalb der verknüpften Organisation (free-text).';
COMMENT ON COLUMN public.contact_student.stage_changed_on IS
  'Zeitpunkt der letzten pipeline_stage-Änderung (Trigger-gesetzt, TIMESTAMPTZ wie Legacy people.stage_changed_on).';
COMMENT ON COLUMN public.contact_instructor.initials IS
  'Kürzel für PADI-Referral-Templates, SkillCheck-Matrix, etc.';

-- ────────────────────────────────────────────────────────────────────────────
-- 2. Backfill aus Legacy-Tabellen
-- ────────────────────────────────────────────────────────────────────────────
UPDATE public.contact_student cs
SET level             = p.level,
    photo_url         = p.photo_url,
    organization_role = p.organization_role,
    stage_changed_on  = p.stage_changed_on
FROM public.people p
WHERE cs.contact_id = p.id
  AND (cs.level             IS DISTINCT FROM p.level
    OR cs.photo_url         IS DISTINCT FROM p.photo_url
    OR cs.organization_role IS DISTINCT FROM p.organization_role
    OR cs.stage_changed_on  IS DISTINCT FROM p.stage_changed_on);

UPDATE public.contact_instructor ci
SET initials = i.initials
FROM public.instructors i
WHERE ci.contact_id = i.id
  AND ci.initials IS DISTINCT FROM i.initials;
```

**Achtung:** Vor Schreiben verifizieren, dass `people.stage_changed_on` und `people.photo_url` tatsächlich Spalten sind. Falls eine fehlt → Backfill-Klausel entsprechend rausnehmen.

- [ ] **Step 2: Schema-Check vor Apply**

Dominik im Studio:
```sql
SELECT column_name FROM information_schema.columns
WHERE table_schema='public' AND table_name='people'
  AND column_name IN ('level','photo_url','organization_role','stage_changed_on');

SELECT column_name FROM information_schema.columns
WHERE table_schema='public' AND table_name='instructors'
  AND column_name='initials';
```

Expected: 5 Spalten (4 people + 1 instructors). Wenn weniger → Backfill-Block im Migration-File entsprechend anpassen.

- [ ] **Step 3: Migration in Studio anwenden (Teil 1 — Section 1+2)**

Dominik kopiert Sections 1 und 2 aus dem File ins Studio und führt sie aus.

- [ ] **Step 4: Verify**

```sql
SELECT column_name, data_type FROM information_schema.columns
WHERE table_schema='public' AND table_name='contact_student'
  AND column_name IN ('level','photo_url','organization_role','stage_changed_on');

SELECT count(*) AS backfilled_students FROM contact_student WHERE level IS NOT NULL;
SELECT count(*) AS backfilled_instructors FROM contact_instructor WHERE initials IS NOT NULL;
```

Expected: 4 Spalten, Counts > 0 (sofern Legacy-Daten existieren).

---

## Task 3: Migration 0091 — stage_changed_on-Trigger

**Files:**
- Modify: `supabase/migrations/0091_phase_j_etappe_3a_sidecars.sql` (Section 3 anhängen)

- [ ] **Step 1: Trigger-Function + Trigger ans File anhängen**

```sql
-- ────────────────────────────────────────────────────────────────────────────
-- 3. stage_changed_on-Trigger
-- ────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION tg_contact_student_stage_changed()
RETURNS TRIGGER AS $$
BEGIN
  IF OLD.pipeline_stage IS DISTINCT FROM NEW.pipeline_stage THEN
    NEW.stage_changed_on := now();
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_contact_student_stage_changed ON public.contact_student;
CREATE TRIGGER trg_contact_student_stage_changed
  BEFORE UPDATE ON public.contact_student
  FOR EACH ROW EXECUTE FUNCTION tg_contact_student_stage_changed();
```

- [ ] **Step 2: Section 3 in Studio anwenden**

- [ ] **Step 3: Verify**

```sql
-- Test: pipeline_stage update setzt stage_changed_on
SELECT contact_id, pipeline_stage, stage_changed_on
FROM contact_student
LIMIT 1;
-- Wenn None: einen Schüler anlegen, hier weitermachen.

-- Setze pipeline_stage auf einen anderen Wert
UPDATE contact_student
SET pipeline_stage = 'lead'
WHERE contact_id = '<ID aus obiger Query>';

-- Prüfe, dass stage_changed_on = heute
SELECT contact_id, pipeline_stage, stage_changed_on
FROM contact_student
WHERE contact_id = '<gleiche ID>';
```

Expected: `stage_changed_on` ist now()-Timestamp (heute).

---

## Task 4: ~~Migration 0091 — Sync-Trigger erweitern (Legacy → Sidecar)~~ ENTFÄLLT

**Begründung (14.05. Pre-Flight-Befund):** Die 0083-Forward-Sync-Triggers existieren in Production nicht mehr. Was läuft sind partial-Sync-Triggers (`trg_sync_student_name`, `trg_sync_pipeline_stage_changed`, `trg_sync_instructor_name`, `trg_auto_link_instructor`) — die spiegeln nur Namen + intra-Tabelle-Bookkeeping, nicht die neuen Felder. Die orphan'd Functions `sync_people_to_contacts` / `sync_instructors_to_contacts` rufen keine Triggers mehr auf, also wäre eine Erweiterung wirkungslos.

Diese Cleanup-Schulden werden in Etappe 3c (`0092_drop_legacy_triggers.sql`) bereinigt — nicht hier.

**Hinweis für Etappe 3c:** Vor Trigger/Function-Drop in 3c noch prüfen, ob inzwischen ein anderer Pfad (z. B. Edge-Function, Cron-Job) auf diese Functions zurückgreift.

---

<details>
<summary>Original-Task-Text (archiviert, NICHT mehr ausführen)</summary>

Die `sync_people_to_contacts`-Function aus 0083 (mit 0088-Erweiterung) wird nochmal CREATE-OR-REPLACE'd, diesmal mit den 4 neuen Sidecar-Spalten in INSERT + UPDATE:

```sql
-- ────────────────────────────────────────────────────────────────────────────
-- 4. Sync-Trigger erweitern für neue Sidecar-Spalten
-- ────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION sync_people_to_contacts()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    INSERT INTO public.contacts (
      id, kind, first_name, last_name, birth_date,
      primary_email, phones, languages, roles, source, notes,
      created_at, updated_at
    ) VALUES (
      NEW.id,
      'person',
      NULLIF(TRIM(NEW.first_name), ''),
      COALESCE(NULLIF(TRIM(NEW.last_name), ''), '-'),
      NEW.birthday,
      NEW.email,
      CASE WHEN NEW.phone IS NOT NULL AND NEW.phone <> ''
           THEN jsonb_build_array(jsonb_build_object('label','mobile','e164',NEW.phone,'primary',true))
           ELSE '[]'::jsonb END,
      COALESCE(NEW.languages, '{}'::TEXT[]),
      ARRAY(
        SELECT r FROM (VALUES
          (CASE WHEN NEW.is_student   THEN 'student'   END),
          (CASE WHEN NEW.is_candidate THEN 'candidate' END)
        ) AS t(r) WHERE r IS NOT NULL
      ),
      'sync_from_legacy',
      NEW.notes,
      now(), now()
    )
    ON CONFLICT (id) DO NOTHING;

    IF NEW.is_student OR NEW.is_candidate THEN
      INSERT INTO public.contact_student (
        contact_id, pipeline_stage, lead_source, is_candidate,
        level, photo_url, organization_role, stage_changed_on,
        preferred_language, created_at, updated_at
      ) VALUES (
        NEW.id,
        NULLIF(NEW.pipeline_stage, 'none'),
        NULLIF(NEW.lead_source, ''),
        NEW.is_candidate,
        NEW.level, NEW.photo_url, NEW.organization_role, NEW.stage_changed_on,
        NEW.preferred_language,
        now(), now()
      )
      ON CONFLICT (contact_id) DO NOTHING;
    END IF;

  ELSIF TG_OP = 'UPDATE' THEN
    UPDATE public.contacts SET
      first_name    = NULLIF(TRIM(NEW.first_name), ''),
      last_name     = COALESCE(NULLIF(TRIM(NEW.last_name), ''), '-'),
      birth_date    = NEW.birthday,
      primary_email = NEW.email,
      phones        = CASE WHEN NEW.phone IS NOT NULL AND NEW.phone <> ''
                           THEN jsonb_build_array(jsonb_build_object('label','mobile','e164',NEW.phone,'primary',true))
                           ELSE '[]'::jsonb END,
      languages     = COALESCE(NEW.languages, '{}'::TEXT[]),
      notes         = NEW.notes,
      updated_at    = now()
    WHERE id = NEW.id;

    UPDATE public.contact_student SET
      pipeline_stage    = NULLIF(NEW.pipeline_stage, 'none'),
      lead_source       = NULLIF(NEW.lead_source, ''),
      is_candidate      = NEW.is_candidate,
      level             = NEW.level,
      photo_url         = NEW.photo_url,
      organization_role = NEW.organization_role,
      stage_changed_on  = NEW.stage_changed_on,
      preferred_language = NEW.preferred_language,
      updated_at        = now()
    WHERE contact_id = NEW.id;

  ELSIF TG_OP = 'DELETE' THEN
    DELETE FROM public.contacts WHERE id = OLD.id;
  END IF;

  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION sync_instructors_to_contacts()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    INSERT INTO public.contacts (
      id, kind, first_name, last_name,
      primary_email, phones, languages, roles, source, created_at, updated_at
    ) VALUES (
      NEW.id,
      'person',
      NULLIF(TRIM(NEW.first_name), ''),
      COALESCE(NULLIF(TRIM(NEW.last_name), ''), '-'),
      NEW.email,
      CASE WHEN NEW.phone IS NOT NULL AND NEW.phone <> ''
           THEN jsonb_build_array(jsonb_build_object('label','mobile','e164',NEW.phone,'primary',true))
           ELSE '[]'::jsonb END,
      '{}'::TEXT[],
      ARRAY['instructor', NEW.role::TEXT],
      'sync_from_legacy',
      now(), now()
    )
    ON CONFLICT (id) DO NOTHING;

    INSERT INTO public.contact_instructor (
      contact_id, auth_user_id, padi_pro_number, padi_level,
      account_balance, active, app_role, preferred_language, initials,
      created_at, updated_at
    ) VALUES (
      NEW.id, NEW.auth_user_id, NEW.padi_nr, NEW.padi_level,
      NEW.opening_balance_chf, NEW.active, NEW.role, NEW.preferred_language, NEW.initials,
      now(), now()
    )
    ON CONFLICT (contact_id) DO NOTHING;

  ELSIF TG_OP = 'UPDATE' THEN
    UPDATE public.contacts SET
      first_name    = NULLIF(TRIM(NEW.first_name), ''),
      last_name     = COALESCE(NULLIF(TRIM(NEW.last_name), ''), '-'),
      primary_email = NEW.email,
      phones        = CASE WHEN NEW.phone IS NOT NULL AND NEW.phone <> ''
                           THEN jsonb_build_array(jsonb_build_object('label','mobile','e164',NEW.phone,'primary',true))
                           ELSE '[]'::jsonb END,
      updated_at    = now()
    WHERE id = NEW.id;

    UPDATE public.contact_instructor SET
      auth_user_id        = NEW.auth_user_id,
      padi_pro_number     = NEW.padi_nr,
      padi_level          = NEW.padi_level,
      account_balance     = NEW.opening_balance_chf,
      active              = NEW.active,
      app_role            = NEW.role,
      preferred_language  = NEW.preferred_language,
      initials            = NEW.initials,
      updated_at          = now()
    WHERE contact_id = NEW.id;

  ELSIF TG_OP = 'DELETE' THEN
    DELETE FROM public.contacts WHERE id = OLD.id;
  END IF;

  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;
```

**Achtung:** Diese Functions stützen sich auf Spalten der Legacy-Tabellen (z. B. `people.level`, `instructors.initials`). Wenn eine Legacy-Spalte nicht existiert (siehe Task 2 Step 2), entsprechende Zeile rauslöschen.

- [ ] **Step 2: Section 4 in Studio anwenden**

- [ ] **Step 3: Verify Sync-Pfad**

```sql
-- Test: people.level-Update spiegelt sich in contact_student.level
SELECT id, level FROM people LIMIT 1;
UPDATE people SET level = 'OWD' WHERE id = '<obige ID>';
SELECT level FROM contact_student WHERE contact_id = '<obige ID>';
```

Expected: `contact_student.level = 'OWD'`. Reset danach mit `UPDATE people SET level = '<Original>' WHERE id = '<ID>';`.

</details>

---

## Task 5: Migration 0091 — student_upsert-RPC

**Files:**
- Modify: `supabase/migrations/0091_phase_j_etappe_3a_sidecars.sql` (Section 5 anhängen)

- [ ] **Step 1: RPC schreiben**

```sql
-- ────────────────────────────────────────────────────────────────────────────
-- 5. student_upsert RPC — atomarer Write auf contacts + contact_student
--    + optional works_at-Relationship
-- ────────────────────────────────────────────────────────────────────────────
--
-- Signatur:
--   student_upsert(
--     p_contact_id UUID,        -- NULL = Insert, gesetzt = Update
--     p_contact    JSONB,       -- Stammdaten für contacts
--     p_student    JSONB,       -- Sidecar-Felder für contact_student
--     p_org_id     UUID         -- NULL = kein Org-Link, gesetzt = works_at
--   ) RETURNS UUID
--
-- p_contact-Schema (alles optional ausser first_name/last_name beim Insert):
--   { first_name, last_name, primary_email, phone, birthday, notes,
--     address: {street, postal_code, city, country}, tags, languages,
--     is_student (bool), is_candidate (bool), photo_url }
--
-- p_student-Schema (alles optional):
--   { pipeline_stage, lead_source, is_candidate, level,
--     photo_url, organization_role }
--
-- p_org_id: UUID der Organisation (contact_id). Wenn gesetzt → works_at
-- Relationship sicherstellen. Wenn NULL → bestehende works_at-Relationship
-- für diesen Schüler löschen.
--
-- Implementierungs-Note: photo_url lebt ausschliesslich auf contact_student
-- (neu in 0091). Im RPC wird p_contact->'photo_url' ignoriert; das Feld
-- aus dem p_student-Payload gelesen.

CREATE OR REPLACE FUNCTION student_upsert(
  p_contact_id UUID,
  p_contact    JSONB,
  p_student    JSONB,
  p_org_id     UUID DEFAULT NULL
) RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_contact_id UUID;
  v_roles      TEXT[];
  v_phones     JSONB;
  v_addresses  JSONB;
  v_languages  TEXT[];
  v_tags       TEXT[];
BEGIN
  -- Phones jsonb bauen aus simplem phone-Feld
  v_phones := CASE
    WHEN p_contact->>'phone' IS NOT NULL AND p_contact->>'phone' <> ''
    THEN jsonb_build_array(jsonb_build_object(
      'label','mobile','e164',p_contact->>'phone','primary',true))
    ELSE '[]'::jsonb
  END;

  -- Addresses jsonb bauen aus Adress-Sub-Objekt
  v_addresses := CASE
    WHEN p_contact->'address' IS NOT NULL
     AND (p_contact->'address'->>'street' <> ''
       OR p_contact->'address'->>'city'   <> '')
    THEN jsonb_build_array(jsonb_build_object(
      'label','home',
      'street',     COALESCE(p_contact->'address'->>'street',''),
      'postal_code',COALESCE(p_contact->'address'->>'postal_code',''),
      'city',       COALESCE(p_contact->'address'->>'city',''),
      'country',    COALESCE(p_contact->'address'->>'country',''),
      'primary',true))
    ELSE '[]'::jsonb
  END;

  -- Tags + languages aus jsonb-Arrays zu TEXT[]
  v_tags      := COALESCE(ARRAY(SELECT jsonb_array_elements_text(p_contact->'tags')),     '{}');
  v_languages := COALESCE(ARRAY(SELECT jsonb_array_elements_text(p_contact->'languages')),'{}');

  -- Roles bauen aus Flags
  v_roles := ARRAY[]::TEXT[];
  IF (p_contact->>'is_student')::BOOLEAN   THEN v_roles := array_append(v_roles, 'student');   END IF;
  IF (p_contact->>'is_candidate')::BOOLEAN THEN v_roles := array_append(v_roles, 'candidate'); END IF;

  IF p_contact_id IS NULL THEN
    -- ─── INSERT-Pfad ────────────────────────────────────────────────────
    INSERT INTO contacts (
      kind, first_name, last_name, primary_email, phones, addresses,
      languages, roles, tags, notes, birth_date, source
    ) VALUES (
      'person',
      p_contact->>'first_name',
      COALESCE(NULLIF(p_contact->>'last_name',''), '-'),
      NULLIF(p_contact->>'primary_email',''),
      v_phones,
      v_addresses,
      v_languages,
      v_roles,
      v_tags,
      NULLIF(p_contact->>'notes',''),
      NULLIF(p_contact->>'birthday','')::DATE,
      'student_upsert'
    )
    RETURNING id INTO v_contact_id;

    INSERT INTO contact_student (
      contact_id, pipeline_stage, lead_source, is_candidate,
      level, photo_url, organization_role
    ) VALUES (
      v_contact_id,
      NULLIF(p_student->>'pipeline_stage','none'),
      NULLIF(p_student->>'lead_source',''),
      COALESCE((p_student->>'is_candidate')::BOOLEAN, false),
      NULLIF(p_student->>'level',''),
      NULLIF(p_student->>'photo_url',''),
      NULLIF(p_student->>'organization_role','')
    );

  ELSE
    -- ─── UPDATE-Pfad ────────────────────────────────────────────────────
    v_contact_id := p_contact_id;

    UPDATE contacts SET
      first_name    = p_contact->>'first_name',
      last_name     = COALESCE(NULLIF(p_contact->>'last_name',''), '-'),
      primary_email = NULLIF(p_contact->>'primary_email',''),
      phones        = v_phones,
      addresses     = v_addresses,
      languages     = v_languages,
      roles         = v_roles,
      tags          = v_tags,
      notes         = NULLIF(p_contact->>'notes',''),
      birth_date    = NULLIF(p_contact->>'birthday','')::DATE,
      updated_at    = now()
    WHERE id = v_contact_id;

    -- Sidecar upsert (Schüler ohne bisherigen Sidecar → erstellen)
    INSERT INTO contact_student (
      contact_id, pipeline_stage, lead_source, is_candidate,
      level, photo_url, organization_role
    ) VALUES (
      v_contact_id,
      NULLIF(p_student->>'pipeline_stage','none'),
      NULLIF(p_student->>'lead_source',''),
      COALESCE((p_student->>'is_candidate')::BOOLEAN, false),
      NULLIF(p_student->>'level',''),
      NULLIF(p_student->>'photo_url',''),
      NULLIF(p_student->>'organization_role','')
    )
    ON CONFLICT (contact_id) DO UPDATE SET
      pipeline_stage    = EXCLUDED.pipeline_stage,
      lead_source       = EXCLUDED.lead_source,
      is_candidate      = EXCLUDED.is_candidate,
      level             = EXCLUDED.level,
      photo_url         = EXCLUDED.photo_url,
      organization_role = EXCLUDED.organization_role,
      updated_at        = now();
  END IF;

  -- ─── Org-Link (works_at) ──────────────────────────────────────────────
  IF p_org_id IS NOT NULL THEN
    INSERT INTO contact_relationships (from_contact_id, to_contact_id, kind)
    VALUES (v_contact_id, p_org_id, 'works_at')
    ON CONFLICT DO NOTHING;
    -- Andere works_at-Relationships dieses Schülers entfernen (1:1-Annahme für Pitch)
    DELETE FROM contact_relationships
    WHERE from_contact_id = v_contact_id
      AND kind = 'works_at'
      AND to_contact_id <> p_org_id;
  ELSE
    DELETE FROM contact_relationships
    WHERE from_contact_id = v_contact_id
      AND kind = 'works_at';
  END IF;

  RETURN v_contact_id;
END;
$$;

-- RLS: dispatcher/owner dürfen aufrufen
GRANT EXECUTE ON FUNCTION student_upsert(UUID, JSONB, JSONB, UUID) TO authenticated;
```

- [ ] **Step 2: Section 5 in Studio anwenden**

- [ ] **Step 3: Synthetic Smoke-Test der RPC**

```sql
-- Insert-Pfad
SELECT student_upsert(
  NULL,
  '{"first_name":"Test","last_name":"Schueler","primary_email":"test@example.ch",
    "phone":"+41 79 000 00 00","birthday":"1990-01-15","notes":"RPC smoke test",
    "address":{"street":"Bahnhofstr 1","postal_code":"8001","city":"Zürich","country":"CH"},
    "tags":["smoke"],"languages":["de","en"],"is_student":true,"is_candidate":false}'::jsonb,
  '{"pipeline_stage":"lead","lead_source":"smoke","is_candidate":false,
    "level":"Anfänger","photo_url":null,"organization_role":null}'::jsonb,
  NULL
) AS new_id;

-- Verify
SELECT c.id, c.first_name, c.last_name, c.primary_email, c.phones, c.addresses,
       c.roles, c.tags, c.languages,
       cs.pipeline_stage, cs.lead_source, cs.level
FROM contacts c JOIN contact_student cs ON cs.contact_id = c.id
WHERE c.first_name = 'Test' AND c.last_name = 'Schueler';

-- Update-Pfad
SELECT student_upsert(
  '<new_id von oben>',
  '{"first_name":"Test","last_name":"Schueler","primary_email":"test@example.ch",
    "phone":"+41 79 000 00 00","birthday":"1990-01-15","notes":"updated",
    "address":{"street":"Bahnhofstr 1","postal_code":"8001","city":"Zürich","country":"CH"},
    "tags":["smoke"],"languages":["de","en"],"is_student":true,"is_candidate":false}'::jsonb,
  '{"pipeline_stage":"qualified","lead_source":"smoke","is_candidate":false,
    "level":"OWD","photo_url":null,"organization_role":null}'::jsonb,
  NULL
);

-- Verify stage_changed_on
SELECT pipeline_stage, stage_changed_on FROM contact_student
WHERE contact_id = '<new_id>';
-- Expected: 'qualified', current_date

-- Cleanup
DELETE FROM contacts WHERE first_name='Test' AND last_name='Schueler';
```

Expected: Insert liefert UUID, Update liefert dieselbe UUID, `stage_changed_on = current_date` nach Update.

---

## Task 6: Migration 0091 commiten

**Files:** keine Code-Änderung — nur Git.

- [ ] **Step 1: Migration-File committen**

Copy-Paste für Dominik:
```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add supabase/migrations/0091_phase_j_etappe_3a_sidecars.sql
git commit -m "feat(db): 0091 contact_student/instructor columns + stage_changed_on + student_upsert RPC"
```

---

## Task 7: TypeScript-Types nachziehen + `listStudents`-Helper

**Files:**
- Modify: `apps/web/src/types/contacts.ts` (ContactStudent + ContactInstructor)
- Modify: `apps/web/src/lib/contactQueries.ts` (am Ende anhängen, vor "Dedup & merge"-Section)

- [ ] **Step 0: ContactStudent + ContactInstructor Types ergänzen**

In `apps/web/src/types/contacts.ts` das `ContactStudent`-Interface erweitern um:

```typescript
export interface ContactStudent {
  contact_id: string
  pipeline_stage?: string | null
  lead_source?: string | null
  highest_brevet?: string | null
  intake_status?: string | null
  external_brevet_history?: unknown[]
  is_candidate: boolean
  candidate_target_level?: string | null
  medical_clearance_at?: string | null
  insurance_provider?: string | null
  // Aus Migration 0088
  preferred_language?: string | null
  // Aus Migration 0091 (Phase J Etappe 3a)
  level?: string | null
  photo_url?: string | null
  organization_role?: string | null
  stage_changed_on?: string | null
  created_at: string
  updated_at: string
}
```

Und `ContactInstructor` analog erweitern:

```typescript
export interface ContactInstructor {
  contact_id: string
  auth_user_id?: string | null
  padi_pro_number?: string | null
  padi_level?: string | null
  account_balance: number
  hourly_rate_chf?: number | null
  daily_rate_chf?: number | null
  active: boolean
  hire_date?: string | null
  termination_date?: string | null
  emergency_contact_name?: string | null
  emergency_contact_phone?: string | null
  notes_internal?: string | null
  // Aus Migration 0088
  app_role?: string | null
  preferred_language?: string | null
  // Aus Migration 0091 (Phase J Etappe 3a)
  initials?: string | null
  created_at: string
  updated_at: string
}
```

- [ ] **Step 1: Helper-Funktion einfügen**

Direkt nach `listPipelineContacts` (Zeile ~227):

```typescript
/**
 * Schüler-Liste für EnrollStudentSheet, MyStudentsScreen etc.
 *
 * Query: contacts JOIN contact_student (INNER), filtered auf archived_at IS NULL.
 * Liefert Backward-Compatible-Shape für fetchStudents-Caller.
 */
export interface StudentRow {
  id: string
  name: string
  email: string | null
  phone: string | null
  birthday: string | null
  level: string | null
  notes: string | null
  active: boolean
  created_at: string
  is_student: boolean
  is_candidate: boolean
  pipeline_stage: string | null
}

export async function listStudents(): Promise<StudentRow[]> {
  const { data, error } = await supabase
    .from('contacts')
    .select(
      'id, first_name, last_name, display_name, primary_email, phones, birth_date, ' +
        'notes, roles, archived_at, created_at, ' +
        'student:contact_student!inner(level, is_candidate, pipeline_stage)',
    )
    .is('archived_at', null)
    .order('last_name', { nullsFirst: false })
    .order('first_name', { nullsFirst: false })
  if (error) throw error
  return (data ?? []).map((c: unknown) => {
    const row = c as {
      id: string
      first_name: string | null
      last_name: string | null
      display_name: string | null
      primary_email: string | null
      phones: Array<{ e164?: string; primary?: boolean }> | null
      birth_date: string | null
      notes: string | null
      roles: string[] | null
      archived_at: string | null
      created_at: string
      student: { level: string | null; is_candidate: boolean; pipeline_stage: string | null } | null
    }
    const primaryPhone = (row.phones ?? []).find((p) => p.primary)?.e164 ?? row.phones?.[0]?.e164 ?? null
    return {
      id: row.id,
      name: row.display_name ?? [row.last_name, row.first_name].filter(Boolean).join(', '),
      email: row.primary_email,
      phone: primaryPhone,
      birthday: row.birth_date,
      level: row.student?.level ?? null,
      notes: row.notes,
      active: row.archived_at === null,
      created_at: row.created_at,
      is_student: (row.roles ?? []).includes('student'),
      is_candidate: row.student?.is_candidate ?? false,
      pipeline_stage: row.student?.pipeline_stage ?? null,
    }
  })
}
```

- [ ] **Step 2: TypeScript-Compile-Check**

Dominik:
```bash
cd /Users/dominik/Desktop/Developer/Dispo
npm --prefix apps/web run typecheck 2>&1 | head -30
```
Falls kein `typecheck`-Script existiert: `npx --prefix apps/web tsc --noEmit -p apps/web/tsconfig.json 2>&1 | head -30`.

Expected: keine Errors zu `listStudents`.

---

## Task 8: `fetchStudents` zum Wrapper umbauen

**Files:**
- Modify: `apps/web/src/lib/queries.ts` (Zeilen ~240–273)

- [ ] **Step 1: Alten `fetchStudents`-Body durch Wrapper ersetzen**

Ersetze in `apps/web/src/lib/queries.ts` den Block ab `export interface Student {` bis Ende von `fetchStudents()` durch:

```typescript
// ============================================================
// Students — Wrapper auf contactQueries.listStudents
// ============================================================

import { listStudents, type StudentRow } from '@/lib/contactQueries'

export type Student = StudentRow

export async function fetchStudents(): Promise<Student[]> {
  return listStudents()
}
```

**Note:** Importzeile oben in der Datei adden, falls noch nicht vorhanden — `import { listStudents, type StudentRow } from '@/lib/contactQueries'`. Den Re-Import als Inline-Statement nur in `legacy queries.ts` zu lassen ist OK, weil queries.ts den Helper bewusst zum Wrapper-Layer wird.

`Student`-Interface-Felder, die NICHT mehr im Shape sind: `padi_nr`, `organization_id`. EnrollStudentSheet nutzt nur `id, name, active` → kompatibel. Wenn der TypeScript-Compiler andere Caller flag't, in eigener Step adressieren.

- [ ] **Step 2: TypeScript-Compile-Check**

```bash
npm --prefix apps/web run typecheck 2>&1 | head -30
```

Expected: keine Errors. Falls Errors zu `padi_nr` / `organization_id` in anderen Files auftauchen — dort den Zugriff entfernen (war eh Schüler-Pro-Verwechslung).

- [ ] **Step 3: Commit**

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add apps/web/src/lib/contactQueries.ts apps/web/src/lib/queries.ts
git commit -m "feat(students): listStudents helper + fetchStudents wrapper auf contacts"
```

---

## Task 9: StudentEditSheet — `padi_nr`-Feld + State entfernen

**Files:**
- Modify: `apps/web/src/screens/StudentEditSheet.tsx`

- [ ] **Step 1: `padi_nr` aus Form-Interface entfernen**

In Zeile 14 löschen:
```typescript
  padi_nr: string
```

- [ ] **Step 2: `padi_nr` aus EMPTY-Default entfernen**

In Zeile 96 löschen:
```typescript
  padi_nr: '',
```

- [ ] **Step 3: `padi_nr` aus dem useEffect-Read entfernen**

In Zeile 142–146 die `cols`-Liste:
```typescript
      const cols = [
        'first_name','last_name','name','email','phone','birthday','level','notes','active',
        'address','postal_code','city','country','photo_url',
        'pipeline_stage','lead_source','tags','languages','organization_id','organization_role','is_candidate','is_student',
      ].join(',')
```
(`padi_nr` ist raus.)

Und in Zeile 164:
```typescript
            padi_nr: d.padi_nr ?? '',
```
löschen.

- [ ] **Step 4: `padi_nr` aus `save()`-Body entfernen**

In Zeile 211:
```typescript
      padi_nr: form.padi_nr.trim() || null,
```
löschen.

- [ ] **Step 5: PADI-Nr-Eingabefeld + Container aus JSX entfernen**

In Zeilen ~284–291 (das Grid mit Birthday + PADI Nr):
```tsx
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
            <Field label={t('student_edit.label_birthday')}>
              <input type="date" value={form.birthday} onChange={(e) => set('birthday', e.target.value)} style={inputStyle} />
            </Field>
            <Field label={t('student_edit.label_padi_nr')}>
              <input value={form.padi_nr} onChange={(e) => set('padi_nr', e.target.value)} placeholder={t('student_edit.placeholder_optional')} style={inputStyle} />
            </Field>
          </div>
```

Ersetzen durch:
```tsx
          <Field label={t('student_edit.label_birthday')}>
            <input type="date" value={form.birthday} onChange={(e) => set('birthday', e.target.value)} style={inputStyle} />
          </Field>
```

- [ ] **Step 6: TypeScript-Compile-Check**

```bash
npm --prefix apps/web run typecheck 2>&1 | grep -i "padi_nr\|StudentEditSheet" | head -20
```

Expected: keine Treffer (alle Referenzen weg).

---

## Task 10: StudentEditSheet — Load-Pfad auf `getContactWithSidecars`

**Files:**
- Modify: `apps/web/src/screens/StudentEditSheet.tsx` (useEffect-Block ~133-191)

- [ ] **Step 1: Import erweitern**

Zeile 5 (oder eigene Zeile) anpassen/ergänzen:
```typescript
import { supabase } from '@/lib/supabase'
import { getContactWithSidecars, listRelationships } from '@/lib/contactQueries'
```

- [ ] **Step 2: useEffect-Load-Block ersetzen**

Den `if (studentId) { ... }`-Block (Zeilen 141–183) komplett ersetzen durch:

```typescript
    if (studentId) {
      void (async () => {
        const cws = await getContactWithSidecars(studentId)
        if (!cws) return
        const phones = (cws.phones as Array<{ e164?: string; primary?: boolean }> | null) ?? []
        const primaryPhone = phones.find((p) => p.primary)?.e164 ?? phones[0]?.e164 ?? ''
        const addresses = (cws.addresses as Array<{
          street?: string; postal_code?: string; city?: string; country?: string; primary?: boolean
        }> | null) ?? []
        const primaryAddr = addresses.find((a) => a.primary) ?? addresses[0]

        // Org-Lookup: bestehende works_at-Relationship dieses Schülers
        let orgId = ''
        if (showCdFields) {
          const rels = await listRelationships(studentId)
          const worksAt = rels.find(
            (r) => r.kind === 'works_at' && r.from_contact_id === studentId,
          )
          orgId = worksAt?.to_contact_id ?? ''
        }

        setForm({
          first_name: cws.first_name ?? '',
          last_name:  cws.last_name === '-' ? '' : (cws.last_name ?? ''),
          email:      cws.primary_email ?? '',
          phone:      primaryPhone,
          birthday:   cws.birth_date ?? '',
          level:      cws.student?.level ?? 'Anfänger',
          notes:      cws.notes ?? '',

          address:     primaryAddr?.street      ?? '',
          postal_code: primaryAddr?.postal_code ?? '',
          city:        primaryAddr?.city        ?? '',
          country:     primaryAddr?.country     ?? '',
          photo_url:   cws.student?.photo_url   ?? '',

          pipeline_stage:    cws.student?.pipeline_stage    ?? 'none',
          lead_source:       cws.student?.lead_source       ?? '',
          tags:              (cws.tags ?? []).join(', '),
          languages:         cws.languages ?? [],
          organization_id:   orgId,
          organization_role: cws.student?.organization_role ?? '',
          is_student:        (cws.roles ?? []).includes('student'),
          is_candidate:      cws.student?.is_candidate ?? false,
        })
      })()
    } else {
```

(Der `else`-Block bleibt unverändert.)

- [ ] **Step 3: Org-Dropdown-Read auch auf contacts umstellen**

Zeile 137:
```typescript
      supabase.from('organizations').select('id, name').order('name').then(({ data }) => {
        setOrgs((data ?? []) as Org[])
      })
```

Ersetzen durch:
```typescript
      supabase
        .from('contacts')
        .select('id, display_name, legal_name, trading_name')
        .eq('kind', 'organization')
        .is('archived_at', null)
        .order('display_name')
        .then(({ data }) => {
          const rows = (data ?? []).map((o: { id: string; display_name: string | null; legal_name: string | null; trading_name: string | null }) => ({
            id: o.id,
            name: o.display_name ?? o.trading_name ?? o.legal_name ?? '(unnamed)',
          }))
          setOrgs(rows)
        })
```

- [ ] **Step 4: TypeScript-Compile-Check + lokal laufen lassen**

```bash
npm --prefix apps/web run typecheck 2>&1 | head -30
npm --prefix apps/web run dev
```

Dominik öffnet localhost, navigiert zum CD-Pipeline-Screen, klickt einen bestehenden Schüler → StudentEditSheet öffnet sich → alle Felder gefüllt? (KEIN Save in diesem Schritt.)

Expected: Form zeigt alle Werte korrekt, kein Console-Error.

---

## Task 11: StudentEditSheet — `save()` auf `student_upsert`-RPC

**Files:**
- Modify: `apps/web/src/screens/StudentEditSheet.tsx` (`save()`-Funktion ~201-249)

- [ ] **Step 1: `save()`-Body komplett ersetzen**

```typescript
  async function save() {
    if (!form.first_name.trim()) return
    setSaving(true)
    setError(null)

    const contactPayload: Record<string, unknown> = {
      first_name: form.first_name.trim(),
      last_name:  form.last_name.trim() || null,
      primary_email: form.email.trim() || null,
      phone:      form.phone.trim() || null,
      birthday:   form.birthday || null,
      notes:      form.notes.trim() || null,
      is_student: showCdFields ? form.is_student : true,
      is_candidate: showCdFields ? form.is_candidate : false,
    }

    if (showCdFields) {
      contactPayload.address = {
        street:      form.address.trim(),
        postal_code: form.postal_code.trim(),
        city:        form.city.trim(),
        country:     form.country.trim(),
      }
      contactPayload.tags = csvToArray(form.tags)
      contactPayload.languages = form.languages
    }

    const studentPayload: Record<string, unknown> = {
      pipeline_stage:    showCdFields ? form.pipeline_stage : 'none',
      lead_source:       showCdFields ? form.lead_source.trim() : '',
      is_candidate:      showCdFields ? form.is_candidate : false,
      level:             form.level || 'Anfänger',
      photo_url:         showCdFields ? (form.photo_url.trim() || null) : null,
      organization_role: showCdFields ? (form.organization_role.trim() || null) : null,
    }

    const { data, error: rpcErr } = await supabase.rpc('student_upsert', {
      p_contact_id: studentId ?? null,
      p_contact:    contactPayload,
      p_student:    studentPayload,
      p_org_id:     showCdFields && form.organization_id ? form.organization_id : null,
    })

    if (rpcErr) { setError(rpcErr.message); setSaving(false); return }
    setSaving(false)
    onSaved(data as string)
    onClose()
  }
```

- [ ] **Step 2: TypeScript-Compile-Check**

```bash
npm --prefix apps/web run typecheck 2>&1 | head -30
```

---

## Task 12: StudentEditSheet — `deleteStudent()` auf `contacts.delete`

**Files:**
- Modify: `apps/web/src/screens/StudentEditSheet.tsx` (~251-260)

- [ ] **Step 1: `deleteStudent()`-Body ersetzen**

```typescript
  async function deleteStudent() {
    if (!isEdit) return
    if (!confirm(t('student_edit.confirm_delete'))) return
    setSaving(true)
    const { error: delErr } = await supabase.from('contacts').delete().eq('id', studentId!)
    setSaving(false)
    if (delErr) { setError(delErr.message); return }
    onSaved()
    onClose()
  }
```

(CASCADE auf `contacts.id` räumt `contact_student`, `contact_relationships`, etc. automatisch auf — definiert in 0079.)

- [ ] **Step 2: TypeScript-Compile-Check + Commit**

```bash
npm --prefix apps/web run typecheck 2>&1 | grep -i "StudentEditSheet" | head -10
```

Expected: leer.

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add apps/web/src/screens/StudentEditSheet.tsx
git commit -m "refactor(students): StudentEditSheet auf contacts + student_upsert RPC, padi_nr-Feld raus"
```

---

## Task 13: Vercel-Preview Smoke-Test

**Files:** keine.

- [ ] **Step 1: Branch pushen**

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git push -u origin phase-j-etappe-3a-students
```

Vercel deployed automatisch einen Preview von dem Branch.

- [ ] **Step 2: 5-Punkt-Smoke-Test im Preview**

| # | Aktion | Erwartung |
|---|---|---|
| 1 | Neuen Schüler anlegen mit Stamm + CD-Feldern (Adresse, Pipeline, Org, Tags, Sprachen) | Erscheint in CD-Pipeline-View. In DB: Eintrag in `contacts`, `contact_student`, `contact_relationships` (works_at). |
| 2 | Schüler bearbeiten — alle Felder ändern | Updates landen am richtigen Ort. `addresses` jsonb hat aktualisierten Eintrag. |
| 3 | Pipeline-Stage ändern (z. B. lead → qualified) | `contact_student.stage_changed_on` = heute. |
| 4 | Schüler löschen | Eintrag in `contacts` weg. `contact_student`, `contact_relationships` ebenfalls weg (CASCADE). Keine Orphans. |
| 5 | EnrollStudentSheet bei einem Kurs öffnen | Liste lädt, Schüler-Auswahl funktioniert (Filter `s.active` greift), Enroll-Save klappt. |

**SQL für Cleanup-Verifikation (nach Test 4):**
```sql
SELECT count(*) FROM contact_student cs LEFT JOIN contacts c ON c.id = cs.contact_id WHERE c.id IS NULL;
SELECT count(*) FROM contact_relationships cr
  LEFT JOIN contacts c1 ON c1.id = cr.from_contact_id
  LEFT JOIN contacts c2 ON c2.id = cr.to_contact_id
  WHERE c1.id IS NULL OR c2.id IS NULL;
```
Expected: beide 0.

- [ ] **Step 3: Bei Bugs — fixen, force-pushen, Smoke-Test neu**

Wenn ein Punkt fehlschlägt → Fix als kleinen Commit auf den Branch, Vercel deployed neu, Tests wiederholen.

---

## Task 14: Merge in main

**Files:** keine.

- [ ] **Step 1: Sync-Trigger nochmal aktiv prüfen**

Studio:
```sql
SELECT tgname, tgenabled FROM pg_trigger
WHERE tgname LIKE '%sync_%_to_contacts%';
```

Expected: alle `O` (enabled). Falls eine auf `D` — `ALTER TABLE <legacy_table> ENABLE TRIGGER <trigger_name>;`.

- [ ] **Step 2: Merge in main**

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git checkout main
git merge --no-ff phase-j-etappe-3a-students -m "merge: Phase J Etappe 3a — StudentEditSheet auf contacts + Migration 0091"
git push origin main
```

- [ ] **Step 3: Branch löschen**

```bash
git branch -d phase-j-etappe-3a-students
git push origin --delete phase-j-etappe-3a-students
```

- [ ] **Step 4: Status-Check**

Dominik:
- Vercel deployed main → Production-Smoke-Test (1 Schüler anlegen, gleich wieder löschen).
- Wenn rot: revert merge mit `git revert -m 1 <merge-commit-sha>` + push.
