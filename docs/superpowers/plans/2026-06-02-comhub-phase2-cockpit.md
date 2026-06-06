# ComHub Phase 2 — Heute-Cockpit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eine **Heute-Cockpit**-Startseite (`.heute`-Modul) in ComHub, die über den `Hub` aggregiert: **Termine heute** (live, Apple+Atoll) und **offene Aufgaben** (über das bestehende `Hub.allTasks()`, leer bis Phase 4 einen TodoProvider verdrahtet), plus saubere Sektionen für **neue Nachrichten** und **neue Leads** (Empty-State bis Phase 3/4). Jede Sektion/Zeile navigiert ins zugehörige Modul.

**Architecture:** Reine, getestete Aggregations-Logik (`CockpitDigest`) wandert nach `AtollHub` (Tages-Filter für Events, Filter/Sort für offene Tasks). Ein `CockpitStore` (`@MainActor @Observable`) im App-Target lädt über den schon vorhandenen `Hub` (`allEvents(in:)` + `allTasks()`) und füllt `CockpitDigest`. Eine `CockpitView` rendert vier Sektionen und meldet Navigationswünsche über eine `onOpenModule: (ComHubModule) -> Void`-Closure an die `HubShell`, die ihren `selectedModule`-`@State` setzt. **Kein** spekulatives Hub-Plumbing für die noch nicht gebauten Phase-3/4-Provider — Nachrichten/Leads sind bewusst Empty-States, deren Phasen später die Hub-Methode **und** die Sektions-Verdrahtung nachziehen.

**Tech Stack:** Swift 6 (strict concurrency complete), SwiftUI Multiplatform (iOS 26 / macOS 26), XcodeGen, XCTest. Baut auf Phase-0/1-APIs: `Hub.allEvents(in:)`/`allTasks()`/`lastErrors`, `UnifiedEvent`/`UnifiedTask`, `ComHubModule`, und der bestehenden `UnifiedEventRow`.

---

## Scope-Grenze (bewusst)

- **Live in Phase 2:** Termine-heute (aus `Hub.allEvents`). Offene Aufgaben sind **verdrahtet** über `Hub.allTasks()`, liefern aber `[]` bis Phase 4 Apple-Reminders/Atoll-Task-TodoProvider in `HubWiring` registriert — dann füllt sich die Sektion **ohne Cockpit-Änderung**.
- **Empty-State in Phase 2:** Neue Nachrichten (Kombox, Phase 3) und neue Leads (CardInbox, Phase 4). Diese Sektionen zeigen einen neutralen „noch keine"-Zustand und navigieren ins (noch Platzhalter-)Modul. Ihre Phasen ergänzen die Hub-Aggregation + ersetzen den Empty-State durch echte Zeilen. **Kein** Vorbau von `CommsProvider`/`CardInboxProvider`-Hub-Methoden hier (Provider-Form ist Phase-3/4-Sache).
- **Tages-Definition:** „heute" = Events, deren **Start** auf den heutigen Kalendertag (Europe/Zurich) fällt. Mehrtägige Apple-Events, die gestern begannen und in heute reichen, erscheinen bewusst **nicht** (Vereinfachung; Verfeinerung später).

---

## File Structure

**Geändertes Paket — `swift-packages/AtollHub/` (reine, getestete Cockpit-Logik):**
- `Sources/AtollHub/Cockpit/CockpitDigest.swift` — `todayEvents(from:now:calendar:)` + `openTasks(from:limit:)`.
- `Tests/AtollHubTests/CockpitDigestTests.swift` — Tests.

**Neue App-Dateien — `apps/comhub-native/ComHub/`:**
- `Cockpit/CockpitStore.swift` — `@Observable` Lade-Zustand: heutige Events + offene Tasks via `Hub`.
- `Cockpit/CockpitView.swift` — vier Sektionen + Navigations-Callback; nutzt `UnifiedEventRow` für Events.

**Geänderte App-Datei:**
- `ComHub/Shell/HubShell.swift` — `.heute` zeigt `CockpitView` (statt Platzhalter), gibt `selectedModule`-Setter als `onOpenModule` rein.

**Doku:**
- `apps/comhub-native/README.md` — Phase-2-Zeile.

---

## Task 1: `CockpitDigest` — reine Aggregations-Helfer (AtollHub)

