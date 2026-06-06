# ComHub Phase 4a — Aufgaben (lesen + mergen) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ein **Aufgaben**-Modul (`.tasks`) im CoHub-Look, das **Apple Erinnerungen** + **Atoll-Tasks** (`contact_events` Typ `task`) **gemergt** anzeigt: Filter-Rail (Alle/Heute/Markiert + „Meine Listen"), Aufgabenliste (offen + erledigt), je Quelle/Liste getönt. Die `TodoProvider` werden in den `Hub` verdrahtet → das **Heute-Cockpit** zeigt automatisch echte „Aufgaben heute".

**Architecture:** `UnifiedTask` (AtollHub) wird additiv um Listen-/Flag-/Prio-/Notiz-Felder erweitert; reine Filter-/Gruppier-Logik (`TaskDigest`) wandert nach AtollHub (TDD). Zwei App-Adapter erfüllen `TodoProvider`: `AppleRemindersAdapter` (EventKit `fetchReminders` → `UnifiedTask`) und `AtollTasksAdapter` (`contact_events eq event_type task` → `UnifiedTask`); beide werden in `HubWiring` (todo-Slot) registriert. Ein `AufgabenStore` + `AufgabenModuleView` (Rail + Liste) rendern. **Lese-only:** Abhaken/Erstellen kommt in Phase 5 (Schreiben) — Checkboxen sind hier Status-Anzeige, keine Buttons.

**Tech Stack:** Swift 6 (strict concurrency complete), SwiftUI Multiplatform (iOS 26 / macOS 26), EventKit (`EKReminder`), `supabase-swift` (PostgREST), XcodeGen, XCTest. Reuse: `Hub`/`AccountConnection.todo`/`allTasks()`, `UnifiedTask`, `HubWiring`, `CockpitStore`/`CockpitDigest` (leuchten automatisch), `CoColor`/`CoTheme`, `AppleAuthorizationService` (Reminders-Permission aus Phase 0).

---

## Scope-Grenzen (bewusst)

- **Lese-only.** Abhaken (EKReminder-Completion / `contact_events`-Status) und Erstellen = **Phase 5** (Schreiben). Checkboxen zeigen nur den Zustand (kein Tap-Toggle).
- **„Meine Listen"** = Apple-Erinnerungslisten (EKCalendar). Atoll-Tasks haben keine Liste/Flag/Prio → dort `nil`/default.
- **Sidebar-Badge** für Aufgaben zurückgestellt (braucht Count-Plumbing in `HubShell`) — das Cockpit-„Aufgaben"-Widget zeigt den Count.
- **Kein Detail-Pane** (Mockup zeigt nur Rail + Liste).

---

## File Structure

**Geändertes Paket — `swift-packages/AtollHub/`:**
- `Sources/AtollHub/Model/UnifiedModels.swift` — `UnifiedTask` additiv erweitern.
- `Sources/AtollHub/Tasks/TaskDigest.swift` — `TaskSmartFilter`, `TaskDigest` (filtern/splitten/Listen).
- `Tests/AtollHubTests/TaskDigestTests.swift`.

**Neue App-Dateien — `apps/comhub-native/ComHub/Tasks/`:**
- `AppleRemindersAdapter.swift` — `TodoProvider` über EventKit.
- `AtollTasksAdapter.swift` — `TodoProvider` über `contact_events`.
- `AufgabenStore.swift` — Lade-Zustand + Filter.
- `AufgabenModuleView.swift` — Rail + Liste.
- `TaskRow.swift` — eine Aufgaben-Zeile.

**Geänderte App-Dateien:**
- `ComHub/Hub/HubWiring.swift` — `todo:`-Provider ergänzen.
- `ComHub/Shell/HubShell.swift` — `.tasks` rendert `AufgabenModuleView`.

**Doku:**
- `apps/comhub-native/README.md` — Phase-4a-Zeile.

---

## Task 1: `UnifiedTask` erweitern + `TaskDigest` (AtollHub, TDD)

**Files:**
- Modify: `swift-packages/AtollHub/Sources/AtollHub/Model/UnifiedModels.swift`
- Create: `swift-packages/AtollHub/Sources/AtollHub/Tasks/TaskDigest.swift`
- Test: `swift-packages/AtollHub/Tests/AtollHubTests/TaskDigestTests.swift`

- [ ] **Step 1: `UnifiedTask` additiv erweitern**

