# iOS Etappe 3 — Kurs-Detail + Teilnehmer-Liste

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tap auf einen Kurs (von TodayView oder Kurse-Tab) öffnet eine neue `CourseDetailView` mit einem Segmented-Picker (Teilnehmer / Skill-Check / Info). Teilnehmer-Tab zeigt die Schüler des Kurses mit Avatar + Status. Info-Tab zeigt Kurs-Stammdaten (ersetzt AssignmentDetailView). Skill-Check-Tab ist Placeholder bis Etappe 5.

**Architecture:** Models `Student` und `CourseParticipant` werden direkt aus PostgREST-Joins decodiert (`contacts` + nested `contact_student`). Neuer `@Observable`-Store `ParticipantsStore` lädt Teilnehmer pro `courseId`. `CourseDetailView` hostet `@State`-Selection und drei Tab-Views. `StudentAvatar` rendert Initialen auf einer ID-Hash-Farbe.

**Tech Stack:** Swift 5.10, SwiftUI, Supabase-Swift 2.x.

**Branch:** `ios-etappe-3-course-detail`

**Bekannte Spec-Abweichungen, die im Plan dokumentiert sind:**
- Spec schlug `Views/Course/`-Subfolder für die drei Tab-Views vor — Plan legt sie flach in `Views/` ab (Xcode-Group-Pflege ist mühsam, wir haben in Etappe 2 gelernt).
- Spec schlug Rename `CalendarView.swift` → `CoursesView.swift` vor — Plan behält den File-Namen (interne Sicht, kein User-Impact).
- AssignmentDetailView wird in dieser Etappe gelöscht (ersetzt durch CourseDetailView).

---

## File Structure

**Created (alle in `apps/ios-native/ATOLL/`):**
- `Models/Student.swift`
- `Models/CourseParticipant.swift`
- `Services/ParticipantsStore.swift`
- `Components/StudentAvatar.swift`
- `Views/CourseDetailView.swift`
- `Views/ParticipantsTabView.swift`
- `Views/CourseInfoTabView.swift`
- `Views/SkillCheckTabView.swift` (placeholder)

**Modified:**
- `Views/TodayView.swift` — navigationDestination switch von `Assignment` zu `Course`
- `Views/CalendarView.swift` — selber Switch

**Deleted (via Xcode "Move to Trash"):**
- `Views/AssignmentDetailView.swift`

---

## Tasks

### Task 1: Feature-Branch anlegen (User)

**Voraussetzung:** Xcode schliessen.

- [ ] **Step 1:**

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git status                          # sauber auf main
git checkout -b ios-etappe-3-course-detail
```

---

### Task 2: Data Layer — Models + Store (Subagent)

**Files:**
- Create: `apps/ios-native/ATOLL/Models/Student.swift`
- Create: `apps/ios-native/ATOLL/Models/CourseParticipant.swift`
- Create: `apps/ios-native/ATOLL/Services/ParticipantsStore.swift`

- [ ] **Step 1: `Student.swift` mit folgendem Inhalt:**

```swift
import Foundation

/// Read-Modell für PostgREST `contacts` join `contact_student` (1:1 sidecar).
/// Wird in `CourseParticipant.student` eingebettet.
struct Student: Codable, Identifiable, Hashable {
  let id: UUID                       // = contacts.id
  let firstName: String
  let lastName: String
  let primaryEmail: String?
  let contactStudent: ContactStudentInfo?

  /// Convenience für UI — die zwei häufigsten Sidecar-Felder.
  var level: String? { contactStudent?.level }
  var photoUrl: String? { contactStudent?.photoUrl }

  var displayName: String {
    let trimmed = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
    return trimmed.isEmpty ? "—" : trimmed
  }

  var initials: String {
    let f = firstName.first.map(String.init) ?? ""
    let l = lastName.first.map(String.init) ?? ""
    let combined = (f + l).uppercased()
    return combined.isEmpty ? "—" : combined
  }

  enum CodingKeys: String, CodingKey {
    case id
    case firstName = "first_name"
    case lastName = "last_name"
    case primaryEmail = "primary_email"
    case contactStudent = "contact_student"
  }

  struct ContactStudentInfo: Codable, Hashable {
    let level: String?
    let photoUrl: String?

    enum CodingKeys: String, CodingKey {
      case level
      case photoUrl = "photo_url"
    }
  }
}
```

- [ ] **Step 2: `CourseParticipant.swift`:**

```swift
import Foundation