**Files:**
- Create: `swift-packages/AtollHub/Sources/AtollHub/Cockpit/CockpitDigest.swift`
- Test: `swift-packages/AtollHub/Tests/AtollHubTests/CockpitDigestTests.swift`

- [ ] **Step 1: Failing Test schreiben**

`swift-packages/AtollHub/Tests/AtollHubTests/CockpitDigestTests.swift`:

```swift
import XCTest
@testable import AtollHub

final class CockpitDigestTests: XCTestCase {
  private var cal: Calendar {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "Europe/Zurich")!
    c.firstWeekday = 2
    return c
  }
  private func date(_ s: String) -> Date {
    let f = DateFormatter(); f.calendar = cal; f.timeZone = cal.timeZone
    f.dateFormat = "yyyy-MM-dd HH:mm"; f.locale = Locale(identifier: "en_US_POSIX")
    return f.date(from: s)!
  }
  private func ev(_ id: String, _ start: String, allDay: Bool = false) -> UnifiedEvent {
    UnifiedEvent(id: id, source: AccountRef(accountId: "x", type: .apple),
                 title: id, start: date(start),
                 end: date(start).addingTimeInterval(3600),
                 isAllDay: allDay, location: nil)
  }
  private func task(_ id: String, due: String?, done: Bool) -> UnifiedTask {
    UnifiedTask(id: id, source: AccountRef(accountId: "x", type: .apple),
                title: id, due: due.map(date), isDone: done)
  }

  func test_todayEvents_keepsOnlyTodayAndSortsAllDayFirst() {
    let now = date("2026-06-10 09:00")
    let events = [
      ev("timed", "2026-06-10 14:00"),
      ev("allday", "2026-06-10 00:00", allDay: true),
      ev("yesterday", "2026-06-09 14:00"),
      ev("tomorrow", "2026-06-11 08:00"),
    ]
    let result = CockpitDigest.todayEvents(from: events, now: now, calendar: cal)
    XCTAssertEqual(result.map(\.id), ["allday", "timed"])
  }

  func test_openTasks_dropsDoneSortsByDueNilLastAndCaps() {
    let tasks = [
      task("done", due: "2026-06-10 10:00", done: true),
      task("late", due: "2026-06-12 10:00", done: false),
      task("early", due: "2026-06-10 10:00", done: false),
      task("noDue", due: nil, done: false),
    ]
    let result = CockpitDigest.openTasks(from: tasks, limit: 10)
    XCTAssertEqual(result.map(\.id), ["early", "late", "noDue"])
  }

  func test_openTasks_capsAtLimit() {
    let tasks = (0..<5).map { task("t\($0)", due: "2026-06-1\($0) 10:00", done: false) }
    XCTAssertEqual(CockpitDigest.openTasks(from: tasks, limit: 3).count, 3)
  }
}
```

- [ ] **Step 2: Test ausführen — soll fehlschlagen**

Run: `cd swift-packages/AtollHub && swift test --filter CockpitDigestTests`
Expected: FAIL — `cannot find 'CockpitDigest' in scope`.

- [ ] **Step 3: Implementieren**

`swift-packages/AtollHub/Sources/AtollHub/Cockpit/CockpitDigest.swift`:

```swift
import Foundation

/// Reine Aggregations-Helfer fürs Heute-Cockpit. Keine SwiftUI-/Netzwerk-
/// Abhängigkeit — der `CockpitStore` (App) füttert die Roh-Listen rein.
public enum CockpitDigest {
  /// Events, deren Start auf denselben Kalendertag wie `now` fällt.
  /// Sortiert: all-day zuerst, dann timed nach Startzeit.
  public static func todayEvents(from events: [UnifiedEvent], now: Date,
                                 calendar: Calendar) -> [UnifiedEvent] {
    let today = calendar.startOfDay(for: now)
    return events
      .filter { calendar.startOfDay(for: $0.start) == today }
      .sorted { lhs, rhs in
        if lhs.isAllDay != rhs.isAllDay { return lhs.isAllDay && !rhs.isAllDay }
        return lhs.start < rhs.start
      }
  }

  /// Offene (nicht erledigte) Aufgaben, sortiert nach Fälligkeit
  /// (ohne Fälligkeit zuletzt), begrenzt auf `limit`.
  public static func openTasks(from tasks: [UnifiedTask], limit: Int) -> [UnifiedTask] {
    let open = tasks.filter { !$0.isDone }
    let sorted = open.sorted { lhs, rhs in
      switch (lhs.due, rhs.due) {
      case let (l?, r?): return l < r
      case (nil, _?):    return false   // nil-due nach hinten
      case (_?, nil):    return true
      case (nil, nil):   return lhs.title < rhs.title
      }
    }
    return Array(sorted.prefix(limit))
  }
}
```

