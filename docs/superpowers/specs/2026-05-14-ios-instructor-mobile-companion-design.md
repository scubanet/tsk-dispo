# iOS Instructor Mobile Companion — Studenten, Intake, Skill-Check

**Status:** Draft (User-Review pending)
**Date:** 2026-05-14
**Author:** Dominik Weckherlin (with Claude)
**Spec Owner:** Dominik
**Target Release:** Pre-Pitch (Soft-Live mit 3–5 Test-Instructors)

---

## 1. Kontext & Problem

### Heutiger Zustand

Die iOS-App (`apps/ios-native/ATOLL/`) ist heute eine reine Instructor-Eigen-Sicht: 5 Tabs (`Heute`, `Kalender`, `Einsätze`, `Saldo`, `Profil`). Sie zeigt dem eingeloggten Instructor seine eigenen Einsätze, seinen Saldo, sein Profil. Daten der ihm zugeordneten Kurs-Teilnehmer sind nicht sichtbar — alles was Schüler-zentriert ist, lebt nur im Web.

Zusätzlich liest `AuthState.swift` noch von der Legacy-Tabelle `instructors` (Phase-J-Restschuld, siehe `project_phase_j.md`). Diese Tabelle bleibt zwar als Read-Only-Ghost bestehen, bis sie nach iOS-Audit + Edge-Function-Migration final gedroppt wird.

### Pain-Point

1. Instructor unterwegs (Pool, See, Boot) hat keine Übersicht, **wer in seinem Kurs ist**. Muss aufs Laptop am Abend.
2. Pre-Dive-Checks (Medical, Liability, Safe Diving) müssen heute mit Stift auf Papier oder am Laptop später abgehakt werden — nicht im Moment des Checks.
3. Skill-Abhaken passiert heute frühestens abends am Web. Verlorene Granularität: was im Pool entschieden wurde, ist abends verschwommen.
4. Pitch-Story "The Scuba OS" verspricht mobile Instructor-Companion — Demo ohne iOS-Schüler-Workflow bleibt halbherzig.

### Was diese Spec NICHT löst

- Keine Offline-DB (Optimistisches Online-Pattern reicht)
- Keine Signaturen-Capture / PDF-Generation
- Kein IDC-volles-Intake (nur Pre-Dive-Light: Medical/Liability/Safe Diving)
- Keine Skill-Definitions-Editor in iOS (DB-managed, anderer Pfad)
- Keine Studenten-Stammdaten-Edit oder Neu-Anlage in iOS (Read-only)
- Kein "Kurs anlegen" in iOS (Web-only)
- Saldo und Einsätze entfallen aus der App (zurück zu Web wenn nötig)

---

## 2. Ziel & Vision

iOS-Rolle nach diesem Release: **Mobile Companion** für Instructors. Alles was unterwegs gebraucht wird (Heute-Sicht, Kurse, Teilnehmer ansehen, Intake handhaben, Skill-Check), ist erreichbar. Admin und Reporting bleiben Web.

**Erfolgsmetrik:** Im Pitch-Demo läuft eine End-to-End-Story (Heute → Kurs → Teilnehmer → Intake setzen → Skill abhaken → ergebnis im Web sichtbar) ohne sichtbare Bugs. Im 2-wöchigen Soft-Live nutzen die Test-Instructors die App freiwillig.

---

## 3. Architektur-Überblick

### Tab-Restruktur

| heute (5 Tabs) | nachher (4 Tabs) |
|---|---|
| Heute | Heute |
| Kalender | **Kurse** (umbenannt) |
| Einsätze | — entfällt — |
| Saldo | — entfällt — |
| Profil | Profil |
| — | **Studenten** (neu) |

### Code-Konvention (bestehend, beibehalten)

