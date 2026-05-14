# iOS Etappe 4 — Pre-Dive-Intake-Sheet

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Instructor tippt einen Schüler in der Teilnehmer-Liste → ein Sheet öffnet sich mit drei Toggle-Cards (Medical-Statement / Liability-Release / Safe-Diving) und einem Notiz-Feld. Speichern legt einen `intake_checklists`-Eintrag pro `course_participant` an. Wenn nicht alle drei Häkchen gesetzt sind, zeigt die Teilnehmer-Liste einen orangen "Intake offen"-Hint.

**Architecture:** RLS-Migration öffnet `intake_checklists` für authentifizierte Instructors. iOS-Models: `IntakeChecklist` als Sidecar-Modell. `IntakeStore` lädt alle Intakes pro Kurs (eine Query mit `course_participant_id IN (...)`) und cached sie in einem `[UUID: IntakeChecklist]`-Dictionary. `IntakeSheet` ist eine eigene `View`, präsentiert als `.sheet(item:)` aus `ParticipantsTabView`.

**Tech Stack:** Swift 5.10, SwiftUI, Supabase-Swift 2.x, Postgres + RLS.

**Branch:** `ios-etappe-4-pre-dive-intake` — Branch wegen DB-RLS-Migration.

**DB-Migration (User wendet manuell in Supabase-Studio an, dann committet):**
`supabase/migrations/0096_intake_checklists_instructor_rls.sql`

---

## File Structure

**Created (alle in `apps/ios-native/ATOLL/`):**
- `Models/IntakeChecklist.swift`
- `Services/IntakeStore.swift`
- `Views/IntakeSheet.swift`

**Modified:**
- `Views/ParticipantsTabView.swift` — Tap-Handler, Sheet-Präsentation, Intake-Status-Hint

**Database:**
- `supabase/migrations/0096_intake_checklists_instructor_rls.sql` (neu)

---

## Tasks

### Task 1: Feature-Branch + Plan-Commit (User)

**Voraussetzung:** Xcode schliessen.

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git status
git add docs/superpowers/plans/2026-05-14-ios-etappe-4-pre-dive-intake.md
git commit -m 'docs(plan): iOS Etappe 4 — Pre-Dive-Intake plan'
git checkout -b ios-etappe-4-pre-dive-intake
```

---

### Task 2: DB-Migration schreiben (Subagent)

**Files:**
- Create: `supabase/migrations/0096_intake_checklists_instructor_rls.sql`

- [ ] **Step 1: Migration-File mit folgendem Inhalt:**

```sql
-- 0096: intake_checklists — RLS-Öffnung für authentifizierte Instructors
-- Heute: nur CD darf schreiben (intake_cd_all). Owner darf lesen (intake_owner_read).
-- Neu: Jeder authentifizierte User mit einem contact_instructor-Eintrag darf
--      INSERT/UPDATE/DELETE. Bewusst permissiv für Soft-Live (3–5 Test-Instructors).
--      Post-Pitch wird die Constraint auf "Instructor des konkreten Kurses" verengt.

CREATE POLICY intake_instructor_write ON public.intake_checklists
  FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.contact_instructor ci
      WHERE ci.auth_user_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.contact_instructor ci
      WHERE ci.auth_user_id = auth.uid()
    )
  );

COMMENT ON POLICY intake_instructor_write ON public.intake_checklists IS
  'Soft-Live-Permissive: alle authentifizierten Instructors dürfen Intakes schreiben. Post-Pitch verengen auf Kurs-Instructor.';
