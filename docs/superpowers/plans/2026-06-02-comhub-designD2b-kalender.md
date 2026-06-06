# ComHub Design D2b — Kalender-Rebuild (Zeitgitter) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Das **Kalender-Modul** im CoHub-Mockup-Look neu als echtes **Zeitgitter**: Tag/Woche mit Stundenraster (Zeit-Gutter, Gitterlinien, absolut positionierte Event-Blöcke mit Überlapp-Spalten, Ganztags-Lane, rote Now-Linie, Tages-Header mit Heute-Markierung) und Monat als 7-Spalten-Raster mit Tageszahlen + Event-Farb-Dots. Restyle-Header (Segmented Tag/Woche/Monat, Titel, ‹ Heute ›). Reiner Restyle/Rebuild der bestehenden Lese-Funktion (Apple+Atoll-Events) — kein Schreiben.

**Architecture:** Die zwei algorithmischen Kerne wandern als reine, getestete Helfer nach `AtollHub`: `EventColumns.layout` (Überlapp-Spalten-Packing für überlappende Termine, das `packDay` des Mockups) und `DayWindow.hours` (sichtbare Stundenrange aus den Events, geklammert). Die SwiftUI-UI wird ComHub-lokal neu gebaut: `CalendarGeometry` (pure y/Höhe-Arithmetik), `EventBlockView`, `TimeGutterView`, `DayGridView` (ein/mehrere Tagesspalten mit Header + Ganztags-Lane + scrollbarem Gitter + Now-Linie), `MonthGridView` (Raster + Dots), und ein restylter `CalendarModuleView`-Header (`Segmented`). Reuse: `CalendarStore` (anchor/kind/events/eventsByDay/Navigation aus Phase 1), `CalendarLayout`/`CalendarWindow` (AtollHub), D1-`CoColor`. Exakte Masse: `docs/superpowers/specs/2026-06-02-comhub-design-system.md` (Kalender) + `view-kalender.jsx`.

**Tech Stack:** Swift 6 (strict concurrency complete), SwiftUI Multiplatform (iOS 26 / macOS 26), XcodeGen, XCTest. Reuse: `UnifiedEvent` (`.start`/`.end`/`.isAllDay`/`.title`/`.location`/`.source`), `CalendarStore` (`.kind`/`.anchor`/`.eventsByDay`/`.calendar`/`.step`/`.goToToday`/`.reload`), `CalendarLayout.weekDays`/`.monthGrid`, `CalendarKind`, `CoColor`.

---

## Scope-Grenzen (bewusst)

