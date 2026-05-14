# iOS Etappe 6 — Global Studenten-Tab

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Der Studenten-Tab (aktuell Placeholder) wird zur richtigen Liste aller Schüler mit Suchleiste und Sektionen pro Level. Tap auf Schüler öffnet eine Read-only-Detail-View mit Stammdaten.

**Architecture:** Neuer `StudentsStore` lädt alle `contacts` mit `contact_student!inner`-Join via PostgREST. Reuse der Student-Struktur aus Etappe 3. Suche ist client-side in-memory. Detail-View ist eine simple List mit LabeledContent.

**Tech Stack:** Swift 5.10, SwiftUI, Supabase-Swift 2.x.

**Branch:** `ios-etappe-6-students-tab` (Branch nicht zwingend — kein DB-Migration, kein Auth-kritisches Code — aber für saubere History trotzdem).

---

## File Structure

**Created:**
- `apps/ios-native/ATOLL/Services/StudentsStore.swift`
- `apps/ios-native/ATOLL/Views/StudentDetailView.swift`

**Modified (Replace):**
- `apps/ios-native/ATOLL/Views/StudentsView.swift` — vom Placeholder zur richtigen Liste

---

## Tasks

### Task 1: Branch + Plan-Commit (User)

Xcode schliessen vorher.

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git status
git add docs/superpowers/plans/2026-05-14-ios-etappe-6-students-tab.md
git commit -m 'docs(plan): iOS Etappe 6 — Studenten-Tab plan'
git checkout -b ios-etappe-6-students-tab
```

---

### Task 2: StudentsStore (Subagent)

**Files:**
- Create: `apps/ios-native/ATOLL/Services/StudentsStore.swift`

- [ ] **Step 1:**

```swift
import Foundation
import Supabase

@MainActor
@Observable
final class StudentsStore {
  enum LoadState {
    case idle, loading, loaded, error
  }

  private(set) var allStudents: [Student] = []
  private(set) var loadState: LoadState = .idle
  private(set) var errorMessage: String?

  private let supabase = SupabaseClient.shared

  /// Lädt alle `contacts` mit `contact_student!inner`-Sidecar (= alle Schüler).
  /// Sortiert nach Last-Name aufsteigend.
  func loadAll() async {
    loadState = .loading
    errorMessage = nil
    do {
      let rows: [Student] = try await supabase
        .from("contacts")
        .select("id, first_name, last_name, primary_email, contact_student!inner(level, photo_url)")
        .eq("kind", value: "person")
        .order("last_name", ascending: true)
        .execute()
        .value
      allStudents = rows
      loadState = .loaded
    } catch {
      #if DEBUG
      print("⚠️ StudentsStore.loadAll failed: \(error)")
      #endif
      loadState = .error
      errorMessage = error.localizedDescription
    }
  }

  /// Client-side Volltextsuche über first_name + last_name + email.
  /// Case-insensitive, Substring-Match. Bei leerem Query: alle Schüler.
  func search(_ query: String) -> [Student] {
    let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    guard !trimmed.isEmpty else { return allStudents }
    return allStudents.filter { s in
      s.firstName.lowercased().contains(trimmed)
        || s.lastName.lowercased().contains(trimmed)
        || (s.primaryEmail?.lowercased().contains(trimmed) ?? false)
    }
  }
}
```

---

### Task 3: StudentsView ausbauen (Subagent)

**Files:**
- Replace: `apps/ios-native/ATOLL/Views/StudentsView.swift`

Komplett ersetzen mit:

- [ ] **Step 1:**

```swift
import SwiftUI

struct StudentsView: View {
  let user: CurrentUser

  @State private var store = StudentsStore()
  @State private var query: String = ""

  var body: some View {
    NavigationStack {
      Group {
        switch store.loadState {
        case .idle, .loading where store.allStudents.isEmpty:
          ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        case .error:
          ContentUnavailableView {
            Label("Fehler beim Laden", systemImage: "exclamationmark.triangle")
          } description: {
            Text(store.errorMessage ?? "")
          } actions: {
            Button("Nochmal versuchen") {
              Task { await store.loadAll() }
            }
          }
        default:
          if store.allStudents.isEmpty {
            ContentUnavailableView(
              "Noch keine Schüler",
              systemImage: "person.2",
              description: Text("Sobald Schüler eingeschrieben sind, erscheinen sie hier.")
            )
          } else if filtered.isEmpty {
            ContentUnavailableView.search(text: query)
          } else {
            list
          }
        }
      }
      .navigationTitle("Studenten")
      .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Name oder Email")
      .refreshable { await store.loadAll() }
      .task { await store.loadAll() }
    }
  }

