# ATOLL × CD App Integration — Plan v4.0

**Datum:** 2026-05-03
**Status:** Plan, bereit für Phase 1
**Quelle:** Übernimmt Logik aus `/Users/dominik/Desktop/Developer/CD App` (SwiftUI/SwiftData/CloudKit)
**Ziel:** Komplette CD-Funktionalität (v1 + v2 CRM) in ATOLL als neue Rolle "CD"

---

## User-Entscheidungen (Final v2)

1. **Scope:** Alles übernehmen (v1 + v2 CRM)
2. **People-DB:** Eine Tabelle für alle Personen (existing `students` erweitern)
3. **Kurse:** **GLEICHE Logik** wie ATOLL-Kurse — DM/IDC/SPEI/EFRI sind schon als `course_types` da. KEINE separate `cd_courses` Tabelle. Kandidaten = Students mit `is_candidate=true` und Course-Enrollment via existing `course_participants`.
4. **CD-Modul ist exklusiv für `cd`-Rolle** — Dispatcher sieht es NICHT (zukünftiges SaaS-Modell: dazukauen). Owner sieht es read-only.
5. **CD App:** Wird neu gebaut auf Supabase, alte iOS-CD-App wird abgelöst
6. **Plattform:** Web first

### Anmerkung zu DM (2026-05-03)

DM ist KEIN originärer CD-Kurs. Im CD-Modul wird er trotzdem geführt, weil er als **Recruiting-Kanal** für DM-Kandidat:innen dient die später in den IDC eingeführt werden sollen — genau wie es die alte CD-App auch handhabte. Im UI ist das durch ein Label „Pro-Stufen (IDC, SPEI, EFRI · DM für Recruiting)" und einen Hinweis im PR-Tab-Header gekennzeichnet. Die echten Pro-Level-Kurse die der CD leitet sind IDC, SPEI und EFRI.

## Architektur-Entscheidungen (basierend auf User)

### A1. `students` als zentrale People-Tabelle

Existing `students` wird erweitert. Felder die schon da sind: `first_name`, `last_name`, `email`, `phone`, `birthday`, `padi_nr`, `level`, `notes`, `active`. Neu hinzu kommen die CD-spezifischen Felder.

Vermeidet eine separate `candidates`-Tabelle und doppelte Identitäten.

### A2. CD-Kurse separat von ATOLL-Kursen

`courses` (existing) sind operative Tauchkurse mit Pool/See-Tagen, Vergütung etc.
`cd_courses` (neu) sind Kandidaten-Kurse (DM/IDC/SPEI/EFRI) mit Sessions + PRs.

Begründung: Komplett andere Logik. Dispatcher bucht keine Vergütung für DM-Kandidaten-Kurse, dort geht's um PR-Check-Offs nicht um Stundensätze.

### A3. CD-Rolle mit Vollzugriff

`cd` ENUM-Wert dazu. CD sieht **alles vom Dispatcher** PLUS die CD-Module:
- Kandidaten (= erweiterte Student-Liste mit CD-Felder)
- CD-Kurse (DM/IDC/SPEI Pipeline)
- Live Check-Off
- CRM (Organizations, Pipeline, Communication)

### A4. PADI-Standards als Daten in DB, nicht JSON

CD App hat Kataloge als `pr-catalogs/*.json`. Diese werden zu einer `pr_catalogs` Tabelle in Supabase. Ein-Mal-Seed beim Setup, später optional editierbar.

---

## Phasen-Übersicht

| Phase | Inhalt | Aufwand |
|---|---|---|
| 1 | Schema: students erweitern, neue Tabellen, CD-Rolle, RLS | 3-4h |
| 2 | PR-Kataloge importieren (JSON → DB seed migration) | 2h |
| 3 | People-DB erweitern im Web (StudentEditSheet/StudentDetailPanel) | 4-6h |
| 4 | CD-Kurse: Liste + Detail + Anlegen + Kandidaten zuweisen | 6-8h |
| 5 | Sessions pro CD-Kurs + Live Check-Off Sheet | 6-8h |
| 6 | Course Dashboard mit Lückenanalyse + Pre-Req-Checker | 4-6h |
| 7 | CRM v2: Organizations, Pipeline, Communication-Logs | 8-12h |
| 8 | Daten-Migration aus alter CD App (CloudKit-Export → Supabase) | 4h |

**Total:** ~6 Wochen Teilzeit, je nach Tempo

---

## Phase 1 — Schema (DETAIL)

### 1.1 Migration 0048: students erweitern + CD-Rolle

```sql
-- ENUM erweitern um 'cd'
ALTER TYPE app_role ADD VALUE IF NOT EXISTS 'cd';

-- students um CD-spezifische Felder erweitern
ALTER TABLE students
  ADD COLUMN IF NOT EXISTS address     TEXT NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS postal_code TEXT NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS city        TEXT NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS country     TEXT NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS photo_url   TEXT,
  ADD COLUMN IF NOT EXISTS pipeline_stage TEXT NOT NULL DEFAULT 'none',
  ADD COLUMN IF NOT EXISTS lead_source    TEXT NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS tags           TEXT[] NOT NULL DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS languages      TEXT[] NOT NULL DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS organization_id UUID REFERENCES organizations(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS organization_role TEXT NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS stage_changed_on TIMESTAMPTZ NOT NULL DEFAULT now(),
  ADD COLUMN IF NOT EXISTS is_candidate   BOOLEAN NOT NULL DEFAULT false;

-- CD-Helper-Function
CREATE OR REPLACE FUNCTION is_cd_or_dispatcher() ... role IN ('cd', 'dispatcher');
CREATE OR REPLACE FUNCTION is_cd() ... role = 'cd';
```

