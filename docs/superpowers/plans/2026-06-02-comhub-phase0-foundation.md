# ComHub Phase 0 — Foundation & Provider-Kern Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eine neue SwiftUI-Multiplatform-App „ComHub" steht lauffähig (macOS zuerst): OTP-Login gegen Atoll-Supabase, leere 3-Spalten-Shell mit Modul-Leiste, und ein neues, voll unit-getestetes Provider-/Account-Kernpaket `AtollHub` (Capability-Protokolle + Aggregation + Kontakt-Normalisierung).

**Architecture:** Neue App `apps/comhub-native` nach dem exakten Muster von `apps/atollcal-native` (XcodeGen `project.yml`, `AtollCoreConfig.register`-Bootstrap, `AtollCore` + `AtollDesign` als lokale Pakete). Der anbieter-offene Kern ist ein eigenes, dependency-leichtes Swift-Paket `swift-packages/AtollHub`: quellneutrale Modelle, Capability-Protokolle (`CalendarProvider`/`MailProvider`/`TodoProvider`/`ContactsProvider` + Atoll-spezifisch `CommsProvider`/`EventsProvider`/`CardInboxProvider`), ein `Hub`-Aggregator über `Account`-Verbindungen und reine Hilfen (`ContactKey`-Normalisierung, `ContactMatcher`, `ComHubModule`, `OTPCode`). Konkrete Adapter (Apple/Atoll) und echte Module folgen in Phase 1+.

**Tech Stack:** Swift 6 (strict concurrency complete), SwiftUI Multiplatform (iOS 26 / macOS 26), XcodeGen, XCTest, `supabase-swift` (≥ 2.0, via `AtollCore`), EventKit/Contacts (nur Permission-Scaffolding in Phase 0).

**Scope-Grenze:** Phase 0 baut **keine** echten Daten-Adapter, keinen Kalender, keine Kombox. „AtollCal als Paket einbinden" und das Merge des Kalenders sind **Phase-1-Voraussetzungen** (AtollCal ist heute eine App, kein Paket — die Extraktion gehört in den Phase-1-Plan). Apple-Permissions in Phase 0 = Berechtigung anfragen + Status mappen, **kein** Lesen von Events/Kontakten.

---

## File Structure

**Neues Paket — `swift-packages/AtollHub/` (der Provider-Kern, rein, getestet):**
- `Package.swift` — Library `AtollHub`, iOS/macOS 26, Swift-Mode v6, **keine** schweren Abhängigkeiten.
- `Sources/AtollHub/Model/AccountType.swift` — `AccountType`, `Capability`.
- `Sources/AtollHub/Model/Account.swift` — `Account`, `AccountRef`.
- `Sources/AtollHub/Model/UnifiedModels.swift` — `UnifiedEvent`, `UnifiedMessage`, `UnifiedTask`, `UnifiedContact`, `Lead`, `MessageChannel`, `MessageDirection`.
- `Sources/AtollHub/Capabilities/Providers.swift` — die sieben Capability-Protokolle.
- `Sources/AtollHub/Hub/Hub.swift` — `AccountConnection`, `Hub` (Aggregation, fehlertolerant).
- `Sources/AtollHub/Matching/ContactKey.swift` — E-Mail/Telefon-Normalisierung.
- `Sources/AtollHub/Matching/ContactMatcher.swift` — Gruppierung nach Schlüssel.
- `Sources/AtollHub/Navigation/ComHubModule.swift` — die Modul-Leiste (rein).
- `Sources/AtollHub/Auth/OTPCode.swift` — OTP-Code-Validierung (rein).
- `Tests/AtollHubTests/*` — XCTest-Suiten pro Einheit + `Fakes.swift`.

**Geändertes Paket — `swift-packages/AtollCore/`:**
- `Sources/AtollCore/Auth/AuthState.swift` — additive OTP-Code-Methoden (`signInWithEmailCode`, `verifyEmailCode`).

**Neue App — `apps/comhub-native/` (Muster: `apps/atollcal-native`):**
- `project.yml` — XcodeGen, Target `ComHub` (iOS+macOS), Pakete AtollCore/AtollDesign/AtollHub/supabase-swift, EventKit+Contacts SDKs, Info.plist-Properties, URL-Scheme `comhub`.
- `.gitignore` — `*.xcodeproj`, `.swiftpm/`, `.DS_Store`, `xcuserdata/`.
- `ComHub/ComHubApp.swift` — App-Entry mit `AtollCoreConfig.register`-Bootstrap.
- `ComHub/Config.swift` — Supabase-Prod-Werte + `comhub://auth/callback`.
- `ComHub/Auth/SignInView.swift` — E-Mail → Code → Verify.
- `ComHub/Apple/AppleAuthorizationService.swift` — EventKit/Contacts/Reminders-Permission + Status-Mapping.
- `ComHub/Shell/RootView.swift` — gated nach `auth.status`.
- `ComHub/Shell/HubShell.swift` — `NavigationSplitView` 3-spaltig + Modul-Leiste, Platzhalter pro Modul.
- `ComHub/Assets.xcassets/` — `AppIcon` (Platzhalter), `AccentColor`.
- `ComHubTests/SmokeTests.swift` — App-Target kompiliert + Modul-Leiste sichtbar (light).
- `README.md` — Setup/Build wie AtollCal.

**Doku:**
- `swift-packages/README.md` — Abschnitt `AtollHub` ergänzen.

---

## Task 1: `AtollHub`-Paket-Skelett

**Files:**
- Create: `swift-packages/AtollHub/Package.swift`
- Create: `swift-packages/AtollHub/Sources/AtollHub/AtollHub.swift`
- Test: `swift-packages/AtollHub/Tests/AtollHubTests/SmokeTests.swift`

- [ ] **Step 1: Paketmanifest + Platzhalter-Quelle anlegen**

