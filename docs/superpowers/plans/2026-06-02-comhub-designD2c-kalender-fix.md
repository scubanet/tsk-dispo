# ComHub Design D2c — Kalender Feinschliff (Layout + Farben + Kalender-Filter) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Den Kalender kompakt + korrekt machen: (1) Layout-Bug fixen (riesige Leerräume in Tag/Woche), (2) **echte Kalender-Farben** je Quelle (Apple-EKCalendar-Farbe, Atoll-Akzent) statt grauer Blöcke, (3) ein **Kalender-Filter** (einzelne Kalender ein/ausschalten, persistent) — der zugleich die Doppel-Events beseitigt (abonnierten iCloud-Kalender deaktivieren).

**Architecture:** `UnifiedEvent` (AtollHub) wird additiv um `calendarId` + `colorHex` erweitert; `AppleEventMapper`/`AtollEventMapper` setzen sie (Apple = EKCalendar-Identifier + Farbe; Atoll = "atoll" + Akzent). `AppleCalendarAdapter` reicht Kalender-Id/Farbe durch. Eine `CalendarSourcesStore` (App, `@Observable`, `@AppStorage`-persistiert) listet die verfügbaren Kalender (EKCalendars + Atoll) und hält die aktiven; reine `CalendarFilter.apply` (AtollHub, TDD) filtert Events. `CalendarStore` filtert vor `eventsByDay`. Die Views (`EventBlockView`, Ganztags-Lane, Monats-Dots) nutzen `colorHex`. Der Header-Layout-Bug wird in `DayGridView` behoben. Ein Toolbar-Popover im Kalender-Header schaltet Kalender.

**Tech Stack:** Swift 6 (strict concurrency complete), SwiftUI Multiplatform (iOS 26 / macOS 26), EventKit, XcodeGen, XCTest. Reuse: `UnifiedEvent`/`AppleEventMapper`/`AtollEventMapper`/`CalendarLayout`/`DayGridView`/`MonthGridView`/`CalendarStore`/`CoColor`/`Color(hex:)` (aus 4a).

---

## Scope-Grenzen (bewusst)