In `swift-packages/AtollHub/Sources/AtollHub/Model/UnifiedModels.swift` die `UnifiedTask`-Struktur ersetzen durch (neue Felder mit Defaults — der bestehende Aufruf `UnifiedTask(id:source:title:due:isDone:)` bleibt gültig):

```swift
/// Quellneutrale Aufgabe (Apple Erinnerungen / Atoll-Tasks).
public struct UnifiedTask: Sendable, Identifiable, Equatable, Hashable {
  public let id: String
  public let source: AccountRef
  public let title: String
  public let due: Date?
  public let isDone: Bool
  public let listName: String?
  public let listColorHex: String?
  public let isFlagged: Bool
  public let priority: Int        // 0 = keine
  public let notes: String?

  public init(id: String, source: AccountRef, title: String, due: Date?, isDone: Bool,
              listName: String? = nil, listColorHex: String? = nil,
              isFlagged: Bool = false, priority: Int = 0, notes: String? = nil) {
    self.id = id; self.source = source; self.title = title
    self.due = due; self.isDone = isDone
    self.listName = listName; self.listColorHex = listColorHex
    self.isFlagged = isFlagged; self.priority = priority; self.notes = notes
  }
}
```

- [ ] **Step 2: Failing Test schreiben**

`swift-packages/AtollHub/Tests/AtollHubTests/TaskDigestTests.swift`:

```swift
import XCTest
@testable import AtollHub

final class TaskDigestTests: XCTestCase {
  private var cal: Calendar {
    var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "Europe/Zurich")!; return c
  }
  private func day(_ s: String) -> Date {
    let f = DateFormatter(); f.calendar = cal; f.timeZone = cal.timeZone
    f.dateFormat = "yyyy-MM-dd"; f.locale = Locale(identifier: "en_US_POSIX"); return f.date(from: s)!
  }
  private func task(_ id: String, due: Date?, done: Bool = false, flagged: Bool = false,
                    list: String? = nil) -> UnifiedTask {
    UnifiedTask(id: id, source: AccountRef(accountId: "x", type: .apple), title: id,
                due: due, isDone: done, listName: list, isFlagged: flagged)
  }

  func test_smartToday_keepsDueToday() {
    let now = day("2026-06-02")
    let tasks = [task("t", due: day("2026-06-02")), task("m", due: day("2026-06-03")), task("n", due: nil)]
    let r = TaskDigest.filter(tasks, smart: .today, list: nil, now: now, calendar: cal)
    XCTAssertEqual(r.open.map(\.id), ["t"])
  }

  func test_smartFlagged() {
    let tasks = [task("a", due: nil, flagged: true), task("b", due: nil)]
    let r = TaskDigest.filter(tasks, smart: .flagged, list: nil, now: day("2026-06-02"), calendar: cal)
    XCTAssertEqual(r.open.map(\.id), ["a"])
  }

  func test_splitOpenDone_andListFilter() {
    let tasks = [task("o", due: nil, list: "Schule"), task("d", due: nil, done: true, list: "Schule"),
                 task("x", due: nil, list: "Privat")]
    let r = TaskDigest.filter(tasks, smart: .all, list: "Schule", now: day("2026-06-02"), calendar: cal)
    XCTAssertEqual(r.open.map(\.id), ["o"])
    XCTAssertEqual(r.done.map(\.id), ["d"])
  }

  func test_lists_groupsWithOpenCount() {
    let tasks = [task("a", due: nil, list: "Schule"), task("b", due: nil, done: true, list: "Schule"),
                 task("c", due: nil, list: "Privat")]
    let lists = TaskDigest.lists(tasks)
    XCTAssertEqual(lists.map(\.name), ["Privat", "Schule"]) // alphabetisch
    XCTAssertEqual(lists.first { $0.name == "Schule" }?.openCount, 1)
  }
}
```

- [ ] **Step 3: Test ausführen — soll fehlschlagen**

Run: `cd swift-packages/AtollHub && swift test --filter TaskDigestTests`
Expected: FAIL — `cannot find 'TaskDigest' in scope`.

- [ ] **Step 4: Implementieren**

`swift-packages/AtollHub/Sources/AtollHub/Tasks/TaskDigest.swift`:

```swift
import Foundation

/// Smart-Filter der Aufgaben-Rail.
public enum TaskSmartFilter: String, Sendable, CaseIterable, Identifiable {
  case all, today, flagged
  public var id: String { rawValue }
  public var title: String {
    switch self { case .all: return "Alle"; case .today: return "Heute"; case .flagged: return "Markiert" }
  }
}

/// Eine „Meine Listen"-Gruppe.
public struct TaskList: Sendable, Identifiable, Equatable {
  public let id: String           // = name
  public let name: String
  public let colorHex: String?
  public let openCount: Int
  public init(name: String, colorHex: String?, openCount: Int) {
    self.id = name; self.name = name; self.colorHex = colorHex; self.openCount = openCount
  }
}

/// Reine Filter-/Gruppier-Logik fürs Aufgaben-Modul.
public enum TaskDigest {
  /// Gefiltert (Smart + optionale Liste) und in offen/erledigt gesplittet.
  /// Offen: nach Faelligkeit (nil zuletzt). Erledigt: nach Titel.
  public static func filter(_ tasks: [UnifiedTask], smart: TaskSmartFilter, list: String?,
                            now: Date, calendar: Calendar) -> (open: [UnifiedTask], done: [UnifiedTask]) {
    let today = calendar.startOfDay(for: now)
    var filtered = tasks
    switch smart {
    case .all:     break
    case .today:   filtered = filtered.filter { $0.due.map { calendar.startOfDay(for: $0) == today } ?? false }
    case .flagged: filtered = filtered.filter { $0.isFlagged }
    }
    if let list { filtered = filtered.filter { $0.listName == list } }

    let open = filtered.filter { !$0.isDone }.sorted { lhs, rhs in
      switch (lhs.due, rhs.due) {
      case let (l?, r?): return l < r
      case (nil, _?):    return false
      case (_?, nil):    return true
      case (nil, nil):   return lhs.title < rhs.title
      }
    }
    let done = filtered.filter { $0.isDone }.sorted { $0.title < $1.title }
    return (open, done)
  }

  /// „Meine Listen" aus allen Tasks (mit `listName`), alphabetisch, je offene Anzahl.
  public static func lists(_ tasks: [UnifiedTask]) -> [TaskList] {
    var color: [String: String?] = [:]
    var openCount: [String: Int] = [:]
    for t in tasks {
      guard let name = t.listName else { continue }
      if color[name] == nil { color[name] = t.listColorHex }
      if !t.isDone { openCount[name, default: 0] += 1 }
    }
    return color.keys.sorted().map {
      TaskList(name: $0, colorHex: color[$0] ?? nil, openCount: openCount[$0] ?? 0)
    }
  }
}
```

- [ ] **Step 5: Test ausführen — soll grün sein**

Run: `cd swift-packages/AtollHub && swift test --filter TaskDigestTests`
Expected: PASS — 4 Tests grün.

- [ ] **Step 6: Volle Paket-Suite + Commit**

Run: `cd swift-packages/AtollHub && swift test`
Expected: PASS — alle Suiten grün (auch `CockpitDigestTests`, da der `UnifiedTask`-Init rückwärtskompatibel ist).

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add swift-packages/AtollHub/Sources/AtollHub/Model/UnifiedModels.swift swift-packages/AtollHub/Sources/AtollHub/Tasks/TaskDigest.swift swift-packages/AtollHub/Tests/AtollHubTests/TaskDigestTests.swift
git commit -m "AtollHub: UnifiedTask erweitert (Liste/Flag/Prio/Notiz) + TaskDigest (Filter/Listen)"
```

---

## Task 2: `AppleRemindersAdapter` (EventKit → TodoProvider) (ComHub)

**Files:**
- Create: `apps/comhub-native/ComHub/Tasks/AppleRemindersAdapter.swift`

- [ ] **Step 1: Adapter schreiben**

`apps/comhub-native/ComHub/Tasks/AppleRemindersAdapter.swift`:

```swift
import Foundation
@preconcurrency import EventKit
import AtollHub

/// Erfüllt `TodoProvider` über Apple Erinnerungen (`EKReminder`). Lese-only.
/// Liste = `EKCalendar.title` (+ Farbe), Flag ~ hohe Priorität, isDone = completed.
struct AppleRemindersAdapter: TodoProvider {
  let accountId: String
  private let store: EKEventStore

  init(accountId: String = "apple", store: EKEventStore) {
    self.accountId = accountId
    self.store = store
  }