`swift-packages/AtollHub/Package.swift`:

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "AtollHub",
  defaultLocalization: "de",
  platforms: [
    .iOS("26.0"),
    .macOS("26.0"),
  ],
  products: [
    .library(
      name: "AtollHub",
      targets: ["AtollHub"]
    ),
  ],
  targets: [
    .target(
      name: "AtollHub",
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    .testTarget(
      name: "AtollHubTests",
      dependencies: ["AtollHub"],
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
  ]
)
```

`swift-packages/AtollHub/Sources/AtollHub/AtollHub.swift`:

```swift
// AtollHub — anbieter-offener Kern für ComHub.
//
// Definiert quellneutrale Modelle, Capability-Protokolle und die Aggregation
// über mehrere Konten. Konkrete Adapter (Apple, Atoll, Google, Microsoft)
// implementieren die Protokolle in späteren Phasen.

/// Paket-Versionsmarker (nur für den Smoke-Test).
public enum AtollHub {
  public static let version = "0.1.0"
}
```

- [ ] **Step 2: Failing Smoke-Test schreiben**

`swift-packages/AtollHub/Tests/AtollHubTests/SmokeTests.swift`:

```swift
import XCTest
@testable import AtollHub

final class SmokeTests: XCTestCase {
  func test_packageImports() {
    XCTAssertEqual(AtollHub.version, "0.1.0")
  }
}
```

- [ ] **Step 3: Test ausführen — soll grün sein (Skelett ist trivial)**

Run: `cd swift-packages/AtollHub && swift test`
Expected: PASS — `Executed 1 test, with 0 failures`. (Falls FAIL: Toolchain/Pfad prüfen.)

- [ ] **Step 4: Commit**

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add swift-packages/AtollHub/Package.swift swift-packages/AtollHub/Sources swift-packages/AtollHub/Tests
git commit -m "AtollHub: Paket-Skelett (Provider-Kern fuer ComHub)"
```

---

## Task 2: Quellneutrale Modelle

**Files:**
- Create: `swift-packages/AtollHub/Sources/AtollHub/Model/UnifiedModels.swift`
- Test: `swift-packages/AtollHub/Tests/AtollHubTests/UnifiedModelsTests.swift`

- [ ] **Step 1: Failing Test schreiben**

`swift-packages/AtollHub/Tests/AtollHubTests/UnifiedModelsTests.swift`:

```swift
import XCTest
@testable import AtollHub

final class UnifiedModelsTests: XCTestCase {
  func test_unifiedEvent_isConstructibleAndEquatable() {
    let ref = AccountRef(accountId: "a1", type: .apple)
    let start = Date(timeIntervalSince1970: 1_000)
    let end = Date(timeIntervalSince1970: 4_600)
    let e1 = UnifiedEvent(id: "e1", source: ref, title: "Tauchgang",
                          start: start, end: end, isAllDay: false, location: "Hausriff")
    let e2 = UnifiedEvent(id: "e1", source: ref, title: "Tauchgang",
                          start: start, end: end, isAllDay: false, location: "Hausriff")
    XCTAssertEqual(e1, e2)
    XCTAssertEqual(e1.source.type, .apple)
  }

  func test_unifiedMessage_carriesChannelAndDirection() {
    let ref = AccountRef(accountId: "atoll", type: .atoll)
    let m = UnifiedMessage(id: "m1", source: ref, channel: .whatsapp,
                           direction: .inbound, contactName: "Anna",
                           preview: "Hallo", timestamp: Date(timeIntervalSince1970: 5),
                           isUnread: true)
    XCTAssertEqual(m.channel, .whatsapp)
    XCTAssertEqual(m.direction, .inbound)
    XCTAssertTrue(m.isUnread)
  }
}
```

- [ ] **Step 2: Test ausführen — soll fehlschlagen**

Run: `cd swift-packages/AtollHub && swift test --filter UnifiedModelsTests`
Expected: FAIL — `cannot find 'AccountRef'`/`'UnifiedEvent' in scope` (Compile-Fehler).

- [ ] **Step 3: Modelle implementieren**

`swift-packages/AtollHub/Sources/AtollHub/Model/UnifiedModels.swift`:

```swift
import Foundation

/// Verweis auf die Quelle (Konto) eines Datensatzes — der „source"-Tag.
public struct AccountRef: Sendable, Equatable, Hashable {
  public let accountId: String
  public let type: AccountType
  public init(accountId: String, type: AccountType) {
    self.accountId = accountId
    self.type = type
  }
}

/// Kanal einer Nachricht in der Kombox.
public enum MessageChannel: String, Sendable, CaseIterable {
  case mail
  case whatsapp
}

/// Richtung einer Nachricht.
public enum MessageDirection: String, Sendable {
  case inbound
  case outbound
}

/// Quellneutraler Kalendertermin (Apple, Atoll, später Google/MS).
public struct UnifiedEvent: Sendable, Identifiable, Equatable, Hashable {
  public let id: String
  public let source: AccountRef
  public let title: String
  public let start: Date
  public let end: Date
  public let isAllDay: Bool
  public let location: String?
  public init(id: String, source: AccountRef, title: String, start: Date,
              end: Date, isAllDay: Bool, location: String?) {
    self.id = id; self.source = source; self.title = title
    self.start = start; self.end = end; self.isAllDay = isAllDay
    self.location = location
  }
}

/// Quellneutrale Nachricht (Mail/WhatsApp) für die Kombox.
public struct UnifiedMessage: Sendable, Identifiable, Equatable, Hashable {
  public let id: String
  public let source: AccountRef
  public let channel: MessageChannel
  public let direction: MessageDirection
  public let contactName: String?
  public let preview: String
  public let timestamp: Date
  public let isUnread: Bool
  public init(id: String, source: AccountRef, channel: MessageChannel,
              direction: MessageDirection, contactName: String?, preview: String,
              timestamp: Date, isUnread: Bool) {
    self.id = id; self.source = source; self.channel = channel
    self.direction = direction; self.contactName = contactName
    self.preview = preview; self.timestamp = timestamp; self.isUnread = isUnread
  }
}

/// Quellneutrale Aufgabe (Apple Erinnerungen / Atoll-Tasks).
public struct UnifiedTask: Sendable, Identifiable, Equatable, Hashable {
  public let id: String
  public let source: AccountRef
  public let title: String
  public let due: Date?
  public let isDone: Bool
  public init(id: String, source: AccountRef, title: String, due: Date?, isDone: Bool) {
    self.id = id; self.source = source; self.title = title
    self.due = due; self.isDone = isDone
  }
}

/// Quellneutraler Kontakt (Atoll-CRM / Apple-Kontakte).
public struct UnifiedContact: Sendable, Identifiable, Equatable, Hashable {
  public let id: String
  public let source: AccountRef
  public let firstName: String
  public let lastName: String
  public let emails: [String]
  public let phones: [String]
  public init(id: String, source: AccountRef, firstName: String, lastName: String,
              emails: [String], phones: [String]) {
    self.id = id; self.source = source; self.firstName = firstName
    self.lastName = lastName; self.emails = emails; self.phones = phones
  }
}

/// Neuer Lead aus AtollCard (`card_leads`) für die CardInbox.
public struct Lead: Sendable, Identifiable, Equatable, Hashable {
  public let id: String
  public let name: String
  public let createdAt: Date
  public let email: String?
  public let phone: String?
  public init(id: String, name: String, createdAt: Date, email: String?, phone: String?) {
    self.id = id; self.name = name; self.createdAt = createdAt
    self.email = email; self.phone = phone
  }
}
```

- [ ] **Step 4: Test ausführen — soll grün sein**

Run: `cd swift-packages/AtollHub && swift test --filter UnifiedModelsTests`
Expected: PASS — 2 Tests grün.

- [ ] **Step 5: Commit**

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add swift-packages/AtollHub/Sources/AtollHub/Model/UnifiedModels.swift swift-packages/AtollHub/Tests/AtollHubTests/UnifiedModelsTests.swift
git commit -m "AtollHub: quellneutrale Modelle (Event/Message/Task/Contact/Lead)"
```

---

## Task 3: `Account` + `Capability`

**Files:**
- Create: `swift-packages/AtollHub/Sources/AtollHub/Model/AccountType.swift`
- Create: `swift-packages/AtollHub/Sources/AtollHub/Model/Account.swift`
- Test: `swift-packages/AtollHub/Tests/AtollHubTests/AccountTests.swift`

- [ ] **Step 1: Failing Test schreiben**

`swift-packages/AtollHub/Tests/AtollHubTests/AccountTests.swift`:

```swift
import XCTest
@testable import AtollHub

final class AccountTests: XCTestCase {
  func test_account_reportsSupportedCapabilities() {
    let atoll = Account(id: "atoll", type: .atoll, displayName: "Atoll",
                        capabilities: [.calendar, .comms, .contacts, .cardInbox, .todo])
    XCTAssertTrue(atoll.supports(.comms))
    XCTAssertTrue(atoll.supports(.calendar))
    XCTAssertFalse(atoll.supports(.mail))
  }

  func test_accountRef_derivesFromAccount() {
    let apple = Account(id: "icloud", type: .apple, displayName: "iCloud",
                        capabilities: [.calendar, .contacts, .todo])
    XCTAssertEqual(apple.ref, AccountRef(accountId: "icloud", type: .apple))
  }
}
```

- [ ] **Step 2: Test ausführen — soll fehlschlagen**

Run: `cd swift-packages/AtollHub && swift test --filter AccountTests`
Expected: FAIL — `cannot find 'Account'`/`'AccountType'` in scope.

- [ ] **Step 3: Implementieren**

`swift-packages/AtollHub/Sources/AtollHub/Model/AccountType.swift`:

```swift
/// Typ eines angebundenen Kontos.
public enum AccountType: String, Sendable, CaseIterable {
  case apple
  case google
  case microsoft
  case atoll
}

/// Fähigkeit, die ein Konto liefern kann.
public enum Capability: String, Sendable, CaseIterable {
  case mail
  case calendar
  case todo
  case contacts
  case comms      // Atoll: Kombox (WhatsApp + Mail pro Kontakt)
  case events     // Atoll: Atoll-Events
  case cardInbox  // Atoll: card_leads
}
```

`swift-packages/AtollHub/Sources/AtollHub/Model/Account.swift`:

```swift
/// Ein angebundenes Konto. Erfüllt eine oder mehrere Capabilities; die
/// konkreten Provider-Instanzen hängen über `AccountConnection` (siehe Hub).
public struct Account: Sendable, Identifiable, Equatable, Hashable {
  public let id: String
  public let type: AccountType
  public let displayName: String
  public let capabilities: Set<Capability>

  public init(id: String, type: AccountType, displayName: String,
              capabilities: Set<Capability>) {
    self.id = id; self.type = type
    self.displayName = displayName; self.capabilities = capabilities
  }

  public func supports(_ capability: Capability) -> Bool {
    capabilities.contains(capability)
  }

  public var ref: AccountRef { AccountRef(accountId: id, type: type) }
}
```

- [ ] **Step 4: Test ausführen — soll grün sein**

Run: `cd swift-packages/AtollHub && swift test --filter AccountTests`
Expected: PASS — 2 Tests grün.

- [ ] **Step 5: Commit**

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add swift-packages/AtollHub/Sources/AtollHub/Model/AccountType.swift swift-packages/AtollHub/Sources/AtollHub/Model/Account.swift swift-packages/AtollHub/Tests/AtollHubTests/AccountTests.swift
git commit -m "AtollHub: Account + Capability-Modell"
```

---

## Task 4: Capability-Protokolle + Test-Fakes

**Files:**
- Create: `swift-packages/AtollHub/Sources/AtollHub/Capabilities/Providers.swift`
- Create: `swift-packages/AtollHub/Tests/AtollHubTests/Fakes.swift`
- Test: `swift-packages/AtollHub/Tests/AtollHubTests/ProvidersTests.swift`

- [ ] **Step 1: Failing Test + Fakes schreiben**

`swift-packages/AtollHub/Tests/AtollHubTests/Fakes.swift`:

```swift
import Foundation
@testable import AtollHub

/// Liefert eine feste Event-Liste.
final class FakeCalendar: CalendarProvider {
  let events: [UnifiedEvent]
  init(_ events: [UnifiedEvent]) { self.events = events }
  func events(in interval: DateInterval) async throws -> [UnifiedEvent] {
    events.filter { $0.start >= interval.start && $0.start <= interval.end }
  }
}

/// Wirft immer — für Fehlertoleranz-Tests.
struct FailingCalendar: CalendarProvider {
  struct Boom: Error {}
  func events(in interval: DateInterval) async throws -> [UnifiedEvent] {
    throw Boom()
  }
}

/// Liefert feste Tasks.
final class FakeTodo: TodoProvider {
  let items: [UnifiedTask]
  init(_ items: [UnifiedTask]) { self.items = items }
  func tasks() async throws -> [UnifiedTask] { items }
}

/// Liefert feste Kontakte.
final class FakeContacts: ContactsProvider {
  let items: [UnifiedContact]
  init(_ items: [UnifiedContact]) { self.items = items }
  func contacts() async throws -> [UnifiedContact] { items }
}

/// Test-Helfer zum Bauen eines Events.
func makeEvent(_ id: String, type: AccountType, start: TimeInterval) -> UnifiedEvent {
  UnifiedEvent(id: id, source: AccountRef(accountId: type.rawValue, type: type),
               title: id, start: Date(timeIntervalSince1970: start),
               end: Date(timeIntervalSince1970: start + 3600),
               isAllDay: false, location: nil)
}
```

`swift-packages/AtollHub/Tests/AtollHubTests/ProvidersTests.swift`:

```swift
import XCTest
@testable import AtollHub

final class ProvidersTests: XCTestCase {
  func test_fakeCalendar_conformsAndFiltersByInterval() async throws {
    let provider: CalendarProvider = FakeCalendar([
      makeEvent("inside", type: .apple, start: 100),
      makeEvent("outside", type: .apple, start: 10_000),
    ])
    let window = DateInterval(start: Date(timeIntervalSince1970: 0),
                              end: Date(timeIntervalSince1970: 1_000))
    let result = try await provider.events(in: window)
    XCTAssertEqual(result.map(\.id), ["inside"])
  }
}
```

- [ ] **Step 2: Test ausführen — soll fehlschlagen**

Run: `cd swift-packages/AtollHub && swift test --filter ProvidersTests`
Expected: FAIL — `cannot find type 'CalendarProvider' in scope`.

- [ ] **Step 3: Protokolle implementieren**

`swift-packages/AtollHub/Sources/AtollHub/Capabilities/Providers.swift`:

```swift
import Foundation

// Capability-Protokolle. Ein Adapter (Apple/Atoll/…) erfüllt jene, die sein
// Konto laut `Account.capabilities` anbietet. Alle sind `Sendable`, weil der
// Hub sie über Konkurrenz-Grenzen hinweg hält.

/// Liefert Kalendertermine in einem Zeitfenster.
public protocol CalendarProvider: Sendable {
  func events(in interval: DateInterval) async throws -> [UnifiedEvent]
}

/// Liefert E-Mails (jüngste zuerst), begrenzt auf `limit`.
public protocol MailProvider: Sendable {
  func messages(limit: Int) async throws -> [UnifiedMessage]
}

/// Liefert offene/erledigte Aufgaben.
public protocol TodoProvider: Sendable {
  func tasks() async throws -> [UnifiedTask]
}

/// Liefert Kontakte.
public protocol ContactsProvider: Sendable {
  func contacts() async throws -> [UnifiedContact]
}

// — Atoll-spezifische Capabilities —

/// Kombox-Nachrichten (WhatsApp + Mail) für einen Kontakt.
public protocol CommsProvider: Sendable {
  func thread(contactId: String) async throws -> [UnifiedMessage]
}

/// Atoll-Events (Kurse/Termine aus dem CRM).
public protocol EventsProvider: Sendable {
  func atollEvents(in interval: DateInterval) async throws -> [UnifiedEvent]
}

/// Neue Leads aus AtollCard (`card_leads`).
public protocol CardInboxProvider: Sendable {
  func newLeads(limit: Int) async throws -> [Lead]
}
```

- [ ] **Step 4: Test ausführen — soll grün sein**

Run: `cd swift-packages/AtollHub && swift test --filter ProvidersTests`
Expected: PASS — 1 Test grün.

- [ ] **Step 5: Commit**

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add swift-packages/AtollHub/Sources/AtollHub/Capabilities/Providers.swift swift-packages/AtollHub/Tests/AtollHubTests/Fakes.swift swift-packages/AtollHub/Tests/AtollHubTests/ProvidersTests.swift
git commit -m "AtollHub: Capability-Protokolle + Test-Fakes"
```

---

## Task 5: `Hub`-Aggregator (fehlertolerant)

**Files:**
- Create: `swift-packages/AtollHub/Sources/AtollHub/Hub/Hub.swift`
- Test: `swift-packages/AtollHub/Tests/AtollHubTests/HubTests.swift`

- [ ] **Step 1: Failing Test schreiben**

`swift-packages/AtollHub/Tests/AtollHubTests/HubTests.swift`:

```swift
import XCTest
@testable import AtollHub

@MainActor
final class HubTests: XCTestCase {
  private var fullWindow: DateInterval {
    DateInterval(start: Date(timeIntervalSince1970: 0),
                 end: Date(timeIntervalSince1970: 1_000_000))
  }

  func test_allEvents_mergesAcrossAccountsAndSortsByStart() async {
    let apple = Account(id: "icloud", type: .apple, displayName: "iCloud",
                        capabilities: [.calendar])
    let atoll = Account(id: "atoll", type: .atoll, displayName: "Atoll",
                        capabilities: [.calendar])
    let hub = Hub()
    hub.connect(AccountConnection(account: apple,
      calendar: FakeCalendar([makeEvent("late", type: .apple, start: 500)])))
    hub.connect(AccountConnection(account: atoll,
      calendar: FakeCalendar([makeEvent("early", type: .atoll, start: 100)])))

    let merged = await hub.allEvents(in: fullWindow)

    XCTAssertEqual(merged.map(\.id), ["early", "late"])
    XCTAssertTrue(hub.lastErrors.isEmpty)
  }

  func test_allEvents_skipsFailingProviderButKeepsOthers() async {
    let ok = Account(id: "icloud", type: .apple, displayName: "iCloud",
                     capabilities: [.calendar])
    let bad = Account(id: "atoll", type: .atoll, displayName: "Atoll",
                      capabilities: [.calendar])
    let hub = Hub()
    hub.connect(AccountConnection(account: ok,
      calendar: FakeCalendar([makeEvent("ok", type: .apple, start: 1)])))
    hub.connect(AccountConnection(account: bad, calendar: FailingCalendar()))

    let merged = await hub.allEvents(in: fullWindow)

    XCTAssertEqual(merged.map(\.id), ["ok"])
    XCTAssertEqual(hub.lastErrors.count, 1)
  }

  func test_allTasks_onlyQueriesConnectionsWithTodoProvider() async {
    let apple = Account(id: "icloud", type: .apple, displayName: "iCloud",
                        capabilities: [.todo])
    let calOnly = Account(id: "x", type: .google, displayName: "G",
                          capabilities: [.calendar])
    let hub = Hub()
    hub.connect(AccountConnection(account: apple,
      todo: FakeTodo([UnifiedTask(id: "t1", source: apple.ref, title: "Tank fuellen",
                                  due: nil, isDone: false)])))
    hub.connect(AccountConnection(account: calOnly,
      calendar: FakeCalendar([])))

    let tasks = await hub.allTasks()

    XCTAssertEqual(tasks.map(\.id), ["t1"])
  }
}
```

- [ ] **Step 2: Test ausführen — soll fehlschlagen**

Run: `cd swift-packages/AtollHub && swift test --filter HubTests`
Expected: FAIL — `cannot find 'Hub'`/`'AccountConnection'` in scope.

- [ ] **Step 3: Hub implementieren**

`swift-packages/AtollHub/Sources/AtollHub/Hub/Hub.swift`:

```swift
import Foundation
import Observation

/// Bündelt ein Konto mit seinen konkreten Provider-Instanzen. Nicht jede
/// Capability muss belegt sein — `nil` heißt „dieses Konto liefert das nicht".
public struct AccountConnection: Sendable {
  public let account: Account
  public let calendar: CalendarProvider?
  public let mail: MailProvider?
  public let todo: TodoProvider?
  public let contacts: ContactsProvider?

  public init(account: Account,
              calendar: CalendarProvider? = nil,
              mail: MailProvider? = nil,
              todo: TodoProvider? = nil,
              contacts: ContactsProvider? = nil) {
    self.account = account
    self.calendar = calendar
    self.mail = mail
    self.todo = todo
    self.contacts = contacts
  }
}

/// Der Hub-Kern: hält alle Konto-Verbindungen und aggregiert quellneutral
/// über sie. Fehlerhafte Provider werden übersprungen (gesammelt in
/// `lastErrors`), damit ein kaputtes Konto die übrigen nicht blockiert.
@MainActor
@Observable
public final class Hub {
  public private(set) var connections: [AccountConnection] = []
  public private(set) var lastErrors: [String] = []

  public init() {}

  public func connect(_ connection: AccountConnection) {
    connections.append(connection)
  }

  public func reset() {
    connections.removeAll()
    lastErrors.removeAll()
  }

  // MARK: – Aggregation

  public func allEvents(in interval: DateInterval) async -> [UnifiedEvent] {
    lastErrors.removeAll()
    var out: [UnifiedEvent] = []
    for connection in connections {
      guard let provider = connection.calendar else { continue }
      do {
        out += try await provider.events(in: interval)
      } catch {
        lastErrors.append("calendar[\(connection.account.id)]: \(error)")
      }
    }
    return out.sorted { $0.start < $1.start }
  }

  public func allTasks() async -> [UnifiedTask] {
    lastErrors.removeAll()
    var out: [UnifiedTask] = []
    for connection in connections {
      guard let provider = connection.todo else { continue }
      do {
        out += try await provider.tasks()
      } catch {
        lastErrors.append("todo[\(connection.account.id)]: \(error)")
      }
    }
    return out
  }

  public func allContacts() async -> [UnifiedContact] {
    lastErrors.removeAll()
    var out: [UnifiedContact] = []
    for connection in connections {
      guard let provider = connection.contacts else { continue }
      do {
        out += try await provider.contacts()
      } catch {
        lastErrors.append("contacts[\(connection.account.id)]: \(error)")
      }
    }
    return out
  }
}
```

- [ ] **Step 4: Test ausführen — soll grün sein**

Run: `cd swift-packages/AtollHub && swift test --filter HubTests`
Expected: PASS — 3 Tests grün.

- [ ] **Step 5: Commit**

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add swift-packages/AtollHub/Sources/AtollHub/Hub/Hub.swift swift-packages/AtollHub/Tests/AtollHubTests/HubTests.swift
git commit -m "AtollHub: Hub-Aggregator (fehlertolerant) ueber Konto-Verbindungen"
```

---

## Task 6: `ContactKey` — E-Mail/Telefon-Normalisierung

**Files:**
- Create: `swift-packages/AtollHub/Sources/AtollHub/Matching/ContactKey.swift`
- Test: `swift-packages/AtollHub/Tests/AtollHubTests/ContactKeyTests.swift`

- [ ] **Step 1: Failing Test schreiben**

`swift-packages/AtollHub/Tests/AtollHubTests/ContactKeyTests.swift`:

```swift
import XCTest
@testable import AtollHub

final class ContactKeyTests: XCTestCase {
  func test_email_lowercasesAndTrims() {
    XCTAssertEqual(ContactKey.email("  Anna@Example.COM "), "anna@example.com")
  }

  func test_email_rejectsEmptyOrInvalid() {
    XCTAssertNil(ContactKey.email("   "))
    XCTAssertNil(ContactKey.email("not-an-email"))
  }

  func test_phone_keepsLeadingPlusAndStripsFormatting() {
    XCTAssertEqual(ContactKey.phone("+41 (079) 123-45 67"), "+41079123 4567".replacingOccurrences(of: " ", with: ""))
    XCTAssertEqual(ContactKey.phone("+41 79 123 45 67"), "+41791234567")
  }

  func test_phone_stripsNonDigitsWhenNoPlus() {
    XCTAssertEqual(ContactKey.phone("079/123 45 67"), "0791234567")
  }

  func test_phone_rejectsTooShort() {
    XCTAssertNil(ContactKey.phone("123"))
  }
}
```

- [ ] **Step 2: Test ausführen — soll fehlschlagen**

Run: `cd swift-packages/AtollHub && swift test --filter ContactKeyTests`
Expected: FAIL — `cannot find 'ContactKey' in scope`.

- [ ] **Step 3: Implementieren**

`swift-packages/AtollHub/Sources/AtollHub/Matching/ContactKey.swift`:

```swift
import Foundation

/// Normalisiert E-Mail/Telefon zu vergleichbaren Schlüsseln fürs Kontakt-Matching.
/// Bewusst konservativ: ein `nil` heißt „taugt nicht als Matching-Schlüssel".
public enum ContactKey {
  /// Klein + getrimmt; `nil` wenn leer oder kein „x@y"-Muster.
  public static func email(_ raw: String) -> String? {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    guard !trimmed.isEmpty else { return nil }
    // Minimaler Plausi-Check: genau ein @, je ein nicht-leerer Teil, Punkt im Domain-Teil.
    let parts = trimmed.split(separator: "@", omittingEmptySubsequences: false)
    guard parts.count == 2, !parts[0].isEmpty, parts[1].contains(".") else { return nil }
    return trimmed
  }

  /// Entfernt alle Nicht-Ziffern; ein führendes `+` bleibt erhalten.
  /// `nil` wenn nach der Bereinigung < 6 Ziffern übrig sind.
  public static func phone(_ raw: String) -> String? {
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    let hasPlus = trimmed.hasPrefix("+")
    let digits = trimmed.filter { $0.isNumber }
    guard digits.count >= 6 else { return nil }
    return hasPlus ? "+" + digits : digits
  }
}
```

- [ ] **Step 4: Test ausführen — soll grün sein**

Run: `cd swift-packages/AtollHub && swift test --filter ContactKeyTests`
Expected: PASS — 5 Tests grün.

- [ ] **Step 5: Commit**

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add swift-packages/AtollHub/Sources/AtollHub/Matching/ContactKey.swift swift-packages/AtollHub/Tests/AtollHubTests/ContactKeyTests.swift
git commit -m "AtollHub: ContactKey-Normalisierung (E-Mail/Telefon)"
```

---

## Task 7: `ContactMatcher` — Gruppierung nach Schlüssel

**Files:**
- Create: `swift-packages/AtollHub/Sources/AtollHub/Matching/ContactMatcher.swift`
- Test: `swift-packages/AtollHub/Tests/AtollHubTests/ContactMatcherTests.swift`

- [ ] **Step 1: Failing Test schreiben**

`swift-packages/AtollHub/Tests/AtollHubTests/ContactMatcherTests.swift`:

```swift
import XCTest
@testable import AtollHub

final class ContactMatcherTests: XCTestCase {
  private func contact(_ id: String, type: AccountType, emails: [String] = [],
                       phones: [String] = []) -> UnifiedContact {
    UnifiedContact(id: id, source: AccountRef(accountId: type.rawValue, type: type),
                   firstName: id, lastName: "Test", emails: emails, phones: phones)
  }

  func test_group_linksBySharedEmailAcrossSources() {
    let atoll = contact("atoll1", type: .atoll, emails: ["Anna@Example.com"])
    let apple = contact("apple1", type: .apple, emails: ["anna@example.com"])
    let other = contact("apple2", type: .apple, emails: ["ben@example.com"])

    let groups = ContactMatcher.group([atoll, apple, other])

    let linked = groups.first { $0.count == 2 }
    XCTAssertNotNil(linked)
    XCTAssertEqual(Set(linked!.map(\.id)), ["atoll1", "apple1"])
    XCTAssertEqual(groups.count, 2) // {atoll1,apple1} + {apple2}
  }

  func test_group_linksByPhoneWhenEmailDiffers() {
    let a = contact("a", type: .atoll, phones: ["+41 79 123 45 67"])
    let b = contact("b", type: .apple, phones: ["079 123 45 67"]) // ergibt anderen Key (kein +)
    let c = contact("c", type: .apple, phones: ["+41791234567"])  // gleich wie a

    let groups = ContactMatcher.group([a, b, c])

    let linked = groups.first { Set($0.map(\.id)) == ["a", "c"] }
    XCTAssertNotNil(linked)
  }

  func test_group_singletonWhenNoKeys() {
    let lonely = contact("x", type: .apple)
    let groups = ContactMatcher.group([lonely])
    XCTAssertEqual(groups.map { $0.map(\.id) }, [["x"]])
  }
}
```

- [ ] **Step 2: Test ausführen — soll fehlschlagen**

Run: `cd swift-packages/AtollHub && swift test --filter ContactMatcherTests`
Expected: FAIL — `cannot find 'ContactMatcher' in scope`.

- [ ] **Step 3: Implementieren**

`swift-packages/AtollHub/Sources/AtollHub/Matching/ContactMatcher.swift`:

```swift
import Foundation

/// Gruppiert Kontakte verschiedener Quellen, die über einen gemeinsamen
/// normalisierten E-Mail-/Telefon-Schlüssel zusammengehören (Union-Find).
/// Kontakte ohne brauchbaren Schlüssel bleiben Einzelgruppen.
public enum ContactMatcher {
  public static func group(_ contacts: [UnifiedContact]) -> [[UnifiedContact]] {
    var parent = Array(0..<contacts.count)

    func find(_ i: Int) -> Int {
      var root = i
      while parent[root] != root { root = parent[root] }
      var cur = i
      while parent[cur] != root { let next = parent[cur]; parent[cur] = root; cur = next }
      return root
    }
    func union(_ a: Int, _ b: Int) { parent[find(a)] = find(b) }

    // Schlüssel → erster Index, der ihn gesehen hat.
    var keyToIndex: [String: Int] = [:]
    for (i, c) in contacts.enumerated() {
      let keys = c.emails.compactMap(ContactKey.email) + c.phones.compactMap(ContactKey.phone)
      for key in keys {
        if let seen = keyToIndex[key] { union(i, seen) } else { keyToIndex[key] = i }
      }
    }

    // Indizes nach Wurzel bündeln, Eingabereihenfolge erhalten.
    var buckets: [Int: [UnifiedContact]] = [:]
    var order: [Int] = []
    for (i, c) in contacts.enumerated() {
      let root = find(i)
      if buckets[root] == nil { order.append(root) }
      buckets[root, default: []].append(c)
    }
    return order.map { buckets[$0]! }
  }
}
```

- [ ] **Step 4: Test ausführen — soll grün sein**

Run: `cd swift-packages/AtollHub && swift test --filter ContactMatcherTests`
Expected: PASS — 3 Tests grün.

- [ ] **Step 5: Commit**

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add swift-packages/AtollHub/Sources/AtollHub/Matching/ContactMatcher.swift swift-packages/AtollHub/Tests/AtollHubTests/ContactMatcherTests.swift
git commit -m "AtollHub: ContactMatcher (Union-Find ueber E-Mail/Telefon-Keys)"
```

---

## Task 8: `ComHubModule` — Modul-Leiste

**Files:**
- Create: `swift-packages/AtollHub/Sources/AtollHub/Navigation/ComHubModule.swift`
- Test: `swift-packages/AtollHub/Tests/AtollHubTests/ComHubModuleTests.swift`

- [ ] **Step 1: Failing Test schreiben**

`swift-packages/AtollHub/Tests/AtollHubTests/ComHubModuleTests.swift`:

```swift
import XCTest
@testable import AtollHub

final class ComHubModuleTests: XCTestCase {
  func test_orderStartsWithHeuteAndEndsWithEinstellungen() {
    XCTAssertEqual(ComHubModule.allCases.first, .heute)
    XCTAssertEqual(ComHubModule.allCases.last, .einstellungen)
  }

  func test_everyModuleHasTitleAndSymbol() {
    for module in ComHubModule.allCases {
      XCTAssertFalse(module.title.isEmpty, "\(module) ohne Titel")
      XCTAssertFalse(module.systemImage.isEmpty, "\(module) ohne Symbol")
    }
  }

  func test_heuteTitleIsLocalisedLabel() {
    XCTAssertEqual(ComHubModule.heute.title, "Heute")
    XCTAssertEqual(ComHubModule.kombox.title, "Kombox")
  }
}
```

- [ ] **Step 2: Test ausführen — soll fehlschlagen**

Run: `cd swift-packages/AtollHub && swift test --filter ComHubModuleTests`
Expected: FAIL — `cannot find 'ComHubModule' in scope`.

- [ ] **Step 3: Implementieren**

`swift-packages/AtollHub/Sources/AtollHub/Navigation/ComHubModule.swift`:

```swift
/// Die Module der linken Leiste, in Anzeigereihenfolge. `systemImage` sind
/// SF-Symbol-Namen (UI-neutral als String gehalten, damit der Kern
/// SwiftUI-frei bleibt und testbar ist).
public enum ComHubModule: String, Sendable, CaseIterable, Identifiable {
  case heute
  case kalender
  case kombox
  case kontakte
  case tasks
  case cardInbox
  case einstellungen

  public var id: String { rawValue }

  public var title: String {
    switch self {
    case .heute:         return "Heute"
    case .kalender:      return "Kalender"
    case .kombox:        return "Kombox"
    case .kontakte:      return "Kontakte"
    case .tasks:         return "Aufgaben"
    case .cardInbox:     return "CardInbox"
    case .einstellungen: return "Einstellungen"
    }
  }

  public var systemImage: String {
    switch self {
    case .heute:         return "house"
    case .kalender:      return "calendar"
    case .kombox:        return "bubble.left.and.bubble.right"
    case .kontakte:      return "person.2"
    case .tasks:         return "checklist"
    case .cardInbox:     return "tray.and.arrow.down"
    case .einstellungen: return "gearshape"
    }
  }
}
```

- [ ] **Step 4: Test ausführen — soll grün sein**

Run: `cd swift-packages/AtollHub && swift test --filter ComHubModuleTests`
Expected: PASS — 3 Tests grün.

- [ ] **Step 5: Commit**

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add swift-packages/AtollHub/Sources/AtollHub/Navigation/ComHubModule.swift swift-packages/AtollHub/Tests/AtollHubTests/ComHubModuleTests.swift
git commit -m "AtollHub: ComHubModule (Modul-Leiste, UI-neutral)"
```

---

## Task 9: `OTPCode` — Code-Validierung

**Files:**
- Create: `swift-packages/AtollHub/Sources/AtollHub/Auth/OTPCode.swift`
- Test: `swift-packages/AtollHub/Tests/AtollHubTests/OTPCodeTests.swift`

- [ ] **Step 1: Failing Test schreiben**

`swift-packages/AtollHub/Tests/AtollHubTests/OTPCodeTests.swift`:

```swift
import XCTest
@testable import AtollHub

final class OTPCodeTests: XCTestCase {
  func test_validSixDigits() {
    XCTAssertTrue(OTPCode.isValid("123456"))
  }

  func test_rejectsWrongLengthOrNonDigits() {
    XCTAssertFalse(OTPCode.isValid("12345"))
    XCTAssertFalse(OTPCode.isValid("1234567"))
    XCTAssertFalse(OTPCode.isValid("12a456"))
    XCTAssertFalse(OTPCode.isValid(""))
  }

  func test_sanitizeKeepsOnlyDigits() {
    XCTAssertEqual(OTPCode.sanitize(" 12 34-56 "), "123456")
  }
}
```

- [ ] **Step 2: Test ausführen — soll fehlschlagen**

Run: `cd swift-packages/AtollHub && swift test --filter OTPCodeTests`
Expected: FAIL — `cannot find 'OTPCode' in scope`.

- [ ] **Step 3: Implementieren**

`swift-packages/AtollHub/Sources/AtollHub/Auth/OTPCode.swift`:

```swift
/// Reiner Validierungs-Helfer für den 6-stelligen E-Mail-OTP-Code.
public enum OTPCode {
  public static let length = 6

  /// Nur Ziffern behalten (Leerzeichen/Bindestriche aus Paste entfernen).
  public static func sanitize(_ raw: String) -> String {
    String(raw.filter { $0.isNumber })
  }

  /// Genau `length` Ziffern.
  public static func isValid(_ raw: String) -> Bool {
    let s = sanitize(raw)
    return s.count == length && s.allSatisfy { $0.isNumber }
  }
}
```

- [ ] **Step 4: Test ausführen — soll grün sein**

Run: `cd swift-packages/AtollHub && swift test --filter OTPCodeTests`
Expected: PASS — 3 Tests grün.

- [ ] **Step 5: Volle Paket-Suite + Commit**

Run: `cd swift-packages/AtollHub && swift test`
Expected: PASS — alle Suiten grün (Smoke, UnifiedModels, Account, Providers, Hub, ContactKey, ContactMatcher, ComHubModule, OTPCode).

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add swift-packages/AtollHub/Sources/AtollHub/Auth/OTPCode.swift swift-packages/AtollHub/Tests/AtollHubTests/OTPCodeTests.swift
git commit -m "AtollHub: OTPCode-Validierung + volle Suite gruen"
```

---

## Task 10: ComHub-App-Gerüst (XcodeGen, baut leer)

**Files:**
- Create: `apps/comhub-native/project.yml`
- Create: `apps/comhub-native/.gitignore`
- Create: `apps/comhub-native/ComHub/Config.swift`
- Create: `apps/comhub-native/ComHub/ComHubApp.swift`
- Create: `apps/comhub-native/ComHub/ComHub.entitlements`
- Create: `apps/comhub-native/ComHub/Assets.xcassets/Contents.json`
- Create: `apps/comhub-native/ComHub/Assets.xcassets/AppIcon.appiconset/Contents.json`
- Create: `apps/comhub-native/ComHub/Assets.xcassets/AccentColor.colorset/Contents.json`
- Create: `apps/comhub-native/ComHubTests/SmokeTests.swift`

- [ ] **Step 1: `project.yml` schreiben** (Muster: `apps/atollcal-native/project.yml`, plus AtollHub + Contacts + Test-Target)

`apps/comhub-native/project.yml`:

```yaml
name: ComHub
options:
  bundleIdPrefix: swiss.atoll
  deploymentTarget:
    iOS: "26.0"
    macOS: "26.0"
  developmentLanguage: de

settings:
  base:
    SWIFT_VERSION: "6.0"
    SWIFT_STRICT_CONCURRENCY: complete
    MARKETING_VERSION: "0.1.0"
    CURRENT_PROJECT_VERSION: "1"
    DEVELOPMENT_TEAM: "XK8V89P2QV"
    CODE_SIGN_STYLE: Automatic
    SUPPORTS_MACCATALYST: NO
    SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD: NO

packages:
  AtollCore:
    path: ../../swift-packages/AtollCore
  AtollDesign:
    path: ../../swift-packages/AtollDesign
  AtollHub:
    path: ../../swift-packages/AtollHub
  supabase-swift:
    url: https://github.com/supabase/supabase-swift
    from: "2.0.0"

targets:
  ComHub:
    type: application
    platform: [iOS, macOS]
    sources:
      - path: ComHub
    resources:
      - path: ComHub/Assets.xcassets
    entitlements:
      path: ComHub/ComHub.entitlements
      properties:
        com.apple.security.app-sandbox: true
        com.apple.security.network.client: true
        com.apple.security.personal-information.calendars: true
        com.apple.security.personal-information.addressbook: true
    dependencies:
      - package: AtollCore
      - package: AtollDesign
      - package: AtollHub
      - package: supabase-swift
        product: Supabase
      - sdk: EventKit.framework
      - sdk: Contacts.framework
    info:
      path: ComHub/Info.plist
      properties:
        CFBundleDisplayName: ComHub
        CFBundleShortVersionString: $(MARKETING_VERSION)
        CFBundleVersion: $(CURRENT_PROJECT_VERSION)
        ITSAppUsesNonExemptEncryption: false
        NSCalendarsFullAccessUsageDescription: "ComHub zeigt deine Termine aus iCloud und Atoll an."
        NSRemindersFullAccessUsageDescription: "ComHub zeigt deine Aufgaben aus Erinnerungen und Atoll an."
        NSContactsUsageDescription: "ComHub fuehrt deine Atoll- und Apple-Kontakte zusammen."
        CFBundleURLTypes:
          - CFBundleURLName: swiss.atoll.hub
            CFBundleURLSchemes:
              - comhub
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: swiss.atoll.hub

  ComHubTests:
    type: bundle.unit-test
    platform: [iOS, macOS]
    sources:
      - path: ComHubTests
    dependencies:
      - target: ComHub
      - package: AtollHub

schemes:
  ComHub:
    build:
      targets:
        ComHub: all
    test:
      targets:
        - ComHubTests
    run:
      config: Debug
```

- [ ] **Step 2: Restliche Gerüst-Dateien schreiben**

`apps/comhub-native/.gitignore`:

```
*.xcodeproj
.swiftpm/
.DS_Store
xcuserdata/
*.bak
```

`apps/comhub-native/ComHub/Config.swift` (Werte identisch zu `apps/atollcal-native/AtollCal/Config.swift`, nur Scheme/Name angepasst):

```swift
import Foundation
import AtollCore

/// Supabase-Konfiguration. `anonKey` ist öffentlich (Client-Apps) — RLS sichert die Daten.
enum Config {
  static let supabaseURL     = URL(string: "https://axnrilhdokkfujzjifhj.supabase.co")!
  static let supabaseAnonKey = "sb_publishable_qNhMQ7GMfvtkZgZ78e4kOw_3YOLcrwv"
  static let authRedirectURL = URL(string: "comhub://auth/callback")!
  static let appName    = "ComHub"
  static let tenantName = "TSK Zürich"
}

/// AtollCore-Konformität — verbindet Config mit dem geteilten Supabase-Client.
struct AppSupabaseConfig: SupabaseConfig {
  var supabaseURL: URL        { Config.supabaseURL }
  var supabaseAnonKey: String { Config.supabaseAnonKey }
  var authRedirectURL: URL    { Config.authRedirectURL }
}
```

`apps/comhub-native/ComHub/ComHubApp.swift` (minimal lauffähig; wird in Task 15 verdrahtet):

```swift
import SwiftUI
import AtollCore

@main
struct ComHubApp: App {
  /// Erzwingt `AtollCoreConfig.register(...)` vor jeder `State`-Initialisierung —
  /// siehe swift-packages/README.md (AuthState.init greift sofort auf
  /// SupabaseClient.shared zu, das die Config braucht).
  private static let bootstrap: Void = {
    AtollCoreConfig.register(AppSupabaseConfig())
    return ()
  }()

  init() { _ = Self.bootstrap }

  var body: some Scene {
    WindowGroup {
      Text(verbatim: "ComHub")
        .padding()
    }
  }
}
```

`apps/comhub-native/ComHub/ComHub.entitlements`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>com.apple.security.app-sandbox</key>
  <true/>
  <key>com.apple.security.network.client</key>
  <true/>
  <key>com.apple.security.personal-information.calendars</key>
  <true/>
  <key>com.apple.security.personal-information.addressbook</key>
  <true/>
</dict>
</plist>
```

`apps/comhub-native/ComHub/Assets.xcassets/Contents.json`:

```json
{
  "info" : { "author" : "xcode", "version" : 1 }
}
```

`apps/comhub-native/ComHub/Assets.xcassets/AppIcon.appiconset/Contents.json`:

```json
{
  "images" : [
    { "idiom" : "universal", "platform" : "ios", "size" : "1024x1024" },
    { "idiom" : "mac", "scale" : "1x", "size" : "16x16" },
    { "idiom" : "mac", "scale" : "2x", "size" : "16x16" },
    { "idiom" : "mac", "scale" : "1x", "size" : "32x32" },
    { "idiom" : "mac", "scale" : "2x", "size" : "32x32" },
    { "idiom" : "mac", "scale" : "1x", "size" : "128x128" },
    { "idiom" : "mac", "scale" : "2x", "size" : "128x128" },
    { "idiom" : "mac", "scale" : "1x", "size" : "256x256" },
    { "idiom" : "mac", "scale" : "2x", "size" : "256x256" },
    { "idiom" : "mac", "scale" : "1x", "size" : "512x512" },
    { "idiom" : "mac", "scale" : "2x", "size" : "512x512" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
```

`apps/comhub-native/ComHub/Assets.xcassets/AccentColor.colorset/Contents.json`:

```json
{
  "colors" : [ { "idiom" : "universal" } ],
  "info" : { "author" : "xcode", "version" : 1 }
}
```

`apps/comhub-native/ComHubTests/SmokeTests.swift` (beweist, dass das App-Target gegen AtollHub linkt):

```swift
import XCTest
import AtollHub
@testable import ComHub

@MainActor
final class SmokeTests: XCTestCase {
  func test_hubStartsEmpty() {
    let hub = Hub()
    XCTAssertTrue(hub.connections.isEmpty)
  }

  func test_moduleRailHasAllModules() {
    XCTAssertEqual(ComHubModule.allCases.count, 7)
  }
}
```

- [ ] **Step 3: Projekt generieren**

Run: `cd apps/comhub-native && xcodegen generate`
Expected: `Created project at .../apps/comhub-native/ComHub.xcodeproj` ohne Fehler.

- [ ] **Step 4: macOS-Build verifizieren**

Run: `cd apps/comhub-native && xcodebuild -scheme ComHub -destination 'platform=macOS,arch=arm64' build`
Expected: `** BUILD SUCCEEDED **` (App-Icon-Warnungen sind ok).

- [ ] **Step 5: Commit**

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add apps/comhub-native/project.yml apps/comhub-native/.gitignore apps/comhub-native/ComHub apps/comhub-native/ComHubTests
git commit -m "ComHub: App-Geruest (XcodeGen, baut leer auf macOS)"
```

---

## Task 11: `AuthState` um OTP-Code erweitern (AtollCore)

**Files:**
- Modify: `swift-packages/AtollCore/Sources/AtollCore/Auth/AuthState.swift`

> Additive, `public` Erweiterung — bestehende Magic-Link-Apps bleiben unberührt. Der vorhandene `listenToAuthChanges()`-Listener lädt nach erfolgreicher Verifikation automatisch den User (`.signedIn`), darum ruft `verifyEmailCode` `loadCurrentUser` nicht selbst.

- [ ] **Step 1: OTP-Methoden einfügen**

In `swift-packages/AtollCore/Sources/AtollCore/Auth/AuthState.swift`, direkt **nach** der bestehenden Methode `handleAuthCallback(url:)` (vor `// MARK: – Sign out`) einfügen:

```swift
  // MARK: – Sign in (OTP-Code, native — z.B. ComHub)

  /// Schickt eine E-Mail mit 6-stelligem OTP-Code (kein Magic-Link-Redirect).
  /// `shouldCreateUser: false` — nur bestehende Atoll-Accounts dürfen sich anmelden.
  public func sendEmailCode(to email: String) async throws {
    try await supabase.auth.signInWithOTP(email: email, shouldCreateUser: false)
  }

  /// Verifiziert den eingegebenen Code. Bei Erfolg feuert der
  /// `authStateChanges`-Listener `.signedIn` und lädt den User.
  public func verifyEmailCode(email: String, code: String) async throws {
    _ = try await supabase.auth.verifyOTP(email: email, token: code, type: .email)
  }
```

- [ ] **Step 2: Paket baut + Bestandstests grün**

Run: `cd swift-packages/AtollCore && swift build && swift test`
Expected: `Build complete!` und `Executed 1 test, with 0 failures` (Bestands-Smoke-Test). Compile beweist die korrekten supabase-swift-Signaturen (`signInWithOTP(email:shouldCreateUser:)`, `verifyOTP(email:token:type:)`).

- [ ] **Step 3: Commit**

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add swift-packages/AtollCore/Sources/AtollCore/Auth/AuthState.swift
git commit -m "AtollCore: AuthState um OTP-Code-Login erweitern (sendEmailCode/verifyEmailCode)"
```

---

## Task 12: `SignInView` (E-Mail → Code → Verify)

**Files:**
- Create: `apps/comhub-native/ComHub/Auth/SignInView.swift`

- [ ] **Step 1: View schreiben**

`apps/comhub-native/ComHub/Auth/SignInView.swift`:

```swift
import SwiftUI
import AtollCore
import AtollHub

/// Zweistufiger OTP-Login: E-Mail eingeben → Code anfordern → Code eingeben → anmelden.
struct SignInView: View {
  @Environment(AuthState.self) private var auth

  private enum Step { case email, code }
  @State private var step: Step = .email
  @State private var email = ""
  @State private var code = ""
  @State private var busy = false
  @State private var errorText: String?

  var body: some View {
    VStack(spacing: 16) {
      Text(verbatim: "ComHub").font(.largeTitle.weight(.semibold))
      Text("Anmelden mit deiner Atoll-E-Mail").foregroundStyle(.secondary)

      switch step {
      case .email:
        TextField("E-Mail", text: $email)
          .textContentType(.emailAddress)
          .textFieldStyle(.roundedBorder)
          .frame(maxWidth: 320)
          #if os(iOS)
          .keyboardType(.emailAddress)
          .textInputAutocapitalization(.never)
          #endif
        Button(action: requestCode) {
          Text(busy ? "Sende…" : "Code anfordern")
        }
        .buttonStyle(.borderedProminent)
        .disabled(busy || !email.contains("@"))

      case .code:
        Text("Code aus der E-Mail an \(email)").font(.callout).foregroundStyle(.secondary)
        TextField("6-stelliger Code", text: $code)
          .textContentType(.oneTimeCode)
          .textFieldStyle(.roundedBorder)
          .frame(maxWidth: 220)
          #if os(iOS)
          .keyboardType(.numberPad)
          #endif
          .onChange(of: code) { _, new in code = OTPCode.sanitize(new) }
        Button(action: verify) {
          Text(busy ? "Prüfe…" : "Anmelden")
        }
        .buttonStyle(.borderedProminent)
        .disabled(busy || !OTPCode.isValid(code))
        Button("E-Mail ändern") { step = .email; code = ""; errorText = nil }
          .buttonStyle(.plain).font(.footnote)
      }

      if let errorText {
        Text(errorText).font(.footnote).foregroundStyle(.red)
      }
    }
    .padding(40)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private func requestCode() {
    busy = true; errorText = nil
    Task {
      do {
        try await auth.sendEmailCode(to: email.trimmingCharacters(in: .whitespaces))
        step = .code
      } catch {
        errorText = "Konnte keinen Code senden: \(error.localizedDescription)"
      }
      busy = false
    }
  }

  private func verify() {
    busy = true; errorText = nil
    Task {
      do {
        try await auth.verifyEmailCode(email: email.trimmingCharacters(in: .whitespaces), code: code)
        // Bei Erfolg schaltet RootView via auth.status automatisch auf die Shell.
      } catch {
        errorText = "Code ungültig oder abgelaufen."
      }
      busy = false
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
git add apps/comhub-native/ComHub/Auth/SignInView.swift
git commit -m "ComHub: SignInView (OTP-Code-Login)"
```

---

## Task 13: `AppleAuthorizationService` (Permissions)

**Files:**
- Create: `apps/comhub-native/ComHub/Apple/AppleAuthorizationService.swift`

> Phase 0 fragt nur die Berechtigungen an und hält den Status. Tatsächliches Lesen von Events/Kontakten kommt in Phase 1. Reine Logik liegt schon getestet in `AtollHub`; dieser Service kapselt die Apple-Frameworks und wird per manuellem Smoke-Test geprüft (System-Dialoge erscheinen beim ersten Start).

- [ ] **Step 1: Service schreiben**

`apps/comhub-native/ComHub/Apple/AppleAuthorizationService.swift`:

```swift
import Foundation
import Observation
import EventKit
import Contacts

/// Vereinheitlichter Berechtigungs-Status pro Apple-Datenquelle.
enum CapabilityAuthorization: Sendable {
  case notDetermined, authorized, denied, restricted
}

@MainActor
@Observable
final class AppleAuthorizationService {
  private(set) var calendars: CapabilityAuthorization = .notDetermined
  private(set) var reminders: CapabilityAuthorization = .notDetermined
  private(set) var contacts: CapabilityAuthorization = .notDetermined

  private let eventStore = EKEventStore()
  private let contactStore = CNContactStore()

  /// Beim App-Start aufrufen: fragt alle drei Berechtigungen an und merkt sich den Status.
  func requestAll() async {
    calendars = await mapEvent { try await eventStore.requestFullAccessToEvents() }
    reminders = await mapEvent { try await eventStore.requestFullAccessToReminders() }
    contacts  = await requestContacts()
  }

  func refreshStatus() {
    calendars = Self.map(EKEventStore.authorizationStatus(for: .event))
    reminders = Self.map(EKEventStore.authorizationStatus(for: .reminder))
    contacts  = Self.map(CNContactStore.authorizationStatus(for: .contacts))
  }

  // MARK: – Helpers

  private func mapEvent(_ request: () async throws -> Bool) async -> CapabilityAuthorization {
    do { return try await request() ? .authorized : .denied }
    catch { return .denied }
  }

  private func requestContacts() async -> CapabilityAuthorization {
    await withCheckedContinuation { continuation in
      contactStore.requestAccess(for: .contacts) { granted, _ in
        continuation.resume(returning: granted ? .authorized : .denied)
      }
    }
  }

  private static func map(_ status: EKAuthorizationStatus) -> CapabilityAuthorization {
    // `default` statt explizitem (deprecated) `.authorized` — vermeidet
    // Compile-Risiko, falls das Symbol auf dem SDK entfällt; `.fullAccess`
    // und `.writeOnly` sind das aktuelle „darf lesen/schreiben".
    switch status {
    case .fullAccess, .writeOnly: return .authorized
    case .denied:        return .denied
    case .restricted:    return .restricted
    case .notDetermined: return .notDetermined
    default:             return .notDetermined
    }
  }

  private static func map(_ status: CNAuthorizationStatus) -> CapabilityAuthorization {
    switch status {
    case .authorized:    return .authorized
    case .denied:        return .denied
    case .restricted:    return .restricted
    case .notDetermined: return .notDetermined
    default:             return .authorized  // .limited (neuere SDKs) zählt als Zugriff
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
git add apps/comhub-native/ComHub/Apple/AppleAuthorizationService.swift
git commit -m "ComHub: AppleAuthorizationService (Kalender/Erinnerungen/Kontakte)"
```

---

## Task 14: `HubShell` (3-Spalten-Shell + Modul-Leiste)

**Files:**
- Create: `apps/comhub-native/ComHub/Shell/HubShell.swift`

- [ ] **Step 1: Shell schreiben**

`apps/comhub-native/ComHub/Shell/HubShell.swift`:

```swift
import SwiftUI
import AtollHub

/// Outlook-artige 3-Spalten-Shell: Modul-Leiste · Liste · Detail.
/// Phase 0 zeigt Platzhalter pro Modul; echte Inhalte folgen in Phase 1+.
struct HubShell: View {
  @State private var selectedModule: ComHubModule = .heute

  var body: some View {
    NavigationSplitView {
      List(ComHubModule.allCases, selection: $selectedModule) { module in
        Label(module.title, systemImage: module.systemImage)
          .tag(module)
      }
      .navigationTitle("ComHub")
      #if os(macOS)
      .frame(minWidth: 200)
      #endif
    } content: {
      ModulePlaceholder(module: selectedModule, pane: "Liste")
        #if os(macOS)
        .frame(minWidth: 280)
        #endif
    } detail: {
      ModulePlaceholder(module: selectedModule, pane: "Detail")
    }
  }
}

/// Platzhalter-Pane bis das jeweilige Modul gebaut ist.
private struct ModulePlaceholder: View {
  let module: ComHubModule
  let pane: String

  var body: some View {
    VStack(spacing: 8) {
      Image(systemName: module.systemImage).font(.system(size: 40)).foregroundStyle(.secondary)
      Text(module.title).font(.title2.weight(.semibold))
      Text("\(pane) — kommt in einer späteren Phase").foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding()
  }
}
```

- [ ] **Step 2: Build verifizieren**

Run: `cd apps/comhub-native && xcodegen generate && xcodebuild -scheme ComHub -destination 'platform=macOS,arch=arm64' build`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add apps/comhub-native/ComHub/Shell/HubShell.swift
git commit -m "ComHub: HubShell (3-Spalten-Shell mit Modul-Leiste, Platzhalter)"
```

---

## Task 15: `RootView` + App verdrahten (voller Durchstich)

**Files:**
- Create: `apps/comhub-native/ComHub/Shell/RootView.swift`
- Modify: `apps/comhub-native/ComHub/ComHubApp.swift`

- [ ] **Step 1: `RootView` schreiben** (Gate nach Auth-Status)

`apps/comhub-native/ComHub/Shell/RootView.swift`:

```swift
import SwiftUI
import AtollCore

/// Wurzel-View: schaltet zwischen Lade-Spinner, Login und Shell — gesteuert
/// vom `AuthState.status`.
struct RootView: View {
  @Environment(AuthState.self) private var auth

  var body: some View {
    switch auth.status {
    case .loading:
      ProgressView().controlSize(.large)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    case .signedOut:
      SignInView()
    case .signedIn:
      HubShell()
    }
  }
}
```

- [ ] **Step 2: `ComHubApp.swift` verdrahten** (ganzen Datei-Inhalt aus Task 10 ersetzen)

`apps/comhub-native/ComHub/ComHubApp.swift`:

```swift
import SwiftUI
import AtollCore
import AtollHub
import OSLog

@main
struct ComHubApp: App {
  @Environment(\.scenePhase) private var scenePhase

  @State private var auth: AuthState
  @State private var localeStore: LocaleStore
  @State private var hub: Hub
  @State private var appleAuth: AppleAuthorizationService

  private static let logger = Logger(subsystem: "swiss.atoll.hub", category: "app")

  /// Erzwingt `AtollCoreConfig.register(...)` vor jeder `State`-Initialisierung —
  /// siehe swift-packages/README.md (AuthState.init greift sofort auf
  /// SupabaseClient.shared zu, das die Config braucht).
  private static let bootstrap: Void = {
    AtollCoreConfig.register(AppSupabaseConfig())
    return ()
  }()

  init() {
    _ = Self.bootstrap
    _auth = State(initialValue: AuthState())
    _localeStore = State(initialValue: LocaleStore())
    _hub = State(initialValue: Hub())
    _appleAuth = State(initialValue: AppleAuthorizationService())
  }

  var body: some Scene {
    WindowGroup {
      RootView()
        .environment(auth)
        .environment(localeStore)
        .environment(hub)
        .environment(appleAuth)
        .environment(\.locale, localeStore.locale)
        .task {
          // Apple-Berechtigungen beim ersten Start anfragen (System-Dialoge).
          await appleAuth.requestAll()
        }
        .onOpenURL { url in
          guard url.scheme == "comhub" else { return }
          Task { @MainActor in
            do { try await auth.handleAuthCallback(url: url) }
            catch { Self.logger.error("handleAuthCallback failed: \(error.localizedDescription, privacy: .public)") }
          }
        }
        .onChange(of: scenePhase) { _, newPhase in
          if newPhase == .active { appleAuth.refreshStatus() }
        }
    }
  }
}
```

- [ ] **Step 3: Generieren + voller Build + Tests**

Run: `cd apps/comhub-native && xcodegen generate && xcodebuild -scheme ComHub -destination 'platform=macOS,arch=arm64' build`
Expected: `** BUILD SUCCEEDED **`.

Run: `cd apps/comhub-native && xcodebuild test -scheme ComHub -destination 'platform=macOS,arch=arm64'`
Expected: `** TEST SUCCEEDED **` — `ComHubTests` (2 Tests) grün.

- [ ] **Step 4: Manueller Smoke-Test** (auf echtem Mac, nicht automatisierbar)

Reihenfolge durchspielen:
- [ ] App startet → Lade-Spinner → `SignInView`.
- [ ] System-Dialoge für Kalender/Erinnerungen/Kontakte erscheinen (einmalig).
- [ ] E-Mail eingeben → „Code anfordern" → Mail mit 6-stelligem Code trifft ein.
- [ ] Code eingeben → „Anmelden" → Shell erscheint.
- [ ] Modul-Leiste: zwischen Heute/Kalender/Kombox/Kontakte/Aufgaben/CardInbox/Einstellungen wechseln → Platzhalter zeigen Titel + Pane.
- [ ] App neu starten → bleibt angemeldet (Session aus Keychain) → direkt Shell.

- [ ] **Step 5: Commit**

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add apps/comhub-native/ComHub/Shell/RootView.swift apps/comhub-native/ComHub/ComHubApp.swift
git commit -m "ComHub: RootView-Gating + App verdrahtet (Auth, Hub, Apple-Permissions) — Durchstich gruen"
```

---

## Task 16: Dokumentation

**Files:**
- Modify: `swift-packages/README.md`
- Create: `apps/comhub-native/README.md`

- [ ] **Step 1: `swift-packages/README.md` ergänzen**

In `swift-packages/README.md`, in der Liste unter „## Packages" **nach** dem `AtollDesign`-Eintrag einfügen:

```markdown
- **AtollHub** — anbieter-offener Kern für ComHub: quellneutrale Modelle
  (`UnifiedEvent/Message/Task/Contact`, `Lead`), Capability-Protokolle
  (`CalendarProvider`/`MailProvider`/`TodoProvider`/`ContactsProvider` +
  Atoll-spezifisch `CommsProvider`/`EventsProvider`/`CardInboxProvider`),
  der `Hub`-Aggregator über `AccountConnection`, sowie reine Hilfen
  (`ContactKey`, `ContactMatcher`, `ComHubModule`, `OTPCode`).
  Dependency-leicht (keine Supabase-Abhängigkeit) — Adapter implementieren die
  Protokolle in den Apps. Konsumiert von: `apps/comhub-native`.
  Tests: `cd swift-packages/AtollHub && swift test`.
```

- [ ] **Step 2: `apps/comhub-native/README.md` schreiben**

`apps/comhub-native/README.md`:

```markdown
# ComHub — anbieter-offener macOS/iOS-Hub

Native SwiftUI-App (iOS 26 / macOS 26, Swift 6, Strict Concurrency Complete).
Outlook-artiger Hub: Heute-Cockpit, Kalender, Kombox, Kontakte, Aufgaben,
CardInbox — anbieter-offen (Apple/iCloud + Atoll zuerst; Google/Microsoft
später). Baut auf `AtollCore`, `AtollDesign` und `AtollHub` auf.

- Bundle-ID: `swiss.atoll.hub`
- URL-Scheme: `comhub://`
- Single-Tenant: TSK Zürich

## Setup

```bash
cd apps/comhub-native
xcodegen generate
open ComHub.xcodeproj
```

`ComHub.xcodeproj` ist gitignored — wird aus `project.yml` regeneriert.

## Build & Test

```bash
# macOS
xcodebuild -scheme ComHub -destination 'platform=macOS,arch=arm64' build
xcodebuild test -scheme ComHub -destination 'platform=macOS,arch=arm64'

# Kern-Logik (schnell, ohne Xcode)
cd ../../swift-packages/AtollHub && swift test
```

## Phase 0 (dieser Stand)

OTP-Login gegen Atoll-Supabase, leere 3-Spalten-Shell mit Modul-Leiste,
getesteter Provider-Kern (`AtollHub`). **Keine** echten Daten-Adapter — die
kommen in Phase 1+ (siehe `docs/superpowers/plans/`).
```

- [ ] **Step 3: Commit**

```bash
cd /Users/dominik/Desktop/Developer/Dispo
git add swift-packages/README.md apps/comhub-native/README.md
git commit -m "Docs: AtollHub im Packages-README + ComHub-README (Phase 0)"
```

---

## Self-Review (durchgeführt)

**1. Spec-Abdeckung (Phase 0 laut Spec §11):**
- „Multiplatform-SwiftUI-Projekt" → Task 10 (`project.yml`, iOS+macOS).
- „AtollDesign + (AtollCal) als Packages; supabase-swift" → AtollDesign + supabase-swift in Task 10 verdrahtet; **AtollCal-Paketierung bewusst Phase-1-Voraussetzung** (Scope-Grenze oben + README).
- „Provider-/Account-Kern (Protokolle + Capability-Matrix)" → Tasks 2–5 (Modelle, Account/Capability, Protokolle, Hub).
- „Atoll-Auth (OTP)" → Task 11 (AuthState) + Task 12 (SignInView) + Task 9 (OTPCode).
- „Apple-Permissions" → Task 13 (AppleAuthorizationService) + Info.plist/Entitlements in Task 10.
- „leere 3-Spalten-Shell + Modul-Leiste" → Task 8 (ComHubModule) + Task 14 (HubShell) + Task 15 (RootView/Gating).

**2. Platzhalter-Scan:** Keine „TBD/TODO/später ausfüllen"-Schritte; jeder Code-Schritt zeigt vollständigen Code, jeder Run-Schritt nennt Befehl + erwartete Ausgabe. „Platzhalter"-Views (ModulePlaceholder) sind bewusste, vollständig implementierte UI — kein Plan-Loch.

**3. Typ-Konsistenz:** `AccountRef(accountId:type:)`, `Account(id:type:displayName:capabilities:)` + `.ref`/`.supports`, `UnifiedEvent(id:source:title:start:end:isAllDay:location:)`, `CalendarProvider.events(in:)`, `Hub.connect(_:)`/`allEvents(in:)`/`allTasks()`/`allContacts()`/`connections`/`lastErrors`, `AccountConnection(account:calendar:mail:todo:contacts:)`, `ContactKey.email/phone`, `ContactMatcher.group(_:)`, `ComHubModule.title/systemImage/allCases`, `OTPCode.isValid/sanitize`, `AuthState.sendEmailCode(to:)`/`verifyEmailCode(email:code:)` — über Tests, Fakes, App und SignInView hinweg identisch verwendet.

---

## Execution Handoff

**Plan komplett und gespeichert unter `docs/superpowers/plans/2026-06-02-comhub-phase0-foundation.md`. Zwei Ausführungs-Optionen:**

**1. Subagent-Driven (empfohlen)** — ich schicke pro Task einen frischen Subagenten los, prüfe zwischen den Tasks, schnelle Iteration. (REQUIRED SUB-SKILL: superpowers:subagent-driven-development.)

**2. Inline-Ausführung** — Tasks in dieser Session abarbeiten, Batch mit Checkpoints (REQUIRED SUB-SKILL: superpowers:executing-plans).

**Welcher Ansatz?**