- **Lesen + Anzeige + Filter.** Kein Schreiben (Termin erstellen = Phase 5).
- **Kalender-Filter** = ein/aus je Quelle (Apple-EKCalendar einzeln + „Atoll" als eine Quelle). Persistiert via `@AppStorage`. Default: alle an.
- **Farben:** Apple = EKCalendar-Farbe; Atoll = ein Akzentton (kein per-Kurs-Farbschema — später).
- **Doppel-Events** werden über den Filter gelöst (redundante iCloud-Quelle aus). Ein zusätzliches Title+Zeit-Dedup ist **optional** (Task 5, klein) als Sicherheitsnetz.

---

## File Structure

**Geändertes Paket — `swift-packages/AtollHub/`:**
- `Sources/AtollHub/Model/UnifiedModels.swift` — `UnifiedEvent` additiv (+`calendarId`,+`colorHex`).
- `Sources/AtollHub/Mapping/AppleMappers.swift` — `AppleEventMapper.event(...)` um `calendarId`/`colorHex` erweitern (Defaults).
- `Sources/AtollHub/Mapping/AtollEventMapper.swift` — `calendarId`/`colorHex` setzen.
- `Sources/AtollHub/Calendar/CalendarFilter.swift` — `CalendarFilter.apply(_:enabledIds:)`.
- `Tests/AtollHubTests/CalendarFilterTests.swift` (+ ggf. Mapper-Tests anpassen).

**Neue App-Datei:**
- `apps/comhub-native/ComHub/Calendar/CalendarSourcesStore.swift` — verfügbare Kalender + aktive (persistent).
- `apps/comhub-native/ComHub/Calendar/CalendarFilterPopover.swift` — Toggle-UI.

**Geänderte App-Dateien:**
- `ComHub/Adapters/AppleCalendarAdapter.swift` — Kalender-Id/Farbe durchreichen.
- `ComHub/Calendar/CalendarStore.swift` — Filter nach aktiven Quellen.
- `ComHub/Calendar/EventBlockView.swift` — Farbe aus `colorHex`.
- `ComHub/Calendar/DayGridView.swift` — Header-Höhe fixieren (Layout-Fix) + Farben in Ganztags-Lane.
- `ComHub/Calendar/MonthGridView.swift` — farbige Dots.
- `ComHub/Calendar/CalendarModuleView.swift` — Filter-Button + Store-Verdrahtung.

**Doku:**
- `apps/comhub-native/README.md` — D2c-Zeile.

---

## Task 1: `UnifiedEvent` Farbe/Id + Mapper + `CalendarFilter` (AtollHub, TDD)

**Files:**
- Modify: `swift-packages/AtollHub/Sources/AtollHub/Model/UnifiedModels.swift`
- Modify: `swift-packages/AtollHub/Sources/AtollHub/Mapping/AppleMappers.swift`
- Modify: `swift-packages/AtollHub/Sources/AtollHub/Mapping/AtollEventMapper.swift`
- Create: `swift-packages/AtollHub/Sources/AtollHub/Calendar/CalendarFilter.swift`
- Test: `swift-packages/AtollHub/Tests/AtollHubTests/CalendarFilterTests.swift`

- [ ] **Step 1: `UnifiedEvent` additiv erweitern**

In `UnifiedModels.swift` die `UnifiedEvent`-Struktur ersetzen (neue Felder mit Defaults — `withTimes`/`init` bleiben gültig; falls eine `withTimes`-Helper-Extension existiert, deren Konstruktion um die neuen Felder ergänzen):

```swift
/// Quellneutraler Kalendertermin (Apple, Atoll, später Google/MS).
public struct UnifiedEvent: Sendable, Identifiable, Equatable, Hashable {
  public let id: String
  public let source: AccountRef
  public let title: String
  public let start: Date
  public let end: Date
  public let isAllDay: Bool
  public let location: String?
  public let calendarId: String?   // EKCalendar.identifier bzw. "atoll"
  public let colorHex: String?     // Kalender-Farbe

  public init(id: String, source: AccountRef, title: String, start: Date,
              end: Date, isAllDay: Bool, location: String?,
              calendarId: String? = nil, colorHex: String? = nil) {
    self.id = id; self.source = source; self.title = title
    self.start = start; self.end = end; self.isAllDay = isAllDay
    self.location = location; self.calendarId = calendarId; self.colorHex = colorHex
  }
}
```

> **WICHTIG:** Falls es eine `extension UnifiedEvent { func withTimes(start:end:) }` gibt (aus dem Multi-Day-Clip), MUSS sie `calendarId`/`colorHex` mitkopieren — sonst gehen Farben beim Clippen verloren. Den `UnifiedEvent(...)`-Aufruf in `withTimes` um `calendarId: calendarId, colorHex: colorHex` ergänzen. Datei suchen: `grep -rn "func withTimes" swift-packages/AtollHub`.

- [ ] **Step 2: `AppleEventMapper.event` erweitern** (additiv)

In `AppleMappers.swift` die Signatur + Konstruktion erweitern:

```swift
  public static func event(accountId: String, identifier: String, title: String,
                           start: Date, end: Date, isAllDay: Bool, location: String?,
                           calendarId: String? = nil, colorHex: String? = nil) -> UnifiedEvent {
    let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
    let loc = location?.trimmingCharacters(in: .whitespacesAndNewlines)
    return UnifiedEvent(
      id: "apple:\(identifier)",
      source: AccountRef(accountId: accountId, type: .apple),
      title: cleanTitle.isEmpty ? "(Ohne Titel)" : cleanTitle,
      start: start, end: end, isAllDay: isAllDay,
      location: (loc?.isEmpty ?? true) ? nil : loc,
      calendarId: calendarId, colorHex: colorHex
    )
  }
```

(Bestehende `AppleEventMapperTests` bleiben grün — die neuen Parameter haben Defaults.)

- [ ] **Step 3: `AtollEventMapper` — `calendarId`/`colorHex` setzen**

In `AtollEventMapper.swift` bei JEDEM `UnifiedEvent(...)`-Aufruf (timed + all-day) ergänzen: `calendarId: "atoll", colorHex: "#0A84FF"` (Atoll-Akzent). (Die bestehenden `AtollEventMapperTests` prüfen Titel/Location/isAllDay — bleiben grün.)

- [ ] **Step 4: Failing Test für `CalendarFilter`**

`swift-packages/AtollHub/Tests/AtollHubTests/CalendarFilterTests.swift`:

```swift
import XCTest
@testable import AtollHub

final class CalendarFilterTests: XCTestCase {
  private func ev(_ id: String, cal: String?) -> UnifiedEvent {
    UnifiedEvent(id: id, source: AccountRef(accountId: "x", type: .apple), title: id,
                 start: Date(timeIntervalSince1970: 0), end: Date(timeIntervalSince1970: 1),
                 isAllDay: false, location: nil, calendarId: cal)
  }

  func test_keepsOnlyEnabledCalendars() {
    let events = [ev("a", cal: "c1"), ev("b", cal: "c2"), ev("c", cal: "atoll")]
    let r = CalendarFilter.apply(events, enabledIds: ["c1", "atoll"])
    XCTAssertEqual(r.map(\.id), ["a", "c"])
  }

  func test_nilEnabledKeepsEverything() {
    let events = [ev("a", cal: "c1"), ev("b", cal: nil)]
    XCTAssertEqual(CalendarFilter.apply(events, enabledIds: nil).count, 2)
  }

  func test_eventWithoutCalendarIdAlwaysKept() {
    let events = [ev("a", cal: nil), ev("b", cal: "c2")]
    XCTAssertEqual(CalendarFilter.apply(events, enabledIds: ["c1"]).map(\.id), ["a"])
  }
}
```

- [ ] **Step 5: Test ausführen — soll fehlschlagen**

Run: `cd swift-packages/AtollHub && swift test --filter CalendarFilterTests`
Expected: FAIL — `cannot find 'CalendarFilter' in scope`.

- [ ] **Step 6: `CalendarFilter` implementieren**

`swift-packages/AtollHub/Sources/AtollHub/Calendar/CalendarFilter.swift`:

```swift
import Foundation

/// Filtert Events nach aktiven Kalender-Ids. `enabledIds == nil` → kein Filter.
/// Events ohne `calendarId` werden immer behalten (keine Quelle zum Ausschalten).
public enum CalendarFilter {
  public static func apply(_ events: [UnifiedEvent], enabledIds: Set<String>?) -> [UnifiedEvent] {
    guard let enabledIds else { return events }
    return events.filter { ev in
      guard let id = ev.calendarId else { return true }
      return enabledIds.contains(id)
    }
  }
}
```

- [ ] **Step 7: Test grün + volle Suite + Commit**

Run: `cd swift-packages/AtollHub && swift test`
Expected: PASS — alle Suiten grün (inkl. AppleEventMapper/AtollEventMapper/CalendarLayout — Rückwärtskompatibilität durch Defaults).

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add swift-packages/AtollHub/Sources/AtollHub swift-packages/AtollHub/Tests/AtollHubTests/CalendarFilterTests.swift
git commit -m "AtollHub: UnifiedEvent calendarId/colorHex + Mapper + CalendarFilter (rein/getestet)"
```

---

## Task 2: `AppleCalendarAdapter` — Kalender-Id + Farbe durchreichen (ComHub)

**Files:**
- Modify: `apps/comhub-native/ComHub/Adapters/AppleCalendarAdapter.swift`

- [ ] **Step 1: Mapping um Kalender-Id/Farbe ergänzen**

In `AppleCalendarAdapter.swift` die `events`-Map ersetzen:

```swift
    return ekEvents.map { e in
      AppleEventMapper.event(
        accountId: accountId,
        identifier: e.eventIdentifier ?? "ts-\(e.startDate.timeIntervalSince1970)",
        title: e.title ?? "",
        start: e.startDate, end: e.endDate,
        isAllDay: e.isAllDay, location: e.location,
        calendarId: e.calendar?.calendarIdentifier,
        colorHex: e.calendar?.cgColor.flatMap(Self.hex(from:))
      )
    }
  }

  private static func hex(from cg: CGColor) -> String? {
    guard let c = cg.components, c.count >= 3 else { return nil }
    let r = Int((c[0] * 255).rounded()), g = Int((c[1] * 255).rounded()), b = Int((c[2] * 255).rounded())
    return String(format: "#%02X%02X%02X", r, g, b)
  }