  func tasks() async throws -> [UnifiedTask] {
    guard EKEventStore.authorizationStatus(for: .reminder) == .fullAccess else { return [] }
    let predicate = store.predicateForReminders(in: nil)
    let reminders: [EKReminder] = await withCheckedContinuation { cont in
      store.fetchReminders(matching: predicate) { cont.resume(returning: $0 ?? []) }
    }
    let ref = AccountRef(accountId: accountId, type: .apple)
    return reminders.map { r in
      let due = r.dueDateComponents.flatMap { Calendar.current.date(from: $0) }
      let colorHex = r.calendar?.cgColor.flatMap(Self.hex(from:))
      return UnifiedTask(
        id: "apple:\(r.calendarItemIdentifier)",
        source: ref, title: r.title ?? "(Ohne Titel)",
        due: due, isDone: r.isCompleted,
        listName: r.calendar?.title, listColorHex: colorHex,
        isFlagged: r.priority != 0 && r.priority <= 3,   // EKReminder 1..4 = hoch
        priority: r.priority, notes: r.notes
      )
    }
  }

  private static func hex(from cg: CGColor) -> String? {
    guard let c = cg.components, c.count >= 3 else { return nil }
    let r = Int((c[0] * 255).rounded()), g = Int((c[1] * 255).rounded()), b = Int((c[2] * 255).rounded())
    return String(format: "#%02X%02X%02X", r, g, b)
  }
}
```

- [ ] **Step 2: Build verifizieren**

Run: `cd apps/comhub-native && xcodegen generate && xcodebuild -scheme ComHub -destination 'platform=macOS,arch=arm64' build`
Expected: `** BUILD SUCCEEDED **`. (Reminders-Permission wird vom `AppleAuthorizationService` (Phase 0) angefragt.) **Falls** `fetchReminders(matching:)`/`predicateForReminders(in:)`/`EKReminder.priority`-Signaturen abweichen, an der EventKit-Doku/AtollCal `SystemCalendarStore` ausrichten — melden.

- [ ] **Step 3: Commit**

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add apps/comhub-native/ComHub/Tasks/AppleRemindersAdapter.swift
git commit -m "ComHub: AppleRemindersAdapter (EventKit -> TodoProvider, lesen)"
```

---

## Task 3: `AtollTasksAdapter` (`contact_events` task → TodoProvider) (ComHub)

**Files:**
- Create: `apps/comhub-native/ComHub/Tasks/AtollTasksAdapter.swift`

- [ ] **Step 1: Adapter schreiben**

`apps/comhub-native/ComHub/Tasks/AtollTasksAdapter.swift`:

```swift
import Foundation
import AtollCore
import AtollHub
import Supabase

/// Erfüllt `TodoProvider` über Atoll-`contact_events` mit `event_type = "task"`.
/// `due` aus `payload.due_date`; `isDone` = Status nicht „open" oder `completed_at` gesetzt.
struct AtollTasksAdapter: TodoProvider {
  let accountId: String
  private let supabase = SupabaseClient.shared

  init(accountId: String = "atoll") { self.accountId = accountId }

  private struct TaskRow: Decodable {
    let id: String
    let summary: String
    let body: String?
    let status: String
    let payload: TaskPayload?
    struct TaskPayload: Decodable {
      let dueDate: String?
      let completedAt: String?
      enum CodingKeys: String, CodingKey { case dueDate = "due_date"; case completedAt = "completed_at" }
    }
  }

  func tasks() async throws -> [UnifiedTask] {
    let rows: [TaskRow] = try await supabase
      .from("contact_events")
      .select("id, summary, body, status, payload")
      .eq("event_type", value: "task")
      .order("occurred_at", ascending: false)
      .limit(500)
      .execute()
      .value
    let ref = AccountRef(accountId: accountId, type: .atoll)
    return rows.map { row in
      let done = row.status != "open" || (row.payload?.completedAt != nil)
      let due = row.payload?.dueDate.flatMap(Self.parseDate)
      return UnifiedTask(id: "atoll:\(row.id)", source: ref, title: row.summary,
                         due: due, isDone: done, notes: row.body)
    }
  }

  private static func parseDate(_ s: String) -> Date? {
    // due_date ist ein ISO-Datum ("YYYY-MM-DD") oder Timestamp.
    let dayOnly = DateFormatter()
    dayOnly.dateFormat = "yyyy-MM-dd"; dayOnly.locale = Locale(identifier: "en_US_POSIX")
    dayOnly.timeZone = TimeZone(identifier: "Europe/Zurich")
    if let d = dayOnly.date(from: s) { return d }
    let iso = ISO8601DateFormatter()
    iso.formatOptions = [.withInternetDateTime]
    return iso.date(from: s)
  }
}
```

