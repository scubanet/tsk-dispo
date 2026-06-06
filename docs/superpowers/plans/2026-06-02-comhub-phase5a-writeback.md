# ComHub Phase 5a — Schreiben (Write-back) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** ComHub vom Lese-Tool zum Arbeits-Tool machen: **Aufgaben abhaken** (Apple Erinnerungen + Atoll-Tasks), **Termin erstellen**, **Erinnerung erstellen**, **Termin bearbeiten/löschen** — alles über EventKit (Apple) bzw. `contact_events` (Atoll), quellneutral über den Hub geroutet.

**Architecture:** Die Capability-Protokolle (`TodoProvider`, `CalendarProvider`) bekommen **optionale Schreib-Methoden** mit Default-Implementierung, die `ProviderWriteError.unsupported` wirft — bestehende/fremde Adapter bleiben unberührt, nur die schreibfähigen überschreiben sie. Reine, getestete Helfer in AtollHub: `SourceID` (Prefix-Parsing der `apple:`/`atoll:`-Ids), `EventDraft` (Eingabemodell), `AtollTaskDone` (Status/Payload-Patch). Der `Hub` routet eine Schreib-Aktion an die richtige Verbindung (per `task.source.type` bzw. das Apple-Kalender-Konto) — getestet mit Fake-Providern. App-Adapter implementieren die echten EventKit-/Supabase-Schreibvorgänge. UI: interaktive Checkboxen (Aufgaben + Heute-Cockpit, optimistisch), ein „+"-Termin-Sheet (Kalenderwahl) und ein Event-Tap → Detail/Bearbeiten/Löschen-Sheet.

**Tech Stack:** Swift 6 (strict concurrency complete), SwiftUI Multiplatform (iOS 26 / macOS 26), EventKit (`@preconcurrency`), supabase-swift 2.46 (PostgREST `.update().eq()`), XcodeGen, XCTest.

---

## Scope-Grenzen (bewusst)

- **5a = nur App-seitiges Schreiben.** Kein APNs/Push (das ist 5b: `device_tokens` + `comms-inbound`-Edge-Function).
- **Aufgaben abhaken:** Apple Erinnerung `isCompleted` umschalten (EventKit) **und** Atoll-Task (`contact_events`) `status`/`completed_at` umschalten.
- **Termin erstellen/bearbeiten/löschen:** nur **Apple-Kalender** (EventKit). Atoll-Events (Kurse) sind read-only (kommen aus dem CRM) — kein Schreiben dorthin.
- **Erinnerung erstellen:** Apple-Erinnerung in wählbare Liste.
- Konflikt-/Sync-Strategie: einfaches Reload nach Schreiben (kein optimistisches Merge-Modell außer der lokalen Checkbox-Spiegelung).

---

## File Structure

**AtollHub (`swift-packages/AtollHub/`):**
- `Sources/AtollHub/Capabilities/Providers.swift` — `TodoProvider`/`CalendarProvider` Schreib-Methoden + Default-Extensions; `ProviderWriteError`.
- `Sources/AtollHub/Model/EventDraft.swift` (neu) — `EventDraft` Eingabemodell.
- `Sources/AtollHub/Calendar/SourceID.swift` (neu) — `apple:`/`atoll:`-Prefix-Parsing.
- `Sources/AtollHub/Calendar/AtollTaskDone.swift` (neu) — Status/Payload-Patch für Atoll-Task-Done.
- `Sources/AtollHub/Hub/Hub.swift` — Routing-Methoden `setTaskDone`/`createEvent`/`updateEvent`/`deleteEvent`.
- `Tests/AtollHubTests/SourceIDTests.swift`, `AtollTaskDoneTests.swift`, `HubRoutingTests.swift` (neu).

**App (`apps/comhub-native/ComHub/`):**
- `Tasks/AppleRemindersAdapter.swift` — `setDone` (EKReminder speichern) + `createReminder`.
- `Tasks/AtollTasksAdapter.swift` — `setDone` (`contact_events.update`).
- `Adapters/AppleCalendarAdapter.swift` — `createEvent`/`updateEvent`/`deleteEvent` (EKEvent).
- `Tasks/AufgabenStore.swift` — `toggleDone(_:)` (optimistisch).
- `Tasks/TaskRow.swift` — Checkbox interaktiv (Callback).
- `Cockpit/CockpitView.swift` — Aufgaben-Widget-Checkbox interaktiv.
- `Calendar/CalendarStore.swift` — `createEvent`/`updateEvent`/`deleteEvent` Durchreichen + Reload.
- `Calendar/EventEditSheet.swift` (neu) — Erstellen/Bearbeiten-Formular.
- `Calendar/EventBlockView.swift` + `Calendar/CalendarModuleView.swift` — „+"-Button + Event-Tap → Sheet.

**Doku:** `apps/comhub-native/README.md` — Phase-5a-Zeile.

---

## Task 1: Schreib-Protokolle + reine Helfer (AtollHub, TDD)

**Files:**
- Modify: `swift-packages/AtollHub/Sources/AtollHub/Capabilities/Providers.swift`
- Create: `swift-packages/AtollHub/Sources/AtollHub/Model/EventDraft.swift`
- Create: `swift-packages/AtollHub/Sources/AtollHub/Calendar/SourceID.swift`
- Create: `swift-packages/AtollHub/Sources/AtollHub/Calendar/AtollTaskDone.swift`
- Test: `swift-packages/AtollHub/Tests/AtollHubTests/SourceIDTests.swift`
- Test: `swift-packages/AtollHub/Tests/AtollHubTests/AtollTaskDoneTests.swift`

- [ ] **Step 1: `ProviderWriteError` + Schreib-Methoden mit Default-Extensions**

In `Providers.swift` ans Ende anfügen (NICHT die bestehenden Read-Protokolle ändern, nur erweitern):