```

(Die `hex(from:)`-Helper analog zum `AppleRemindersAdapter`.)

- [ ] **Step 2: Build verifizieren**

Run: `cd apps/comhub-native && xcodegen generate && xcodebuild -scheme ComHub -destination 'platform=macOS,arch=arm64' build`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add apps/comhub-native/ComHub/Adapters/AppleCalendarAdapter.swift
git commit -m "ComHub: AppleCalendarAdapter reicht Kalender-Id + Farbe durch"
```

---

## Task 3: `CalendarSourcesStore` — Kalenderliste + aktive (persistent) (ComHub)

**Files:**
- Create: `apps/comhub-native/ComHub/Calendar/CalendarSourcesStore.swift`

- [ ] **Step 1: Store schreiben**

`apps/comhub-native/ComHub/Calendar/CalendarSourcesStore.swift`:

```swift
import Foundation
import Observation
@preconcurrency import EventKit
import SwiftUI

/// Eine wählbare Kalender-Quelle (Apple-EKCalendar oder Atoll).
struct CalendarSource: Identifiable, Equatable {
  let id: String          // EKCalendar.identifier bzw. "atoll"
  let title: String
  let colorHex: String?
}

/// Verfuegbare Kalender (Apple-EKCalendars + Atoll) + die aktiven (persistent).
/// `enabledIds == nil` heisst „alle" (Default). Sobald der User toggelt, wird
/// eine konkrete Menge gespeichert.
@MainActor
@Observable
final class CalendarSourcesStore {
  private(set) var sources: [CalendarSource] = []
  /// Aktive Kalender-Ids; `nil` = alle aktiv.
  private(set) var enabledIds: Set<String>?

  private let store: EKEventStore
  private let defaultsKey = "comhub.calendar.disabledIds"

  init(store: EKEventStore) {
    self.store = store
    refresh()
  }

  /// Liest die Apple-Kalender + fügt Atoll hinzu; lädt deaktivierte Ids aus den Defaults.
  func refresh() {
    var out: [CalendarSource] = []
    if EKEventStore.authorizationStatus(for: .event) == .fullAccess {
      for cal in store.calendars(for: .event) {
        out.append(CalendarSource(id: cal.calendarIdentifier, title: cal.title,
                                  colorHex: cal.cgColor.flatMap(Self.hex(from:))))
      }
    }
    out.append(CalendarSource(id: "atoll", title: "Atoll", colorHex: "#0A84FF"))
    sources = out.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }

    let disabled = Set((UserDefaults.standard.array(forKey: defaultsKey) as? [String]) ?? [])
    enabledIds = disabled.isEmpty ? nil : Set(sources.map(\.id)).subtracting(disabled)
  }

  func isEnabled(_ id: String) -> Bool { enabledIds?.contains(id) ?? true }

  func toggle(_ id: String) {
    var enabled = enabledIds ?? Set(sources.map(\.id))
    if enabled.contains(id) { enabled.remove(id) } else { enabled.insert(id) }
    enabledIds = enabled
    let disabled = Set(sources.map(\.id)).subtracting(enabled)
    UserDefaults.standard.set(Array(disabled), forKey: defaultsKey)
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
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add apps/comhub-native/ComHub/Calendar/CalendarSourcesStore.swift
git commit -m "ComHub: CalendarSourcesStore (Kalenderliste + aktive, persistent)"
```