/// Read-Modell für PostgREST `course_participants` join nested `student:contacts(...)`.
struct CourseParticipant: Codable, Identifiable, Hashable {
  let id: UUID
  let courseId: UUID
  let studentId: UUID
  let status: Status
  let certificateNr: String?
  let notes: String?
  let student: Student?

  enum Status: String, Codable, Hashable {
    case enrolled, certified, dropped

    var label: String {
      switch self {
      case .enrolled:  "Eingeschrieben"
      case .certified: "Zertifiziert"
      case .dropped:   "Abgebrochen"
      }
    }
  }

  enum CodingKeys: String, CodingKey {
    case id, status, notes, student
    case courseId      = "course_id"
    case studentId     = "student_id"
    case certificateNr = "certificate_nr"
  }
}
```

- [ ] **Step 3: `ParticipantsStore.swift`:**

```swift
import Foundation
import Supabase

@MainActor
@Observable
final class ParticipantsStore {
  enum LoadState {
    case idle, loading, loaded, error
  }

  private(set) var participants: [CourseParticipant] = []
  private(set) var loadState: LoadState = .idle
  private(set) var errorMessage: String?

  private let supabase = SupabaseClient.shared

  func load(courseId: UUID) async {
    loadState = .loading
    errorMessage = nil
    do {
      let result: [CourseParticipant] = try await supabase
        .from("course_participants")
        .select("id, course_id, student_id, status, certificate_nr, notes, student:contacts!inner(id, first_name, last_name, primary_email, contact_student(level, photo_url))")
        .eq("course_id", value: courseId)
        .execute()
        .value

      participants = result.sorted {
        ($0.student?.lastName ?? "") < ($1.student?.lastName ?? "")
      }
      loadState = .loaded
    } catch {
      #if DEBUG
      print("⚠️ ParticipantsStore.load(\(courseId)) failed: \(error)")
      #endif
      if !participants.isEmpty {
        loadState = .loaded
      } else {
        loadState = .error
        errorMessage = error.localizedDescription
      }
    }
  }
}
```

---

### Task 3: Avatar Component (Subagent)

**Files:**
- Create: `apps/ios-native/ATOLL/Components/StudentAvatar.swift`

- [ ] **Step 1: `StudentAvatar.swift`:**

```swift
import SwiftUI

/// Initialen-Avatar in einer konsistenten Farbe basierend auf dem ID-Hash.
/// Zweck: Bessere Wiedererkennung in Teilnehmer-Listen und Skill-Chips.
struct StudentAvatar: View {
  let initials: String
  let id: UUID
  var size: CGFloat = 32

  var body: some View {
    Circle()
      .fill(backgroundColor)
      .frame(width: size, height: size)
      .overlay(
        Text(initials)
          .font(.system(size: size * 0.4, weight: .semibold, design: .rounded))
          .foregroundStyle(foregroundColor)
      )
  }

  /// Stabile Farbe pro UUID. Wir nehmen das erste Byte der UUID modulo Palette-Grösse.
  private var paletteIndex: Int {
    let firstByte = withUnsafeBytes(of: id.uuid) { $0.first ?? 0 }
    return Int(firstByte) % Self.palette.count
  }

  private var backgroundColor: Color { Self.palette[paletteIndex].background }
  private var foregroundColor: Color { Self.palette[paletteIndex].foreground }

  /// 8 Farb-Paare, hell genug für weisse Schrift bzw. dunkel genug für dunkle Schrift.
  /// Light-/dark-mode-tauglich über SwiftUI Color-Konstanten.
  private static let palette: [(background: Color, foreground: Color)] = [
    (Color(red: 0.62, green: 0.88, blue: 0.79), Color(red: 0.02, green: 0.20, blue: 0.17)), // teal
    (Color(red: 0.71, green: 0.83, blue: 0.96), Color(red: 0.02, green: 0.17, blue: 0.33)), // blue
    (Color(red: 0.96, green: 0.75, blue: 0.82), Color(red: 0.29, green: 0.08, blue: 0.16)), // pink
    (Color(red: 0.98, green: 0.78, blue: 0.46), Color(red: 0.26, green: 0.14, blue: 0.01)), // amber
    (Color(red: 0.81, green: 0.80, blue: 0.96), Color(red: 0.15, green: 0.13, blue: 0.36)), // purple
    (Color(red: 0.96, green: 0.77, blue: 0.70), Color(red: 0.29, green: 0.11, blue: 0.05)), // coral
    (Color(red: 0.75, green: 0.87, blue: 0.59), Color(red: 0.09, green: 0.20, blue: 0.04)), // green
    (Color(red: 0.83, green: 0.82, blue: 0.78), Color(red: 0.17, green: 0.17, blue: 0.16)), // gray
  ]
}
```

---

### Task 4: View-Layer — CourseDetailView + 3 Tabs (Subagent)

**Files:**
- Create: `apps/ios-native/ATOLL/Views/CourseDetailView.swift`
- Create: `apps/ios-native/ATOLL/Views/ParticipantsTabView.swift`
- Create: `apps/ios-native/ATOLL/Views/CourseInfoTabView.swift`
- Create: `apps/ios-native/ATOLL/Views/SkillCheckTabView.swift`

- [ ] **Step 1: `CourseDetailView.swift` — Host mit Segmented-Picker:**

```swift
import SwiftUI