```swift
/// Fehler, wenn ein Provider eine Schreib-Operation nicht unterstützt.
public enum ProviderWriteError: Error, Sendable, Equatable {
  case unsupported            // dieser Provider kann das nicht (Default)
  case notFound               // Ziel-Objekt (Task/Event) nicht gefunden
  case invalid(String)        // ungültige Eingabe
}

public extension TodoProvider {
  /// Schaltet den Erledigt-Status einer Aufgabe um. Default: nicht unterstützt.
  func setDone(taskId: String, isDone: Bool) async throws {
    throw ProviderWriteError.unsupported
  }
  /// Legt eine neue Aufgabe an (Liste optional). Default: nicht unterstützt.
  func createTask(title: String, due: Date?, listId: String?) async throws {
    throw ProviderWriteError.unsupported
  }
}

public extension CalendarProvider {
  /// Erstellt einen Termin und liefert ihn quellneutral zurück. Default: nicht unterstützt.
  func createEvent(_ draft: EventDraft) async throws -> UnifiedEvent {
    throw ProviderWriteError.unsupported
  }
  /// Aktualisiert einen Termin (per UnifiedEvent.id). Default: nicht unterstützt.
  func updateEvent(id: String, with draft: EventDraft) async throws -> UnifiedEvent {
    throw ProviderWriteError.unsupported
  }
  /// Löscht einen Termin (per UnifiedEvent.id). Default: nicht unterstützt.
  func deleteEvent(id: String) async throws {
    throw ProviderWriteError.unsupported
  }
}
```

> **Wichtig:** Die Default-Implementierungen liegen in einer **Protocol-Extension** (nicht im Protokoll-Body), damit bestehende Conformer (AtollEventsAdapter, AppleContactsAdapter, …) ohne Änderung weiter kompilieren. Nur die schreibfähigen Adapter (Tasks 3–5) überschreiben sie.

- [ ] **Step 2: `EventDraft` Eingabemodell**

`swift-packages/AtollHub/Sources/AtollHub/Model/EventDraft.swift`:

```swift
import Foundation

/// Quellneutrale Eingabe für Termin-Erstellen/-Bearbeiten. `calendarId == nil`
/// heißt „Standard-Kalender des Geräts".
public struct EventDraft: Sendable, Equatable {
  public var title: String
  public var start: Date
  public var end: Date
  public var isAllDay: Bool
  public var location: String?
  public var calendarId: String?

  public init(title: String, start: Date, end: Date, isAllDay: Bool = false,
              location: String? = nil, calendarId: String? = nil) {
    self.title = title; self.start = start; self.end = end
    self.isAllDay = isAllDay; self.location = location; self.calendarId = calendarId
  }
}
```

- [ ] **Step 3: Failing Test für `SourceID`**

`swift-packages/AtollHub/Tests/AtollHubTests/SourceIDTests.swift`:

```swift
import XCTest
@testable import AtollHub

final class SourceIDTests: XCTestCase {
  func test_stripsApplePrefix() {
    XCTAssertEqual(SourceID.raw(from: "apple:ABC-123"), "ABC-123")
  }
  func test_stripsAtollPrefix() {
    XCTAssertEqual(SourceID.raw(from: "atoll:d1e2f3"), "d1e2f3")
  }
  func test_keepsValueAfterFirstColonOnly() {
    XCTAssertEqual(SourceID.raw(from: "apple:has:colons"), "has:colons")
  }
  func test_noPrefixReturnsWholeString() {
    XCTAssertEqual(SourceID.raw(from: "plainid"), "plainid")
  }
}
```

- [ ] **Step 4: Test ausführen — soll fehlschlagen**

Run: `cd swift-packages/AtollHub && swift test --filter SourceIDTests`
Expected: FAIL — `cannot find 'SourceID' in scope`.

- [ ] **Step 5: `SourceID` implementieren**

`swift-packages/AtollHub/Sources/AtollHub/Calendar/SourceID.swift`:

```swift
import Foundation

/// Trennt das Quell-Präfix (`apple:` / `atoll:`) von der rohen Anbieter-Id ab,
/// die `UnifiedEvent`/`UnifiedTask` in ihrer `id` tragen.
public enum SourceID {
  /// Liefert alles nach dem ERSTEN Doppelpunkt; ohne Doppelpunkt den ganzen String.
  public static func raw(from id: String) -> String {
    guard let i = id.firstIndex(of: ":") else { return id }
    return String(id[id.index(after: i)...])
  }
}
```

- [ ] **Step 6: Failing Test für `AtollTaskDone`**

`swift-packages/AtollHub/Tests/AtollHubTests/AtollTaskDoneTests.swift`:

```swift
import XCTest
@testable import AtollHub

final class AtollTaskDoneTests: XCTestCase {
  func test_donePatch_setsResolvedAndCompletedAt() {
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let p = AtollTaskDone.patch(isDone: true, now: now)
    XCTAssertEqual(p.status, "resolved")
    XCTAssertNotNil(p.completedAt)              // ISO-8601-String
    XCTAssertTrue(p.completedAt?.contains("2023") ?? false)
  }
  func test_undonePatch_setsOpenAndNilCompletedAt() {
    let p = AtollTaskDone.patch(isDone: false, now: Date())
    XCTAssertEqual(p.status, "open")
    XCTAssertNil(p.completedAt)
  }
}
```

- [ ] **Step 7: Test ausführen — soll fehlschlagen**

Run: `cd swift-packages/AtollHub && swift test --filter AtollTaskDoneTests`
Expected: FAIL — `cannot find 'AtollTaskDone' in scope`.

- [ ] **Step 8: `AtollTaskDone` implementieren**

`swift-packages/AtollHub/Sources/AtollHub/Calendar/AtollTaskDone.swift`:

```swift
import Foundation

/// Reine Logik für das Erledigt-Umschalten eines Atoll-Tasks (`contact_events`).
/// Done → `status = "resolved"` + `completed_at` (ISO-8601); Undone → `status = "open"` + `nil`.
public enum AtollTaskDone {
  public struct Patch: Equatable, Sendable {
    public let status: String
    public let completedAt: String?     // ISO-8601 oder nil
  }

  public static func patch(isDone: Bool, now: Date) -> Patch {
    guard isDone else { return Patch(status: "open", completedAt: nil) }
    let iso = ISO8601DateFormatter()
    iso.formatOptions = [.withInternetDateTime]
    return Patch(status: "resolved", completedAt: iso.string(from: now))
  }
}
```

- [ ] **Step 9: Volle Suite grün + Commit**

Run: `cd swift-packages/AtollHub && swift test`
Expected: PASS — alle Suiten grün (inkl. der bestehenden 92 Tests; die Protocol-Extension bricht keine Conformance).

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add swift-packages/AtollHub/Sources/AtollHub swift-packages/AtollHub/Tests/AtollHubTests/SourceIDTests.swift swift-packages/AtollHub/Tests/AtollHubTests/AtollTaskDoneTests.swift
git commit -m "AtollHub: Schreib-Protokolle (Todo/Calendar) + SourceID + AtollTaskDone + EventDraft (rein/getestet)"
```

---

## Task 2: Hub-Routing (AtollHub, TDD mit Fakes)

**Files:**
- Modify: `swift-packages/AtollHub/Sources/AtollHub/Hub/Hub.swift`
- Test: `swift-packages/AtollHub/Tests/AtollHubTests/HubRoutingTests.swift`

- [ ] **Step 1: Failing Test mit Fake-Providern**

`swift-packages/AtollHub/Tests/AtollHubTests/HubRoutingTests.swift`:

```swift
import XCTest
@testable import AtollHub

@MainActor
final class HubRoutingTests: XCTestCase {
  // Fake-Provider, die Schreibaufrufe protokollieren.
  final class FakeTodo: TodoProvider {
    var doneCalls: [(String, Bool)] = []
    func tasks() async throws -> [UnifiedTask] { [] }
    func setDone(taskId: String, isDone: Bool) async throws { doneCalls.append((taskId, isDone)) }
  }
  final class FakeCalendar: CalendarProvider {
    var created: [EventDraft] = []
    func events(in interval: DateInterval) async throws -> [UnifiedEvent] { [] }
    func createEvent(_ draft: EventDraft) async throws -> UnifiedEvent {
      created.append(draft)
      return UnifiedEvent(id: "apple:new", source: AccountRef(accountId: "a", type: .apple),
                          title: draft.title, start: draft.start, end: draft.end,
                          isAllDay: draft.isAllDay, location: draft.location)
    }
  }

  private func account(_ id: String, _ type: AccountType) -> Account {
    Account(id: id, type: type, displayName: id, capabilities: [.todo, .calendar])
  }

  func test_setTaskDone_routesToMatchingSource() async throws {
    let apple = FakeTodo(), atoll = FakeTodo()
    let hub = Hub()
    hub.connect(AccountConnection(account: account("apple", .apple), todo: apple))
    hub.connect(AccountConnection(account: account("atoll", .atoll), todo: atoll))

    let task = UnifiedTask(id: "atoll:42", source: AccountRef(accountId: "atoll", type: .atoll),
                           title: "x", due: nil, isDone: false)
    try await hub.setTaskDone(task, done: true)

    XCTAssertEqual(atoll.doneCalls.count, 1)
    XCTAssertEqual(atoll.doneCalls.first?.0, "atoll:42")
    XCTAssertEqual(atoll.doneCalls.first?.1, true)
    XCTAssertTrue(apple.doneCalls.isEmpty)        // nicht ans falsche Konto
  }

  func test_createEvent_routesToAppleCalendar() async throws {
    let cal = FakeCalendar()
    let hub = Hub()
    hub.connect(AccountConnection(account: account("apple", .apple), calendar: cal))
    let draft = EventDraft(title: "Meeting", start: Date(timeIntervalSince1970: 0),
                           end: Date(timeIntervalSince1970: 3600))
    let ev = try await hub.createEvent(draft)
    XCTAssertEqual(cal.created.count, 1)
    XCTAssertEqual(ev.title, "Meeting")
  }

  func test_setTaskDone_throwsWhenNoMatchingConnection() async {
    let hub = Hub()
    let task = UnifiedTask(id: "atoll:1", source: AccountRef(accountId: "atoll", type: .atoll),
                           title: "x", due: nil, isDone: false)
    do { try await hub.setTaskDone(task, done: true); XCTFail("should throw") }
    catch { /* erwartet */ }
  }
}
```

> Prüfe die echten Initializer-Signaturen beim Schreiben des Tests: `Account(...)` (Felder/Reihenfolge in `Model/Account.swift`) und `UnifiedTask(...)` (in `Model/UnifiedModels.swift:66` — Felder: id, source, title, due, isDone, listName?, listColorHex?, isFlagged?, priority?, notes?). Passe die Argumente an die tatsächliche API an; nutze nur Pflichtfelder + Defaults.

- [ ] **Step 2: Test ausführen — soll fehlschlagen**

Run: `cd swift-packages/AtollHub && swift test --filter HubRoutingTests`
Expected: FAIL — `value of type 'Hub' has no member 'setTaskDone'`.

- [ ] **Step 3: Routing-Methoden im Hub**

In `Hub.swift` in der `Hub`-Klasse (nach der Aggregations-`MARK`) ergänzen:

```swift
  // MARK: – Schreiben (Routing an die passende Verbindung)

  /// Schaltet den Erledigt-Status eines Tasks um — am Konto, das zur Quelle passt.
  public func setTaskDone(_ task: UnifiedTask, done: Bool) async throws {
    guard let conn = connections.first(where: {
      $0.account.type == task.source.type && $0.todo != nil
    }), let todo = conn.todo else {
      throw ProviderWriteError.notFound
    }
    try await todo.setDone(taskId: task.id, isDone: done)
  }

  /// Erstellt einen Termin im ersten schreibfähigen **Apple**-Kalender-Konto.
  @discardableResult
  public func createEvent(_ draft: EventDraft) async throws -> UnifiedEvent {
    guard let cal = appleCalendar else { throw ProviderWriteError.notFound }
    return try await cal.createEvent(draft)
  }

  @discardableResult
  public func updateEvent(id: String, with draft: EventDraft) async throws -> UnifiedEvent {
    guard let cal = appleCalendar else { throw ProviderWriteError.notFound }
    return try await cal.updateEvent(id: id, with: draft)
  }

  public func deleteEvent(id: String) async throws {
    guard let cal = appleCalendar else { throw ProviderWriteError.notFound }
    try await cal.deleteEvent(id: id)
  }

  /// Der Apple-Kalender-Provider (Schreiben geht nur nach Apple; Atoll-Events sind read-only).
  private var appleCalendar: CalendarProvider? {
    connections.first(where: { $0.account.type == .apple && $0.calendar != nil })?.calendar
  }