---

## Task 4: `CalendarStore` filtert nach aktiven Quellen (ComHub)

**Files:**
- Modify: `apps/comhub-native/ComHub/Calendar/CalendarStore.swift`

- [ ] **Step 1: Filter einbauen**

In `CalendarStore.swift`:
1. `import AtollHub` ist da. Property ergänzen:

```swift
  /// Aktive Kalender-Ids (vom CalendarSourcesStore gesetzt). nil = alle.
  var enabledCalendarIds: Set<String>?
```

2. In `reload(using:)` nach `let merged = await hub.allEvents(in: window)` filtern:

```swift
    let filtered = CalendarFilter.apply(merged, enabledIds: enabledCalendarIds)
    events = filtered
    eventsByDay = CalendarLayout.eventsByDay(filtered, calendar: calendar)
```

(statt `merged` direkt zu verwenden.)

- [ ] **Step 2: Build verifizieren**

Run: `cd apps/comhub-native && xcodegen generate && xcodebuild -scheme ComHub -destination 'platform=macOS,arch=arm64' build`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add apps/comhub-native/ComHub/Calendar/CalendarStore.swift
git commit -m "ComHub: CalendarStore filtert Events nach aktiven Kalendern"
```

---

## Task 5: Layout-Fix + Farben (DayGridView, EventBlockView, MonthGridView) (ComHub)

**Files:**
- Modify: `apps/comhub-native/ComHub/Calendar/EventBlockView.swift`
- Modify: `apps/comhub-native/ComHub/Calendar/DayGridView.swift`
- Modify: `apps/comhub-native/ComHub/Calendar/MonthGridView.swift`

- [ ] **Step 1: `EventBlockView` — Farbe aus `colorHex`**

In `EventBlockView.swift` die `tint`-Berechnung ersetzen:

```swift
  private var tint: Color {
    if let hex = event.colorHex, let c = Color(hex: hex) { return c }
    return event.source.type == .atoll ? CoColor.accent : .secondary
  }
