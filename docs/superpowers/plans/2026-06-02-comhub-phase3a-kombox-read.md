# ComHub Phase 3a — Kombox lesen + Realtime Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Das **Kombox**-Modul (`.kombox`) in ComHub zeigt **lese-only** die Atoll-Comms: eine **Kontaktliste** (Konversationen mit letzter Nachricht, neueste zuerst) und einen **Verlauf** pro Kontakt (WhatsApp-Bubbles in/out, aufklappbare Mail-Karten, System-Marker, Tages-Trenner) — mit **Live-Updates** über Supabase-Realtime auf `contact_events`. Senden/Antworten/Löschen/Filter kommen in Phase 3b; der Privat-WhatsApp-WebView-Tab in 3c.

**Architecture:** Reine, getestete Logik (`KomboxEvent`-Modell, `KomboxMapper`, `KomboxDigest`) wandert nach `AtollHub`: Wire-Decodables für eine `contact_events`-Zeile (mit eingebettetem `contacts`), Mapping auf ein quellneutrales `KomboxEvent`, Gruppierung zu Konversationen (neueste pro Kontakt) und Tages-Sektionen für den Verlauf. Ein `KomboxStore` (`@MainActor @Observable`) im App-Target lädt über `SupabaseClient.shared` (`contact_events`-Select mit `contacts`-Embed) und abonniert **Realtime** (Channel auf `contact_events`, INSERT/UPDATE, RLS-gescoped) nach dem bewährten **invalidate→refetch**-Muster (Vorbild: `apps/atollcard-native/AtollCard/Repositories/LeadStore.swift`). Die UI (`KomboxModuleView` = Kontaktliste + Verlauf, plus die drei Zeilen-Typen) rendert aus dem Store. **Kein Backend-Change** — Konversationsliste wird **client-seitig** aus den jüngsten Events gruppiert.

**Tech Stack:** Swift 6 (strict concurrency complete), SwiftUI Multiplatform (iOS 26 / macOS 26), XcodeGen, XCTest, `supabase-swift` 2.46 (PostgREST `contacts`-Embed; Realtime V2 `channel().postgresChange(InsertAction.self, …)` + `subscribeWithError()`). Reuse: Phase-0 `MessageDirection`, `ComHubModule.kombox`.

---

## Scope-Grenzen (bewusst)

- **Nur lesen.** Composer/Senden (`comms-outbound`), Antworten, Löschen, Status, Filter Alle/WA/Mail + Suche, Quick-Log → **Phase 3b**. Privat-WhatsApp-WebView → **Phase 3c**.
- **Quelle = `contact_events`** (nicht die breitere `v_contact_timeline`-View): Kombox = Comms/geloggte Events; deckt sich mit dem Realtime-Kanal (`contact_events` ist in der Publication, `v_*` nicht). Die UI rendert drei sichtbare Typen: **WhatsApp** (`whatsapp_log`), **Mail** (`email_external`), **System** (alles andere: note/call/task/meeting…).
- **Kein read/unread** im Schema → **kein Ungelesen-Badge** in 3a (es existiert serverseitig kein Flag; Inbound wird vom Webhook auto-gelesen). Die Spec-Zeile „Ungelesen-Badge" ist damit gegenstandslos und wird bewusst weggelassen.
- **Konversationsliste client-seitig**: jüngste N `contact_events` (mit `contacts`-Embed) laden, nach `contact_id` gruppieren, neuestes Event je Kontakt → Konversation. Kein neues DB-View/Backend.
- **Realtime = invalidate→refetch**: bei INSERT/UPDATE auf `contact_events` lädt der Store die Konversationsliste neu und (falls betroffen) den offenen Verlauf — wie der Web-Hook `useContactTimelineRealtime`. (Realtime-Payload trägt keine Joins, daher refetch statt Inkrement.)

---

## File Structure

**Geändertes Paket — `swift-packages/AtollHub/`:**
- `Sources/AtollHub/Kombox/KomboxEvent.swift` — `KomboxKind`, `KomboxEvent` (quellneutral), `KomboxConversation`, `KomboxDaySection`.
- `Sources/AtollHub/Kombox/KomboxWire.swift` — `KomboxPayload`, `KomboxContactRef`, `KomboxEventRow` (Decodable, Wire-Format).
- `Sources/AtollHub/Kombox/KomboxMapper.swift` — `KomboxEventRow` → `KomboxEvent` (Timestamp-Parse, Typ/Direction-Klassifikation).
- `Sources/AtollHub/Kombox/KomboxDigest.swift` — `conversations(from:)`, `threadSections(_:calendar:)`.
- `Tests/AtollHubTests/KomboxMapperTests.swift`, `KomboxDigestTests.swift`.

**Neue App-Dateien — `apps/comhub-native/ComHub/Kombox/`:**
- `KomboxStore.swift` — `@Observable` Lade-Zustand + Realtime (Konversationen + Verlauf).
- `KomboxRows.swift` — `KomboxBubble`, `KomboxMailCard`, `KomboxSystemMarker`.
- `ThreadView.swift` — Verlauf eines Kontakts (Tages-Sektionen + Zeilen).
- `ConversationListView.swift` — Kontaktliste (Konversationen).
- `KomboxModuleView.swift` — 2-Pane (Liste + Verlauf).

**Geänderte App-Datei:**
- `ComHub/Shell/HubShell.swift` — `.kombox` zeigt `KomboxModuleView`.

**Doku:**
- `apps/comhub-native/README.md` — Phase-3a-Zeile.

---

## Task 1: `KomboxEvent`-Modell + Wire-Decodables + `KomboxMapper` (AtollHub)