```

- [ ] **Step 4: Test grün + volle Suite + Commit**

Run: `cd swift-packages/AtollHub && swift test`
Expected: PASS — alles grün.

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add swift-packages/AtollHub/Sources/AtollHub/Hub/Hub.swift swift-packages/AtollHub/Tests/AtollHubTests/HubRoutingTests.swift
git commit -m "AtollHub: Hub routet Schreib-Aktionen (setTaskDone/createEvent/update/delete) an die Quelle"
```

---

## Task 3: AppleRemindersAdapter — Schreiben (ComHub)

**Files:**
- Modify: `apps/comhub-native/ComHub/Tasks/AppleRemindersAdapter.swift`

- [ ] **Step 1: `setDone` + `createTask` implementieren**

READ die Datei zuerst (sie hält den `EKEventStore` als `nonisolated(unsafe)` und mappt `id = "apple:\(r.calendarItemIdentifier)"`). In der struct ergänzen (Methoden, die die Protocol-Defaults überschreiben):

```swift
  func setDone(taskId: String, isDone: Bool) async throws {
    let identifier = SourceID.raw(from: taskId)
    guard let item = store.calendarItem(withIdentifier: identifier) as? EKReminder else {
      throw ProviderWriteError.notFound
    }
    item.isCompleted = isDone               // setzt/entfernt completionDate automatisch
    try store.save(item, commit: true)
  }

  func createTask(title: String, due: Date?, listId: String?) async throws {
    let reminder = EKReminder(eventStore: store)
    reminder.title = title
    if let listId, let cal = store.calendar(withIdentifier: listId) {
      reminder.calendar = cal
    } else {
      reminder.calendar = store.defaultCalendarForNewReminders()
    }
    if let due {
      reminder.dueDateComponents = Calendar.current.dateComponents(
        [.year, .month, .day, .hour, .minute], from: due)
    }
    try store.save(reminder, commit: true)
  }
```

> `SourceID` ist aus AtollHub (bereits importiert). `EKReminder` verlässt die Methode nicht (kein Sendable-Übertritt). `store` ist `nonisolated(unsafe)` — passe den exakten Zugriff an die reale Schreibweise in der Datei an (ggf. `self.store`).

- [ ] **Step 2: Build verifizieren**

Run:
```bash
cd /Users/dominik/Desktop/Developer/Dispo/apps/comhub-native
rm -rf "ComHub 2.xcodeproj" 2>/dev/null; true
xcodegen generate
xcodebuild -scheme ComHub -destination 'platform=macOS,arch=arm64' build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add apps/comhub-native/ComHub/Tasks/AppleRemindersAdapter.swift
git commit -m "ComHub: AppleRemindersAdapter schreibt (Erledigt umschalten + Erinnerung anlegen)"
```

---

## Task 4: AtollTasksAdapter — Schreiben (ComHub)

**Files:**
- Modify: `apps/comhub-native/ComHub/Tasks/AtollTasksAdapter.swift`

- [ ] **Step 1: `setDone` via `contact_events.update`**

In der struct (sie hält `private let supabase = SupabaseClient.shared`) ergänzen:

```swift
  func setDone(taskId: String, isDone: Bool) async throws {
    let rowId = SourceID.raw(from: taskId)
    let patch = AtollTaskDone.patch(isDone: isDone, now: Date())
    struct Update: Encodable {
      let status: String
      let payload_completed_at: String?
    }
    // payload ist JSONB; wir patchen nur completed_at über eine eigene RPC-freie
    // Variante: status direkt, completed_at im payload. supabase-swift erlaubt
    // verschachteltes JSON nicht trivial per .update — daher zwei Felder:
    _ = try await supabase
      .from("contact_events")
      .update(["status": patch.status])
      .eq("id", value: rowId)
      .execute()
    // completed_at im JSONB-payload setzen/entfernen via RPC-freier Merge:
    let completed = AnyJSON.string(patch.completedAt ?? "")
    let payloadValue: AnyJSON = patch.completedAt == nil ? AnyJSON.null
      : AnyJSON.object(["completed_at": completed])
    _ = try? await supabase
      .from("contact_events")
      .update(["payload": payloadValue])
      .eq("id", value: rowId)
      .execute()
  }
```