- **Nur lesen/restyle.** Termin-Erstellen/Drag/Edit (Mockup-Button „+ Termin") = Phase 5 (Schreiben) — in D2b **weggelassen**.
- **Quell-Farbe:** Apple-Events grau/sekundär, Atoll-Events Akzent (wie im bisherigen `UnifiedEventRow`). Eine echte per-Kalender-Palette (EKCalendar-Farbe) ist Phase-5/später; D2b nutzt die binäre Atoll/Apple-Tönung.
- **Stunden-Fenster dynamisch:** statt fix 07–18 (Mockup-Demo) berechnet `DayWindow.hours` die sichtbare Range aus den Events (geklammert auf [6, 23], Default 7–19), damit frühe/späte Atoll-Module nicht abgeschnitten werden.
- **Monat:** Tageszahlen + bis zu 4 Event-Farb-Dots je Tag (kein Event-Titel im Monat); Tippen auf Tag → Tag-Ansicht.

---

## File Structure

**Geändertes Paket — `swift-packages/AtollHub/`:**
- `Sources/AtollHub/Calendar/EventColumns.swift` — `PositionedEvent`, `EventColumns.layout(_:)`.
- `Sources/AtollHub/Calendar/DayWindow.swift` — `DayWindow.hours(for:calendar:)`.
- `Tests/AtollHubTests/EventColumnsTests.swift`, `DayWindowTests.swift`.

**Neue App-Dateien — `apps/comhub-native/ComHub/Calendar/`:**
- `CalendarGeometry.swift` — pxPerMin + y/Höhe-Helfer.
- `EventBlockView.swift` — ein positionierter Event-Block.
- `TimeGutterView.swift` — Stunden-Beschriftung + Gitterlinien.
- `DayGridView.swift` — Tages-Header + Ganztags-Lane + scrollbares Gitter (1..7 Spalten) + Now-Linie.
- `MonthGridView.swift` — **Rebuild** (Raster + Dots). (ersetzt Phase-1-Version)

**Geänderte App-Dateien:**
- `ComHub/Calendar/CalendarModuleView.swift` — Header restyle (`Segmented`), Tag/Woche → `DayGridView`, Monat → neue `MonthGridView`.
- **Entfernt/ersetzt:** `ComHub/Calendar/DayColumnView.swift`, `ComHub/Calendar/WeekGridView.swift` (Phase-1-Listen-Views) — durch `DayGridView` abgelöst.

**Doku:**
- `apps/comhub-native/README.md` — D2b-Zeile.

---

## Task 1: `EventColumns.layout` — Überlapp-Spalten-Packing (AtollHub, TDD)

**Files:**
- Create: `swift-packages/AtollHub/Sources/AtollHub/Calendar/EventColumns.swift`
- Test: `swift-packages/AtollHub/Tests/AtollHubTests/EventColumnsTests.swift`

- [ ] **Step 1: Failing Test schreiben**

`swift-packages/AtollHub/Tests/AtollHubTests/EventColumnsTests.swift`:

```swift
import XCTest
@testable import AtollHub

final class EventColumnsTests: XCTestCase {
  private func ev(_ id: String, _ startMin: Int, _ endMin: Int) -> UnifiedEvent {
    UnifiedEvent(id: id, source: AccountRef(accountId: "x", type: .apple),
                 title: id, start: Date(timeIntervalSince1970: Double(startMin) * 60),
                 end: Date(timeIntervalSince1970: Double(endMin) * 60),
                 isAllDay: false, location: nil)
  }

  func test_nonOverlapping_allSingleColumn() {
    let slots = EventColumns.layout([ev("a", 540, 600), ev("b", 660, 720)])
    XCTAssertEqual(slots.count, 2)
    XCTAssertTrue(slots.allSatisfy { $0.column == 0 && $0.columnCount == 1 })
  }

  func test_twoOverlapping_twoColumns() {
    let slots = EventColumns.layout([ev("a", 540, 660), ev("b", 600, 720)])
    let a = slots.first { $0.event.id == "a" }!
    let b = slots.first { $0.event.id == "b" }!
    XCTAssertEqual(a.column, 0); XCTAssertEqual(b.column, 1)
    XCTAssertEqual(a.columnCount, 2); XCTAssertEqual(b.columnCount, 2)
  }

  func test_thirdFitsFreedColumn() {
    // a 9-10, b 9-11 (overlap a), c 10-11 (overlaps b, not a) -> a col0, b col1, c col0; count 2
    let slots = EventColumns.layout([ev("a", 540, 600), ev("b", 540, 660), ev("c", 600, 660)])
    let c = slots.first { $0.event.id == "c" }!
    XCTAssertEqual(c.column, 0)
    XCTAssertTrue(slots.allSatisfy { $0.columnCount == 2 })
  }

  func test_allDayAndOutOfOrderHandled() {
    let allDay = UnifiedEvent(id: "ad", source: AccountRef(accountId: "x", type: .apple),
                              title: "ad", start: Date(timeIntervalSince1970: 0),
                              end: Date(timeIntervalSince1970: 86_400), isAllDay: true, location: nil)
    let slots = EventColumns.layout([ev("late", 660, 720), allDay, ev("early", 540, 600)])
    XCTAssertEqual(slots.map(\.event.id), ["early", "late"]) // all-day raus, sortiert
  }
}
```

- [ ] **Step 2: Test ausführen — soll fehlschlagen**

Run: `cd swift-packages/AtollHub && swift test --filter EventColumnsTests`
Expected: FAIL — `cannot find 'EventColumns' in scope`.

- [ ] **Step 3: Implementieren**

`swift-packages/AtollHub/Sources/AtollHub/Calendar/EventColumns.swift`:

```swift
import Foundation

/// Ein Event mit zugewiesener Spalte fürs Tages-Zeitgitter (Überlapp-Layout).
public struct PositionedEvent: Sendable, Identifiable, Equatable {
  public let event: UnifiedEvent
  public let column: Int
  public let columnCount: Int
  public var id: String { event.id }
  public init(event: UnifiedEvent, column: Int, columnCount: Int) {
    self.event = event; self.column = column; self.columnCount = columnCount
  }
}

/// Spalten-Packing für überlappende timed Events (Mockup `packDay`):
/// Cluster sich überlappender Events teilen sich nebeneinanderliegende Spalten.
public enum EventColumns {
  public static func layout(_ events: [UnifiedEvent]) -> [PositionedEvent] {
    let timed = events.filter { !$0.isAllDay }.sorted { $0.start < $1.start }
    var out: [PositionedEvent] = []
    var cluster: [UnifiedEvent] = []
    var clusterEnd: Date = .distantPast

    func flush() {
      guard !cluster.isEmpty else { return }
      var colEnds: [Date] = []          // letzte Endzeit je Spalte
      var assigned: [(UnifiedEvent, Int)] = []
      for ev in cluster {
        var placed = false
        for c in colEnds.indices where colEnds[c] <= ev.start {
          colEnds[c] = ev.end; assigned.append((ev, c)); placed = true; break
        }
        if !placed { colEnds.append(ev.end); assigned.append((ev, colEnds.count - 1)) }
      }
      let count = colEnds.count
      out += assigned.map { PositionedEvent(event: $0.0, column: $0.1, columnCount: count) }
      cluster = []
    }

    for ev in timed {
      if !cluster.isEmpty, ev.start < clusterEnd {
        cluster.append(ev); clusterEnd = max(clusterEnd, ev.end)
      } else {
        flush(); cluster = [ev]; clusterEnd = ev.end
      }
    }
    flush()
    // Ausgabe nach Startzeit (stabil fuer Tests/Anzeige).
    return out.sorted { $0.event.start < $1.event.start }
  }
}
```

- [ ] **Step 4: Test ausführen — soll grün sein**

Run: `cd swift-packages/AtollHub && swift test --filter EventColumnsTests`
Expected: PASS — 4 Tests grün.

- [ ] **Step 5: Commit**

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add swift-packages/AtollHub/Sources/AtollHub/Calendar/EventColumns.swift swift-packages/AtollHub/Tests/AtollHubTests/EventColumnsTests.swift
git commit -m "AtollHub: EventColumns (Ueberlapp-Spalten-Packing, rein/getestet)"
```

---

## Task 2: `DayWindow.hours` — sichtbare Stundenrange (AtollHub, TDD)

**Files:**
- Create: `swift-packages/AtollHub/Sources/AtollHub/Calendar/DayWindow.swift`
- Test: `swift-packages/AtollHub/Tests/AtollHubTests/DayWindowTests.swift`

- [ ] **Step 1: Failing Test schreiben**

`swift-packages/AtollHub/Tests/AtollHubTests/DayWindowTests.swift`:

```swift
import XCTest
@testable import AtollHub

final class DayWindowTests: XCTestCase {
  private var cal: Calendar {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "Europe/Zurich")!
    return c
  }
  private func at(_ hour: Int, _ minute: Int = 0) -> Date {
    cal.date(from: DateComponents(timeZone: cal.timeZone, year: 2026, month: 6, day: 2,
                                  hour: hour, minute: minute))!
  }
  private func ev(_ sH: Int, _ eH: Int) -> UnifiedEvent {
    UnifiedEvent(id: "\(sH)", source: AccountRef(accountId: "x", type: .apple),
                 title: "e", start: at(sH), end: at(eH), isAllDay: false, location: nil)
  }

  func test_defaultWhenNoEvents() {
    let w = DayWindow.hours(for: [], calendar: cal)
    XCTAssertEqual(w.startHour, 7); XCTAssertEqual(w.endHour, 19)
  }

  func test_expandsToEventsWithPadding() {
    // Events 09-11 und 14-15 -> Start min(7, 9-1=8)->? Regel: startHour = clamp(minStart-1, 6, 9 default)
    let w = DayWindow.hours(for: [ev(9, 11), ev(14, 15)], calendar: cal)
    XCTAssertLessThanOrEqual(w.startHour, 8)
    XCTAssertGreaterThanOrEqual(w.endHour, 16)
    XCTAssertGreaterThanOrEqual(w.startHour, 6)
    XCTAssertLessThanOrEqual(w.endHour, 23)
  }

  func test_clampsExtremes() {
    let w = DayWindow.hours(for: [ev(0, 1), ev(22, 23)], calendar: cal)
    XCTAssertEqual(w.startHour, 6)   // geklammert
    XCTAssertEqual(w.endHour, 23)
  }

  func test_ignoresAllDay() {
    let allDay = UnifiedEvent(id: "ad", source: AccountRef(accountId: "x", type: .apple),
                              title: "ad", start: at(0), end: at(0), isAllDay: true, location: nil)
    let w = DayWindow.hours(for: [allDay], calendar: cal)
    XCTAssertEqual(w.startHour, 7); XCTAssertEqual(w.endHour, 19)
  }
}
```

- [ ] **Step 2: Test ausführen — soll fehlschlagen**

Run: `cd swift-packages/AtollHub && swift test --filter DayWindowTests`
Expected: FAIL — `cannot find 'DayWindow' in scope`.

- [ ] **Step 3: Implementieren**

`swift-packages/AtollHub/Sources/AtollHub/Calendar/DayWindow.swift`:

```swift
import Foundation