```

(`Color(hex:)` ist aus Phase 4a `TaskRow.swift` global verfügbar.)

- [ ] **Step 2: `DayGridView` — Header-Höhe fixieren (LAYOUT-BUG) + Lane-Farben**

In `DayGridView.swift`:

a) Den `headerRow`-`Color.clear` **vertikal entgreifen** — die Zeile

```swift
      Color.clear.frame(width: 54)
```
ersetzen durch:
```swift
      Spacer().frame(width: 54)
```
und den gesamten `headerRow`-`HStack` mit fixer Höhe versehen — am Ende des `HStack { … }` (vor dem schliessenden `}` von `headerRow`) ergänzen:
```swift
    }
    .fixedSize(horizontal: false, vertical: true)
  }
```
(d. h. `headerRow` bekommt `.fixedSize(horizontal: false, vertical: true)`, damit die Zeile nur ihre Inhalts-Höhe nimmt und nicht mit der ScrollView um Platz konkurriert.)

b) Ganztags-Lane farbig: in `allDayLane` den Bar-Hintergrund

```swift
                .background(ev.source.type == .atoll ? CoColor.accent : Color.secondary,
                            in: RoundedRectangle(cornerRadius: 5))
```
ersetzen durch:
```swift
                .background((ev.colorHex.flatMap(Color.init(hex:)) ?? (ev.source.type == .atoll ? CoColor.accent : .secondary)),
                            in: RoundedRectangle(cornerRadius: 5))
```

c) Auch die Ganztags-Lane vertikal entgreifen — den `allDayLane`-`HStack`'s `Text("ganztägig").frame(width: 54, alignment: .trailing)` ist ok (Text ist nicht gierig); falls die Lane dennoch zu hoch wirkt, am `if`-Block-`HStack` ebenfalls `.fixedSize(horizontal: false, vertical: true)` ergänzen.

- [ ] **Step 3: `MonthGridView` — farbige Dots**

In `MonthGridView.swift` die Dot-Berechnung von Quelle-Typ auf Kalender-Farbe umstellen. Die Zeile, die `dotColors`/die Dots rendert, so ändern, dass pro Tag bis zu 4 **distinkte Kalender-Farben** gezeigt werden:

```swift
    let events = store.eventsByDay[dayStart] ?? []
    let dotColors: [Color] = Array(
      events.compactMap { $0.colorHex.flatMap(Color.init(hex:)) ?? ($0.source.type == .atoll ? CoColor.accent : Color.secondary) }
        .reduce(into: [Color]()) { acc, c in if !acc.contains(c) { acc.append(c) } }
        .prefix(4)
    )
```
und die Dot-`ForEach` auf `dotColors` (Farben statt Typen) umstellen:
```swift
      HStack(spacing: 3) {
        ForEach(Array(dotColors.enumerated()), id: \.offset) { _, c in
          Circle().fill(c).frame(width: 6, height: 6)
        }
      }
```
(`Color` ist nicht `Hashable` für `id`, daher `enumerated().offset` als id.)

- [ ] **Step 4: Generieren + Build**

Run: `cd apps/comhub-native && xcodegen generate && xcodebuild -scheme ComHub -destination 'platform=macOS,arch=arm64' build`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Zwischen-Smoke (empfohlen)** — **Tag/Woche**: keine Riesen-Lücken mehr (Header kompakt, Ganztags-Lane direkt darunter, Gitter füllt den Rest); Events tragen **Kalender-Farben**. **Monat**: farbige Dots.

- [ ] **Step 6: Commit**

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add apps/comhub-native/ComHub/Calendar/EventBlockView.swift apps/comhub-native/ComHub/Calendar/DayGridView.swift apps/comhub-native/ComHub/Calendar/MonthGridView.swift
git commit -m "ComHub: Kalender-Layout-Fix (Header-Hoehe) + Kalender-Farben (Tag/Woche/Monat)"
```

---

## Task 6: Kalender-Filter-UI + Verdrahtung (ComHub)