> **Achtung — verifiziere die supabase-swift-API für JSONB-Updates.** Wenn `update(["payload": AnyJSON…])` nicht typt, NUTZE STATTDESSEN die einfachere, sichere Variante: nur `status` aktualisieren (das genügt für die Done-Erkennung, denn `tasks()` liest `done = row.status != "open" || completedAt != nil`). Lösche dann den zweiten `update`-Block komplett und kommentiere: „completed_at wird vom Backend/Trigger gesetzt; status genügt für die App-Logik". Bevorzuge die robuste Status-only-Variante, wenn der payload-Merge zickt:

```swift
  func setDone(taskId: String, isDone: Bool) async throws {
    let rowId = SourceID.raw(from: taskId)
    let status = isDone ? "resolved" : "open"
    _ = try await supabase
      .from("contact_events")
      .update(["status": status])
      .eq("id", value: rowId)
      .execute()
  }
```

Entscheide beim Implementieren: **erst den payload-Merge probieren; wenn er nicht sauber kompiliert, die Status-only-Variante nehmen** (sie ist mit `tasks()` konsistent). Dokumentiere die Wahl im Commit-Body.

- [ ] **Step 2: Build verifizieren**

Run:
```bash
cd /Users/dominik/Desktop/Developer/Dispo/apps/comhub-native
rm -rf "ComHub 2.xcodeproj" 2>/dev/null; true
xcodegen generate
xcodebuild -scheme ComHub -destination 'platform=macOS,arch=arm64' build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add apps/comhub-native/ComHub/Tasks/AtollTasksAdapter.swift
git commit -m "ComHub: AtollTasksAdapter schreibt Erledigt-Status nach contact_events"
```

---

## Task 5: AppleCalendarAdapter — Termin erstellen/bearbeiten/löschen (ComHub)

**Files:**
- Modify: `apps/comhub-native/ComHub/Adapters/AppleCalendarAdapter.swift`

- [ ] **Step 1: Schreib-Methoden implementieren**

READ die Datei (EKEventStore, `id = "apple:\(eventIdentifier)"`, `hex(from:)`-Helfer aus D2c, nutzt `AppleEventMapper.event(...)`). In der struct ergänzen:

```swift
  func createEvent(_ draft: EventDraft) async throws -> UnifiedEvent {
    let e = EKEvent(eventStore: store)
    apply(draft, to: e)
    try store.save(e, span: .thisEvent, commit: true)
    return mapped(e)
  }

  func updateEvent(id: String, with draft: EventDraft) async throws -> UnifiedEvent {
    let identifier = SourceID.raw(from: id)
    guard let e = store.event(withIdentifier: identifier) else { throw ProviderWriteError.notFound }
    apply(draft, to: e)
    try store.save(e, span: .thisEvent, commit: true)
    return mapped(e)
  }

  func deleteEvent(id: String) async throws {
    let identifier = SourceID.raw(from: id)
    guard let e = store.event(withIdentifier: identifier) else { throw ProviderWriteError.notFound }
    try store.remove(e, span: .thisEvent, commit: true)
  }

  private func apply(_ draft: EventDraft, to e: EKEvent) {
    e.title = draft.title
    e.startDate = draft.start
    e.endDate = draft.end
    e.isAllDay = draft.isAllDay
    e.location = draft.location
    if let calId = draft.calendarId, let cal = store.calendar(withIdentifier: calId) {
      e.calendar = cal
    } else if e.calendar == nil {
      e.calendar = store.defaultCalendarForNewEvents
    }
  }

  private func mapped(_ e: EKEvent) -> UnifiedEvent {
    AppleEventMapper.event(
      accountId: accountId,
      identifier: e.eventIdentifier ?? "ts-\(e.startDate.timeIntervalSince1970)",
      title: e.title ?? "", start: e.startDate, end: e.endDate,
      isAllDay: e.isAllDay, location: e.location,
      calendarId: e.calendar?.calendarIdentifier,
      colorHex: e.calendar?.cgColor.flatMap(Self.hex(from:))
    )
  }
```

> Passe `accountId`/`store`/`Self.hex(from:)` an die realen Namen in der Datei an (der `mapped`-Body spiegelt die D2c-Fetch-Map). `EKEvent` verlässt die Methode nicht roh — nur das gemappte `UnifiedEvent`.

- [ ] **Step 2: Build verifizieren**

Run:
```bash
cd /Users/dominik/Desktop/Developer/Dispo/apps/comhub-native
rm -rf "ComHub 2.xcodeproj" 2>/dev/null; true
xcodegen generate
xcodebuild -scheme ComHub -destination 'platform=macOS,arch=arm64' build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add apps/comhub-native/ComHub/Adapters/AppleCalendarAdapter.swift
git commit -m "ComHub: AppleCalendarAdapter erstellt/bearbeitet/loescht Termine (EventKit)"
```

---

## Task 6: Aufgaben abhaken — Store + UI (ComHub)

**Files:**
- Modify: `apps/comhub-native/ComHub/Tasks/AufgabenStore.swift`
- Modify: `apps/comhub-native/ComHub/Tasks/TaskRow.swift`
- Modify: `apps/comhub-native/ComHub/Tasks/AufgabenModuleView.swift`
- Modify: `apps/comhub-native/ComHub/Cockpit/CockpitView.swift`

- [ ] **Step 1: `AufgabenStore.toggleDone` (optimistisch)**

In `AufgabenStore.swift` ergänzen (der Store hält `private(set) var all: [UnifiedTask]` und `reload(using:)`):

```swift
  /// Schaltet Erledigt optimistisch um (sofortige UI-Reaktion), schreibt über
  /// den Hub und lädt bei Fehler neu (Rollback).
  func toggleDone(_ task: UnifiedTask, using hub: Hub) async {
    let target = !task.isDone
    if let i = all.firstIndex(where: { $0.id == task.id }) {
      all[i] = all[i].withDone(target)        // lokale Spiegelung
    }
    do {
      try await hub.setTaskDone(task, done: target)
    } catch {
      await reload(using: hub)                 // Rollback bei Fehler
    }
  }
```