/// Sichtbare Stundenrange eines Tages-/Wochen-Gitters.
public enum DayWindow {
  public struct Range: Sendable, Equatable {
    public let startHour: Int   // 0..23
    public let endHour: Int     // 1..24, > startHour
  }

  /// Default 7–19; erweitert sich an die timed Events (mit 1h Puffer),
  /// geklammert auf [6, 23]/[?, 23] bzw. min. die Default-Breite.
  public static func hours(for events: [UnifiedEvent], calendar: Calendar) -> Range {
    let timed = events.filter { !$0.isAllDay }
    guard !timed.isEmpty else { return Range(startHour: 7, endHour: 19) }

    let starts = timed.map { calendar.component(.hour, from: $0.start) }
    // Endstunde aufrunden: wenn Minuten > 0, eine Stunde mehr.
    let ends = timed.map { ev -> Int in
      let h = calendar.component(.hour, from: ev.end)
      let m = calendar.component(.minute, from: ev.end)
      return m > 0 ? h + 1 : h
    }
    let minStart = max(6, min((starts.min() ?? 7) - 1, 7))
    let maxEnd = min(23, max((ends.max() ?? 19) + 1, 19))
    return Range(startHour: minStart, endHour: maxEnd)
  }
}
```

- [ ] **Step 4: Test ausführen — soll grün sein**

Run: `cd swift-packages/AtollHub && swift test --filter DayWindowTests`
Expected: PASS — 4 Tests grün.

- [ ] **Step 5: Volle Paket-Suite + Commit**

Run: `cd swift-packages/AtollHub && swift test`
Expected: PASS — alle Suiten grün.

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add swift-packages/AtollHub/Sources/AtollHub/Calendar/DayWindow.swift swift-packages/AtollHub/Tests/AtollHubTests/DayWindowTests.swift
git commit -m "AtollHub: DayWindow (sichtbare Stundenrange aus Events, rein/getestet)"
```

