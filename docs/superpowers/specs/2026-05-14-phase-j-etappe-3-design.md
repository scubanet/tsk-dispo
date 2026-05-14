# Phase J Etappe 3 — Schema-Cleanup & Legacy-Drop

**Status:** Draft (User-Review pending)
**Date:** 2026-05-14
**Author:** Dominik Weckherlin (with Claude)
**Spec Owner:** Dominik
**Target Release:** Post-Pitch — kein Pitch-Blocker

---

## 1. Kontext & Problem

Phase J migriert das Datenmodell von Legacy-Tabellen (`instructors`, `people`, `organizations`) auf `contacts` + Sidecars (`contact_instructor`, `contact_student`, `contact_organization`).

**Stand heute (verifiziert 2026-05-14):**

- Etappen 1, 2a–2d sind durch. `from('people')`/`from('instructors')` ist im Frontend bis auf 5 Stellen weg.
- Migrations 0080–0089 sind angewandt. 0090 ist mit `padi_skill_records` belegt — die Memory-Annahme „0090 = contact_student-Spalten" ist obsolet.
- `from('people')`-Reste: `StudentEditSheet.tsx` (4 Operations), `lib/queries.ts::fetchStudents` (1 Read).
- `from('instructors')`-Reste: `SkillCheckTab.tsx`, `lib/padiReferralFill.ts` (beide Reads für `initials`), `i18n/useLanguage.ts` (Write `preferred_language`).
- Sync-Triggers aus 0083/0088 sind aktiv und spiegeln Legacy → Sidecar.

**Pain-Point:** Das System läuft funktional, aber zwei Datenmodelle parallel zu pflegen ist Overhead — und Sync-Trigger-Disabling (wie am 10.05. bei Migration 0086) hat historisch Drift erzeugt, die manuell nachgeholt werden musste.

**Ziel:** Forward-only-Cutover der letzten 5 Frontend-Stellen, dann Sync-Triggers droppen, dann Legacy-Tabellen droppen. Ein Datenmodell, kein Trigger-Overhead, weniger Drift-Risiko.

## 2. Scope & Out-of-Scope

**In Scope:**

- Migration 0091 — Spalten auf `contact_student` und `contact_instructor` ergänzen, Sync-Trigger erweitern.
- Frontend-Cutover: 5 Files auf `contacts` + Sidecars umstellen, `padi_nr`-Feld aus StudentEditSheet entfernen.
- Migration 0092 — Sync-Triggers droppen.
- Migration 0093 — Legacy-Tabellen `instructors`, `people`, `organizations` droppen (CASCADE).

**Out of Scope:**

- Refactor von `contact_student.highest_brevet` und `candidate_target_level` (unbesetzt, bleiben für späteren Cleanup-PR).
- Multi-Org-Modellierung für `organization_role` (YAGNI für Pitch).
- AvailabilityTab Etappen 3+4.
- Resend-Email, iOS-Audit (eigene Specs).

## 3. Datenmodell-Entscheidungen

### 3.1 Schüler vs. Pro — Trennlinie im UI

**Entscheidung:** PADI-Pro-Nummern (DM aufwärts) leben ausschliesslich auf `contact_instructor.padi_pro_number`. Das Eingabefeld wird aus `StudentEditSheet` entfernt und bleibt nur im `InstructorTab` editierbar.

**Begründung:** Schüler bis und mit Rescue Diver haben keine fixe PADI-Mitgliedsnummer, sondern wechselnde Zertifikat-Nummern pro Karte. Diese gehören in `student_certifications.certificate_nr` (existiert seit langem), nicht auf die Person. Die saubere Trennung im UI spiegelt das Datenmodell.

### 3.2 Migration 0091 — Spalten-Ergänzungen

**`contact_student` — neue Spalten:**

| Spalte | Typ | Quelle (Legacy) | Default |
|---|---|---|---|
| `level` | TEXT | `people.level` | NULL |
| `photo_url` | TEXT | `people.photo_url` | NULL |
| `organization_role` | TEXT | `people.organization_role` | NULL |
| `stage_changed_on` | DATE | (neu, Trigger-gesetzt) | NULL |

**`contact_instructor` — neue Spalte (Stretch für Etappe 3b):**

| Spalte | Typ | Quelle (Legacy) | Default |
|---|---|---|---|
| `initials` | TEXT | `instructors.initials` | NULL |

**`level` als TEXT:** Frei-Text mit UI-seitiger Validierung gegen die `LEVELS`-Konstante in StudentEditSheet (13 Werte). Kein eigener Enum — der bestehende `padi_level`-Enum passt nur für Pro-Levels (DM aufwärts).

**`stage_changed_on`-Trigger:**