```

---

### Task 3: User wendet Migration an (User)

- [ ] **Step 1:** Supabase-Studio öffnen → SQL Editor → Inhalt von `0096_intake_checklists_instructor_rls.sql` einfügen → Run.

Expected: "Success. No rows returned."

- [ ] **Step 2: Verifikation:**

```sql
SELECT polname FROM pg_policy WHERE polrelid = 'public.intake_checklists'::regclass;
```

Expected: 3 rows: `intake_cd_all`, `intake_owner_read`, `intake_instructor_write`.

- [ ] **Step 3:** Smoke-Test als nicht-CD-Instructor (z.B. Test-Instructor-Account aus Soft-Live):
  
  ```sql
  -- Als Instructor in Supabase-Studio "Test as user" einschalten, dann:
  INSERT INTO intake_checklists (course_participant_id, medical_signed, liability_signed, safe_diving_signed)
  VALUES ('<beliebige-existierende-course_participant_id>', true, true, true)
  ON CONFLICT (course_participant_id) DO NOTHING
  RETURNING *;
  ```

  Wenn das durchgeht: RLS-Policy wirkt. Wenn `permission denied for table intake_checklists`: Policy nicht aktiv, neu prüfen.

  Falls keine `UNIQUE (course_participant_id)`-Constraint existiert, schlägt `ON CONFLICT` fehl — dann den `ON CONFLICT`-Teil weglassen und Row danach manuell löschen.

---

### Task 4: iOS-Models + Store (Subagent)

**Files:**
- Create: `apps/ios-native/ATOLL/Models/IntakeChecklist.swift`
- Create: `apps/ios-native/ATOLL/Services/IntakeStore.swift`

- [ ] **Step 1: `IntakeChecklist.swift`:**

```swift
import Foundation

/// Pre-Dive-Intake-Datensatz pro course_participant. Nur die 3 Felder die
/// Instructors auf iOS setzen — die volle CD-IDC-Checkliste (Medical/EFR/
/// Logbook/…) bleibt Web-only.
struct IntakeChecklist: Codable, Identifiable, Hashable {
  let id: UUID?
  let courseParticipantId: UUID?
  let medicalSigned: Bool
  let liabilitySigned: Bool
  let safeDivingSigned: Bool
  let notes: String?
  let checkedOn: String?        // ISO date "yyyy-MM-dd"
  let checkedById: UUID?        // legacy instructors.id (siehe legacyInstructorId)

  /// Convenience: ist die Pre-Dive-Check komplett?
  var isComplete: Bool {
    medicalSigned && liabilitySigned && safeDivingSigned
  }

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

/// Insert/Update-Payload — nur die 3 Felder + Bookkeeping.
/// Volle `intake_checklists`-Row hat 20+ Felder (CD-Checkliste), die wir
/// hier bewusst NULL lassen.
struct IntakeUpsert: Encodable {
  let courseParticipantId: UUID
  let medicalSigned: Bool
  let liabilitySigned: Bool
  let safeDivingSigned: Bool
  let notes: String?
  let checkedOn: String          // ISO yyyy-MM-dd
  let checkedById: UUID?

  enum CodingKeys: String, CodingKey {
    case courseParticipantId = "course_participant_id"
    case medicalSigned       = "medical_signed"
    case liabilitySigned     = "liability_signed"
    case safeDivingSigned    = "safe_diving_signed"
    case notes
    case checkedOn           = "checked_on"
    case checkedById         = "checked_by_id"
  }
}
```

- [ ] **Step 2: `IntakeStore.swift`:**

```swift
import Foundation
import Supabase

@MainActor
@Observable
final class IntakeStore {
  enum LoadState {
    case idle, loading, loaded, error
  }

  /// Intakes keyed by `course_participant_id` für schnelles Lookup in der View.
  private(set) var intakesByParticipant: [UUID: IntakeChecklist] = [:]
  private(set) var loadState: LoadState = .idle
  private(set) var errorMessage: String?

  private let supabase = SupabaseClient.shared