**Files:**
- Create: `swift-packages/AtollHub/Sources/AtollHub/Kombox/KomboxEvent.swift`
- Create: `swift-packages/AtollHub/Sources/AtollHub/Kombox/KomboxWire.swift`
- Create: `swift-packages/AtollHub/Sources/AtollHub/Kombox/KomboxMapper.swift`
- Test: `swift-packages/AtollHub/Tests/AtollHubTests/KomboxMapperTests.swift`

- [ ] **Step 1: Failing Test schreiben**

`swift-packages/AtollHub/Tests/AtollHubTests/KomboxMapperTests.swift`:

```swift
import XCTest
@testable import AtollHub

final class KomboxMapperTests: XCTestCase {
  private func rows(_ json: String) throws -> [KomboxEventRow] {
    try JSONDecoder().decode([KomboxEventRow].self, from: Data(json.utf8))
  }

  func test_mapsWhatsappOutboundWithContactName() throws {
    let r = try rows("""
    [{
      "id": "e1", "contact_id": "c1", "event_type": "whatsapp_log",
      "occurred_at": "2026-06-02T14:30:00+00:00",
      "summary": "Hallo", "body": "Hallo Welt", "status": "open",
      "payload": {"direction": "outbound"},
      "contacts": {"id":"c1","kind":"person","first_name":"Anna","last_name":"Muster"}
    }]
    """)
    let events = KomboxMapper.events(from: r)
    XCTAssertEqual(events.count, 1)
    let e = events[0]
    XCTAssertEqual(e.id, "e1")
    XCTAssertEqual(e.contactId, "c1")
    XCTAssertEqual(e.contactName, "Anna Muster")
    XCTAssertEqual(e.kind, .whatsapp)
    XCTAssertEqual(e.direction, .outbound)
    XCTAssertEqual(e.summary, "Hallo")
    XCTAssertNil(e.subject)
  }

  func test_mapsEmailInboundWithSubjectFromPayload() throws {
    let r = try rows("""
    [{
      "id": "e2", "contact_id": "c2", "event_type": "email_external",
      "occurred_at": "2026-06-02T08:15:00+00:00",
      "summary": "Re: Kurs", "body": "Text", "status": "open",
      "payload": {"direction": "inbound", "subject": "Re: Kurs"},
      "contacts": {"id":"c2","kind":"organization","trading_name":"Tauchschule Z"}
    }]
    """)
    let e = KomboxMapper.events(from: r)[0]
    XCTAssertEqual(e.kind, .email)
    XCTAssertEqual(e.direction, .inbound)
    XCTAssertEqual(e.subject, "Re: Kurs")
    XCTAssertEqual(e.contactName, "Tauchschule Z")
  }

  func test_unknownTypeBecomesSystemAndNilDirection() throws {
    let r = try rows("""
    [{
      "id": "e3", "contact_id": "c3", "event_type": "note",
      "occurred_at": "2026-06-02T09:00:00+00:00",
      "summary": "Notiz", "body": null, "status": "open",
      "payload": null, "contacts": {"id":"c3","first_name":"Ben","last_name":"B"}
    }]
    """)
    let e = KomboxMapper.events(from: r)[0]
    XCTAssertEqual(e.kind, .system)
    XCTAssertNil(e.direction)
  }

  func test_parsesFractionalSecondsTimestamp() throws {
    let r = try rows("""
    [{
      "id": "e4", "contact_id": "c4", "event_type": "whatsapp_log",
      "occurred_at": "2026-06-02T14:30:00.123456+00:00",
      "summary": "x", "body": null, "status": "open",
      "payload": {"direction":"inbound"}, "contacts": {"id":"c4","first_name":"A","last_name":"B"}
    }]
    """)
    XCTAssertEqual(KomboxMapper.events(from: r).count, 1) // parst, wird nicht verworfen
  }

  func test_dropsRowWithUnparsableTimestamp() throws {
    let r = try rows("""
    [{
      "id": "bad", "contact_id": "c5", "event_type": "note",
      "occurred_at": "not-a-date",
      "summary": "x", "body": null, "status": "open",
      "payload": null, "contacts": {"id":"c5","first_name":"A","last_name":"B"}
    }]
    """)
    XCTAssertTrue(KomboxMapper.events(from: r).isEmpty)
  }
}
```

- [ ] **Step 2: Test ausführen — soll fehlschlagen**

Run: `cd swift-packages/AtollHub && swift test --filter KomboxMapperTests`
Expected: FAIL — `cannot find 'KomboxEventRow' in scope`.

- [ ] **Step 3: Implementieren**

`swift-packages/AtollHub/Sources/AtollHub/Kombox/KomboxEvent.swift`:

```swift
import Foundation

/// Sichtbarer Typ einer Kombox-Zeile (steuert die Darstellung).
public enum KomboxKind: String, Sendable, Equatable, Hashable {
  case whatsapp   // event_type "whatsapp_log"
  case email      // event_type "email_external"
  case system     // alles andere (note/call/task/meeting/…)
}

/// Quellneutrales Kombox-Event (eine `contact_events`-Zeile, UI-fertig).
public struct KomboxEvent: Sendable, Identifiable, Equatable, Hashable {
  public let id: String
  public let contactId: String
  public let contactName: String
  public let kind: KomboxKind
  public let direction: MessageDirection?   // nil bei System-Events
  public let summary: String
  public let body: String?
  public let subject: String?               // nur Mail
  public let timestamp: Date
  public let status: String                 // "open" | "resolved" | "archived"

  public init(id: String, contactId: String, contactName: String, kind: KomboxKind,
              direction: MessageDirection?, summary: String, body: String?,
              subject: String?, timestamp: Date, status: String) {
    self.id = id; self.contactId = contactId; self.contactName = contactName
    self.kind = kind; self.direction = direction; self.summary = summary
    self.body = body; self.subject = subject; self.timestamp = timestamp; self.status = status
  }
}

/// Eine Konversation = neuestes Event je Kontakt (für die Kontaktliste).
public struct KomboxConversation: Sendable, Identifiable, Equatable, Hashable {
  public let id: String           // = contactId
  public let contactName: String
  public let lastEvent: KomboxEvent
  public init(id: String, contactName: String, lastEvent: KomboxEvent) {
    self.id = id; self.contactName = contactName; self.lastEvent = lastEvent
  }
}

/// Eine Tages-Sektion im Verlauf (für Tages-Trenner).
public struct KomboxDaySection: Sendable, Identifiable, Equatable {
  public let id: Date             // = Tagesbeginn
  public let day: Date
  public let events: [KomboxEvent]
  public init(day: Date, events: [KomboxEvent]) {
    self.id = day; self.day = day; self.events = events
  }
}
```