- [ ] **Step 2: Build verifizieren**

Run: `cd apps/comhub-native && xcodegen generate && xcodebuild -scheme ComHub -destination 'platform=macOS,arch=arm64' build`
Expected: `** BUILD SUCCEEDED **`. (Compile beweist die `TaskRow`-Decoding-Signatur + PostgREST-Kette. RLS: `contact_events` ist owner-gescoped — gleiche Sichtbarkeit wie Kombox.)

- [ ] **Step 3: Commit**

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add apps/comhub-native/ComHub/Tasks/AtollTasksAdapter.swift
git commit -m "ComHub: AtollTasksAdapter (contact_events task -> TodoProvider)"
```

---

## Task 4: `HubWiring` — Todo-Provider verdrahten (ComHub)

**Files:**
- Modify: `apps/comhub-native/ComHub/Hub/HubWiring.swift`

- [ ] **Step 1: `todo:` ergänzen**

In `apps/comhub-native/ComHub/Hub/HubWiring.swift`:

1. Beim Apple-`AccountConnection` `.todo` ergänzen + Capability `.todo`:

```swift
    let apple = Account(id: "apple", type: .apple, displayName: "iCloud",
                        capabilities: [.calendar, .contacts, .todo])
    hub.connect(AccountConnection(
      account: apple,
      calendar: AppleCalendarAdapter(store: eventStore),
      todo: AppleRemindersAdapter(store: eventStore),
      contacts: AppleContactsAdapter()
    ))
```

2. Beim Atoll-`AccountConnection` `.todo` ergänzen + Capability `.todo`:

```swift
    let atoll = Account(id: "atoll", type: .atoll, displayName: "Atoll",
                        capabilities: [.calendar, .contacts, .todo])
    hub.connect(AccountConnection(
      account: atoll,
      calendar: AtollEventsAdapter(instructorId: currentUser.legacyInstructorId),
      todo: AtollTasksAdapter(),
      contacts: AtollContactsAdapter()
    ))
```

(Die `AccountConnection(account:calendar:mail:todo:contacts:)`-Signatur aus Phase 0 hat den `todo:`-Slot bereits.)

- [ ] **Step 2: Build verifizieren**

Run: `cd apps/comhub-native && xcodegen generate && xcodebuild -scheme ComHub -destination 'platform=macOS,arch=arm64' build`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Zwischen-Smoke (optional, empfohlen)** — App starten, **Heute**: „Aufgaben heute" zeigt jetzt echte offene Aufgaben (statt „Keine Aufgaben fällig").

- [ ] **Step 4: Commit**

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add apps/comhub-native/ComHub/Hub/HubWiring.swift
git commit -m "ComHub: HubWiring Todo-Provider (Apple Reminders + Atoll-Tasks) -> Cockpit leuchtet"
```

---

## Task 5: `AufgabenStore` + `AufgabenModuleView` + `TaskRow` + Shell (ComHub)

**Files:**
- Create: `apps/comhub-native/ComHub/Tasks/AufgabenStore.swift`
- Create: `apps/comhub-native/ComHub/Tasks/TaskRow.swift`
- Create: `apps/comhub-native/ComHub/Tasks/AufgabenModuleView.swift`
- Modify: `apps/comhub-native/ComHub/Shell/HubShell.swift`

- [ ] **Step 1: `AufgabenStore` schreiben**

`apps/comhub-native/ComHub/Tasks/AufgabenStore.swift`:

```swift
import Foundation
import Observation
import AtollHub

/// Lade-Zustand fürs Aufgaben-Modul: alle Tasks via Hub, Smart/Listen-Filter.
@MainActor
@Observable
final class AufgabenStore {
  private(set) var all: [UnifiedTask] = []
  private(set) var loading = false
  var smart: TaskSmartFilter = .all
  var list: String?            // ausgewählte „Meine Liste" (überschreibt smart, wenn gesetzt)

  private var calendar: Calendar {
    var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "Europe/Zurich") ?? .current
    c.firstWeekday = 2; return c
  }

  var lists: [TaskList] { TaskDigest.lists(all) }
  var result: (open: [UnifiedTask], done: [UnifiedTask]) {
    TaskDigest.filter(all, smart: list == nil ? smart : .all, list: list, now: Date(), calendar: calendar)
  }

  func reload(using hub: Hub) async {
    loading = true
    all = await hub.allTasks()
    loading = false
  }
}
```

- [ ] **Step 2: `TaskRow` schreiben**