---

## Task 3: `CalendarGeometry` + `EventBlockView` + `TimeGutterView` (ComHub)

**Files:**
- Create: `apps/comhub-native/ComHub/Calendar/CalendarGeometry.swift`
- Create: `apps/comhub-native/ComHub/Calendar/EventBlockView.swift`
- Create: `apps/comhub-native/ComHub/Calendar/TimeGutterView.swift`

- [ ] **Step 1: `CalendarGeometry` schreiben**

`apps/comhub-native/ComHub/Calendar/CalendarGeometry.swift`:

```swift
import Foundation
import AtollHub

/// Reine Geometrie fürs Zeitgitter: minutenbasierte y-Position und Höhe.
struct CalendarGeometry {
  let startHour: Int
  let endHour: Int
  let pxPerMin: CGFloat
  let calendar: Calendar

  var totalHeight: CGFloat { CGFloat((endHour - startHour) * 60) * pxPerMin }

  /// Minuten seit Mitternacht (lokaler Kalender) eines Datums.
  func minutes(_ date: Date) -> Int {
    calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
  }

  /// y-Offset eines Datums relativ zum Gitter-Anfang.
  func y(_ date: Date) -> CGFloat {
    CGFloat(minutes(date) - startHour * 60) * pxPerMin
  }

  /// Höhe eines Events (min 16).
  func height(start: Date, end: Date) -> CGFloat {
    max(CGFloat(minutes(end) - minutes(start)) * pxPerMin, 16)
  }
}
```

- [ ] **Step 2: `EventBlockView` schreiben**

`apps/comhub-native/ComHub/Calendar/EventBlockView.swift`:

```swift
import SwiftUI
import AtollHub

/// Ein positionierter Event-Block im Tagesgitter.
struct EventBlockView: View {
  let event: UnifiedEvent

  private var tint: Color { event.source.type == .atoll ? CoColor.accent : Color.secondary }

  private static let time: DateFormatter = {
    let f = DateFormatter(); f.dateFormat = "HH:mm"
    f.timeZone = TimeZone(identifier: "Europe/Zurich"); return f
  }()

  var body: some View {
    VStack(alignment: .leading, spacing: 1) {
      Text(event.title).font(.system(size: 11.5, weight: .semibold)).lineLimit(1)
      Text("\(Self.time.string(from: event.start))\(event.location.map { " · \($0)" } ?? "")")
        .font(.system(size: 10.5)).foregroundStyle(.secondary).lineLimit(1)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .padding(.horizontal, 6).padding(.vertical, 3)
    .background(tint.opacity(0.16), in: RoundedRectangle(cornerRadius: 6))
    .overlay(alignment: .leading) {
      RoundedRectangle(cornerRadius: 2).fill(tint).frame(width: 3)
    }
    .clipShape(RoundedRectangle(cornerRadius: 6))
  }
}
```

- [ ] **Step 3: `TimeGutterView` schreiben**

`apps/comhub-native/ComHub/Calendar/TimeGutterView.swift`:

```swift
import SwiftUI

/// Linke Stunden-Beschriftung (07:00 … 18:00), ausgerichtet aufs Gitter.
struct TimeGutterView: View {
  let geo: CalendarGeometry

  var body: some View {
    ZStack(alignment: .topLeading) {
      ForEach(geo.startHour...geo.endHour, id: \.self) { h in
        Text(String(format: "%02d:00", h))
          .font(.system(size: 10.5, weight: .medium)).foregroundStyle(.tertiary)
          .frame(width: 46, alignment: .trailing)
          .offset(x: 0, y: CGFloat((h - geo.startHour) * 60) * geo.pxPerMin - 6)
      }
    }
    .frame(width: 54, height: geo.totalHeight, alignment: .topLeading)
  }
}
```

- [ ] **Step 4: Build verifizieren**