`swift-packages/AtollHub/Sources/AtollHub/Kombox/KomboxWire.swift`:

```swift
import Foundation

/// JSONB `payload` einer `contact_events`-Zeile (Subset).
public struct KomboxPayload: Decodable, Sendable {
  public let direction: String?
  public let subject: String?
}

/// Eingebetteter `contacts`-Datensatz (PostgREST-Embed).
public struct KomboxContactRef: Decodable, Sendable {
  public let id: String
  public let kind: String?
  public let firstName: String?
  public let lastName: String?
  public let tradingName: String?
  public let legalName: String?
  enum CodingKeys: String, CodingKey {
    case id, kind
    case firstName = "first_name"
    case lastName = "last_name"
    case tradingName = "trading_name"
    case legalName = "legal_name"
  }
}

/// Wire-Format einer `contact_events`-Zeile, wie ComHub sie liest.
public struct KomboxEventRow: Decodable, Sendable {
  public let id: String
  public let contactId: String
  public let eventType: String
  public let occurredAt: String
  public let summary: String
  public let body: String?
  public let payload: KomboxPayload?
  public let status: String
  public let contacts: KomboxContactRef?
  enum CodingKeys: String, CodingKey {
    case id, summary, body, payload, status, contacts
    case contactId = "contact_id"
    case eventType = "event_type"
    case occurredAt = "occurred_at"
  }
}
```

`swift-packages/AtollHub/Sources/AtollHub/Kombox/KomboxMapper.swift`:

```swift
import Foundation

/// Übersetzt `contact_events`-Wire-Zeilen in quellneutrale `KomboxEvent`s.
/// Reine Funktion — der App-Store erledigt Netzwerk + Realtime.
public enum KomboxMapper {
  public static func events(from rows: [KomboxEventRow]) -> [KomboxEvent] {
    rows.compactMap { row in
      guard let ts = parseTimestamp(row.occurredAt) else { return nil }
      let kind: KomboxKind
      switch row.eventType {
      case "whatsapp_log":   kind = .whatsapp
      case "email_external": kind = .email
      default:               kind = .system
      }
      let direction: MessageDirection?
      switch row.payload?.direction {
      case "inbound":  direction = .inbound
      case "outbound": direction = .outbound
      default:         direction = nil
      }
      return KomboxEvent(
        id: row.id, contactId: row.contactId,
        contactName: contactName(row.contacts, fallback: row.contactId),
        kind: kind, direction: direction,
        summary: row.summary, body: row.body, subject: row.payload?.subject,
        timestamp: ts, status: row.status
      )
    }
  }

  /// Anzeigename: Person „Vor Nach", Organisation Trading/Legal, sonst Fallback-id.
  static func contactName(_ c: KomboxContactRef?, fallback: String) -> String {
    guard let c else { return fallback }
    if c.kind == "organization" {
      let n = (c.tradingName ?? c.legalName ?? "").trimmingCharacters(in: .whitespaces)
      return n.isEmpty ? fallback : n
    }
    let n = "\(c.firstName ?? "") \(c.lastName ?? "")".trimmingCharacters(in: .whitespaces)
    return n.isEmpty ? fallback : n
  }

  /// Parst Supabase-`timestamptz` (ISO8601, mit/ohne Sekundenbruchteile).
  static func parseTimestamp(_ s: String) -> Date? {
    let withFraction = ISO8601DateFormatter()
    withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let d = withFraction.date(from: s) { return d }
    let plain = ISO8601DateFormatter()
    plain.formatOptions = [.withInternetDateTime]
    return plain.date(from: s)
  }
}
```

- [ ] **Step 4: Test ausführen — soll grün sein**

Run: `cd swift-packages/AtollHub && swift test --filter KomboxMapperTests`
Expected: PASS — 5 Tests grün.

- [ ] **Step 5: Commit**

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add swift-packages/AtollHub/Sources/AtollHub/Kombox/KomboxEvent.swift swift-packages/AtollHub/Sources/AtollHub/Kombox/KomboxWire.swift swift-packages/AtollHub/Sources/AtollHub/Kombox/KomboxMapper.swift swift-packages/AtollHub/Tests/AtollHubTests/KomboxMapperTests.swift
git commit -m "AtollHub: KomboxEvent-Modell + Wire-Decodables + KomboxMapper"
```

---

## Task 2: `KomboxDigest.conversations` — Konversationen gruppieren (AtollHub)

**Files:**
- Create: `swift-packages/AtollHub/Sources/AtollHub/Kombox/KomboxDigest.swift`
- Test: `swift-packages/AtollHub/Tests/AtollHubTests/KomboxDigestTests.swift`

- [ ] **Step 1: Failing Test schreiben**

`swift-packages/AtollHub/Tests/AtollHubTests/KomboxDigestTests.swift`:

```swift
import XCTest
@testable import AtollHub