### 1.2 Migration 0049: organizations Tabelle

```sql
CREATE TABLE organizations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  kind TEXT,                      -- "dive_club", "company", etc.
  address, postal_code, city, country TEXT,
  email, phone, website TEXT,
  notes TEXT,
  active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

### 1.3 Migration 0050: contact_relationships, communication_entries

### 1.4 Migration 0051: prior_certifications erweitern (existing aus 0028 nutzen)

Existing `certifications` Tabelle hat schon `student_id`, `certification`, `certified_on`. Möglicherweise erweitern um:
- `agency` (PADI / SSI / SDI)
- `cert_number`
- `instructor` (wer hat zertifiziert)

### 1.5 Migration 0052: elearning_progress

```sql
CREATE TABLE elearning_progress (
  id UUID PRIMARY KEY,
  student_id UUID REFERENCES students(id) ON DELETE CASCADE,
  course_code TEXT NOT NULL,        -- "OWD", "AOWD", "DM", etc.
  status TEXT,                       -- "started", "completed"
  progress_pct INT,
  started_on, completed_on DATE,
  notes TEXT
);
```

### 1.6 Migration 0053: intake_checklists

```sql
CREATE TABLE intake_checklists (
  id UUID PRIMARY KEY,
  student_id UUID REFERENCES students(id) ON DELETE CASCADE UNIQUE,
  medical_received, medical_signed, logbook_seen,
  id_seen, insurance_proof BOOLEAN ...,
  notes TEXT
);
```

### 1.7 Migration 0054: cd_courses + cd_sessions

```sql
CREATE TABLE cd_courses (
  id UUID PRIMARY KEY,
  type TEXT NOT NULL,                -- "DM" | "IDC" | "SPEI" | "EFRI"
  variant TEXT,
  title TEXT NOT NULL,
  start_date, end_date DATE,
  location TEXT,
  status TEXT,                        -- "planned" | "active" | "completed"
  catalog_version TEXT,
  notes TEXT,
  cd_id UUID REFERENCES instructors(id), -- der CD der den Kurs leitet
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE cd_course_candidates (
  cd_course_id UUID REFERENCES cd_courses(id) ON DELETE CASCADE,
  student_id UUID REFERENCES students(id) ON DELETE CASCADE,
  PRIMARY KEY (cd_course_id, student_id)
);

CREATE TABLE cd_sessions (
  id UUID PRIMARY KEY,
  cd_course_id UUID REFERENCES cd_courses(id) ON DELETE CASCADE,
  date DATE NOT NULL,
  slot_code TEXT,                     -- "CW1", "OW1", "Theory1"
  title TEXT,
  location TEXT,
  duration_minutes INT,
  notes TEXT
);

CREATE TABLE cd_session_attendees (
  cd_session_id UUID REFERENCES cd_sessions(id) ON DELETE CASCADE,
  student_id UUID REFERENCES students(id) ON DELETE CASCADE,
  PRIMARY KEY (cd_session_id, student_id)
);
```

### 1.8 Migration 0055: performance_records

```sql
CREATE TABLE performance_records (
  id UUID PRIMARY KEY,
  student_id UUID REFERENCES students(id) ON DELETE CASCADE,
  cd_course_id UUID REFERENCES cd_courses(id) ON DELETE CASCADE,
  cd_session_id UUID REFERENCES cd_sessions(id) ON DELETE SET NULL,
  pr_code TEXT NOT NULL,
  status TEXT NOT NULL,              -- "not_started" | "in_progress" | "completed" | "remediation"
  score INT,
  assessed_on DATE,
  assessed_by TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_pr_student_course ON performance_records(student_id, cd_course_id);
```

### 1.9 Migration 0056: pr_catalogs (PADI Standards)

```sql
CREATE TABLE pr_catalogs (
  id UUID PRIMARY KEY,
  course_type TEXT NOT NULL,        -- "DM" | "IDC" | "SPEI" | "EFRI"
  language TEXT NOT NULL,            -- "de" | "en"
  version TEXT NOT NULL,
  data JSONB NOT NULL,               -- whole catalog as JSON (slots, skills, prereqs)
  active BOOLEAN NOT NULL DEFAULT true,
  UNIQUE (course_type, language, version)
);
```

### 1.10 RLS für alle neuen Tabellen

- Read: `is_owner_or_dispatcher()` OR `is_cd()`
- Write: `is_dispatcher()` OR `is_cd()` (Dispatcher kann auch CD-Daten editieren)

---

## Phase 1 Deliverables (jetzt)

- [ ] Migration 0048: ENUM 'cd' + students erweitert + Helper Functions
- [ ] Migration 0049: organizations
- [ ] Migration 0050: contact_relationships + communication_entries
- [ ] Migration 0051: certifications erweitern
- [ ] Migration 0052: elearning_progress
- [ ] Migration 0053: intake_checklists
- [ ] Migration 0054: cd_courses + cd_sessions + Pivots
- [ ] Migration 0055: performance_records
- [ ] Migration 0056: pr_catalogs
- [ ] RLS für alle neuen Tabellen

Migrationen 0048-0056 sind ein zusammenhängendes Schema-Set. Nach Anwendung ist die DB bereit für die Web-UI.