- Models: `Codable struct`, in `Models/`
- Stores: `@Observable final class`, in `Services/`, sprechen direkt Supabase-Client (siehe `MovementsStore`, `SkillsStore` als Vorbild)
- Views: SwiftUI `struct`, in `Views/`
- Kein Repository-Layer, keine Dependency Injection, keine Test-Frameworks zusätzlich
- Sprache: Deutsch in der UI, Englisch im Code (existierende Konvention)

### Neue Files

```
apps/ios-native/ATOLL/
  Models/
    Student.swift                       (neu)
    CourseParticipant.swift             (neu)
    IntakeChecklist.swift               (neu)
    SkillDefinition.swift               (neu)
    SkillRecord.swift                   (neu)
  Services/
    ParticipantsStore.swift             (neu)
    StudentsStore.swift                 (neu)
    IntakeStore.swift                   (neu)
    SkillCheckStore.swift               (neu)
  Views/
    CourseDetailView.swift              (neu — Hauptdetail mit Segmented-Picker)
    Course/
      ParticipantsTabView.swift         (neu)
      SkillCheckTabView.swift           (neu)
      CourseInfoTabView.swift           (neu)
    Students/
      StudentsView.swift                (neu — Global-Tab)
      StudentDetailView.swift           (neu — Read-only Stammdaten)
    Intake/
      IntakeSheet.swift                 (neu)
  Components/
    StudentAvatar.swift                 (neu — farbig basierend auf ID-Hash)
    SkillChip.swift                     (neu — toggle-Chip)
```

### Entfernte Files

- `Views/AssignmentsView.swift`
- `Views/AssignmentDetailView.swift`
- `Views/SaldoView.swift`
- `Services/AssignmentsStore.swift`
- `Services/MovementsStore.swift`
- `Models/Assignment.swift`
- `Models/Movement.swift`
- `Views/MovementDetailView.swift`

Diese werden in Etappe 2 entfernt. Falls Saldo später zurückkommen soll, ist die letzte Commit-SHA im Git auffindbar.

---

## 4. Datenmodell-Änderungen

### Migration 0094a — `padi_skill_records.instructor_id` FK retargeten

Heute: FK auf `instructors(id)`. Nach Phase-J-Wrap soll diese Tabelle gedroppt werden. iOS Etappe 1 schreibt ab Auth-Cutover die `contacts.id` (= `contact_instructor.contact_id`) als `instructor_id`. Migration retargetet die FK auf `contacts(id) ON DELETE SET NULL`.

Reihenfolge:
1. iOS Etappe 1 deployt (App schreibt schon `contacts.id`).
2. Migration 0094a anwenden.
3. Spätere Phase-J-Migration (0094b oder 0095) droppt dann `instructors` mitsamt allen verbleibenden Konsumenten.

### Migration 0095 — `skill_definitions` (neu)

```sql
CREATE TABLE public.skill_definitions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  course_type_code TEXT NOT NULL,        -- 'owd', 'aowd', 'rescue', ...
  skill_code TEXT NOT NULL,              -- 'cw1-mask-clear'
  section TEXT NOT NULL,                 -- 'cw_dive', 'ow_dive', 'kd', 'assessment', 'cw_flex', 'ow_flex'
  label_de TEXT NOT NULL,
  label_en TEXT NOT NULL,
  display_order INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(course_type_code, skill_code)
);

CREATE INDEX idx_skill_definitions_course_type ON public.skill_definitions(course_type_code);

ALTER TABLE public.skill_definitions ENABLE ROW LEVEL SECURITY;
CREATE POLICY skill_definitions_read ON public.skill_definitions
  FOR SELECT TO authenticated USING (true);
-- Schreibrechte nur via Studio / Migrations (kein UI-Editor in dieser Phase)
```

**Seed:** Existierende `PADI_OWD_SKILLS` aus `apps/web/src/lib/padiOwdSkills.ts` werden als INSERT-Statements ausgespielt. Damit kennt Web-`SkillCheckTab` und iOS-`SkillCheckTabView` dieselbe Quelle.