final class KomboxDigestTests: XCTestCase {
  private var cal: Calendar {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "Europe/Zurich")!
    c.firstWeekday = 2
    return c
  }
  private func ts(_ s: String) -> Date {
    let f = DateFormatter(); f.calendar = cal; f.timeZone = cal.timeZone
    f.dateFormat = "yyyy-MM-dd HH:mm"; f.locale = Locale(identifier: "en_US_POSIX")
    return f.date(from: s)!
  }
  private func ev(_ id: String, contact: String, name: String, _ time: String,
                  kind: KomboxKind = .whatsapp) -> KomboxEvent {
    KomboxEvent(id: id, contactId: contact, contactName: name, kind: kind,
                direction: .inbound, summary: id, body: nil, subject: nil,
                timestamp: ts(time), status: "open")
  }

  func test_conversations_latestPerContactSortedNewestFirst() {
    let events = [
      ev("a1", contact: "A", name: "Anna", "2026-06-02 09:00"),
      ev("a2", contact: "A", name: "Anna", "2026-06-02 15:00"),   // neuer fuer A
      ev("b1", contact: "B", name: "Ben",  "2026-06-02 12:00"),
    ]
    let convs = KomboxDigest.conversations(from: events)
    XCTAssertEqual(convs.map(\.id), ["A", "B"])      // A (15:00) vor B (12:00)
    XCTAssertEqual(convs[0].lastEvent.id, "a2")
    XCTAssertEqual(convs[0].contactName, "Anna")
  }

  func test_threadSections_groupedByDayAscendingWithEventsAscending() {
    let events = [
      ev("d2", contact: "A", name: "Anna", "2026-06-02 15:00"),
      ev("d1b", contact: "A", name: "Anna", "2026-06-01 18:00"),
      ev("d1a", contact: "A", name: "Anna", "2026-06-01 09:00"),
    ]
    let sections = KomboxDigest.threadSections(events, calendar: cal)
    XCTAssertEqual(sections.count, 2)
    XCTAssertEqual(sections[0].day, cal.startOfDay(for: ts("2026-06-01 00:00")))
    XCTAssertEqual(sections[0].events.map(\.id), ["d1a", "d1b"])
    XCTAssertEqual(sections[1].events.map(\.id), ["d2"])
  }
}
```

- [ ] **Step 2: Test ausführen — soll fehlschlagen**

Run: `cd swift-packages/AtollHub && swift test --filter KomboxDigestTests`
Expected: FAIL — `cannot find 'KomboxDigest' in scope`.

- [ ] **Step 3: Implementieren**

`swift-packages/AtollHub/Sources/AtollHub/Kombox/KomboxDigest.swift`:

```swift
import Foundation

/// Reine Aggregations-Helfer für die Kombox.
public enum KomboxDigest {
  /// Neuestes Event je Kontakt → Konversationen, neueste zuerst.
  public static func conversations(from events: [KomboxEvent]) -> [KomboxConversation] {
    var latest: [String: KomboxEvent] = [:]
    for e in events {
      if let cur = latest[e.contactId] {
        if e.timestamp > cur.timestamp { latest[e.contactId] = e }
      } else {
        latest[e.contactId] = e
      }
    }
    return latest.values
      .sorted { $0.timestamp > $1.timestamp }
      .map { KomboxConversation(id: $0.contactId, contactName: $0.contactName, lastEvent: $0) }
  }

  /// Events eines Verlaufs nach Tag gruppiert (Sektionen aufsteigend,
  /// Events innerhalb aufsteigend nach Zeit) — für Tages-Trenner.
  public static func threadSections(_ events: [KomboxEvent],
                                    calendar: Calendar) -> [KomboxDaySection] {
    var byDay: [Date: [KomboxEvent]] = [:]
    for e in events {
      let day = calendar.startOfDay(for: e.timestamp)
      byDay[day, default: []].append(e)
    }
    return byDay.keys.sorted().map { day in
      KomboxDaySection(day: day,
                       events: byDay[day]!.sorted { $0.timestamp < $1.timestamp })
    }
  }
}
```

- [ ] **Step 4: Test ausführen — soll grün sein**

Run: `cd swift-packages/AtollHub && swift test --filter KomboxDigestTests`
Expected: PASS — 2 Tests grün.

- [ ] **Step 5: Volle Paket-Suite + Commit**

Run: `cd swift-packages/AtollHub && swift test`
Expected: PASS — alle Suiten grün (inkl. KomboxMapper, KomboxDigest).

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add swift-packages/AtollHub/Sources/AtollHub/Kombox/KomboxDigest.swift swift-packages/AtollHub/Tests/AtollHubTests/KomboxDigestTests.swift
git commit -m "AtollHub: KomboxDigest (Konversationen + Tages-Sektionen)"
```

---

## Task 3: `KomboxStore` — Laden + Realtime (ComHub)

**Files:**
- Create: `apps/comhub-native/ComHub/Kombox/KomboxStore.swift`

> **Referenz für Realtime/Concurrency:** `apps/atollcard-native/AtollCard/Repositories/LeadStore.swift` (gleicher SDK-Stand 2.46). Lies es, falls eine Realtime-Signatur abweicht. Muster: `channel(_:)` → `postgresChange(InsertAction.self, schema:table:)` → `try await channel.subscribeWithError()` → `for await … in stream`; Task halten und in `stop()` canceln. `subscribe()` ist in 2.46 **deprecated** — `subscribeWithError()` nutzen.

- [ ] **Step 1: Store schreiben**

`apps/comhub-native/ComHub/Kombox/KomboxStore.swift`:

```swift
import Foundation
import Observation
import AtollCore
import AtollHub
import Supabase
import OSLog

/// Lädt die Kombox (Konversationen + Verlauf) aus `contact_events` und hält
/// sie via Supabase-Realtime aktuell. Realtime folgt dem invalidate→refetch-
/// Muster: bei INSERT/UPDATE wird neu geladen (der Realtime-Payload trägt
/// keine `contacts`-Joins).
@MainActor
@Observable
final class KomboxStore {
  private(set) var conversations: [KomboxConversation] = []
  private(set) var thread: [KomboxDaySection] = []
  private(set) var loadingConversations = false
  private(set) var loadingThread = false
  var selectedContactId: String?

  private let supabase = SupabaseClient.shared
  private let logger = Logger(subsystem: "swiss.atoll.hub", category: "kombox")
  private var realtimeTask: Task<Void, Never>?

  /// Zürich-Kalender, konsistent mit den übrigen ComHub-Datumshelfern.
  private var calendar: Calendar {
    var c = Calendar(identifier: .gregorian)
    c.timeZone = TimeZone(identifier: "Europe/Zurich") ?? .current
    c.firstWeekday = 2
    return c
  }

  private static let selectColumns =
    "id, contact_id, event_type, occurred_at, summary, body, payload, status, " +
    "contacts!inner(id, kind, first_name, last_name, trading_name, legal_name)"

  // MARK: – Laden

  func reloadConversations() async {
    loadingConversations = true
    do {
      let rows: [KomboxEventRow] = try await supabase
        .from("contact_events")
        .select(Self.selectColumns)
        .order("occurred_at", ascending: false)
        .limit(300)
        .execute()
        .value
      conversations = KomboxDigest.conversations(from: KomboxMapper.events(from: rows))
    } catch {
      logger.error("reloadConversations failed: \(error.localizedDescription, privacy: .public)")
    }
    loadingConversations = false
  }

  func selectContact(_ contactId: String) async {
    selectedContactId = contactId
    await reloadThread()
  }

  func reloadThread() async {
    guard let contactId = selectedContactId else { thread = []; return }
    loadingThread = true
    do {
      let rows: [KomboxEventRow] = try await supabase
        .from("contact_events")
        .select(Self.selectColumns)
        .eq("contact_id", value: contactId)
        .order("occurred_at", ascending: true)
        .limit(500)
        .execute()
        .value
      thread = KomboxDigest.threadSections(KomboxMapper.events(from: rows), calendar: calendar)
    } catch {
      logger.error("reloadThread failed: \(error.localizedDescription, privacy: .public)")
    }
    loadingThread = false
  }

  // MARK: – Realtime (invalidate -> refetch)

  func startRealtime() {
    realtimeTask?.cancel()
    realtimeTask = Task { [weak self] in
      guard let self else { return }
      let channel = self.supabase.channel("public:contact_events:comhub")
      let inserts = channel.postgresChange(InsertAction.self, schema: "public", table: "contact_events")
      let updates = channel.postgresChange(UpdateAction.self, schema: "public", table: "contact_events")
      do { try await channel.subscribeWithError() }
      catch {
        self.logger.error("realtime subscribe failed: \(error.localizedDescription, privacy: .public)")
        return
      }
      await withTaskGroup(of: Void.self) { group in
        group.addTask { for await _ in inserts { await self.onRealtimeChange() } }
        group.addTask { for await _ in updates { await self.onRealtimeChange() } }
      }
    }
  }

  func stopRealtime() {
    realtimeTask?.cancel()
    realtimeTask = nil
  }

  private func onRealtimeChange() async {
    await reloadConversations()
    if selectedContactId != nil { await reloadThread() }
  }
}
```

- [ ] **Step 2: Build verifizieren**

Run: `cd apps/comhub-native && xcodegen generate && xcodebuild -scheme ComHub -destination 'platform=macOS,arch=arm64' build`
Expected: `** BUILD SUCCEEDED **`. Dieser Build beweist die kritischen supabase-swift-2.46-Signaturen: `channel(_:)`, `postgresChange(InsertAction.self, schema:table:)`, `subscribeWithError()`, sowie die PostgREST-Kette `.from().select().order(_:ascending:).limit().eq(_:value:).execute().value`. **Falls eine Realtime-Signatur abweicht**, vergleiche mit `apps/atollcard-native/AtollCard/Repositories/LeadStore.swift` (kompiliert mit demselben SDK) und passe an; melde die Anpassung. Ändere **nicht** das AtollHub-Paket.

- [ ] **Step 3: Commit**

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add apps/comhub-native/ComHub/Kombox/KomboxStore.swift
git commit -m "ComHub: KomboxStore (Konversationen + Verlauf + Realtime, lesen)"
```

---

## Task 4: Kombox-Zeilen-Views (Bubble / Mail-Karte / System-Marker)

**Files:**
- Create: `apps/comhub-native/ComHub/Kombox/KomboxRows.swift`

- [ ] **Step 1: Zeilen-Views schreiben**

`apps/comhub-native/ComHub/Kombox/KomboxRows.swift`:

```swift
import SwiftUI
import AtollHub

/// WhatsApp-Bubble: inbound links/grau, outbound rechts/grün.
struct KomboxBubble: View {
  let event: KomboxEvent
  private var isOutbound: Bool { event.direction == .outbound }

  private static let time: DateFormatter = {
    let f = DateFormatter(); f.dateFormat = "HH:mm"
    f.timeZone = TimeZone(identifier: "Europe/Zurich"); return f
  }()

  var body: some View {
    HStack {
      if isOutbound { Spacer(minLength: 40) }
      VStack(alignment: .leading, spacing: 2) {
        Text("WhatsApp").font(.caption2).foregroundStyle(.secondary)
        Text(event.body ?? event.summary).font(.callout)
        Text(Self.time.string(from: event.timestamp))
          .font(.caption2).foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .trailing)
      }
      .padding(8)
      .frame(maxWidth: 360, alignment: .leading)
      .background(isOutbound ? Color.green.opacity(0.25) : Color.secondary.opacity(0.15),
                  in: RoundedRectangle(cornerRadius: 12))
      if !isOutbound { Spacer(minLength: 40) }
    }
  }
}