  /// Lädt alle bestehenden Intakes für eine Liste von course_participant_ids.
  /// Nicht existierende Intakes erscheinen einfach nicht im Dictionary.
  func load(participantIds: [UUID]) async {
    guard !participantIds.isEmpty else {
      intakesByParticipant = [:]
      loadState = .loaded
      return
    }
    loadState = .loading
    errorMessage = nil
    do {
      let rows: [IntakeChecklist] = try await supabase
        .from("intake_checklists")
        .select("id, course_participant_id, medical_signed, liability_signed, safe_diving_signed, notes, checked_on, checked_by_id")
        .in("course_participant_id", values: participantIds.map(\.uuidString))
        .execute()
        .value

      intakesByParticipant = Dictionary(uniqueKeysWithValues: rows.compactMap { row in
        guard let cpid = row.courseParticipantId else { return nil }
        return (cpid, row)
      })
      loadState = .loaded
    } catch {
      #if DEBUG
      print("⚠️ IntakeStore.load failed: \(error)")
      #endif
      loadState = .error
      errorMessage = error.localizedDescription
    }
  }

  /// Speichert Pre-Dive-Intake. Existiert noch keine Row: INSERT. Sonst UPDATE.
  /// Aktualisiert das lokale Dictionary optimistisch erst NACH erfolgreichem Save
  /// (kein Risiko von Lying-UI bei Fail).
  func save(
    participantId: UUID,
    medical: Bool,
    liability: Bool,
    safeDiving: Bool,
    notes: String?,
    checkedById: UUID?
  ) async throws {
    let today = Self.isoDateFormatter.string(from: Date())
    let payload = IntakeUpsert(
      courseParticipantId: participantId,
      medicalSigned: medical,
      liabilitySigned: liability,
      safeDivingSigned: safeDiving,
      notes: notes,
      checkedOn: today,
      checkedById: checkedById
    )

    let saved: IntakeChecklist
    if let existing = intakesByParticipant[participantId], let id = existing.id {
      // UPDATE — RLS-Policy intake_instructor_write greift wenn der User
      // einen contact_instructor-Eintrag hat.
      saved = try await supabase
        .from("intake_checklists")
        .update(payload)
        .eq("id", value: id)
        .select()
        .single()
        .execute()
        .value
    } else {
      // INSERT
      saved = try await supabase
        .from("intake_checklists")
        .insert(payload)
        .select()
        .single()
        .execute()
        .value
    }

    intakesByParticipant[participantId] = saved
  }

  private static let isoDateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = TimeZone(identifier: "Europe/Zurich")
    return f
  }()
}
```

---

### Task 5: IntakeSheet-View (Subagent)

**Files:**
- Create: `apps/ios-native/ATOLL/Views/IntakeSheet.swift`

- [ ] **Step 1: `IntakeSheet.swift`:**

```swift
import SwiftUI

struct IntakeSheet: View {
  let participant: CourseParticipant
  let user: CurrentUser
  let store: IntakeStore
  let onSaved: () -> Void

  @Environment(\.dismiss) private var dismiss

  @State private var medical: Bool = false
  @State private var liability: Bool = false
  @State private var safeDiving: Bool = false
  @State private var notes: String = ""

  @State private var saving = false
  @State private var saveError: String?

  var body: some View {
    NavigationStack {
      Form {
        Section {
          Toggle(isOn: $medical) {
            VStack(alignment: .leading, spacing: 2) {
              Text("Medical Statement").font(.body)
              Text("unterschrieben (ohne Arztzeichnung)")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }
          Toggle(isOn: $liability) {
            VStack(alignment: .leading, spacing: 2) {
              Text("Liability Release").font(.body)
              Text("PADI-Formular unterschrieben")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }
          Toggle(isOn: $safeDiving) {
            VStack(alignment: .leading, spacing: 2) {
              Text("Safe Diving Procedures").font(.body)
              Text("Standard-Verfahren besprochen")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }
        } header: {
          Text("Pre-Dive-Checks")
        }

        Section("Notiz") {
          TextField("Optional", text: $notes, axis: .vertical)
            .lineLimit(2...6)
        }

        if let error = saveError {
          Section {
            Text(error)
              .font(.caption)
              .foregroundStyle(.red)
          }
        }
      }
      .navigationTitle(participant.student?.displayName ?? "Pre-Dive-Check")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Abbrechen") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button(saving ? "Speichert…" : "Speichern") {
            Task { await save() }
          }
          .disabled(saving)
        }
      }
    }
    .task { loadExisting() }
  }