  private var filtered: [Student] {
    store.search(query)
  }

  private var grouped: [(level: String, students: [Student])] {
    let groups = Dictionary(grouping: filtered, by: { $0.level ?? "Ohne Level" })
    // Sortier-Reihenfolge: bekannte Level zuerst, dann alphabetisch, "Ohne Level" am Ende.
    let knownOrder = ["DSD", "Scuba Diver", "OWD", "AOWD", "Rescue", "Divemaster", "Instructor", "Other"]
    let sortedKeys = groups.keys.sorted { lhs, rhs in
      let li = knownOrder.firstIndex(of: lhs) ?? Int.max
      let ri = knownOrder.firstIndex(of: rhs) ?? Int.max
      if li != ri { return li < ri }
      if lhs == "Ohne Level" { return false }
      if rhs == "Ohne Level" { return true }
      return lhs < rhs
    }
    return sortedKeys.map { (level: $0, students: groups[$0] ?? []) }
  }

  private var list: some View {
    List {
      ForEach(grouped, id: \.level) { group in
        Section(group.level) {
          ForEach(group.students) { student in
            NavigationLink(value: student) {
              StudentRow(student: student)
            }
          }
        }
      }
    }
    .listStyle(.insetGrouped)
    .navigationDestination(for: Student.self) { student in
      StudentDetailView(student: student)
    }
  }
}

private struct StudentRow: View {
  let student: Student

  var body: some View {
    HStack(spacing: 12) {
      StudentAvatar(
        initials: student.initials,
        id: student.id,
        size: 36
      )
      VStack(alignment: .leading, spacing: 2) {
        Text(student.displayName)
          .font(.subheadline.bold())
        if let email = student.primaryEmail {
          Text(email)
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
      }
      Spacer()
    }
    .padding(.vertical, 4)
  }
}
```

Hinweise:
- `MainTabView.swift` ruft schon `StudentsView(user: user)` auf — Signatur passt.
- `ContentUnavailableView.search(text:)` ist iOS 17+ built-in für "Keine Treffer für 'X'" — passt zu unserer iOS-Mindest-Version.
- `.searchable` mit `.always`-Display-Mode zeigt die Suchleiste permanent (statt erst nach Pull-Down).

---

### Task 4: StudentDetailView (Subagent)

**Files:**
- Create: `apps/ios-native/ATOLL/Views/StudentDetailView.swift`

- [ ] **Step 1:**

```swift
import SwiftUI

struct StudentDetailView: View {
  let student: Student