/// Mail-Karte: aufklappbar (Betreff → Body).
struct KomboxMailCard: View {
  let event: KomboxEvent
  @State private var expanded = false
  private var isOutbound: Bool { event.direction == .outbound }

  private static let time: DateFormatter = {
    let f = DateFormatter(); f.dateFormat = "dd.MM. HH:mm"
    f.timeZone = TimeZone(identifier: "Europe/Zurich"); return f
  }()

  var body: some View {
    HStack {
      if isOutbound { Spacer(minLength: 40) }
      VStack(alignment: .leading, spacing: 6) {
        Button { expanded.toggle() } label: {
          HStack(spacing: 8) {
            Image(systemName: "envelope")
            VStack(alignment: .leading, spacing: 1) {
              Text(isOutbound ? "Gesendet · E-Mail" : "Empfangen · E-Mail")
                .font(.caption2).foregroundStyle(.secondary)
              Text(event.subject ?? event.summary).font(.callout.weight(.medium)).lineLimit(1)
              if !expanded, let body = event.body, !body.isEmpty {
                Text(body).font(.caption).foregroundStyle(.secondary).lineLimit(1)
              }
            }
            Spacer(minLength: 0)
            Text(Self.time.string(from: event.timestamp)).font(.caption2).foregroundStyle(.secondary)
            Image(systemName: expanded ? "chevron.up" : "chevron.down")
              .font(.caption).foregroundStyle(.tertiary)
          }
        }
        .buttonStyle(.plain)
        if expanded, let body = event.body {
          Text(body).font(.callout).textSelection(.enabled)
        }
      }
      .padding(10)
      .frame(maxWidth: 460, alignment: .leading)
      .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
      if !isOutbound { Spacer(minLength: 40) }
    }
  }
}

/// System-Marker: zentrierter Hinweis (Notiz/Anruf/Task/…).
struct KomboxSystemMarker: View {
  let event: KomboxEvent
  var body: some View {
    HStack {
      Spacer()
      HStack(spacing: 6) {
        Image(systemName: "info.circle").font(.caption2)
        Text(event.summary).font(.caption).lineLimit(1)
      }
      .padding(.horizontal, 10).padding(.vertical, 4)
      .background(.quaternary.opacity(0.5), in: Capsule())
      Spacer()
    }
  }
}

/// Wählt die richtige Zeile je `KomboxKind`.
struct KomboxRow: View {
  let event: KomboxEvent
  var body: some View {
    switch event.kind {
    case .whatsapp: KomboxBubble(event: event)
    case .email:    KomboxMailCard(event: event)
    case .system:   KomboxSystemMarker(event: event)
    }
  }
}
```

- [ ] **Step 2: Build verifizieren**

Run: `cd apps/comhub-native && xcodegen generate && xcodebuild -scheme ComHub -destination 'platform=macOS,arch=arm64' build`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add apps/comhub-native/ComHub/Kombox/KomboxRows.swift
git commit -m "ComHub: Kombox-Zeilen (WhatsApp-Bubble, Mail-Karte, System-Marker)"
```

---

## Task 5: `ThreadView` — Verlauf mit Tages-Trennern (ComHub)

**Files:**
- Create: `apps/comhub-native/ComHub/Kombox/ThreadView.swift`

- [ ] **Step 1: View schreiben**

`apps/comhub-native/ComHub/Kombox/ThreadView.swift`:

```swift
import SwiftUI
import AtollHub

/// Verlauf eines Kontakts: Tages-Sektionen mit Zeilen, neueste unten.
struct ThreadView: View {
  let store: KomboxStore

  private static let dayLabel: DateFormatter = {
    let f = DateFormatter(); f.dateFormat = "EEEE, d. MMMM"
    f.locale = Locale(identifier: "de_CH")
    f.timeZone = TimeZone(identifier: "Europe/Zurich"); return f
  }()

  var body: some View {
    Group {
      if store.selectedContactId == nil {
        ContentUnavailableView("Konversation wählen", systemImage: "bubble.left.and.bubble.right")
      } else if store.thread.isEmpty {
        ContentUnavailableView(store.loadingThread ? "Lädt…" : "Keine Nachrichten",
                               systemImage: "bubble.left")
      } else {
        ScrollView {
          LazyVStack(alignment: .leading, spacing: 10) {
            ForEach(store.thread) { section in
              HStack {
                Spacer()
                Text(Self.dayLabel.string(from: section.day))
                  .font(.caption2).foregroundStyle(.secondary)
                  .padding(.horizontal, 10).padding(.vertical, 3)
                  .background(.quaternary.opacity(0.4), in: Capsule())
                Spacer()
              }
              .padding(.top, 6)
              ForEach(section.events) { KomboxRow(event: $0) }
            }
          }
          .padding(12)
        }
      }
    }
  }
}
```

- [ ] **Step 2: Build verifizieren**

Run: `cd apps/comhub-native && xcodegen generate && xcodebuild -scheme ComHub -destination 'platform=macOS,arch=arm64' build`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add apps/comhub-native/ComHub/Kombox/ThreadView.swift
git commit -m "ComHub: ThreadView (Verlauf mit Tages-Trennern)"
```

---

## Task 6: `ConversationListView` — Kontaktliste (ComHub)

**Files:**
- Create: `apps/comhub-native/ComHub/Kombox/ConversationListView.swift`

- [ ] **Step 1: View schreiben**

`apps/comhub-native/ComHub/Kombox/ConversationListView.swift`:

```swift
import SwiftUI
import AtollHub