> `UnifiedTask` ist ein `struct` mit `let`-Feldern (in AtollHub). Für die optimistische Spiegelung brauchst du eine Kopie mit geändertem `isDone`. Falls keine `withDone`-Helper existiert, ergänze in AtollHub `Model/UnifiedModels.swift` eine kleine Extension:
> ```swift
> public extension UnifiedTask {
>   func withDone(_ done: Bool) -> UnifiedTask {
>     UnifiedTask(id: id, source: source, title: title, due: due, isDone: done,
>                 listName: listName, listColorHex: listColorHex, isFlagged: isFlagged,
>                 priority: priority, notes: notes)
>   }
> }
> ```
> **Prüfe die echte `UnifiedTask`-Memberwise-Init-Signatur** (Felder/Reihenfolge) und kopiere ALLE Felder. Diese Extension gehört ins AtollHub-Paket — falls du sie hinzufügst, committe sie mit Task 6 (oder ziehe sie in Task 1 vor). Build/Tests bleiben grün (additiv).

- [ ] **Step 2: `TaskRow` — Checkbox interaktiv**

READ `TaskRow.swift`. Die View bekommt einen optionalen Toggle-Callback. Signatur erweitern:

```swift
struct TaskRow: View {
  let task: UnifiedTask
  var showList: Bool = false
  var onToggle: (() -> Void)? = nil
  …
```
Die Checkbox (das `Circle`/`checkmark`-Element) in einen Button wickeln:
```swift
      Button { onToggle?() } label: {
        Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
          .font(.system(size: 18))
          .foregroundStyle(task.isDone ? AnyShapeStyle(CoColor.accent) : AnyShapeStyle(.tertiary))
      }
      .buttonStyle(.plain)
```
> Passe an die reale Checkbox-Stelle (`TaskRow.swift:19`) an — ersetze NUR das bisherige read-only Kreis-Element durch den Button; Rest der Zeile unverändert.

- [ ] **Step 3: `AufgabenModuleView` — Toggle verdrahten**

In `AufgabenModuleView.swift` die beiden `TaskRow(...)`-Aufrufe (offene + erledigte Liste, ca. Zeile 85/89) um den Callback ergänzen:

```swift
            ForEach(r.open) { t in
              TaskRow(task: t, showList: store.list == nil) {
                Task { await store.toggleDone(t, using: hub) }
              }
              Divider()
            }
```
analog für `r.done`. `hub` ist `@Environment(Hub.self) private var hub` (bereits vorhanden).

- [ ] **Step 4: Heute-Cockpit — Aufgaben-Widget abhakbar**

READ `CockpitView.swift` um Zeile 172 (Aufgaben-Widget, `openTasks.prefix(4)`). Jede Aufgabenzeile bekommt dieselbe abhakbare Checkbox. Wenn das Widget bereits eine `TaskRow` o. ä. nutzt, gib den Callback durch:
```swift
              TaskRow(task: t) { Task { await tasksToggle(t) } }
```
Falls das Widget eine eigene Inline-Zeile rendert, ersetze deren Kreis durch denselben Button und rufe eine lokale Helper-Funktion, die über den `CockpitStore`/`hub` schreibt. **Wenn der Cockpit-Store keine Tasks hält** (nur eine Vorschau aus dem Hub), schreibe direkt:
```swift
  @Environment(Hub.self) private var hub
  private func tasksToggle(_ t: UnifiedTask) async {
    try? await hub.setTaskDone(t, done: !t.isDone)
    await store.reload()     // Cockpit neu laden (realer Reload-Name prüfen)
  }
```
> Passe `store.reload()` an den realen Cockpit-Reload an. Ziel: Checkbox im Heute-Widget schaltet den Status und aktualisiert die Liste.

- [ ] **Step 5: Generieren + Build**

Run:
```bash
cd /Users/dominik/Desktop/Developer/Dispo/apps/comhub-native
rm -rf "ComHub 2.xcodeproj" 2>/dev/null; true
xcodegen generate
xcodebuild -scheme ComHub -destination 'platform=macOS,arch=arm64' build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`. (Falls die `withDone`-Extension in AtollHub neu ist: auch `cd swift-packages/AtollHub && swift test` grün.)

- [ ] **Step 6: Zwischen-Smoke (empfohlen)** — Aufgaben-Liste: Kreis antippen → Häkchen, Aufgabe wandert nach „erledigt"; erneut antippen → zurück. Heute-Cockpit-Widget: dieselbe Aktion. Apple-Erinnerung ändert sich in der echten Erinnerungen-App; Atoll-Task in Supabase.

- [ ] **Step 7: Commit**

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add swift-packages/AtollHub apps/comhub-native/ComHub/Tasks/AufgabenStore.swift apps/comhub-native/ComHub/Tasks/TaskRow.swift apps/comhub-native/ComHub/Tasks/AufgabenModuleView.swift apps/comhub-native/ComHub/Cockpit/CockpitView.swift
git commit -m "ComHub: Aufgaben abhaken (Aufgaben-Liste + Heute-Cockpit, optimistisch)"
```

---

## Task 7: Termin erstellen/bearbeiten/löschen — UI (ComHub)

**Files:**
- Create: `apps/comhub-native/ComHub/Calendar/EventEditSheet.swift`
- Modify: `apps/comhub-native/ComHub/Calendar/CalendarStore.swift`
- Modify: `apps/comhub-native/ComHub/Calendar/CalendarModuleView.swift`
- Modify: `apps/comhub-native/ComHub/Calendar/EventBlockView.swift`

- [ ] **Step 1: `CalendarStore` — Schreib-Durchreichen + Reload**

In `CalendarStore.swift` ergänzen (Store hält `events`/`eventsByDay`/`enabledCalendarIds`, `reload(using:)`):

```swift
  func create(_ draft: EventDraft, using hub: Hub) async {
    do { _ = try await hub.createEvent(draft); await reload(using: hub) }
    catch { errors.append("create: \(error)") }   // realen Fehler-Property-Namen prüfen
  }
  func update(id: String, with draft: EventDraft, using hub: Hub) async {
    do { _ = try await hub.updateEvent(id: id, with: draft); await reload(using: hub) }
    catch { errors.append("update: \(error)") }
  }
  func delete(id: String, using hub: Hub) async {
    do { try await hub.deleteEvent(id: id); await reload(using: hub) }
    catch { errors.append("delete: \(error)") }
  }