Run: `cd apps/comhub-native && xcodegen generate && xcodebuild -scheme ComHub -destination 'platform=macOS,arch=arm64' build`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add apps/comhub-native/ComHub/Calendar/CalendarGeometry.swift apps/comhub-native/ComHub/Calendar/EventBlockView.swift apps/comhub-native/ComHub/Calendar/TimeGutterView.swift
git commit -m "ComHub: Kalender-Gitter-Primitive (Geometry, EventBlock, TimeGutter)"
```

---

## Task 4: `DayGridView` — Header + Ganztags-Lane + Zeitgitter + Now-Linie (ComHub)

**Files:**
- Create: `apps/comhub-native/ComHub/Calendar/DayGridView.swift`

- [ ] **Step 1: View schreiben**

`apps/comhub-native/ComHub/Calendar/DayGridView.swift`:

```swift
import SwiftUI
import AtollHub

/// Zeitgitter über `days` (1 = Tag, 7 = Woche). Header-Zeile + Ganztags-Lane +
/// scrollbares Stundengitter mit positionierten Event-Blöcken + Now-Linie.
struct DayGridView: View {
  let store: CalendarStore
  let days: [Date]

  private let pxPerMin: CGFloat = 0.9

  private var allEvents: [UnifiedEvent] {
    days.flatMap { store.eventsByDay[store.calendar.startOfDay(for: $0)] ?? [] }
  }
  private var geo: CalendarGeometry {
    let w = DayWindow.hours(for: allEvents, calendar: store.calendar)
    return CalendarGeometry(startHour: w.startHour, endHour: w.endHour,
                            pxPerMin: pxPerMin, calendar: store.calendar)
  }

  private static let dayLabel: DateFormatter = {
    let f = DateFormatter(); f.dateFormat = "EE"
    f.locale = Locale(identifier: "de_CH")
    f.timeZone = TimeZone(identifier: "Europe/Zurich"); return f
  }()

  private func isToday(_ day: Date) -> Bool {
    store.calendar.isDate(day, inSameDayAs: Date())
  }

  var body: some View {
    VStack(spacing: 0) {
      headerRow
      Divider()
      allDayLane
      ScrollView {
        HStack(alignment: .top, spacing: 0) {
          TimeGutterView(geo: geo)
          ForEach(days, id: \.self) { day in
            dayColumn(day)
            Divider()
          }
        }
        .frame(height: geo.totalHeight)
        .padding(.vertical, 6)
      }
    }
  }