/// Kontaktliste: Konversationen (letzte Nachricht je Kontakt, neueste zuerst).
struct ConversationListView: View {
  let store: KomboxStore
  @Binding var selection: String?

  private static let time: DateFormatter = {
    let f = DateFormatter(); f.dateFormat = "dd.MM. HH:mm"
    f.locale = Locale(identifier: "de_CH")
    f.timeZone = TimeZone(identifier: "Europe/Zurich"); return f
  }()

  var body: some View {
    List(store.conversations, selection: $selection) { conv in
      VStack(alignment: .leading, spacing: 2) {
        HStack {
          Image(systemName: icon(conv.lastEvent.kind))
            .font(.caption).foregroundStyle(.secondary)
          Text(conv.contactName).font(.callout.weight(.medium)).lineLimit(1)
          Spacer(minLength: 0)
          Text(Self.time.string(from: conv.lastEvent.timestamp))
            .font(.caption2).foregroundStyle(.secondary)
        }
        Text(preview(conv.lastEvent)).font(.caption).foregroundStyle(.secondary).lineLimit(1)
      }
      .tag(conv.id)
      .padding(.vertical, 2)
    }
    .overlay { if store.loadingConversations && store.conversations.isEmpty { ProgressView() } }
  }

  private func icon(_ kind: KomboxKind) -> String {
    switch kind {
    case .whatsapp: return "bubble.left.fill"
    case .email:    return "envelope.fill"
    case .system:   return "info.circle"
    }
  }
  private func preview(_ e: KomboxEvent) -> String {
    let prefix = e.direction == .outbound ? "Du: " : ""
    return prefix + (e.kind == .email ? (e.subject ?? e.summary) : (e.body ?? e.summary))
  }
}
```

- [ ] **Step 2: Build verifizieren**

Run: `cd apps/comhub-native && xcodegen generate && xcodebuild -scheme ComHub -destination 'platform=macOS,arch=arm64' build`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add apps/comhub-native/ComHub/Kombox/ConversationListView.swift
git commit -m "ComHub: ConversationListView (Kontaktliste)"
```

---

## Task 7: `KomboxModuleView` + Shell + Realtime-Lifecycle (ComHub)

**Files:**
- Create: `apps/comhub-native/ComHub/Kombox/KomboxModuleView.swift`
- Modify: `apps/comhub-native/ComHub/Shell/HubShell.swift`

- [ ] **Step 1: `KomboxModuleView` schreiben** (2-Pane Liste · Verlauf)

`apps/comhub-native/ComHub/Kombox/KomboxModuleView.swift`:

```swift
import SwiftUI
import AtollHub

/// Kombox-Modul: links Konversationen, rechts Verlauf. Lädt beim Erscheinen
/// und hält via Realtime aktuell.
struct KomboxModuleView: View {
  @State private var store = KomboxStore()
  @State private var selection: String?

  var body: some View {
    HStack(spacing: 0) {
      ConversationListView(store: store, selection: $selection)
        #if os(macOS)
        .frame(minWidth: 260, maxWidth: 320)
        #endif
      Divider()
      ThreadView(store: store)
        .frame(maxWidth: .infinity)
    }
    .task {
      await store.reloadConversations()
      store.startRealtime()
    }
    .onDisappear { store.stopRealtime() }
    .onChange(of: selection) { _, new in
      guard let new else { return }
      Task { await store.selectContact(new) }
    }
  }
}
```

- [ ] **Step 2: `.kombox` in die Shell hängen**

In `apps/comhub-native/ComHub/Shell/HubShell.swift` im `content:`-`switch selectedModule` **nach** dem `.kontakte`-Zweig (vor `default:`) einfügen:

```swift
      case .kombox:
        KomboxModuleView()
          #if os(macOS)
          .frame(minWidth: 560)
          #endif
```

Und im `detail:`-`switch` den `.kombox`-Fall zu den selbst-rendernden Modulen hinzufügen — den `case`-Ausdruck ändern von:

```swift
      case .heute, .kalender, .kontakte:
```

zu:

```swift
      case .heute, .kalender, .kontakte, .kombox:
```

(Die übrigen Zweige bleiben unverändert.)

- [ ] **Step 3: Generieren + Build**

Run: `cd apps/comhub-native && xcodegen generate && xcodebuild -scheme ComHub -destination 'platform=macOS,arch=arm64' build`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Manueller Smoke-Test** (echter Mac, Atoll-Login mit Comms-Zugriff)

- [ ] App → Modul **Kombox** → Kontaktliste zeigt Konversationen (neueste zuerst), je Zeile Name + Kanal-Icon + letzte Nachricht/Betreff + Zeit.
- [ ] Konversation wählen → Verlauf rechts: Tages-Trenner, WhatsApp-Bubbles (in links/out rechts), Mail-Karten (aufklappbar), System-Marker zentriert.
- [ ] Leerer Zustand: ohne Auswahl „Konversation wählen"; Kontakt ohne Events „Keine Nachrichten" — kein Absturz.
- [ ] **Realtime:** im Web (oder per Test-Insert) eine neue `contact_events`-Zeile für einen Kontakt anlegen → Liste + offener Verlauf aktualisieren sich **ohne Reload**.

- [ ] **Step 5: Commit**

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add apps/comhub-native/ComHub/Kombox/KomboxModuleView.swift apps/comhub-native/ComHub/Shell/HubShell.swift
git commit -m "ComHub: Kombox-Modul in die Shell (Liste + Verlauf, Realtime-Lifecycle)"
```

---

## Task 8: Dokumentation (Phase 3a)

**Files:**
- Modify: `apps/comhub-native/README.md`

- [ ] **Step 1: Phase-3a-Eintrag ergänzen**

In `apps/comhub-native/README.md` im Abschnitt `## Phasen-Stand` **nach** dem `**Phase 2** …`-Absatz einfügen:

```markdown

**Phase 3a** — **Kombox lesen + Realtime** (`.kombox`-Modul): Kontaktliste
(Konversationen, neueste zuerst, client-seitig aus `contact_events` gruppiert) +
**Verlauf** je Kontakt (WhatsApp-Bubbles in/out, aufklappbare Mail-Karten,
System-Marker, Tages-Trenner) mit **Live-Updates** über Supabase-Realtime
(`contact_events`, invalidate→refetch). Reine Logik getestet in `AtollHub`
(`KomboxEvent`/`KomboxMapper`/`KomboxDigest`). Senden/Antworten/Löschen/Filter
folgen in Phase 3b, der Privat-WhatsApp-WebView-Tab in 3c.
```

- [ ] **Step 2: Commit**

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add apps/comhub-native/README.md
git commit -m "Docs: ComHub-README Phase-3a-Stand (Kombox lesen + Realtime)"
```

---

## Self-Review (durchgeführt)

**1. Spec-Abdeckung (Phase 3 „Kombox" laut Spec §4.3, Slice 3a):**
- „Kontaktliste (letzte Nachricht)" → Task 2 (`KomboxDigest.conversations`) + Task 6 (`ConversationListView`). **„Ungelesen-Badge" bewusst weggelassen** (kein read/unread im Schema — Scope-Grenze dokumentiert).
- „Verlauf (WhatsApp-Bubbles, aufklappbare Mail-Karten, System-Marker, Tages-Trenner)" → Task 4 (`KomboxBubble`/`KomboxMailCard`/`KomboxSystemMarker`) + Task 2 (`threadSections`) + Task 5 (`ThreadView`).
- „Realtime auf `contact_events`" → Task 3 (`KomboxStore.startRealtime`, invalidate→refetch) + Task 7 (Lifecycle).
- „gleicher Aufbau wie die Web-Mailbox" → Liste · Verlauf · (Composer kommt 3b); Zeilen-Typen nach `event_type` wie im Web-`TimelineFeed`.
- **Bewusst 3b/3c:** Composer/Senden/Antworten/Löschen/Filter/Suche (3b), Privat-WhatsApp-WebView (3c) — Slice-Entscheidung oben.

**2. Platzhalter-Scan:** Keine „TBD/TODO". Jeder Code-Schritt zeigt vollständigen Code; jeder Run-Schritt nennt Befehl + erwartete Ausgabe. Empty-States sind vollständig implementierte UI.

**3. Typ-Konsistenz:**
- `KomboxEventRow`/`KomboxPayload`/`KomboxContactRef` (Task 1) ↔ `KomboxStore`-Select-Spalten (Task 3) — Spalten `id, contact_id, event_type, occurred_at, summary, body, payload, status, contacts(…)` decken exakt die CodingKeys. ✔
- `KomboxMapper.events(from:)` (Task 1) ↔ Aufrufe in `KomboxStore` (Task 3). ✔
- `KomboxEvent` Felder `kind/direction/summary/body/subject/timestamp/contactName/contactId` (Task 1) ↔ Zeilen-Views (Task 4) + `ConversationListView` (Task 6). ✔
- `KomboxDigest.conversations(from:)`/`threadSections(_:calendar:)` (Task 2) ↔ Store (Task 3). ✔
- `KomboxConversation` (`id/contactName/lastEvent`) + `KomboxDaySection` (`id/day/events`) (Task 1) ↔ Listen/Thread-Views (Tasks 5/6). ✔
- Reuse Phase 0: `MessageDirection` (.inbound/.outbound), `ComHubModule.kombox`. ✔
- supabase-swift 2.46: `channel(_:)`, `postgresChange(InsertAction.self, schema:table:)`, `UpdateAction`, `subscribeWithError()`, `.from().select().order(_:ascending:).limit().eq(_:value:).execute().value` — gegen die SDK-Quelle + `LeadStore.swift`-Präzedenz geprüft (Task 3 verifiziert per Build; Abweichung → an LeadStore angleichen).

**4. Verifikations-Disziplin:** Tasks 1–2 echte TDD (`swift test`). Tasks 3–7 build-verifiziert (`xcodegen generate` + `xcodebuild`); Task 7 schließt mit manuellem Smoke-Test inkl. Realtime. Konform zu superpowers:verification-before-completion.

**Offene Hinweise an den Menschen (nicht blockierend für 3a, relevant für 3b/Smoke):**
- **Senden (3b)** braucht für den eingeloggten User eine `messaging_accounts`-Zeile (`owner_user_id = auth.uid()`, passender `channel`), sonst liefert `comms-outbound` keinen Account. Vor 3b-Smoke prüfen.
- RLS: Realtime liefert nur Events zu Kontakten, die der User sehen darf (`contact_events_owner`). Wenn die Kombox leer wirkt, an der Atoll-Berechtigung (contact_instructor) liegen — gleiche Sichtbarkeit wie die Web-Mailbox.

---

## Execution Handoff

**Plan komplett und gespeichert unter `docs/superpowers/plans/2026-06-02-comhub-phase3a-kombox-read.md`. Zwei Ausführungs-Optionen:**

**1. Subagent-Driven (empfohlen)** — frischer Subagent pro Task, Review zwischen den Tasks. (REQUIRED SUB-SKILL: superpowers:subagent-driven-development.)

**2. Inline-Ausführung** — Tasks in dieser Session, Batch mit Checkpoints. (REQUIRED SUB-SKILL: superpowers:executing-plans.)

**Welcher Ansatz?**