**Files:**
- Create: `apps/comhub-native/ComHub/Calendar/CalendarFilterPopover.swift`
- Modify: `apps/comhub-native/ComHub/Calendar/CalendarModuleView.swift`

- [ ] **Step 1: Popover schreiben**

`apps/comhub-native/ComHub/Calendar/CalendarFilterPopover.swift`:

```swift
import SwiftUI

/// Toggle-Liste der Kalender-Quellen (Apple-Kalender + Atoll).
struct CalendarFilterPopover: View {
  let store: CalendarSourcesStore
  let onChange: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Text("Kalender").font(.system(size: 12, weight: .bold)).foregroundStyle(.secondary)
        .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 8)
      ForEach(store.sources) { src in
        Button { store.toggle(src.id); onChange() } label: {
          HStack(spacing: 9) {
            Circle().fill(Color(hex: src.colorHex ?? "") ?? .secondary).frame(width: 10, height: 10)
            Text(src.title).font(.system(size: 13)).foregroundStyle(.primary)
            Spacer(minLength: 12)
            Image(systemName: store.isEnabled(src.id) ? "checkmark.circle.fill" : "circle")
              .foregroundStyle(store.isEnabled(src.id) ? CoColor.accent : .tertiary)
          }
          .padding(.horizontal, 14).padding(.vertical, 7).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
      }
    }
    .frame(width: 260).padding(.bottom, 8)
  }
}
```

- [ ] **Step 2: `CalendarModuleView` — Filter-Button + Store verdrahten**

In `CalendarModuleView.swift`:
1. Environment + State ergänzen (oben in der struct):

```swift
  @Environment(AppleAuthorizationService.self) private var appleAuth
  @State private var sources: CalendarSourcesStore?
  @State private var showFilter = false
```

> `CalendarSourcesStore` braucht ein `EKEventStore`. Das App-weite `eventStore` ist in `ComHubApp` als `@State` und wird über die Umgebung nicht gereicht — daher hier ein **eigener** `EKEventStore` (Berechtigung ist prozessweit; konsistent). Initialisiere `sources` in `.task` (siehe unten) mit `EKEventStore()`.

2. Im `header` (in der `HStack`, z. B. vor dem `if store.loading`-Spinner) einen Filter-Button einfügen:

```swift
      Button { showFilter.toggle() } label: { Image(systemName: "line.3.horizontal.decrease.circle") }
        .buttonStyle(.bordered)
        .popover(isPresented: $showFilter) {
          if let sources { CalendarFilterPopover(store: sources) { applyFilter() } }
        }
```

3. Im `body` `.task(id: reloadKey)` so erweitern, dass beim ersten Lauf `sources` erstellt + der Filter angewendet wird:

```swift
    .task(id: reloadKey) {
      if sources == nil { sources = CalendarSourcesStore(store: EKEventStore()) }
      applyFilter()
      await store.reload(using: hub)
    }
```

4. Helfer `applyFilter()` (in der struct):

```swift
  private func applyFilter() {
    store.enabledCalendarIds = sources?.enabledIds
  }
```
und `import EventKit` oben ergänzen. Bei Filter-Änderung neu laden — der `CalendarFilterPopover`-`onChange` ruft `applyFilter()`; danach einen Reload anstossen. Dafür `applyFilter()` erweitern:

```swift
  private func applyFilter() {
    store.enabledCalendarIds = sources?.enabledIds
    Task { await store.reload(using: hub) }
  }
```

- [ ] **Step 3: Generieren + Build**

Run: `cd apps/comhub-native && xcodegen generate && xcodebuild -scheme ComHub -destination 'platform=macOS,arch=arm64' build`
Expected: `** BUILD SUCCEEDED **`. (`AppleAuthorizationService` ist via `.environment` injiziert; `EKEventStore()` lokal.)

- [ ] **Step 4: Manueller Smoke-Test** (echter Mac, Light + Dark)