`apps/comhub-native/ComHub/Tasks/TaskRow.swift`:

```swift
import SwiftUI
import AtollHub

/// Eine Aufgaben-Zeile (lese-only Checkbox = Status-Anzeige).
struct TaskRow: View {
  let task: UnifiedTask
  var showList: Bool = true

  private var listColor: Color {
    if let hex = task.listColorHex, let c = Color(hex: hex) { return c }
    return task.source.type == .atoll ? CoColor.accent : .secondary
  }
  private static let due: DateFormatter = {
    let f = DateFormatter(); f.dateFormat = "dd.MM."
    f.locale = Locale(identifier: "de_CH"); f.timeZone = TimeZone(identifier: "Europe/Zurich"); return f
  }()

  var body: some View {
    HStack(alignment: .top, spacing: 11) {
      ZStack {
        Circle().strokeBorder(task.isDone ? .clear : .secondary, lineWidth: 1.8)
          .background(Circle().fill(task.isDone ? listColor : .clear))
          .frame(width: 20, height: 20)
        if task.isDone { Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundStyle(.white) }
      }
      VStack(alignment: .leading, spacing: 2) {
        HStack(spacing: 7) {
          Text(task.title).font(.system(size: 13.5))
            .foregroundStyle(task.isDone ? .tertiary : .primary)
            .strikethrough(task.isDone)
          if task.isFlagged && !task.isDone {
            Image(systemName: "flag.fill").font(.system(size: 11)).foregroundStyle(Color(red: 1, green: 0.62, blue: 0.04))
          }
        }
        if let notes = task.notes, !notes.isEmpty {
          Text(notes).font(.system(size: 12)).foregroundStyle(.tertiary).lineLimit(1)
        }
        HStack(spacing: 8) {
          if let d = task.due {
            Text(Self.due.string(from: d)).font(.system(size: 11, weight: .medium)).foregroundStyle(.tertiary)
          }
          if showList, let name = task.listName {
            HStack(spacing: 4) {
              Circle().fill(listColor).frame(width: 7, height: 7)
              Text(name).font(.system(size: 11)).foregroundStyle(.tertiary)
            }
          }
        }
      }
      Spacer(minLength: 0)
    }
    .padding(.vertical, 9)
  }
}

/// Hex -> Color Helfer (z.B. "#34C759").
extension Color {
  init?(hex: String) {
    var s = hex.trimmingCharacters(in: .whitespaces)
    if s.hasPrefix("#") { s.removeFirst() }
    guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
    self = Color(red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255,
                 blue: Double(v & 0xFF) / 255)
  }
}
```

- [ ] **Step 3: `AufgabenModuleView` schreiben**

`apps/comhub-native/ComHub/Tasks/AufgabenModuleView.swift`:

```swift
import SwiftUI
import AtollHub

/// Aufgaben-Modul: Filter-Rail (Alle/Heute/Markiert + Meine Listen) + Liste.
struct AufgabenModuleView: View {
  @Environment(Hub.self) private var hub
  @State private var store = AufgabenStore()

  var body: some View {
    @Bindable var store = store
    HStack(spacing: 0) {
      rail(store: store)
        #if os(macOS)
        .frame(width: 210)
        #endif
      Divider()
      list
    }
    .task { await store.reload(using: hub) }
  }

  private func rail(store: AufgabenStore) -> some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 14) {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
          ForEach(TaskSmartFilter.allCases) { f in
            let active = store.list == nil && store.smart == f
            Button { store.list = nil; store.smart = f } label: {
              VStack(alignment: .leading, spacing: 6) {
                Image(systemName: icon(f)).font(.system(size: 16))
                  .foregroundStyle(active ? .white : smartColor(f))
                HStack(alignment: .firstTextBaseline) {
                  Text(f.title).font(.system(size: 11.5, weight: .semibold))
                  Spacer()
                  Text("\(count(f, store))").font(.system(size: 16, weight: .bold))
                }
                .foregroundStyle(active ? .white : .primary)
              }
              .padding(9).frame(maxWidth: .infinity, alignment: .leading)
              .background(active ? AnyShapeStyle(CoColor.accent) : AnyShapeStyle(.quaternary),
                          in: RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
          }
        }
        if !store.lists.isEmpty {
          Text("MEINE LISTEN").font(.system(size: 11, weight: .bold)).foregroundStyle(.tertiary).padding(.horizontal, 8)
          ForEach(store.lists) { l in
            let active = store.list == l.name
            Button { store.list = l.name } label: {
              HStack(spacing: 9) {
                Circle().fill(active ? .white : (Color(hex: l.colorHex ?? "") ?? .secondary)).frame(width: 11, height: 11)
                Text(l.name).font(.system(size: 13, weight: active ? .semibold : .medium))
                Spacer(minLength: 0)
                Text("\(l.openCount)").font(.system(size: 12)).foregroundStyle(active ? .white.opacity(0.8) : .tertiary)
              }
              .foregroundStyle(active ? .white : .primary)
              .padding(.horizontal, 10).frame(height: 32)
              .background(active ? CoColor.accent : .clear, in: RoundedRectangle(cornerRadius: 7))
            }
            .buttonStyle(.plain)
          }
        }
      }
      .padding(12)
    }
  }

  private var list: some View {
    let r = store.result
    return VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: 9) {
        Text(headerTitle).font(.system(size: 20, weight: .bold))
        Spacer()
        if store.loading { ProgressView().controlSize(.small) }
      }
      .padding(.horizontal, 26).frame(height: 52)
      Divider()
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 0) {
          if r.open.isEmpty && r.done.isEmpty {
            ContentUnavailableView("Keine Aufgaben", systemImage: "checklist")
              .padding(.top, 40)
          } else {
            ForEach(r.open) { TaskRow(task: $0, showList: store.list == nil); Divider() }
            if !r.done.isEmpty {
              Text("\(r.done.count) erledigt").font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.tertiary).padding(.top, 16).padding(.bottom, 4)
              ForEach(r.done) { TaskRow(task: $0, showList: store.list == nil); Divider() }
            }
          }
        }
        .padding(.horizontal, 26).padding(.bottom, 30).frame(maxWidth: 680, alignment: .leading)
      }
    }
  }

  private var headerTitle: String {
    if let l = store.list { return l }
    return store.smart.title
  }
  private func icon(_ f: TaskSmartFilter) -> String {
    switch f { case .all: return "checklist"; case .today: return "clock"; case .flagged: return "flag" }
  }
  private func smartColor(_ f: TaskSmartFilter) -> Color {
    switch f { case .all: return .secondary; case .today: return Color(red: 1, green: 0.62, blue: 0.04); case .flagged: return Color(red: 1, green: 0.27, blue: 0.23) }
  }
  private func count(_ f: TaskSmartFilter, _ store: AufgabenStore) -> Int {
    TaskDigest.filter(store.all, smart: f, list: nil, now: Date(), calendar: .current).open.count
  }
}
```

- [ ] **Step 4: Shell — `.tasks` rendern**

In `apps/comhub-native/ComHub/Shell/HubShell.swift`:
1. Im `content:`-`switch` **vor** `default:` einfügen:

```swift
      case .tasks:
        AufgabenModuleView()
          #if os(macOS)
          .frame(minWidth: 520)
          #endif
```

2. Im `detail:`-`switch` `.tasks` zu den `Color.clear`-Modulen ergänzen (Liste der Cases vor `Color.clear` um `.tasks` erweitern).

- [ ] **Step 5: Generieren + Build**

Run: `cd apps/comhub-native && xcodegen generate && xcodebuild -scheme ComHub -destination 'platform=macOS,arch=arm64' build`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 6: Manueller Smoke-Test** (echter Mac, Light + Dark; Reminders-Permission gewährt)

- [ ] **Aufgaben**: Rail mit Alle/Heute/Markiert (Counts) + „Meine Listen" (Apple-Erinnerungslisten mit Farbe + offene Anzahl).
- [ ] Liste zeigt **Apple-Erinnerungen + Atoll-Tasks** gemergt; offen oben, „N erledigt" unten (durchgestrichen).
- [ ] Filter wechseln (Heute → nur heute fällige; Markiert → geflaggte; Liste → nur diese Liste).
- [ ] Fälligkeit/Notiz/Listen-Punkt je Zeile korrekt.
- [ ] **Heute-Cockpit** „Aufgaben heute" zeigt jetzt echte Aufgaben (Wirkung von Task 4).
- [ ] Dark Mode lesbar.