**Web-Refactor (Pflicht in Etappe 5):** `apps/web/src/lib/padiOwdSkills.ts` wird durch einen Hook ersetzt der die Skills aus `skill_definitions` lädt. Die Datei selbst bleibt vorerst als Fallback-Cache stehen, kann post-Pitch entfernt werden.

### Migration 0096 — `intake_checklists` RLS für Instructors öffnen

Heute: `is_cd()` für ALL, `is_owner()` für SELECT only. Damit kann ein normaler Instructor heute nicht schreiben.

Nach Migration: zusätzliche Policy
```sql
CREATE POLICY intake_instructor_write ON intake_checklists
  FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM contact_instructor ci
      WHERE ci.auth_user_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM contact_instructor ci
      WHERE ci.auth_user_id = auth.uid()
    )
  );
```

**Bewusst permissiv:** jeder authentifizierte Instructor (egal welchen Kurses) darf schreiben. Für 3–5 Soft-Live-Tester reicht das. Nach dem Pitch wird die Constraint auf "Instructor des konkreten Kurses" verengt (separate Migration).

### Erweiterung Migration 0096 — optional INSERT-Werte

Pre-Dive-Light schreibt nur 3 Bool-Felder: `medical_signed`, `liability_signed`, `safe_diving_signed`. Die restlichen 18 Felder bleiben NULL. Bestehende CD-Intake-Rows werden nicht angefasst.

### iOS-Models (neu)

```swift
struct Student: Codable, Identifiable, Hashable {
    let id: UUID
    let firstName: String
    let lastName: String
    let email: String?
    let phone: String?
    let level: String?         // contact_student.level (DSD/OWD/...)
    let photoUrl: String?

    enum CodingKeys: String, CodingKey {
        case id, level
        case firstName  = "first_name"
        case lastName   = "last_name"
        case email, phone
        case photoUrl   = "photo_url"
    }
}

struct CourseParticipant: Codable, Identifiable, Hashable {
    let id: UUID
    let courseId: UUID
    let studentId: UUID
    let status: String          // "enrolled" | "certified" | "dropped"
    let certificateNr: String?
    let student: Student?       // PostgREST-join

    enum CodingKeys: String, CodingKey {
        case id, status, student
        case courseId      = "course_id"
        case studentId     = "student_id"
        case certificateNr = "certificate_nr"
    }
}

struct IntakeChecklist: Codable, Hashable {
    let id: UUID?
    let courseParticipantId: UUID?
    let medicalSigned: Bool
    let liabilitySigned: Bool
    let safeDivingSigned: Bool
    let notes: String?
    let checkedOn: String?       // ISO date string
    let checkedById: UUID?

    enum CodingKeys: String, CodingKey {
        case id, notes
        case courseParticipantId = "course_participant_id"
        case medicalSigned       = "medical_signed"
        case liabilitySigned     = "liability_signed"
        case safeDivingSigned    = "safe_diving_signed"
        case checkedOn           = "checked_on"
        case checkedById         = "checked_by_id"
    }
}

struct SkillDefinition: Codable, Identifiable, Hashable {
    let id: UUID
    let courseTypeCode: String
    let skillCode: String
    let section: String
    let labelDe: String
    let labelEn: String
    let displayOrder: Int

    enum CodingKeys: String, CodingKey {
        case id, section
        case courseTypeCode = "course_type_code"
        case skillCode      = "skill_code"
        case labelDe        = "label_de"
        case labelEn        = "label_en"
        case displayOrder   = "display_order"
    }
}

struct SkillRecord: Codable, Identifiable, Hashable {
    let id: UUID?
    let courseId: UUID
    let participantId: UUID
    let skillCode: String
    let completedOn: String?
    let instructorId: UUID?      // = contacts.id (post Etappe 1)
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case id, notes
        case courseId      = "course_id"
        case participantId = "participant_id"
        case skillCode     = "skill_code"
        case completedOn   = "completed_on"
        case instructorId  = "instructor_id"
    }
}
```

---

## 5. Etappen-Walkthrough