  private func loadExisting() {
    if let existing = store.intakesByParticipant[participant.id] {
      medical = existing.medicalSigned
      liability = existing.liabilitySigned
      safeDiving = existing.safeDivingSigned
      notes = existing.notes ?? ""
    }
  }

  private func save() async {
    saving = true
    saveError = nil
    defer { saving = false }
    do {
      try await store.save(
        participantId: participant.id,
        medical: medical,
        liability: liability,
        safeDiving: safeDiving,
        notes: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes,
        checkedById: user.instructorId   // legacy instructors.id — nil wenn unlinked
      )
      onSaved()
      dismiss()
    } catch {
      saveError = error.localizedDescription
    }
  }
}
```

Hinweis zur `checkedById`-Wahl: `user.instructorId` (NICHT `legacyInstructorId`) — denn wir wollen explicit nil schreiben wenn der User keinen Legacy-Eintrag hat, statt einen contacts.id reinzudrücken der gar nicht auf instructors verweist und den FK bricht. Wenn ein Soft-Live-Tester keinen instructors-Row hat, bleibt `checked_by_id` NULL — sauberer Fail-State, kein FK-Konflikt.

---

### Task 6: ParticipantsTabView Integration (Subagent)

**Files:**
- Modify: `apps/ios-native/ATOLL/Views/ParticipantsTabView.swift`

Bestehende View hat einen `ParticipantsStore`. Erweiterungen:
- Eigener `IntakeStore` als `@State`
- Nach Laden der Participants: Intakes laden
- `@State` für selected Participant + sheet-Präsentation
- `onTapGesture` auf ParticipantRow → set selected, sheet zeigen
- ParticipantRow um Status-Indikator erweitern (oranger Punkt wenn Intake nicht komplett oder fehlt)

- [ ] **Step 1: Komplett ersetzen mit:**

```swift
import SwiftUI

struct ParticipantsTabView: View {
  let course: Course
  let user: CurrentUser
  @State private var store = ParticipantsStore()
  @State private var intakeStore = IntakeStore()
  @State private var selectedParticipant: CourseParticipant?

  var body: some View {
    Group {
      switch store.loadState {
      case .idle, .loading where store.participants.isEmpty:
        ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
      case .error:
        ContentUnavailableView {
          Label("Fehler beim Laden", systemImage: "exclamationmark.triangle")
        } description: {
          Text(store.errorMessage ?? "")
        } actions: {
          Button("Nochmal versuchen") {
            Task { await store.load(courseId: course.id) }
          }
        }
      default:
        if store.participants.isEmpty {
          ContentUnavailableView(
            "Noch keine Teilnehmer",
            systemImage: "person.2",
            description: Text("Sobald Schüler eingeschrieben werden, erscheinen sie hier.")
          )
        } else {
          List(store.participants) { p in
            ParticipantRow(
              participant: p,
              intake: intakeStore.intakesByParticipant[p.id]
            )
            .contentShape(Rectangle())
            .onTapGesture { selectedParticipant = p }
          }
          .listStyle(.plain)
        }
      }
    }
    .refreshable {
      await store.load(courseId: course.id)
      await reloadIntakes()
    }
    .task {
      await store.load(courseId: course.id)
      await reloadIntakes()
    }
    .sheet(item: $selectedParticipant) { participant in
      IntakeSheet(
        participant: participant,
        user: user,
        store: intakeStore,
        onSaved: { Task { await reloadIntakes() } }
      )
    }
  }

  private func reloadIntakes() async {
    let ids = store.participants.map(\.id)
    await intakeStore.load(participantIds: ids)
  }
}

private struct ParticipantRow: View {
  let participant: CourseParticipant
  let intake: IntakeChecklist?