- [ ] **Step 4: Test ausführen — soll grün sein**

Run: `cd swift-packages/AtollHub && swift test --filter CockpitDigestTests`
Expected: PASS — 3 Tests grün.

- [ ] **Step 5: Volle Paket-Suite + Commit**

Run: `cd swift-packages/AtollHub && swift test`
Expected: PASS — alle Suiten grün (Phase-0/1 + CockpitDigest).

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add swift-packages/AtollHub/Sources/AtollHub/Cockpit/CockpitDigest.swift swift-packages/AtollHub/Tests/AtollHubTests/CockpitDigestTests.swift
git commit -m "AtollHub: CockpitDigest (Termine-heute + offene Tasks, rein/getestet)"
```

---

## Task 2: `CockpitStore` — Lade-Zustand fürs Cockpit (ComHub)

**Files:**
- Create: `apps/comhub-native/ComHub/Cockpit/CockpitStore.swift`

- [ ] **Step 1: Store schreiben**

`apps/comhub-native/ComHub/Cockpit/CockpitStore.swift`:

```swift
import Foundation
import Observation
import AtollHub

/// Aggregiert die Heute-Cockpit-Daten über den `Hub`: heutige Termine (live)
/// und offene Aufgaben (über `Hub.allTasks()`, leer bis Phase 4 einen
/// TodoProvider verdrahtet). Nachrichten/Leads kommen in Phase 3/4 dazu.
@MainActor
@Observable
final class CockpitStore {
  private(set) var todayEvents: [UnifiedEvent] = []
  private(set) var openTasks: [UnifiedTask] = []
  private(set) var loading = false
  private(set) var errors: [String] = []

  /// Zürich-Kalender, konsistent mit den übrigen ComHub-Datumshelfern.
  private var calendar: Calendar {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "Europe/Zurich") ?? .current
    c.firstWeekday = 2
    return c
  }

  func reload(using hub: Hub) async {
    loading = true
    let now = Date()
    let start = calendar.startOfDay(for: now)
    let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
    let interval = DateInterval(start: start, end: end)

    let events = await hub.allEvents(in: interval)
    let tasks = await hub.allTasks()

    todayEvents = CockpitDigest.todayEvents(from: events, now: now, calendar: calendar)
    openTasks = CockpitDigest.openTasks(from: tasks, limit: 8)
    errors = hub.lastErrors
    loading = false
  }
}
```

- [ ] **Step 2: Build verifizieren**

Run: `cd apps/comhub-native && xcodegen generate && xcodebuild -scheme ComHub -destination 'platform=macOS,arch=arm64' build`
Expected: `** BUILD SUCCEEDED **`. Proves `Hub.allEvents(in:)`/`allTasks()`/`lastErrors` + `CockpitDigest`-Signaturen. (Note: `hub.lastErrors` wird von `allTasks()` ggf. überschrieben, da beide Hub-Methoden `lastErrors` zurücksetzen — für Phase 2 akzeptabel; `errors` spiegelt den letzten Aufruf.)

- [ ] **Step 3: Commit**

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add apps/comhub-native/ComHub/Cockpit/CockpitStore.swift
git commit -m "ComHub: CockpitStore (heutige Termine + offene Tasks via Hub)"
```

---

## Task 3: `CockpitView` — vier Sektionen + Navigation (ComHub)

**Files:**
- Create: `apps/comhub-native/ComHub/Cockpit/CockpitView.swift`

- [ ] **Step 1: View schreiben**

`apps/comhub-native/ComHub/Cockpit/CockpitView.swift`:

```swift
import SwiftUI
import AtollHub

/// Heute-Cockpit: aggregierte Startseite. Sektionen verlinken ins jeweilige
/// Modul über `onOpenModule` (die Shell setzt damit ihren `selectedModule`).
struct CockpitView: View {
  @Environment(Hub.self) private var hub
  @State private var store = CockpitStore()

  /// Navigationswunsch an die Shell (Tippen auf Sektion/Zeile).
  let onOpenModule: (ComHubModule) -> Void

  private static let dateHeader: DateFormatter = {
    let f = DateFormatter(); f.dateFormat = "EEEE, d. MMMM"
    f.locale = Locale(identifier: "de_CH")
    f.timeZone = TimeZone(identifier: "Europe/Zurich"); return f
  }()

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        HStack {
          Text("Heute").font(.largeTitle.weight(.bold))
          Spacer()
          if store.loading { ProgressView().controlSize(.small) }
        }
        Text(Self.dateHeader.string(from: Date()))
          .font(.headline).foregroundStyle(.secondary)

        // Termine heute (live).
        CockpitSection(title: "Termine", systemImage: "calendar",
                       isEmpty: store.todayEvents.isEmpty,
                       emptyText: "Keine Termine heute",
                       onOpen: { onOpenModule(.kalender) }) {
          ForEach(store.todayEvents) { UnifiedEventRow(event: $0) }
        }

        // Offene Aufgaben (via Hub.allTasks; leer bis Phase 4).
        CockpitSection(title: "Aufgaben", systemImage: "checklist",
                       isEmpty: store.openTasks.isEmpty,
                       emptyText: "Keine offenen Aufgaben",
                       onOpen: { onOpenModule(.tasks) }) {
          ForEach(store.openTasks) { TaskRow(task: $0) }
        }

        // Neue Nachrichten (Kombox, Phase 3 — vorerst Empty-State).
        CockpitSection(title: "Neue Nachrichten", systemImage: "bubble.left.and.bubble.right",
                       isEmpty: true,
                       emptyText: "Noch keine neuen Nachrichten",
                       onOpen: { onOpenModule(.kombox) }) { EmptyView() }

        // Neue Leads (CardInbox, Phase 4 — vorerst Empty-State).
        CockpitSection(title: "Neue Leads", systemImage: "tray.and.arrow.down",
                       isEmpty: true,
                       emptyText: "Noch keine neuen Leads",
                       onOpen: { onOpenModule(.cardInbox) }) { EmptyView() }
      }
      .padding(20)
      .frame(maxWidth: 700, alignment: .leading)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .task { await store.reload(using: hub) }
  }
}

/// Eine Cockpit-Sektion: tippbarer Kopf (→ Modul) + Inhalt oder Empty-State.
private struct CockpitSection<Content: View>: View {
  let title: String
  let systemImage: String
  let isEmpty: Bool
  let emptyText: String
  let onOpen: () -> Void
  @ViewBuilder let content: () -> Content

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Button(action: onOpen) {
        HStack(spacing: 6) {
          Image(systemName: systemImage)
          Text(title).font(.title3.weight(.semibold))
          Spacer()
          Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
        }
      }
      .buttonStyle(.plain)

      if isEmpty {
        Text(emptyText).font(.callout).foregroundStyle(.secondary)
          .padding(.vertical, 4)
      } else {
        VStack(alignment: .leading, spacing: 2) { content() }
      }
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
  }
}

/// Eine Aufgaben-Zeile fürs Cockpit (Titel + optionale Fälligkeit + Quell-Badge).
private struct TaskRow: View {
  let task: UnifiedTask

  private static let dueFormatter: DateFormatter = {
    let f = DateFormatter(); f.dateFormat = "dd.MM. HH:mm"
    f.locale = Locale(identifier: "de_CH")
    f.timeZone = TimeZone(identifier: "Europe/Zurich"); return f
  }()

  var body: some View {
    HStack(spacing: 8) {
      Image(systemName: "circle").font(.caption).foregroundStyle(.secondary)
      Text(task.title).font(.callout).lineLimit(1)
      Spacer(minLength: 0)
      if let due = task.due {
        Text(Self.dueFormatter.string(from: due))
          .font(.caption).foregroundStyle(.secondary)
      }
      Text(task.source.type == .atoll ? "Atoll" : "Apple")
        .font(.caption2).foregroundStyle(.secondary)
        .padding(.horizontal, 5).padding(.vertical, 1)
        .background(.quaternary, in: Capsule())
    }
    .padding(.vertical, 2)
  }
}
```