Jede Etappe ist ein eigener Commit (oder Branch+Smoke bei Auth/RLS). Reihenfolge zwingend, weil Auth + Models nachgelagerte Features unblocken.

### Etappe 1 — Auth-Migration auf contact_instructor

**Branch:** `ios-auth-contact-instructor`

**Files:**
- `Services/AuthState.swift` — Read-Pfad von `from('instructors')` auf `from('contact_instructor')` mit Join auf `contacts(*)`.
- `Models/CurrentUser.swift` — neue Felder `contactId: UUID`, `appRole: String`, `preferredLanguage: String?` (aus `contact_instructor.app_role`, `preferred_language`); legacy `instructorId` bleibt als Alias zum smooth-cutover.

**RLS-Annahme:** `contact_instructor` ist bereits SELECT-able für authenticated (Phase-J-3b done).

**Smoke-Test (TestFlight):**
1. Login als bestehender Instructor → Heute-View lädt Einsätze.
2. Logout → Re-Login → Session persistent.
3. Login als CD (Dominik) → `appRole` ist gesetzt, alle Tabs erreichbar.

### Etappe 2 — Tab-Restruktur

**Branch:** main (reversibel)

**Files:**
- `Views/MainTabView.swift` — 4 Tabs: Heute, Kurse (war Kalender), Studenten (neu, leerer Placeholder bis Etappe 6), Profil
- `Views/CalendarView.swift` → `Views/CoursesView.swift` (Umbenennung + leichte Anpassung)
- Delete: `AssignmentsView`, `AssignmentDetailView`, `SaldoView`, `AssignmentsStore`, `MovementsStore`, `Assignment`, `Movement`, `MovementDetailView`

**Smoke-Test:** App startet ohne Crash. 4 Tabs sichtbar. Heute-Tab funktioniert wie vorher. Kurse-Tab zeigt Kurs-Liste (alte Calendar-Logik). Studenten-Tab zeigt Coming-Soon-Placeholder. Profil-Tab erreicht Logout.

### Etappe 3 — Kurs-Detail + Teilnehmer-Liste

**Branch:** main

**Files:**
- `Models/Student.swift`, `Models/CourseParticipant.swift`
- `Services/ParticipantsStore.swift` — `load(courseId: UUID) async`, lädt `course_participants` mit `contacts(*)`-Join
- `Views/CourseDetailView.swift` — Segmented-Picker (Teilnehmer / Skill-Check / Info), Default = Teilnehmer
- `Views/Course/ParticipantsTabView.swift` — Liste mit `StudentAvatar`, Level-Subtitle, Status-Chip
- `Views/Course/CourseInfoTabView.swift` — Read-only Kurs-Daten (Title, Daten, Ort, Notes)
- `Components/StudentAvatar.swift` — Initialen-Avatar mit konsistenter Farbe per ID-Hash
- `Views/CoursesView.swift` — NavigationLink auf `CourseDetailView`

**Smoke-Test:**
1. Kurse-Tab → tap auf Kurs → CourseDetailView öffnet
2. Teilnehmer-Count matcht Web (selber Kurs gegenchecken)
3. Avatar-Farben sind konsistent (gleicher Schüler = gleiche Farbe nach App-Neustart)
4. Status-Chip zeigt "enrolled" / "certified" / "dropped"

### Etappe 4 — Pre-Dive-Intake-Sheet

**Branch:** `ios-intake-pre-dive` (wegen RLS-Migration)

**Migration:** 0096_intake_checklists_instructor_rls.sql

**Files:**
- `Models/IntakeChecklist.swift`
- `Services/IntakeStore.swift` — `load(participantId)`, `save(participantId, fields)` mit upsert
- `Views/Intake/IntakeSheet.swift` — 3 Toggle-Cards (Medical / Liability / Safe Diving), Notiz-Feld, Speichern-Button
- `Views/Course/ParticipantsTabView.swift` — Tap auf Schüler → IntakeSheet erscheint; "Intake offen"-Hint wenn alle 3 Booleans false