  private var headerRow: some View {
    HStack(spacing: 0) {
      Color.clear.frame(width: 54)
      ForEach(days, id: \.self) { day in
        HStack(alignment: .firstTextBaseline, spacing: 7) {
          Text(Self.dayLabel.string(from: day))
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(isToday(day) ? CoColor.module(.kalender) : .secondary)
          Text("\(store.calendar.component(.day, from: day))")
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(isToday(day) ? .white : .primary)
            .padding(.horizontal, isToday(day) ? 7 : 0).padding(.vertical, isToday(day) ? 3 : 0)
            .background(isToday(day) ? CoColor.module(.kalender) : .clear,
                        in: RoundedRectangle(cornerRadius: 8))
          Spacer(minLength: 0)
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        Divider()
      }
    }
  }

  @ViewBuilder
  private var allDayLane: some View {
    let lanes = days.map { day in
      (day, (store.eventsByDay[store.calendar.startOfDay(for: day)] ?? []).filter(\.isAllDay))
    }
    if lanes.contains(where: { !$0.1.isEmpty }) {
      HStack(spacing: 0) {
        Text("ganztägig").font(.system(size: 10)).foregroundStyle(.tertiary)
          .frame(width: 54, alignment: .trailing).padding(.trailing, 8)
        ForEach(lanes, id: \.0) { _, evs in
          VStack(alignment: .leading, spacing: 3) {
            ForEach(evs) { ev in
              Text(ev.title).font(.system(size: 11, weight: .semibold)).foregroundStyle(.white)
                .lineLimit(1).padding(.horizontal, 7).padding(.vertical, 2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(ev.source.type == .atoll ? CoColor.accent : Color.secondary,
                            in: RoundedRectangle(cornerRadius: 5))
            }
          }
          .padding(4).frame(maxWidth: .infinity, alignment: .leading)
          Divider()
        }
      }
      .padding(.vertical, 4)
      Divider()
    }
  }

  private func dayColumn(_ day: Date) -> some View {
    let dayKey = store.calendar.startOfDay(for: day)
    let positioned = EventColumns.layout(store.eventsByDay[dayKey] ?? [])
    return GeometryReader { proxy in
      ZStack(alignment: .topLeading) {
        // Gitterlinien
        ForEach(geo.startHour...geo.endHour, id: \.self) { h in
          Rectangle().fill(Color.primary.opacity(0.06)).frame(height: 1)
            .offset(y: CGFloat((h - geo.startHour) * 60) * geo.pxPerMin)
        }
        // Event-Bloecke
        ForEach(positioned) { slot in
          let colW = proxy.size.width / CGFloat(slot.columnCount)
          EventBlockView(event: slot.event)
            .frame(width: colW - 3, height: geo.height(start: slot.event.start, end: slot.event.end))
            .offset(x: colW * CGFloat(slot.column) + 1, y: geo.y(slot.event.start))
        }
        // Now-Linie (nur heute)
        if isToday(day) {
          let nowY = geo.y(Date())
          if nowY >= 0 && nowY <= geo.totalHeight {
            ZStack(alignment: .leading) {
              Rectangle().fill(CoColor.module(.kalender)).frame(height: 1.5)
              Circle().fill(CoColor.module(.kalender)).frame(width: 8, height: 8).offset(x: -4)
            }
            .offset(y: nowY)
          }
        }
      }
    }
    .frame(maxWidth: .infinity)
    .frame(height: geo.totalHeight)
  }
}
```

- [ ] **Step 2: Build verifizieren**

Run: `cd apps/comhub-native && xcodegen generate && xcodebuild -scheme ComHub -destination 'platform=macOS,arch=arm64' build`
Expected: `** BUILD SUCCEEDED **`. Watch: `GeometryReader` + `ZStack(alignment:.topLeading)` mit `.offset`/`.frame`, `ForEach(geo.startHour...geo.endHour, id: \.self)`. Falls eine SwiftUI-API klemmt, exakten Fehler melden.

- [ ] **Step 3: Commit**

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add apps/comhub-native/ComHub/Calendar/DayGridView.swift
git commit -m "ComHub: DayGridView (Zeitgitter Tag/Woche mit Ueberlapp, Ganztags-Lane, Now-Linie)"
```

---

## Task 5: `MonthGridView` neu (Raster + Dots) (ComHub)

**Files:**
- Modify: `apps/comhub-native/ComHub/Calendar/MonthGridView.swift` (ganzen Inhalt ersetzen)

- [ ] **Step 1: `MonthGridView` ersetzen**

`apps/comhub-native/ComHub/Calendar/MonthGridView.swift`:

```swift
import SwiftUI
import AtollHub

/// Monatsraster im CoHub-Look: 7 Spalten Mo–So, Tageszahlen (Heute markiert),
/// bis zu 4 Event-Farb-Dots je Tag. Tippen → Tag-Ansicht.
struct MonthGridView: View {
  let store: CalendarStore
  let onPickDay: (Date) -> Void

  private var weeks: [[Date]] { CalendarLayout.monthGrid(of: store.anchor, calendar: store.calendar) }
  private var anchorMonth: Int { store.calendar.component(.month, from: store.anchor) }
  private static let head = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]

  var body: some View {
    VStack(spacing: 0) {
      HStack(spacing: 0) {
        ForEach(Self.head, id: \.self) { d in
          Text(d).font(.system(size: 11, weight: .semibold)).foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 6)
        }
      }
      .padding(.vertical, 8)

      VStack(spacing: 0) {
        ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
          HStack(spacing: 0) {
            ForEach(week, id: \.self) { day in
              cell(day); Divider()
            }
          }
          Divider()
        }
      }
      .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(CoTheme.separator, lineWidth: 1))
      .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    .padding(.horizontal, 16).padding(.bottom, 16)
  }

  @ViewBuilder
  private func cell(_ day: Date) -> some View {
    let dayStart = store.calendar.startOfDay(for: day)
    let inMonth = store.calendar.component(.month, from: day) == anchorMonth
    let isToday = store.calendar.isDate(day, inSameDayAs: Date())
    let events = store.eventsByDay[dayStart] ?? []
    let dotColors = Array(Set(events.map { $0.source.type })).prefix(4)

    VStack(alignment: .leading, spacing: 5) {
      Text("\(store.calendar.component(.day, from: day))")
        .font(.system(size: 12.5, weight: isToday ? .bold : .medium))
        .foregroundStyle(isToday ? .white : (inMonth ? .primary : .tertiary))
        .frame(width: 22, height: 22)
        .background(isToday ? CoColor.module(.kalender) : .clear, in: Circle())
      HStack(spacing: 3) {
        ForEach(Array(dotColors), id: \.self) { type in
          Circle().fill(type == .atoll ? CoColor.accent : Color.secondary).frame(width: 6, height: 6)
        }
      }
      Spacer(minLength: 0)
    }
    .padding(6)
    .frame(maxWidth: .infinity, minHeight: 72, alignment: .topLeading)
    .background(inMonth ? Color.clear : Color.primary.opacity(0.03))
    .contentShape(Rectangle())
    .onTapGesture { onPickDay(day) }
  }
}
```

- [ ] **Step 2: Build verifizieren**

Run: `cd apps/comhub-native && xcodegen generate && xcodebuild -scheme ComHub -destination 'platform=macOS,arch=arm64' build`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add apps/comhub-native/ComHub/Calendar/MonthGridView.swift
git commit -m "ComHub: MonthGridView neu (Raster + Farb-Dots, Heute-Markierung)"
```

---

## Task 6: `CalendarModuleView` Header-Restyle + Verdrahtung + Alt-Views entfernen (ComHub)

**Files:**
- Modify: `apps/comhub-native/ComHub/Calendar/CalendarModuleView.swift` (ganzen Inhalt ersetzen)
- Delete: `apps/comhub-native/ComHub/Calendar/DayColumnView.swift`
- Delete: `apps/comhub-native/ComHub/Calendar/WeekGridView.swift`

- [ ] **Step 1: Alte Listen-Views löschen**

```bash
cd /Users/dominik/Desktop/Developer/Dispo
rm apps/comhub-native/ComHub/Calendar/DayColumnView.swift apps/comhub-native/ComHub/Calendar/WeekGridView.swift
```

(`UnifiedEventRow.swift` bleibt — wird vom Heute-Cockpit genutzt.)

- [ ] **Step 2: `CalendarModuleView` ersetzen**

`apps/comhub-native/ComHub/Calendar/CalendarModuleView.swift`:

```swift
import SwiftUI
import AtollHub

/// Kalender-Modul im CoHub-Look: Header (Segmented Tag/Woche/Monat · Titel ·
/// ‹ Heute ›) über dem Zeitgitter bzw. Monatsraster.
struct CalendarModuleView: View {
  @Environment(Hub.self) private var hub
  @State private var store = CalendarStore()

  private static let title: DateFormatter = {
    let f = DateFormatter(); f.dateFormat = "MMMM yyyy"
    f.locale = Locale(identifier: "de_CH")
    f.timeZone = TimeZone(identifier: "Europe/Zurich"); return f
  }()

  var body: some View {
    @Bindable var store = store
    VStack(spacing: 0) {
      header(store: store)
      Divider()
      content
    }
    .task(id: reloadKey) { await store.reload(using: hub) }
  }

  private var reloadKey: String { "\(store.kind.rawValue)-\(store.anchor.timeIntervalSince1970)" }

  private func header(store: CalendarStore) -> some View {
    HStack(spacing: 12) {
      Picker("Ansicht", selection: $store.kind) {
        ForEach(CalendarKind.allCases) { Text($0.title).tag($0) }
      }
      .pickerStyle(.segmented).frame(maxWidth: 240)
      Spacer()
      Text(Self.title.string(from: store.anchor)).font(.system(size: 16, weight: .bold))
      Spacer()
      HStack(spacing: 2) {
        Button { store.step(-1) } label: { Image(systemName: "chevron.left") }
        Button("Heute") { store.goToToday() }
          .font(.system(size: 12.5, weight: .semibold))
        Button { store.step(1) } label: { Image(systemName: "chevron.right") }
      }
      .buttonStyle(.bordered)
      if store.loading { ProgressView().controlSize(.small) }
    }
    .padding(.horizontal, 16).frame(height: 52)
  }

  @ViewBuilder
  private var content: some View {
    switch store.kind {
    case .day:
      DayGridView(store: store, days: [store.calendar.startOfDay(for: store.anchor)])
    case .week:
      DayGridView(store: store, days: CalendarLayout.weekDays(of: store.anchor, calendar: store.calendar))
    case .month:
      MonthGridView(store: store, onPickDay: { day in
        store.anchor = day
        store.kind = .day
      })
    }
  }
}
```

- [ ] **Step 3: Generieren + Build**

Run: `cd apps/comhub-native && xcodegen generate && xcodebuild -scheme ComHub -destination 'platform=macOS,arch=arm64' build`
Expected: `** BUILD SUCCEEDED **`. (Falls `DayColumnView`/`WeekGridView` noch referenziert werden, melden — sollten es nicht, da nur `CalendarModuleView` sie nutzte.)

- [ ] **Step 4: Manueller Smoke-Test** (echter Mac, Light + Dark)

- [ ] **Kalender** → Segmented Tag/Woche/Monat schaltet um; Titel = Monat/Jahr; ‹ Heute › navigieren.
- [ ] **Woche**: Tages-Header (Wochentag + Datum, heute rot markiert), Ganztags-Lane (falls Events), Zeitgitter mit Stunden-Gutter + Gitterlinien; Event-Blöcke an richtiger Zeit/Höhe; überlappende Events nebeneinander; rote Now-Linie auf heute.
- [ ] **Tag**: eine Spalte, gleiche Mechanik.
- [ ] **Monat**: 7-Spalten-Raster, Tageszahlen (heute rot), Farb-Dots je Tag; Tippen auf Tag → Tag-Ansicht.
- [ ] Apple- + Atoll-Events erscheinen (Atoll Akzent, Apple grau).
- [ ] Dark Mode: Gitter/Blöcke/Now-Linie lesbar.

- [ ] **Step 5: Commit**

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add apps/comhub-native/ComHub/Calendar/CalendarModuleView.swift
git rm apps/comhub-native/ComHub/Calendar/DayColumnView.swift apps/comhub-native/ComHub/Calendar/WeekGridView.swift 2>/dev/null || true
git add -A apps/comhub-native/ComHub/Calendar
git commit -m "ComHub: Kalender-Modul Zeitgitter (Header-Restyle, Tag/Woche/Monat neu, Alt-Views entfernt)"
```

---

## Task 7: Dokumentation (D2b)

**Files:**
- Modify: `apps/comhub-native/README.md`

- [ ] **Step 1: D2b-Zeile ergänzen**

In `apps/comhub-native/README.md` im Abschnitt `## Phasen-Stand` **nach** dem `**Design D2a** …`-Absatz einfügen:

```markdown

**Design D2b** — **Kalender** als echtes Zeitgitter (CoHub-Look): Tag/Woche mit
Stunden-Gutter, Gitterlinien, überlappenden Event-Blöcken (Spalten-Packing),
Ganztags-Lane, roter Now-Linie und Heute-markiertem Tages-Header; Monat als
7-Spalten-Raster mit Farb-Dots. Reine Layout-Logik getestet in `AtollHub`
(`EventColumns`, `DayWindow`). Erstellen/Drag (Schreiben) folgt in Phase 5.
```

- [ ] **Step 2: Commit**

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add apps/comhub-native/README.md
git commit -m "Docs: ComHub-README Design-D2b (Kalender-Zeitgitter)"
```

---

## Self-Review (durchgeführt)

**1. Spec-Abdeckung (Mockup `view-kalender.jsx`, Slice D2b):**
- Segmented Tag/Woche/Monat + Titel + ‹ Heute › → Task 6 (`CalendarModuleView`-Header).
- Tag/Woche Zeitgitter: TimeGutter + GridLines + EventBlocks mit Überlapp-Spalten + Ganztags-Lane + Now-Linie + Tages-Header → Tasks 1 (`EventColumns`), 3 (`CalendarGeometry`/`EventBlockView`/`TimeGutterView`), 4 (`DayGridView`), 2 (`DayWindow`).
- Monat Raster + Tageszahlen + Dots + Heute → Task 5 (`MonthGridView`).
- Bewusste Abweichungen (Scope): „+ Termin"/Erstellen entfällt (Phase 5); Quell-Tönung binär Atoll/Apple statt EKCalendar-Farbe; Stunden-Fenster dynamisch statt fix 07–18.

**2. Platzhalter-Scan:** Keine „TBD/TODO". Vollständiger Code je Schritt; Befehl + erwartete Ausgabe je Run.

**3. Typ-Konsistenz:**
- `EventColumns.layout(_:) -> [PositionedEvent]` (`.event`/`.column`/`.columnCount`/`.id`) (Task 1) ↔ `DayGridView.dayColumn` (Task 4). ✔
- `DayWindow.hours(for:calendar:) -> DayWindow.Range` (`.startHour`/`.endHour`) (Task 2) ↔ `DayGridView.geo` (Task 4). ✔
- `CalendarGeometry` (`.totalHeight`/`.y`/`.height`) (Task 3) ↔ `TimeGutterView`/`DayGridView`. ✔
- `EventBlockView(event:)` (Task 3) ↔ `DayGridView` (Task 4). ✔
- `DayGridView(store:days:)` + `MonthGridView(store:onPickDay:)` (Tasks 4/5) ↔ `CalendarModuleView.content` (Task 6). ✔
- Reuse: `CalendarStore` (`.kind`/`.anchor`/`.eventsByDay`/`.calendar`/`.step`/`.goToToday`/`.reload(using:)`/`.loading`), `CalendarLayout.weekDays`/`.monthGrid`, `CalendarKind` (`.day`/`.week`/`.month`, `.title`, `.allCases`), `UnifiedEvent`, `CoColor.module(.kalender)`/`.accent`, `CoTheme.separator` — alle gegen den echten Code geprüft. ✔
- Entfernte `DayColumnView`/`WeekGridView` werden nach Task 6 nur noch vom alten `CalendarModuleView` referenziert (mit ersetzt); `UnifiedEventRow` bleibt (Cockpit). ✔

**4. Verifikations-Disziplin:** Tasks 1–2 echte TDD (`swift test`). Tasks 3–6 build-verifiziert (`xcodegen generate` + `xcodebuild`); Task 6 schliesst mit manuellem Smoke-Test inkl. Dark Mode + Überlapp + Now-Linie. Konform zu superpowers:verification-before-completion.

---

## Execution Handoff

**Plan komplett und gespeichert unter `docs/superpowers/plans/2026-06-02-comhub-designD2b-kalender.md`. Zwei Ausführungs-Optionen:**

**1. Subagent-Driven (empfohlen)** — frischer Subagent pro Task, Review zwischen den Tasks. (REQUIRED SUB-SKILL: superpowers:subagent-driven-development.)

**2. Inline-Ausführung** — Tasks in dieser Session, Batch mit Checkpoints. (REQUIRED SUB-SKILL: superpowers:executing-plans.)

**Welcher Ansatz?**