```
> Passe `errors`-Property an den realen Namen an (Investigator: `CalendarStore` hat ein `errors`-Feld). `EventDraft`/`Hub` aus AtollHub.

- [ ] **Step 2: `EventEditSheet` — Formular**

`apps/comhub-native/ComHub/Calendar/EventEditSheet.swift`:

```swift
import SwiftUI
import AtollHub

/// Erstellen/Bearbeiten eines Apple-Termins. `existing == nil` → Erstellen.
struct EventEditSheet: View {
  let existing: UnifiedEvent?
  let sources: CalendarSourcesStore?
  let onSave: (EventDraft) -> Void
  let onDelete: (() -> Void)?
  @Environment(\.dismiss) private var dismiss

  @State private var title = ""
  @State private var start = Date()
  @State private var end = Date().addingTimeInterval(3600)
  @State private var isAllDay = false
  @State private var location = ""
  @State private var calendarId: String?

  var body: some View {
    NavigationStack {
      Form {
        Section {
          TextField("Titel", text: $title)
          Toggle("Ganztägig", isOn: $isAllDay)
          DatePicker("Beginn", selection: $start)
          DatePicker("Ende", selection: $end)
          TextField("Ort", text: $location)
        }
        // Nur Apple-Kalender als Ziel (Atoll = "atoll" rausfiltern).
        if let appleSources = sources?.sources.filter({ $0.id != "atoll" }), !appleSources.isEmpty {
          Section("Kalender") {
            Picker("Kalender", selection: $calendarId) {
              ForEach(appleSources) { s in
                Text(s.title).tag(Optional(s.id))
              }
            }
          }
        }
        if let onDelete {
          Section {
            Button("Termin löschen", role: .destructive) { onDelete(); dismiss() }
          }
        }
      }
      .navigationTitle(existing == nil ? "Neuer Termin" : "Termin bearbeiten")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button("Sichern") {
            onSave(EventDraft(title: title, start: start, end: end, isAllDay: isAllDay,
                              location: location.isEmpty ? nil : location, calendarId: calendarId))
            dismiss()
          }.disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
        }
      }
      .onAppear {
        if let e = existing {
          title = e.title; start = e.start; end = e.end
          isAllDay = e.isAllDay; location = e.location ?? ""; calendarId = e.calendarId
        }
      }
    }
    #if os(macOS)
    .frame(minWidth: 420, minHeight: 420)
    #endif
  }
}
```

- [ ] **Step 3: `CalendarModuleView` — „+"-Button + Sheet-State**

READ `CalendarModuleView.swift`. Ergänzen:
1. State:
```swift
  @State private var editingEvent: UnifiedEvent?     // gesetzt beim Bearbeiten
  @State private var showCreate = false
```
2. Im `header` (neben dem Filter-Button aus D2c) einen „+"-Button:
```swift
      Button { showCreate = true } label: { Image(systemName: "plus") }
        .buttonStyle(.bordered)
```
3. Am `body` (z. B. nach dem bestehenden Filter-`.popover`) zwei Sheets:
```swift
    .sheet(isPresented: $showCreate) {
      EventEditSheet(existing: nil, sources: sources, onSave: { draft in
        Task { await store.create(draft, using: hub) }
      }, onDelete: nil)
    }
    .sheet(item: $editingEvent) { ev in
      EventEditSheet(existing: ev, sources: sources, onSave: { draft in
        Task { await store.update(id: ev.id, with: draft, using: hub) }
      }, onDelete: {
        Task { await store.delete(id: ev.id, using: hub) }
      })
    }
```
> `sources` (CalendarSourcesStore?) existiert aus D2c. `UnifiedEvent` muss `Identifiable` sein für `.sheet(item:)` — es ist `Identifiable` (hat `id`). `hub`/`store` reale Namen nutzen.

- [ ] **Step 4: Event-Tap → Bearbeiten**

In `EventBlockView.swift` (und/oder der Ganztags-Lane in `DayGridView`) einen Tap-Callback durchreichen. Minimal: `EventBlockView` bekommt `var onTap: (() -> Void)? = nil` und `.onTapGesture { onTap?() }`. In `DayGridView`/`CalendarModuleView` den Callback so setzen, dass er `editingEvent = ev` setzt.
> Wenn das Verdrahten des Taps durch mehrere View-Ebenen (DayGridView → EventBlockView) zu invasiv ist, ist als **Minimal-Variante** akzeptabel: nur das Erstellen (+-Button) plus Bearbeiten/Löschen über einen Tap **im Monats-/Tagesraster auf den Event-Block**. Dokumentiere im Commit, welche Tap-Ebenen verdrahtet wurden. Ziel: mindestens Erstellen + (Bearbeiten ODER Löschen) per UI erreichbar.

- [ ] **Step 5: Generieren + Build**

Run:
```bash
cd /Users/dominik/Desktop/Developer/Dispo/apps/comhub-native
rm -rf "ComHub 2.xcodeproj" 2>/dev/null; true
xcodegen generate
xcodebuild -scheme ComHub -destination 'platform=macOS,arch=arm64' build 2>&1 | tail -5
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 6: Manueller Smoke-Test** (echter Mac, Light + Dark)