**Smoke-Test:**
1. Migration 0096 lokal/staging anwenden
2. Login als Instructor → Kurs → Schüler antippen → IntakeSheet öffnet
3. Alle 3 Toggles ein → Speichern → Sheet schliesst → Hint "Intake offen" verschwunden
4. Web öffnen, gleicher Schüler → `intake_checklists` zeigt die 3 Booleans true
5. Production: RLS-Policy-Test mit 2 Instructors

### Etappe 5 — Skill-Check OWD

**Branch:** main (ohne RLS-Branch, weil padi_skill_records bereits open)

**Migration:** 0095_skill_definitions.sql + OWD-Seed

**Web-Refactor (zwingend in derselben Etappe):**
- `apps/web/src/lib/padiOwdSkills.ts` → wird ersetzt durch Hook `useSkillDefinitions(courseTypeCode)` der aus DB lädt
- `apps/web/src/screens/SkillCheckTab.tsx` — nutzt neuen Hook statt Konstante

**iOS-Files:**
- `Models/SkillDefinition.swift`, `Models/SkillRecord.swift`
- `Services/SkillCheckStore.swift` — `loadDefinitions(courseTypeCode)`, `loadRecords(courseId)`, `toggle(skillCode, participantId)` optimistisch
- `Views/Course/SkillCheckTabView.swift` — Sektionen + Skill-Reihen, pro Reihe Schüler-Chips
- `Components/SkillChip.swift` — Toggle-Chip, mit Initialen + Check-State
- Heute-vs-Alle-Filter (Default Heute, basierend auf `course_dates.has_pool / has_lake / has_theory`; Logik aus Web `sectionsForToday()` portiert)

**Smoke-Test:**
1. Migration 0095 + Seed lokal → `SELECT count(*) FROM skill_definitions WHERE course_type_code='owd'` = passt zur alten Konstante
2. Web-SkillCheckTab öffnen → identische Skill-Liste wie vorher
3. iOS: Kurs → Skill-Check-Tab → identische Skill-Liste
4. iOS-Chip tap → Web refresh → Status passt
5. Web-Tap → iOS refresh → Status passt

### Etappe 6 — Global Studenten-Tab

**Branch:** main

**Files:**
- `Services/StudentsStore.swift` — `loadAll() async`, `search(query)`
- `Views/Students/StudentsView.swift` — Search-Bar, Sectioned-List nach Level (OWD/AOWD/...)
- `Views/Students/StudentDetailView.swift` — Read-only: Avatar, Stammdaten, Liste der Kurs-Teilnahmen mit Status

**Smoke-Test:**
1. Studenten-Tab öffnen → Liste lädt
2. Suche "An" → Anna Bürki sichtbar
3. Tap auf Schüler → StudentDetailView mit Stammdaten + Teilnahme-Historie

---

## 6. Error-Handling & Sync

### Optimistisches Online-Modell

Alle Schreib-Aktionen (Skill-toggle, Intake-Save) folgen demselben Pattern:

```swift
func toggle(skillCode: String, participantId: UUID) async {
    let snapshot = records
    records.toggleLocal(skillCode: skillCode, participantId: participantId)   // UI sofort
    do {
        try await supabase
            .from("padi_skill_records")
            .upsert([...])
            .execute()
    } catch {
        records = snapshot                                                      // rollback
        lastError = error.localizedDescription                                  // Toast
    }
}
```

Kein Retry, keine Queue. User sieht Fehler sofort, kann re-tippen.

### Error-States pro View

| View | Loading | Empty | Error |
|---|---|---|---|
| Teilnehmer-Liste | Skeleton-Rows | "Noch keine Schüler eingeschrieben" | Inline-Banner + Retry |
| Skill-Check | Skeleton-Sektionen | "Keine Skills für heute" | Toast bei toggle, Banner bei load |
| Intake-Sheet | ProgressView mittig | N/A (create on save) | Inline-Error-Chip, Sheet bleibt offen |
| Studenten-Suche | Skeleton-Rows | "Keine Treffer" | Retry-Banner |