  var body: some View {
    HStack(spacing: 12) {
      StudentAvatar(
        initials: participant.student?.initials ?? "—",
        id: participant.studentId,
        size: 36
      )
      VStack(alignment: .leading, spacing: 2) {
        Text(participant.student?.displayName ?? "—")
          .font(.subheadline.bold())
        HStack(spacing: 6) {
          if let level = participant.student?.level {
            Text(level)
              .font(.caption2.monospaced())
              .foregroundStyle(.secondary)
          }
          Text(participant.status.label)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(statusBackground.opacity(0.18), in: Capsule())
            .foregroundStyle(statusBackground)
          if !intakeComplete {
            Text("Intake offen")
              .font(.caption2)
              .padding(.horizontal, 6)
              .padding(.vertical, 2)
              .background(Color.orange.opacity(0.18), in: Capsule())
              .foregroundStyle(.orange)
          }
        }
      }
      Spacer()
      Image(systemName: "chevron.right")
        .font(.caption2.bold())
        .foregroundStyle(.tertiary)
    }
    .padding(.vertical, 4)
  }

  private var intakeComplete: Bool {
    intake?.isComplete ?? false
  }

  private var statusBackground: Color {
    switch participant.status {
    case .enrolled:  .blue
    case .certified: .green
    case .dropped:   .secondary
    }
  }
}
```

**Wichtig:** Signatur ändert sich — `ParticipantsTabView` braucht jetzt `user: CurrentUser`. Konsumenten anpassen → siehe Task 7.

---

### Task 7: CourseDetailView braucht user (Subagent)

**Files:**
- Modify: `apps/ios-native/ATOLL/Views/CourseDetailView.swift`

`ParticipantsTabView` braucht jetzt `user: CurrentUser`. `CourseDetailView` muss `user` propagieren.

- [ ] **Step 1: CourseDetailView Signatur erweitern**

In `CourseDetailView.swift`:

```swift
struct CourseDetailView: View {
  let course: Course
  // ... existing ...
}
```

→

```swift
struct CourseDetailView: View {
  let course: Course
  let user: CurrentUser
  // ... existing ...
}
```

Und im body bei `ParticipantsTabView(course: course)` → `ParticipantsTabView(course: course, user: user)`.

- [ ] **Step 2: Konsumenten von CourseDetailView anpassen**

In `TodayView.swift`:
```swift
.navigationDestination(for: Course.self) { course in
  CourseDetailView(course: course)
}
```
→
```swift
.navigationDestination(for: Course.self) { course in
  CourseDetailView(course: course, user: user)
}
```

In `CalendarView.swift`:
```swift
.navigationDestination(for: Course.self) { CourseDetailView(course: $0) }
```
→
```swift
.navigationDestination(for: Course.self) { CourseDetailView(course: $0, user: user) }
```

---

### Task 8: Xcode-Project + Build (User)

- [ ] **Step 1: Xcode öffnen, neue Files via "Add Files to ATOLL..." adden** in die richtigen Gruppen:
  - `Models/IntakeChecklist.swift` → Models-Gruppe
  - `Services/IntakeStore.swift` → Services-Gruppe
  - `Views/IntakeSheet.swift` → Views-Gruppe

- [ ] **Step 2:** ⌘B → Build sollte grün sein.

---

### Task 9: Simulator-Smoke (User)

- [ ] **Step 1: ⌘R**, login, Kurse-Tab → Kurs → Teilnehmer-Tab

Vor jedem Schüler sollte jetzt entweder kein Intake-Hint sein (wenn Intake komplett) oder ein orangener "Intake offen"-Chip.

- [ ] **Step 2: Tap auf einen Schüler ohne Intake**

Sheet öffnet sich mit Schüler-Name oben, 3 Toggles (alle off), Notiz-Feld, Speichern-Button.

- [ ] **Step 3: 3 Toggles ein, Notiz tippen, Speichern**

Sheet schliesst. Zurück in Liste sollte "Intake offen"-Chip weg sein.

- [ ] **Step 4: Tap auf denselben Schüler nochmal**

Sheet öffnet sich mit 3 Toggles **vorausgefüllt** (geladen aus DB).

- [ ] **Step 5: Web-Cross-Check**

Web öffnen → SkillCheck/Intake-Bereich des selben Schülers → die 3 Booleans medical_signed/liability_signed/safe_diving_signed sollten true sein.

---

### Task 10: Commit + TestFlight (User)

- [ ] **Step 1:** Xcode schliessen

- [ ] **Step 2:** Stagen + Committen (single-quotes!)

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add -A
git status
git commit -m 'ios(intake): Pre-Dive-Sheet mit Medical/Liability/SafeDiving toggles

Neue Models IntakeChecklist + IntakeUpsert. IntakeStore lädt Intakes
pro Kurs in einem [UUID: IntakeChecklist] Dictionary, save()
INSERTet bei neu oder UPDATETet bei bestehend. IntakeSheet als
Form-basierte Sheet-Präsentation aus ParticipantsTabView.

Status-Hint Intake offen in ParticipantRow wenn nicht alle drei
Booleans gesetzt sind. checkedById bleibt user.instructorId
optional — bei unlinked-Usern null.

DB: Migration 0096 öffnet intake_checklists RLS für authentifizierte
Instructors (permissive, Soft-Live-Tester).

Refs: docs/superpowers/specs/2026-05-14-ios-instructor-mobile-companion-design.md (Etappe 4)'

git push -u origin ios-etappe-4-pre-dive-intake
```