```sql
CREATE OR REPLACE FUNCTION tg_contact_student_stage_changed()
RETURNS TRIGGER AS $$
BEGIN
  IF OLD.pipeline_stage IS DISTINCT FROM NEW.pipeline_stage THEN
    NEW.stage_changed_on := current_date;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_contact_student_stage_changed
  BEFORE UPDATE ON contact_student
  FOR EACH ROW EXECUTE FUNCTION tg_contact_student_stage_changed();
```

**Sync-Trigger-Erweiterung:** Die Functions aus 0083/0088 (`sync_people_to_contacts`, `sync_instructors_to_contacts`) werden um die 5 neuen Spalten ergänzt, damit Legacy-Writes bis zum Drop weiter konsistent gespiegelt werden.

### 3.3 Field-Mapping StudentEditSheet → neue Welt

**`contacts`-Felder (existieren, müssen geschrieben werden):**

| UI | Ziel |
|---|---|
| `first_name`, `last_name` | `contacts.first_name`, `contacts.last_name` |
| `email` | `contacts.primary_email` |
| `phone` | `contacts.phones` jsonb: `[{label:'mobile', e164, primary:true}]` |
| `birthday` | `contacts.birth_date` |
| `address/postal_code/city/country` | `contacts.addresses` jsonb: einzelner Eintrag |
| `notes` | `contacts.notes` |
| `tags` (CSV) | `contacts.tags` TEXT[] |
| `languages` (Codes) | `contacts.languages` TEXT[] |
| `is_student` (Bool) | `contacts.roles[]` enthält `'student'` |
| `active` | `contacts.archived_at IS NULL` (invertiert) |

**`contact_student`-Felder (bestehende + neue aus 0091):**

| UI | Ziel |
|---|---|
| `pipeline_stage` | `contact_student.pipeline_stage` (existiert) |
| `lead_source` | `contact_student.lead_source` (existiert) |
| `is_candidate` | `contact_student.is_candidate` (existiert) |
| `level` | `contact_student.level` (neu) |
| `photo_url` | `contact_student.photo_url` (neu) |
| `organization_role` | `contact_student.organization_role` (neu) |

**`contact_relationships`-Feld:**

| UI | Ziel |
|---|---|
| `organization_id` | Row mit `kind='works_at'`, `from_contact_id=student_id`, `to_contact_id=org_id` |

**Entfernt:** `padi_nr` (siehe 3.1).

### 3.4 `student_upsert`-RPC

Frontend macht heute drei Writes pro Save (people, optional org-link in legacy join). Im neuen Modell wären das mindestens drei Targets (`contacts`, `contact_student`, `contact_relationships`). Bei Fehler auf halber Strecke entsteht inkonsistenter State.

**Lösung:** Supabase-RPC `student_upsert(p_contact_id UUID NULL, p_contact JSONB, p_student JSONB, p_org_id UUID NULL)`:

- `p_contact_id = NULL` → Insert-Path: erstellt `contacts`, `contact_student`, optional `contact_relationships` in einer Transaktion.
- `p_contact_id` gesetzt → Update-Path: aktualisiert die drei Targets in einer Transaktion. Org-Link wird upserted (oder gelöscht, wenn `p_org_id = NULL`).
- Return: `contact_id UUID`.

Delete bleibt direkter `DELETE FROM contacts WHERE id = $1` — CASCADE räumt Sidecars + Relationships auf.

## 4. Cutover-Etappen

### 4.1 Etappe 3a — Studenten-Modell

**Branch:** `phase-j-etappe-3a-students`

**Migrations:**
- `0091_contact_sidecars_columns.sql`: Spalten + Backfill + Sync-Trigger-Erweiterung + `stage_changed_on`-Trigger.

**Frontend:**
- `StudentEditSheet.tsx`: `padi_nr`-Feld entfernen; Insert/Update/Delete-Path auf RPC bzw. `from('contacts').delete()`.
- `lib/contactQueries.ts`: neuer Helper `listStudents()` analog `listActiveInstructors`.
- `lib/queries.ts`: `fetchStudents` als Wrapper auf `listStudents` (oder direkt ablösen — `grep` zeigt einen Caller: `EnrollStudentSheet`).

**RPC-Definition:** Teil von Migration 0091 (separate Section am Ende).

**Smoke-Test im Vercel-Preview vor Merge:**
1. Schüler anlegen mit allen Feldern → in DB Schüler vorhanden in `contacts` + `contact_student` + `contact_relationships`.
2. Schüler bearbeiten (alle Felder ändern) → Updates landen am richtigen Ort.
3. Pipeline-Stage ändern → `stage_changed_on` rückt auf heute.
4. Schüler löschen → CASCADE räumt sauber auf.
5. EnrollStudentSheet listet alle Schüler korrekt.

### 4.2 Etappe 3b — Instructor-Reads + i18n

**Branch:** `phase-j-etappe-3b-instructors-i18n`