- [ ] **Kalender** → Filter-Button (oben) öffnet Popover mit allen Kalendern (Apple-Kalender mit Farb-Punkt + „Atoll") + Häkchen.
- [ ] **Doppelte Schul-Events**: den abonnierten iCloud-Schulkalender **deaktivieren** → die Duplikate verschwinden, jeder Termin nur noch 1×.
- [ ] **Tag/Woche**: kompakt (keine Riesen-Lücken), Events in **Kalender-Farben**, Now-Linie korrekt.
- [ ] **Monat**: farbige Dots je Kalender.
- [ ] Filter-Auswahl **bleibt nach Neustart** (persistiert).
- [ ] Dark Mode lesbar.

- [ ] **Step 5: Commit**

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add apps/comhub-native/ComHub/Calendar/CalendarFilterPopover.swift apps/comhub-native/ComHub/Calendar/CalendarModuleView.swift
git commit -m "ComHub: Kalender-Filter (Kalender ein/aus, persistent) im Kalender-Header"
```

---

## Task 7: Dokumentation (D2c)

**Files:**
- Modify: `apps/comhub-native/README.md`

- [ ] **Step 1: D2c-Zeile ergänzen**

In `apps/comhub-native/README.md` im Abschnitt `## Phasen-Stand` nach dem `**Design D2b** …`-Absatz einfügen:

```markdown

**Design D2c** — **Kalender-Feinschliff**: Layout-Fix (Tag/Woche kompakt, keine
Leerräume mehr), echte **Kalender-Farben** je Quelle (Apple-EKCalendar-Farbe,
Atoll-Akzent) und ein **Kalender-Filter** (einzelne Kalender ein/ausschalten,
persistent) — der zugleich Doppel-Events beseitigt (redundanten iCloud-Kalender
aus). Filter-Logik getestet in `AtollHub` (`CalendarFilter`).
```

- [ ] **Step 2: Commit**

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add apps/comhub-native/README.md
git commit -m "Docs: ComHub-README Design-D2c (Kalender-Feinschliff + Filter)"
```

---

## Self-Review (durchgeführt)

**1. Abdeckung der Nutzer-Rückmeldung:**
- „Layouts nicht kompakt / Riesen-Lücken" → Task 5 Step 2 (Header-Höhe fixieren, `Color.clear` entgreifen).
- „Events doppelt" → Task 6 (Kalender-Filter: redundanten iCloud-Kalender aus) + optionales Dedup-Sicherheitsnetz (Scope-Hinweis).
- „farblos" → Task 1 (`colorHex` im Modell) + Task 2 (Apple-Adapter) + Task 5 (Views nutzen Farbe).
- „Kalender ausschalten" → Tasks 3/4/6 (`CalendarSourcesStore` + `CalendarStore`-Filter + Popover, persistent).

**2. Platzhalter-Scan:** Keine „TBD/TODO". Vollständiger Code/Edit je Schritt; Befehl + erwartete Ausgabe je Run.

**3. Typ-Konsistenz:**
- `UnifiedEvent` (+`calendarId`/`colorHex`, rückwärtskompatibel) ↔ Mapper (Task 1) ↔ Adapter (Task 2) ↔ `CalendarFilter`/`CalendarStore` (Tasks 1/4) ↔ Views (Task 5). ✔ — bestehende `AppleEventMapper`/`AtollEventMapper`/`CalendarLayout`/`CockpitDigest`-Nutzung bleibt gültig (Defaults).
- `CalendarSource`/`CalendarSourcesStore` (`.sources`/`.enabledIds`/`.isEnabled`/`.toggle`) (Task 3) ↔ `CalendarStore.enabledCalendarIds` (Task 4) ↔ Popover/Module (Task 6). ✔
- `Color(hex:)` (Phase 4a) ↔ EventBlock/Lane/Dots/Popover. ✔
- **Wichtig (Task 1 Step 1):** `withTimes`-Helper (Multi-Day-Clip) muss `calendarId`/`colorHex` mitkopieren — sonst Farbverlust beim Clippen.

**4. Verifikations-Disziplin:** Task 1 echte TDD (`swift test`, inkl. Rückwärtskompatibilität der Mapper-Tests). Tasks 2–6 build-verifiziert; Task 5 Zwischen-Smoke, Task 6 voller manueller Smoke-Test (Filter, Duplikate weg, Farben, Layout, Persistenz, Dark). Konform zu superpowers:verification-before-completion.

---

## Execution Handoff

**Plan komplett und gespeichert unter `docs/superpowers/plans/2026-06-02-comhub-designD2c-kalender-fix.md`. Zwei Ausführungs-Optionen:**

**1. Subagent-Driven (empfohlen)** — frischer Subagent pro Task, Review zwischen den Tasks. (REQUIRED SUB-SKILL: superpowers:subagent-driven-development.)

**2. Inline-Ausführung** — Tasks in dieser Session, Batch mit Checkpoints. (REQUIRED SUB-SKILL: superpowers:executing-plans.)

**Welcher Ansatz?**