struct CourseDetailView: View {
  let course: Course

  enum Tab: String, CaseIterable, Identifiable {
    case participants, skillCheck, info
    var id: Self { self }
    var label: String {
      switch self {
      case .participants: "Teilnehmer"
      case .skillCheck:   "Skill-Check"
      case .info:         "Info"
      }
    }
  }

  @State private var selectedTab: Tab = .participants

  var body: some View {
    VStack(spacing: 0) {
      Picker("Bereich", selection: $selectedTab) {
        ForEach(Tab.allCases) { tab in
          Text(tab.label).tag(tab)
        }
      }
      .pickerStyle(.segmented)
      .padding(.horizontal)
      .padding(.top, 8)

      Divider().padding(.top, 8)

      switch selectedTab {
      case .participants:
        ParticipantsTabView(course: course)
      case .skillCheck:
        SkillCheckTabView(course: course)
      case .info:
        CourseInfoTabView(course: course)
      }
    }
    .navigationTitle(course.title)
    .navigationBarTitleDisplayMode(.inline)
  }
}
```

- [ ] **Step 2: `ParticipantsTabView.swift`:**

```swift
import SwiftUI

struct ParticipantsTabView: View {
  let course: Course
  @State private var store = ParticipantsStore()

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
            ParticipantRow(participant: p)
          }
          .listStyle(.plain)
        }
      }
    }
    .refreshable { await store.load(courseId: course.id) }
    .task { await store.load(courseId: course.id) }
  }
}

private struct ParticipantRow: View {
  let participant: CourseParticipant

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
        }
      }
      Spacer()
    }
    .padding(.vertical, 4)
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

- [ ] **Step 3: `CourseInfoTabView.swift` — read-only Stammdaten:**

```swift
import SwiftUI

struct CourseInfoTabView: View {
  let course: Course

  var body: some View {
    List {
      Section("Kurs") {
        LabeledContent("Titel", value: course.title)
        if let code = course.courseType?.code {
          LabeledContent("Typ", value: "\(code) – \(course.courseType?.label ?? "")")
        }
        if let loc = course.location, !loc.isEmpty {
          LabeledContent("Ort", value: loc)
        }
        if let status = course.status {
          LabeledContent("Status", value: status.label)
        }
      }

      Section("Termine") {
        if course.allDates.isEmpty {
          Text("Keine Daten").foregroundStyle(.secondary)
        } else {
          ForEach(course.allDates, id: \.self) { date in
            Text(date, format: .dateTime.weekday(.wide).day().month(.wide).locale(Locale(identifier: "de_CH")))
          }
        }
      }

      if let info = course.info, !info.isEmpty {
        Section("Beschreibung") {
          Text(info)
        }
      }

      if let notes = course.notes, !notes.isEmpty {
        Section("Notizen") {
          Text(notes)
        }
      }
    }
  }
}
```

- [ ] **Step 4: `SkillCheckTabView.swift` — Placeholder für Etappe 5:**

```swift
import SwiftUI

struct SkillCheckTabView: View {
  let course: Course

  var body: some View {
    ContentUnavailableView {
      Label("Skill-Check", systemImage: "checkmark.circle")
    } description: {
      Text("PADI-Skill-Matrix kommt in einer der nächsten Updates.")
    }
  }
}
```

---

### Task 5: Navigation umstellen (Subagent)

**Files:**
- Modify: `apps/ios-native/ATOLL/Views/TodayView.swift`
- Modify: `apps/ios-native/ATOLL/Views/CalendarView.swift`

Hintergrund: TodayView und CalendarView pushen heute auf `AssignmentDetailView(assignment:)`. Neu sollen sie auf `CourseDetailView(course:)` pushen. Da `Assignment.course` Optional ist, NavigationLink nur erzeugen wenn Course vorhanden.