  var body: some View {
    List {
      Section {
        HStack(spacing: 16) {
          StudentAvatar(
            initials: student.initials,
            id: student.id,
            size: 64
          )
          VStack(alignment: .leading, spacing: 4) {
            Text(student.displayName)
              .font(.title3.bold())
            if let level = student.level {
              Text(level)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
            }
          }
        }
        .padding(.vertical, 4)
      }

      Section("Kontakt") {
        if let email = student.primaryEmail, !email.isEmpty {
          LabeledContent("Email") {
            Text(email).textSelection(.enabled)
          }
        } else {
          Text("Keine Kontaktdaten").foregroundStyle(.secondary)
        }
      }

      Section {
        Text("Kursteilnahmen kommen in einer der nächsten Updates.")
          .font(.caption)
          .foregroundStyle(.secondary)
      } header: {
        Text("Kursteilnahmen")
      }
    }
    .navigationTitle(student.displayName)
    .navigationBarTitleDisplayMode(.inline)
  }
}
```

Bewusst minimal: Stammdaten + Placeholder für Kursteilnahmen. Letzteres ist in einer kleinen Post-Pitch-Etappe machbar (StudentParticipationsStore + course_participants-Join).

---

### Task 5: Xcode-Project + Build (User)

- [ ] **Step 1: Xcode öffnen, neue Files adden** in passende Gruppen:
  - Services → `apps/ios-native/ATOLL/Services/StudentsStore.swift`
  - Views → `apps/ios-native/ATOLL/Views/StudentDetailView.swift`

- [ ] **Step 2:** `StudentsView.swift` wurde nur modifiziert (war schon im Project) — nichts zusätzlich adden.

- [ ] **Step 3:** ⌘B → grün.

Mögliche Stolpersteine:
- `'Student' is not conforming to 'Hashable'` — Student aus E3 muss schon Hashable sein (Codable, Identifiable, Hashable). Falls Compiler meckert, im Student.swift checken.
- `'ContentUnavailableView' no member 'search'` → iOS-Deployment-Target zu tief; auf iOS 17 setzen.

---

### Task 6: Simulator-Smoke (User)

- [ ] **Step 1: ⌘R**, Login.

- [ ] **Step 2: Studenten-Tab tippen.**

Sollte jetzt zeigen:
- Suchleiste oben
- Sektionen pro Level (OWD, AOWD, etc.), evtl. "Ohne Level"
- Pro Eintrag: Avatar, Name, Email darunter
- Chevron rechts für NavigationLink

- [ ] **Step 3: Suche tippen** (z.B. "an" für Anna o.ä.) — Liste filtert in Echtzeit. Wenn keine Treffer: "Keine Ergebnisse für 'an'" Standard-iOS-Empty-Search.

- [ ] **Step 4: Tap auf einen Schüler** → StudentDetailView öffnet sich:
- Grosser Avatar oben mit Name + Level
- Kontakt-Sektion mit Email
- Placeholder für Kursteilnahmen
- Tap auf "Studenten" zurück → zurück zur Liste, Suche bleibt erhalten

- [ ] **Step 5: Pull-to-Refresh** in der Liste → Reload.

---

### Task 7: Commit + TestFlight (User)

Xcode schliessen.

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add -A
git status
git commit -m 'ios(students): Global Studenten-Tab mit Suche, Sektionen, Detail

Studenten-Tab vom Placeholder zur richtigen Liste. Neuer StudentsStore
laedt alle contacts mit contact_student!inner-Sidecar. Suche ist
client-side in-memory ueber Name + Email. Liste ist sektioniert nach
Level (DSD, OWD, AOWD, Rescue, ... + Ohne Level am Ende).

StudentDetailView ist Read-only mit Stammdaten + Avatar. Kursteilnahmen-
Liste ist deferred fuer Post-Pitch.

Refs: docs/superpowers/specs/2026-05-14-ios-instructor-mobile-companion-design.md (Etappe 6)'

git push -u origin ios-etappe-6-students-tab
```

Dann TestFlight: Build-Number hochzählen → Archive → Upload → iPhone Smoke.

---

### Task 8: Merge nach main (User)

Xcode schliessen.

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git checkout main
git status
git pull --ff-only
git merge --ff-only ios-etappe-6-students-tab
git push
git branch -d ios-etappe-6-students-tab
git push origin --delete ios-etappe-6-students-tab
git log --oneline -3
```

---

## Self-Review

**Spec coverage check (Section 5 Etappe 6):**
- ✅ `Services/StudentsStore.swift` mit `loadAll()`, `search()` — Task 2
- ✅ `Views/StudentsView.swift` mit Suche + sektionierter Liste — Task 3
- ✅ `Views/StudentDetailView.swift` Read-only — Task 4
- ⚠️ Kurs-Teilnahme-Historie in Detail-View AUSGESCHLOSSEN, Placeholder stattdessen — deferred.

**Placeholder scan:** Keine TBDs.

**Type consistency:**
- `Student` aus E3 wird wiederverwendet. `Hashable` ist auf Student schon drauf (E3 hat das definiert), also funktioniert `NavigationLink(value: student)` und `.navigationDestination(for: Student.self)`.
- `StudentAvatar` aus E3 wird wiederverwendet.

**Risiken:**
- R1: Wenn die DB sehr viele Schüler hat (1000+), wird `loadAll()` langsam und der client-side Search nicht optimal. Für aktuelle TSK-Scale (75 Personen Sheet) bei weitem genug.
- R2: PostgREST `contact_student!inner(...)` — falls die Beziehung zwischen `contacts` und `contact_student` nicht als FK definiert ist, schlägt der inner-join fehl. Wir wissen aus E3 dass das funktioniert.

**Spec-Notes für später:**
- Server-side search via `or=ilike` post-Pitch wenn Skalen-Bedarf
- Kursteilnahmen-Historie in Detail-View
- Tap-on-Email → Mail.app öffnen (URL handling)
- Filter-Chips zusätzlich zur Suche (z.B. nur OWD-Schüler)