- [ ] **Step 7: Commit**

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add apps/comhub-native/ComHub/Tasks/AufgabenStore.swift apps/comhub-native/ComHub/Tasks/TaskRow.swift apps/comhub-native/ComHub/Tasks/AufgabenModuleView.swift apps/comhub-native/ComHub/Shell/HubShell.swift
git commit -m "ComHub: Aufgaben-Modul (Rail + gemergte Liste, lese-only) in die Shell"
```

---

## Task 6: Dokumentation (Phase 4a)

**Files:**
- Modify: `apps/comhub-native/README.md`

- [ ] **Step 1: Phase-4a-Zeile ergänzen**

In `apps/comhub-native/README.md` im Abschnitt `## Phasen-Stand` nach dem `**Design D3** …`-Absatz einfügen:

```markdown

**Phase 4a** — **Aufgaben** (`.tasks`-Modul): Apple Erinnerungen + Atoll-Tasks
(`contact_events` Typ `task`) **gemergt** über die Hub-`TodoProvider`
(`AppleRemindersAdapter` + `AtollTasksAdapter`) — damit leuchtet auch das
Heute-Cockpit-„Aufgaben"-Widget. Filter-Rail (Alle/Heute/Markiert + Apple-Listen),
Liste mit offen/erledigt. Lese-only — Abhaken/Erstellen folgt in Phase 5.
Filter-Logik getestet in `AtollHub` (`TaskDigest`). CardInbox folgt in Phase 4b.
```

- [ ] **Step 2: Commit**

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add apps/comhub-native/README.md
git commit -m "Docs: ComHub-README Phase-4a (Aufgaben gemergt, lese-only)"
```

---

## Self-Review (durchgeführt)

**1. Spec-Abdeckung (Spec §11 Phase 4 „Apple Reminders + Atoll-Tasks gemergt", Slice 4a):**
- gemergte Aufgaben → Tasks 2 (`AppleRemindersAdapter`) + 3 (`AtollTasksAdapter`) + 4 (HubWiring) → `hub.allTasks()`.
- Aufgaben-Modul (Rail + Liste) → Task 1 (`TaskDigest`) + Task 5 (Store/View/Row).
- Cockpit-Wirkung → Task 4 (Provider verdrahtet → `CockpitDigest.openTasks` liefert Daten).
- Bewusst out of scope: Abhaken/Erstellen (Schreiben, Phase 5), Sidebar-Badge, Detail-Pane, CardInbox (4b).

**2. Platzhalter-Scan:** Keine „TBD/TODO". Vollständiger Code je Schritt; Befehl + erwartete Ausgabe je Run.

**3. Typ-Konsistenz:**
- `UnifiedTask` (erweitert, rückwärtskompatibler Init) (Task 1) ↔ Adapter (Tasks 2/3) ↔ `TaskRow`/`TaskDigest` (Tasks 1/5). ✔ — bestehende `CockpitDigest`-Nutzung (`UnifiedTask(id:source:title:due:isDone:)`) bleibt gültig (Defaults).
- `TaskSmartFilter`/`TaskList`/`TaskDigest.filter(_:smart:list:now:calendar:)`/`.lists(_:)` (Task 1) ↔ `AufgabenStore`/`AufgabenModuleView` (Task 5). ✔
- `TodoProvider.tasks()` (Phase 0) ↔ Adapter (Tasks 2/3). `AccountConnection(…todo:…)` + `Hub.allTasks()` (Phase 0) ↔ HubWiring (Task 4) ↔ Store (Task 5). ✔
- Reuse: `Hub`, `AppleAuthorizationService` (Reminders-Permission), `SupabaseClient.shared`, `CoColor.accent`, `Color(hex:)` (in Task 5 definiert). ✔

**4. Verifikations-Disziplin:** Task 1 echte TDD (`swift test`, inkl. Rückwärtskompatibilität der Cockpit-Tests). Tasks 2–5 build-verifiziert (`xcodegen generate` + `xcodebuild`); Task 4 mit Zwischen-Smoke (Cockpit), Task 5 mit vollem manuellem Smoke-Test inkl. Dark Mode + Merge. Konform zu superpowers:verification-before-completion.

---

## Execution Handoff

**Plan komplett und gespeichert unter `docs/superpowers/plans/2026-06-02-comhub-phase4a-aufgaben.md`. Zwei Ausführungs-Optionen:**

**1. Subagent-Driven (empfohlen)** — frischer Subagent pro Task, Review zwischen den Tasks. (REQUIRED SUB-SKILL: superpowers:subagent-driven-development.)

**2. Inline-Ausführung** — Tasks in dieser Session, Batch mit Checkpoints. (REQUIRED SUB-SKILL: superpowers:executing-plans.)

**Welcher Ansatz?**