- [ ] **Step 1: TodayView.swift — NavigationDestination + Links**

Ersetze in `TodayView.swift`:

```swift
.navigationDestination(for: Assignment.self) { a in
  AssignmentDetailView(assignment: a)
}
```

durch:

```swift
.navigationDestination(for: Course.self) { course in
  CourseDetailView(course: course)
}
```

Und passe alle `NavigationLink(value: assignment)`-Stellen so an dass wenn `assignment.course` nicht nil ist, der Link auf `course` zeigt:

Aktuell:
```swift
ForEach(store.today()) { assignment in
  NavigationLink(value: assignment) {
    AssignmentCard(assignment: assignment, dateLabel: "Heute")
  }
  .buttonStyle(.plain)
}
```

Neu:
```swift
ForEach(store.today()) { assignment in
  if let course = assignment.course {
    NavigationLink(value: course) {
      AssignmentCard(assignment: assignment, dateLabel: "Heute")
    }
    .buttonStyle(.plain)
  } else {
    AssignmentCard(assignment: assignment, dateLabel: "Heute")
  }
}
```

Selbiges für den "Diese Woche" / upcomingWeek-Block (zweites ForEach in derselben View).

- [ ] **Step 2: CalendarView.swift — analoger Switch**

Ersetze:
```swift
.navigationDestination(for: Assignment.self) { AssignmentDetailView(assignment: $0) }
```
durch:
```swift
.navigationDestination(for: Course.self) { CourseDetailView(course: $0) }
```