- [ ] **Step 2: Build verifizieren**

Run: `cd apps/comhub-native && xcodegen generate && xcodebuild -scheme ComHub -destination 'platform=macOS,arch=arm64' build`
Expected: `** BUILD SUCCEEDED **`. Proves `UnifiedEventRow` (aus Phase 1) ist im Target sichtbar und `ComHubModule`-Cases (`.kalender/.tasks/.kombox/.cardInbox`) existieren.

- [ ] **Step 3: Commit**

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add apps/comhub-native/ComHub/Cockpit/CockpitView.swift
git commit -m "ComHub: CockpitView (vier Sektionen, Navigation in die Module)"
```

---

## Task 4: `.heute` in die Shell hängen (ComHub)

**Files:**
- Modify: `apps/comhub-native/ComHub/Shell/HubShell.swift`

- [ ] **Step 1: `content`-Closure um den `.heute`-Fall erweitern**

In `apps/comhub-native/ComHub/Shell/HubShell.swift` im `NavigationSplitView`-`content:`-Closure **vor** dem `case .kalender:`-Zweig den `.heute`-Fall einfügen, sodass der Anfang des `switch selectedModule {` so aussieht:

```swift
      switch selectedModule {
      case .heute:
        CockpitView(onOpenModule: { selectedModule = $0 })
          #if os(macOS)
          .frame(minWidth: 360)
          #endif
      case .kalender:
        CalendarModuleView()
          #if os(macOS)
          .frame(minWidth: 480)
          #endif
```

(Die übrigen `case`-Zweige `.kontakte` und `default` sowie der `detail:`-Block bleiben unverändert.)

- [ ] **Step 2: `detail`-Closure: `.heute` ohne eigenes Detail**

Im selben File im `detail:`-Closure den `.heute`-Fall zu den Modulen mit leerer Detailspalte hinzufügen. Den `case`-Ausdruck ändern von:

```swift
      switch selectedModule {
      case .kalender, .kontakte:
        // Kalender/Kontakte rendern ihr Detail intern (NavigationSplitView-
        // Detailspalte bleibt fuer diese Module leer/kontextuell).
        Color.clear
      default:
        ModulePlaceholder(module: selectedModule, pane: "Detail")
      }
```

zu:

```swift
      switch selectedModule {
      case .heute, .kalender, .kontakte:
        // Diese Module rendern ihr Detail intern (NavigationSplitView-
        // Detailspalte bleibt fuer sie leer/kontextuell).
        Color.clear
      default:
        ModulePlaceholder(module: selectedModule, pane: "Detail")
      }
```

- [ ] **Step 3: Build verifizieren**

Run: `cd apps/comhub-native && xcodegen generate && xcodebuild -scheme ComHub -destination 'platform=macOS,arch=arm64' build`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Manueller Smoke-Test** (echter Mac)

- [ ] App starten → angemeldet → Startmodul **Heute** zeigt das Cockpit.
- [ ] „Termine"-Sektion listet die heutigen Apple+Atoll-Termine (Quell-Badge); ist heute nichts, steht „Keine Termine heute".
- [ ] „Aufgaben" zeigt „Keine offenen Aufgaben" (kein TodoProvider bis Phase 4) — kein Absturz.
- [ ] „Neue Nachrichten" / „Neue Leads" zeigen ihren neutralen Empty-State.
- [ ] Tippen auf einen Sektions-Kopf wechselt in das Modul (Termine→Kalender, Aufgaben→Aufgaben-Platzhalter, Nachrichten→Kombox-Platzhalter, Leads→CardInbox-Platzhalter).

- [ ] **Step 5: Commit**

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add apps/comhub-native/ComHub/Shell/HubShell.swift
git commit -m "ComHub: Heute-Cockpit in die Shell (Startmodul, Navigation in Module)"
```

---

## Task 5: Dokumentation (Phase 2)

**Files:**
- Modify: `apps/comhub-native/README.md`

- [ ] **Step 1: Phase-2-Eintrag ergänzen**

In `apps/comhub-native/README.md` im Abschnitt `## Phasen-Stand` **nach** dem `**Phase 1** …`-Absatz einfügen:

```markdown

**Phase 2** — **Heute-Cockpit** (`.heute`-Startmodul): aggregiert **Termine heute**
(live, Apple+Atoll über den Hub) und **offene Aufgaben** (verdrahtet über
`Hub.allTasks()`, leer bis ein TodoProvider in Phase 4 dazukommt). Sektionen
**Neue Nachrichten** und **Neue Leads** sind Empty-States, die Phase 3/4 befüllen.
Jede Sektion navigiert ins zugehörige Modul. Reine Aggregations-Logik getestet in
`AtollHub` (`CockpitDigest`).
```

- [ ] **Step 2: Commit**

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add apps/comhub-native/README.md
git commit -m "Docs: ComHub-README Phase-2-Stand (Heute-Cockpit)"
```

---

## Self-Review (durchgeführt)

**1. Spec-Abdeckung (Phase 2 laut Spec §4.1 + §11 + Roadmap):**
- „Heute-Cockpit als Startseite" → Task 4 (`.heute` = Startmodul, `selectedModule` initial `.heute` aus Phase 0).
- „Aggregiert Termine heute" → Task 1 (`CockpitDigest.todayEvents`) + Task 2 (`CockpitStore` via `Hub.allEvents`) + Task 3 (Termine-Sektion). **Live.**
- „offene Tasks" → `Hub.allTasks()` (Phase-0-API) + `CockpitDigest.openTasks` + Aufgaben-Sektion. **Verdrahtet, füllt sich in Phase 4.**
- „neue Nachrichten / neue Leads" → Empty-State-Sektionen (Task 3); bewusst ohne Hub-Vorbau (Scope-Grenze dokumentiert) — Phase 3/4 ziehen Aggregation + Sektion nach.
- „jede Zeile/Sektion verlinkt ins Modul" → `onOpenModule`-Closure (Task 3) + Shell-Verdrahtung (Task 4).
- „Quell-Badges (Atoll/Apple)" → `UnifiedEventRow` (Phase-1-Reuse) für Events; `TaskRow` mit Quell-Badge für Aufgaben.

**2. Platzhalter-Scan:** Keine „TBD/TODO"-Schritte. Jeder Code-Schritt zeigt vollständigen Code; jeder Run-Schritt nennt Befehl + erwartete Ausgabe. Die Empty-State-Sektionen (Nachrichten/Leads) sind **bewusste, vollständig implementierte UI**, kein Plan-Loch — die Scope-Grenze oben erklärt warum.

**3. Typ-Konsistenz:**
- `CockpitDigest.todayEvents(from:now:calendar:)` + `openTasks(from:limit:)` (Task 1) ↔ Aufrufe in `CockpitStore` (Task 2). ✔
- `CockpitStore` Properties `todayEvents`/`openTasks`/`loading` (Task 2) ↔ `CockpitView` (Task 3). ✔
- `CockpitView(onOpenModule:)` (Task 3) ↔ Shell-Aufruf `CockpitView(onOpenModule: { selectedModule = $0 })` (Task 4). ✔
- Phase-0/1-APIs unverändert: `Hub.allEvents(in:)`/`allTasks()`/`lastErrors`, `UnifiedEvent`/`UnifiedTask(id:source:title:due:isDone:)`, `ComHubModule` (`.heute/.kalender/.kombox/.tasks/.cardInbox`), `UnifiedEventRow(event:)`. ✔ (alle gegen den echten Code geprüft).

**4. Verifikations-Disziplin:** Task 1 ist echte TDD (`swift test`). Tasks 2–4 build-verifiziert (`xcodegen generate` + `xcodebuild`); Task 4 schließt mit manuellem Smoke-Test. Konform zu superpowers:verification-before-completion.

---

## Execution Handoff

**Plan komplett und gespeichert unter `docs/superpowers/plans/2026-06-02-comhub-phase2-cockpit.md`. Zwei Ausführungs-Optionen:**

**1. Subagent-Driven (empfohlen)** — frischer Subagent pro Task, Review zwischen den Tasks. (REQUIRED SUB-SKILL: superpowers:subagent-driven-development.)

**2. Inline-Ausführung** — Tasks in dieser Session, Batch mit Checkpoints. (REQUIRED SUB-SKILL: superpowers:executing-plans.)

**Welcher Ansatz?**