**Frontend:**
- `SkillCheckTab.tsx`: Read auf `contacts` join `contact_instructor` (für `initials`).
- `lib/padiReferralFill.ts`: dasselbe.
- `i18n/useLanguage.ts`: Write `preferred_language` auf `contact_instructor.preferred_language` (existiert seit 0088), Legacy-Write entfernen.

**Auth-adjacent:** `useLanguage` läuft mit `auth_user_id`-Lookup. Smoke-Test:
1. Login → Sprache aus Sidecar gelesen.
2. Sprache wechseln → Sidecar-Update sichtbar nach Reload.
3. Logout → Re-Login mit anderer Sprache, kein 401.

### 4.3 Etappe 3c — Legacy-Drop

**Branch:** `phase-j-etappe-3c-cleanup`

**Migrations:**
- `0092_drop_sync_triggers.sql`: alle Sync-Triggers + Functions aus 0083/0088 droppen. Partial-Unique-Index `uniq_works_at` bleibt (harmlos, vom Frontend benötigt).
- `0093_drop_legacy_tables.sql`: `DROP TABLE instructors, people, organizations CASCADE` — vorher `pg_depend`-Check als Migration-Kommentar dokumentiert.

**Lange Preview-Phase:** Dieser Branch bleibt mindestens 48h im Vercel-Preview. Wenn ein vergessener Legacy-Read auftaucht (z. B. in einer Edge-Function, einem `.tar.gz`-Snapshot oder einem Skript-Pfad), bricht der Preview, ohne Production zu touchen.

## 5. Pre-Flight (vor Migration 0091)

Drift-Check seit dem 10.05.-Backfill — Lehre aus dem Sync-Trigger-Disabled-Vorfall:

```sql
-- 1. people → contacts Drift
SELECT p.id, p.first_name, p.last_name, p.created_at
FROM people p LEFT JOIN contacts c ON c.id = p.id
WHERE p.created_at > '2026-05-10' AND c.id IS NULL;

-- 2. instructors → contacts Drift
SELECT i.id, i.name, i.created_at
FROM instructors i LEFT JOIN contacts c ON c.id = i.id
WHERE i.created_at > '2026-05-10' AND c.id IS NULL;

-- 3. organizations → contacts Drift
SELECT o.id, o.name, o.created_at
FROM organizations o LEFT JOIN contacts c ON c.id = o.id
WHERE o.created_at > '2026-05-10' AND c.id IS NULL;

-- 4. Sind die Sync-Triggers aktiv?
SELECT tgname, tgenabled
FROM pg_trigger
WHERE tgname LIKE '%sync_%_to_contacts%';
```

Wenn Drift gefunden → manuell backfillen wie am 10.05., bevor 0091 läuft.

## 6. Risiken & Mitigations

| Risiko | Mitigation |
|---|---|
| Inkonsistenz bei mehrstufigem Save | `student_upsert`-RPC mit Transaktion |
| Drift seit 10.05. nicht erkannt | Pre-Flight-Queries als Migration-Kommentar pflichtig vor Apply |
| Edge-Function oder Backup-Skript greift noch auf Legacy zu | 48h-Preview vor 0093, `grep` durch `supabase/functions/` + `scripts/` als Audit-Schritt vor 3c |
| `padi_nr`-Feld-Verlust verwirrt User | Migrationsnotiz im UI-Helper-Text im InstructorTab; existierende Werte sind in `contact_instructor.padi_pro_number` bereits gespiegelt (0088-Sync) |
| Schema-Migration partial-applied (Studio commits pro Statement) | 0091 strikt idempotent (`ADD COLUMN IF NOT EXISTS`, `IS DISTINCT FROM` in Backfills) |

## 7. Testing & Verification

- **Pre-Flight:** Drift-Queries grün.
- **3a Smoke-Test:** 5 Szenarien aus §4.1.
- **3b Smoke-Test:** 3 Szenarien aus §4.2.
- **3c Audit:** `grep -r "from('people\|from('instructors\|from('organizations" apps/ supabase/functions/ scripts/` muss leer sein.

## 8. Commit-Strategie

Pro Etappe eine PR mit kleinen thematischen Commits:

- 3a: `feat(db): 0091 contact_student/instructor columns + stage trigger` · `feat(rpc): student_upsert` · `refactor(students): StudentEditSheet auf RPC + Sidecar` · `refactor(students): fetchStudents → listStudents` · `feat(ui): padi_nr aus StudentEditSheet entfernt`
- 3b: `refactor(skills): SkillCheckTab auf contact_instructor` · `refactor(forms): padiReferralFill auf contact_instructor` · `refactor(i18n): useLanguage auf contact_instructor.preferred_language`
- 3c: `chore(db): 0092 drop sync triggers` · `chore(db): 0093 drop legacy tables`

Migrations werden nach manuellem Studio-Apply committet, damit Repo + DB synchron bleiben.