Und passe die NavigationLinks in `dayDetails` analog an: nur wenn `a.course != nil` einen NavigationLink mit `value: a.course!` rendern (Swift's optional-unwrap pattern wie oben).

---

### Task 6: Xcode-Project-Refs aktualisieren (User)

- [ ] **Step 1: Xcode öffnen, neue Files hinzufügen**

In Xcode-Project-Navigator → rechtsklick auf `ATOLL`-Top-Folder → **"Add Files to ATOLL..."** → die 8 neuen Files auswählen:
- `Models/Student.swift`
- `Models/CourseParticipant.swift`
- `Services/ParticipantsStore.swift`
- `Components/StudentAvatar.swift`
- `Views/CourseDetailView.swift`
- `Views/ParticipantsTabView.swift`
- `Views/CourseInfoTabView.swift`
- `Views/SkillCheckTabView.swift`

Wichtig: jeweils in der passenden Gruppe ablegen (Models/, Services/, Components/, Views/). ATOLL-Target gehakt. "Create groups" gewählt (nicht "Create folder references").

- [ ] **Step 2: AssignmentDetailView.swift "Move to Trash"**

Im Project-Navigator → `Views/AssignmentDetailView.swift` → rechtsklick → Delete → **Move to Trash**.

- [ ] **Step 3: Build**

⌘B. Sollte grün sein.

Mögliche Stolpersteine:
- "Cannot find 'AssignmentDetailView' in scope" → es gibt noch eine Stelle die es referenziert. Grep im Codebase. Wahrscheinlich übersehene NavigationDestination.
- "Cannot find 'ParticipantsStore' in scope" → Datei nicht ins Project hinzugefügt. Erneut "Add Files..."
- Xcode-Group-Pfad falsch → Datei wird zwar gefunden, aber Project-Navigator zeigt falschen Ort. Cosmetic, kein Build-Blocker.

---

### Task 7: Simulator-Smoke (User)

- [ ] **Step 1: ⌘R, Login**

- [ ] **Step 2: Heute-Tap-Through**

Heute-Tab → tap auf einen Assignment-Card mit Course → CourseDetailView öffnet sich mit Titel des Kurses oben, Segmented-Picker (Teilnehmer/Skill-Check/Info), Teilnehmer-Liste oder Empty-State.

- [ ] **Step 3: Kurse-Tab-Tap-Through**

Kurse-Tab → tap auf einen Tag mit Punkten → Day-Details unten → tap auf eine Assignment-Card → CourseDetailView wie oben.

- [ ] **Step 4: Segmented-Picker durchklicken**

- Teilnehmer: Liste oder Empty
- Skill-Check: ContentUnavailableView "kommt in einer der nächsten Updates"
- Info: Kurs-Stammdaten (Titel, Typ, Ort, Termine, etc.)

- [ ] **Step 5: Avatar-Konsistenz**

Schüler-Avatare sollten farbig sein. Schliess+Re-Open der App → derselbe Schüler hat dieselbe Farbe (UUID-Hash-stabil).

---

### Task 8: Commit + TestFlight (User)

- [ ] **Step 1: Xcode schliessen**

- [ ] **Step 2: Stagen + Committen**

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add -A
git status              # alle 8 neuen Files, 2 modified, 1 deleted, plus pbxproj
git commit -m "ios(courses): CourseDetailView with Segmented-Picker (Teilnehmer/Skill-Check/Info)

New Models Student + CourseParticipant. ParticipantsStore loads participants
per courseId via PostgREST join contacts + contact_student. New
StudentAvatar component with stable hash-color per UUID.

CourseDetailView replaces AssignmentDetailView as the nav target from
TodayView and CalendarView. SkillCheckTabView is a placeholder until
Etappe 5.

Refs: docs/superpowers/specs/2026-05-14-ios-instructor-mobile-companion-design.md (Etappe 3)"
git push -u origin ios-etappe-3-course-detail
```

- [ ] **Step 3: TestFlight**

Xcode öffnen → Build-Number bumpen (z.B. 14 → 15) → "Any iOS Device (arm64)" → Product → Archive → Distribute → TestFlight Only → Upload. Real-Device-Smoke wie Task 7.

---

### Task 9: Merge nach main (User)

- [ ] **Step 1: Xcode schliessen**

- [ ] **Step 2: FF-Merge**

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git checkout main
git pull --ff-only
git merge --ff-only ios-etappe-3-course-detail
git push
git branch -d ios-etappe-3-course-detail
git push origin --delete ios-etappe-3-course-detail
git log --oneline -3
```

---

## Self-Review

**Spec coverage check (Section 5 Etappe 3):**
- ✅ `Models/Student.swift`, `Models/CourseParticipant.swift` — Task 2
- ✅ `Services/ParticipantsStore.swift` mit `load(courseId:)` — Task 2
- ✅ `Views/CourseDetailView.swift` mit Segmented-Picker — Task 4
- ✅ `Views/ParticipantsTabView.swift` mit `StudentAvatar`, Level-Subtitle, Status-Chip — Task 4
- ✅ `Views/Course/CourseInfoTabView.swift` — Spec hat das in `Views/Course/`-Subfolder gelegt, Plan flach. Funktionell identisch.
- ✅ `Components/StudentAvatar.swift` — hash-color per UUID — Task 3
- ✅ `Views/CoursesView.swift` NavigationLink → CourseDetailView — Plan nennt das `CalendarView.swift`, weil File nicht renamed wurde
- ⚠️ SkillCheckTabView ist nur Placeholder — sollte in Etappe 5 ausgebaut werden
- ✅ `AssignmentDetailView` wird hier abgelöst — Task 6

**Placeholder scan:** Keine TBDs, alle Code-Blöcke vollständig.

**Type consistency:**
- `Student.id` = `contacts.id` (UUID)
- `CourseParticipant.studentId` = `contacts.id` (FK nach Phase J 3c)
- `CourseParticipant.courseId` = `courses.id`
- `course.id` in NavigationLink ist `UUID` aus dem existierenden `Course`-Modell

**Pre-flight check:**
- Verifizieren dass Phase-J-3c-Migration in der lokalen Test-DB durch ist:
  `SELECT pg_typeof(student_id) FROM course_participants LIMIT 0;` und FK-Constraint
- Verifizieren dass ein Test-Kurs in Production mindestens 1–2 Teilnehmer hat für Smoke-Test

**Risiken:**
- R1: PostgREST kennt den Join `student:contacts!inner(...)` evtl. nicht, wenn keine FK-Constraint mehr existiert. → Wenn der Smoke-Test "Fehler beim Laden" wirft, im Supabase-Studio prüfen ob `course_participants_student_id_fkey` auf `contacts(id)` zeigt.
- R2: Avatar-Hash-Farbe basiert auf erstem UUID-Byte → 8 Schüler haben theoretisch alle dieselbe Farbe (1/8 Wahrscheinlichkeit-Kollision pro Paar). Akzeptabel für Pitch.
- R3: NavigationDestination `for: Course.self` braucht `Course: Hashable`. Course ist bereits Hashable (siehe `Models/Course.swift`).

**Spec-Notes für später:**
- Spec Section 3 + 5 Etappe 3 nennt `Views/Course/`-Subfolder — Plan legt flach in `Views/` ab. Spec sollte korrigiert werden (klein Docs-Commit).
- Spec sagte `CoursesView.swift` neu — Plan behält `CalendarView.swift`. Auch klein Docs-Korrektur.