- [ ] **Kalender → „+"**: Sheet, Titel/Zeit/Kalender wählen → Sichern → Termin erscheint in der richtigen Farbe; taucht auch in der Apple-Kalender-App auf.
- [ ] **Event antippen** → Bearbeiten-Sheet → Titel/Zeit ändern → Sichern → Änderung sichtbar.
- [ ] **Löschen** im Sheet → Termin verschwindet (App + Apple-Kalender).
- [ ] **Aufgaben/Heute**: Checkboxen schalten (aus Task 6) weiterhin korrekt.
- [ ] Dark Mode lesbar; Sheet auf macOS gut dimensioniert.

- [ ] **Step 7: Commit**

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add apps/comhub-native/ComHub/Calendar/EventEditSheet.swift apps/comhub-native/ComHub/Calendar/CalendarStore.swift apps/comhub-native/ComHub/Calendar/CalendarModuleView.swift apps/comhub-native/ComHub/Calendar/EventBlockView.swift apps/comhub-native/ComHub/Calendar/DayGridView.swift
git commit -m "ComHub: Termin erstellen/bearbeiten/loeschen (EventEditSheet + Kalender-Tap)"
```

---

## Task 8: Dokumentation (Phase 5a)

**Files:**
- Modify: `apps/comhub-native/README.md`

- [ ] **Step 1: Phase-5a-Zeile ergänzen**

Im Abschnitt `## Phasen-Stand` nach dem `**Phase 4a** …`-Absatz einfügen:

```markdown

**Phase 5a** — **Schreiben (Write-back)**: Aufgaben **abhaken** (Apple Erinnerungen
via EventKit + Atoll-Tasks via `contact_events`-Status) direkt in Liste und
Heute-Cockpit (optimistisch); **Termine erstellen/bearbeiten/löschen** im
Apple-Kalender (EventKit, Zielkalender wählbar) über ein `EventEditSheet`; neue
**Erinnerungen** anlegen. Quellneutral über den Hub geroutet (`setTaskDone`/
`createEvent`/`updateEvent`/`deleteEvent`). Reine Logik getestet in `AtollHub`
(`SourceID`, `AtollTaskDone`, Hub-Routing mit Fakes). Push/APNs folgt in Phase 5b.
```

- [ ] **Step 2: Commit**

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add apps/comhub-native/README.md
git commit -m "Docs: ComHub-README Phase 5a (Write-back)"
```

---

## Self-Review (durchgeführt)

**1. Abdeckung der Anforderung (alle vier vom User gewählten Aktionen):**
- „Aufgaben abhaken" → Tasks 3 (Apple) + 4 (Atoll) + 6 (Store/UI/Cockpit). ✔
- „Termin erstellen" → Task 5 (`createEvent`) + Task 7 (Sheet + „+"). ✔
- „Erinnerung erstellen" → Task 3 (`createTask`) — Adapter vorhanden; UI-Einstieg ist in 5a minimal gehalten (Erstellen über dieselbe Aufgaben-Oberfläche kann als kleiner Folge-Schritt ergänzt werden; der Schreibpfad ist fertig). ⚠ Hinweis unten.
- „Termin bearbeiten/löschen" → Task 5 (`updateEvent`/`deleteEvent`) + Task 7 (Tap → Sheet, Löschen-Button). ✔

> **Offen gehalten (klein):** Eine sichtbare „Neue Erinnerung"-Schaltfläche in der Aufgaben-Oberfläche ist nicht als eigener Task ausformuliert (der Schreibpfad `createTask` ist fertig). Falls gewünscht, in Task 6/7-Stil ein „+"-Feld in `AufgabenModuleView` ergänzen — sonst bleibt das Erinnerung-Erstellen über den fertigen Adapter erreichbar/für 5b/UI-Folge.

**2. Platzhalter-Scan:** Keine „TBD/TODO". Vollständiger Code je Schritt; Befehl + erwartete Ausgabe je Run. Zwei bewusst dokumentierte Implementierungs-Weichen (Atoll-payload-Merge vs. status-only in Task 4; Tap-Ebenen-Tiefe in Task 7) mit klarer Default-Empfehlung.

**3. Typ-Konsistenz:**
- `EventDraft` (Task 1) ↔ `CalendarProvider.create/update` (Task 1/2/5) ↔ `EventEditSheet`/`CalendarStore` (Task 7). ✔
- `SourceID.raw` (Task 1) ↔ Adapter-Id-Parsing (Tasks 3/5). ✔
- `AtollTaskDone.patch` (Task 1) ↔ AtollTasksAdapter (Task 4). ✔
- `Hub.setTaskDone/createEvent/...` (Task 2) ↔ Stores (Tasks 6/7). ✔
- `UnifiedTask.withDone` (Task 6, additiv in AtollHub) ↔ optimistische Spiegelung. ✔
- `ProviderWriteError` (Task 1) als einheitlicher Fehlertyp. ✔

**4. Verifikations-Disziplin:** Tasks 1–2 echte TDD (`swift test`, inkl. Fake-Provider-Routing + Rückwärtskompatibilität der 92 Bestandstests). Tasks 3–7 build-verifiziert; Task 6 Zwischen-Smoke, Task 7 voller manueller Smoke. Konform zu superpowers:verification-before-completion.

---

## Execution Handoff

**Plan komplett und gespeichert unter `docs/superpowers/plans/2026-06-02-comhub-phase5a-writeback.md`. Zwei Ausführungs-Optionen:**

**1. Subagent-Driven (empfohlen)** — frischer Subagent pro Task, Review zwischen den Tasks. (REQUIRED SUB-SKILL: superpowers:subagent-driven-development.)

**2. Inline-Ausführung** — Tasks in dieser Session, Batch mit Checkpoints. (REQUIRED SUB-SKILL: superpowers:executing-plans.)

**Welcher Ansatz?**