- [ ] **Step 3:** Xcode öffnen, Build-Number bumpen, Archive → TestFlight Only → Upload. Real-Device-Smoke.

---

### Task 11: Merge nach main (User)

- [ ] **Step 1:** Xcode schliessen
- [ ] **Step 2:** FF-Merge

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git checkout main
git status                    # zur Sicherheit checken dass wir wirklich auf main sind
git pull --ff-only
git merge --ff-only ios-etappe-4-pre-dive-intake
git push
git branch -d ios-etappe-4-pre-dive-intake
git push origin --delete ios-etappe-4-pre-dive-intake
git log --oneline -3
```

---

## Self-Review

**Spec coverage check (Section 5 Etappe 4):**
- ✅ Migration 0096 RLS-Öffnung — Task 2
- ✅ `Models/IntakeChecklist.swift` — Task 4
- ✅ `Services/IntakeStore.swift` mit `load(participantIds:)` und `save(...)` — Task 4
- ✅ `Views/IntakeSheet.swift` mit 3 Toggles + Notiz — Task 5
- ✅ Tap auf Schüler → IntakeSheet — Task 6
- ✅ "Intake offen"-Hint — Task 6

**Placeholder scan:** Keine TBDs.

**Type consistency:**
- `IntakeUpsert.courseParticipantId` = `CourseParticipant.id` = UUID — gleich
- `IntakeChecklist.checkedById` = `user.instructorId` (legacy instructors.id) — explicit Optional damit unlinked-User null schreiben
- `IntakeStore.save()` ist `throws async` — wird im IntakeSheet via do/catch konsumiert

**Pre-flight check:**
- Verifizieren dass `intake_checklists`-Schema das Feld `course_participant_id` hat (Migration 0070+). Auch dass `medical_signed`, `liability_signed`, `safe_diving_signed` existieren (Migration 0050).
- Wenn `course_participant_id` keine UNIQUE-Constraint hat → unsere INSERT/UPDATE-Logik braucht Existenz-Check vor INSERT (haben wir via `if existing` schon). Kein on_conflict-upsert nötig.

**Risiken:**
- R1: Migration 0096 zu permissiv — okay für Soft-Live, post-Pitch verengen.
- R2: `checked_by_id` FK auf instructors(id) — solange instructors-Tabelle lebt, fine. Bei FK-Retarget später muss intake_checklists mit auf contacts(id) — siehe Phase-J-Cleanup-Plan.
- R3: Wenn Soft-Live-Tester keinen `contact_instructor`-Eintrag hat → INSERT scheitert mit RLS-Fail. Sollte nicht passieren wenn Auth durchgegangen ist (Etappe 1 setzt `contact_instructor` voraus für Login).

**Spec-Notes für später:**
- Spec sagt "primary Email" für Student, hier nicht relevant — Modelle aus E3 schon angelegt.