### Logging

Keine zusätzliche Logging-Infrastruktur. `print()` für Dev-Builds, in Release entfernt via `#if DEBUG`. Production-Fehler sieht der User als Toast — Soft-Live-Feedback kommt mündlich/WhatsApp.

---

## 7. Test-Strategie

**Keine Unit-Tests in dieser Phase.** Aufwand-Latenz lohnt sich nicht für eine 6-Etappen-Pitch-Lieferung. Stattdessen pro Etappe TestFlight-Smoke wie in Abschnitt 5.

**Snapshot-Tests** kommen post-Pitch wenn die Views stabil sind.

**End-to-End-Cross-Check** (Pflicht vor Pitch): Web → iOS und iOS → Web für jede schreibende Aktion. Wenn Datenmodell konsistent, ist beides synchron.

---

## 8. Risiken

| ID | Risiko | Mitigation |
|---|---|---|
| R1 | RLS-Migration 0096 zu permissiv für Production | Soft-Live nur intern, harte Constraint nach Pitch |
| R2 | App-Store-Review-Latenz | TestFlight reicht für Soft-Live |
| R3 | Skill-Definitions-Migration ändert OWD-Quelle | Web-Refactor in selber Etappe (5), nicht später |
| R4 | iOS-Auth-Cutover bricht Login | Branch + TestFlight + Re-Login-Smoke vor Merge |
| R5 | `padi_skill_records.instructor_id` FK bricht beim instructors-Drop | Migration 0094a (FK-Retarget) muss laufen bevor Phase-J 0094b |

---

## 9. Out of Scope (YAGNI)

- Offline-DB (SwiftData/GRDB)
- Push-Notifications "neuer Schüler" / "Kurs-Update"
- Signaturen-Capture (Apple Pencil oder Finger)
- PDF-Generation in iOS (Web-only)
- Skill-Definition-Editor in iOS
- IDC-volle-Intake-Checkliste in iOS (bleibt Web-only)
- Excel-Import in iOS
- Saldo-Anzeige
- Studenten-Stammdaten-Edit / Neu-Anlage in iOS
- Kurs anlegen / editieren in iOS
- Multi-Mandanten-Tenant-Switch

---

## 10. Entscheidungen mit Pitch-Trade-off

- **Heute-Tab bleibt unverändert** für diesen Release. Heutiger Kurs wird via Kurse-Tab erreicht. Falls Soft-Live-Feedback "Heute-Kurs prominenter zeigen" verlangt → Post-Pitch-Etappe.
- **Notiz-Feld im Intake-Sheet:** 2-Zeilen-Default (`TextField` mit `axis: .vertical`, `lineLimit(2...6)`).
- **Skill-Chip-Long-Press öffnet Detail-Sheet** mit TG-Nr, Notes, Datum-Override. Web-Parität, sonst hat iOS einen blinden Fleck gegenüber Web.

---

## 11. Referenzen

- `project_atoll.md` — Projekt-Stand & Pitch-Ziel
- `project_phase_j.md` — Adressverwaltung-Migration, iOS-Auth-Restschuld
- `feedback_atoll_workflow.md` — Commit/Branch-Konventionen
- `apps/web/src/screens/SkillCheckTab.tsx` — Vorbild für Skill-Matrix-Logik
- `apps/web/src/screens/cd/IntakeChecklistSheet.tsx` — Volle Intake-Variante (CD), iOS nutzt nur 3 Felder
- `apps/web/src/lib/padiOwdSkills.ts` — Quelle für Migration 0095 OWD-Seed
- `supabase/migrations/0050_cd_elearning_and_intake.sql` — Original-`intake_checklists`-Schema
- `supabase/migrations/0090_padi_skill_records.sql` — Skill-Records-Tabelle
- `supabase/migrations/0079_contacts_schema.sql` — Contacts-Modell
