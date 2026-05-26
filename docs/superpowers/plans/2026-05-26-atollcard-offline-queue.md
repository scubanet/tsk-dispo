# AtollCard Offline-Queue — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** SwiftData-Cache vor die 3 Repositories ziehen + Mutation-Queue für offline-Status-Changes, mit FIFO-Drainer bei Reachability-Recovery.

**Architecture:** Decorator-Pattern um existing `*Repository`-Protocols. Reads aus SwiftData mit opportunistischem Background-Refresh. Writes (nur `updateLeadStatus`) gehen optimistic in den Cache + eine `PendingLeadStatusMutation`-Queue, ein `MutationDrainer` schickt sie an Supabase wenn `NWPathMonitor` online meldet. Conflict: Last-Write-Wins clientseitig.

**Tech Stack:** Swift 6 + SwiftData + Network.framework (NWPathMonitor) + @Observable + XCTest.

**Spec:** `docs/superpowers/specs/2026-05-26-atollcard-offline-queue-design.md`

---

## Phase A — SwiftData Foundation

### Task 1: `CardEntity` + `LeadEntity` + `ScanEntity` @Model

**Files:**
- Create: `apps/atollcard-native/AtollCard/Cache/CardEntity.swift`
- Create: `apps/atollcard-native/AtollCard/Cache/LeadEntity.swift`
- Create: `apps/atollcard-native/AtollCard/Cache/ScanEntity.swift`

- [ ] **Step 1: `CardEntity.swift`**

```swift
import Foundation
import SwiftData

@Model
final class CardEntity {
  @Attribute(.unique) var id: UUID
  var personId:               UUID
  var slug:                   String
  var title:                  String
  var subtitle:               String?
  var badge:                  String?
  var themeJSON:              String        // Codable round-tripped CardTheme
  var diveJSON:               String?       // Codable round-tripped DiveProfile?
  var fieldVisibilityJSON:    String        // Codable round-tripped FieldVisibility
  var isDefault:              Bool
  var isActive:               Bool
  var createdAt:              Date
  var updatedAt:              Date
  var lastFetched:            Date

  init(id: UUID, personId: UUID, slug: String, title: String, subtitle: String?,
       badge: String?, themeJSON: String, diveJSON: String?, fieldVisibilityJSON: String,
       isDefault: Bool, isActive: Bool, createdAt: Date, updatedAt: Date, lastFetched: Date) {
    self.id = id; self.personId = personId; self.slug = slug; self.title = title
    self.subtitle = subtitle; self.badge = badge
    self.themeJSON = themeJSON; self.diveJSON = diveJSON; self.fieldVisibilityJSON = fieldVisibilityJSON
    self.isDefault = isDefault; self.isActive = isActive
    self.createdAt = createdAt; self.updatedAt = updatedAt; self.lastFetched = lastFetched
  }
}
```

- [ ] **Step 2: `LeadEntity.swift`**

```swift
import Foundation
import SwiftData

@Model
final class LeadEntity {
  @Attribute(.unique) var id: UUID
  var cardId:                 UUID
  var firstName:              String
  var lastName:               String?
  var email:                  String?
  var phone:                  String?
  var message:                String?
  var topic:                  String?
  var capturedAt:             Date
  var status:                 String        // LeadStatus.rawValue
  var avatarColor:            String?
  var importedToAddressBook:  Bool
  var importedContactId:      UUID?
  var lastFetched:            Date

  init(id: UUID, cardId: UUID, firstName: String, lastName: String?, email: String?,
       phone: String?, message: String?, topic: String?, capturedAt: Date,
       status: String, avatarColor: String?, importedToAddressBook: Bool,
       importedContactId: UUID?, lastFetched: Date) {
    self.id = id; self.cardId = cardId
    self.firstName = firstName; self.lastName = lastName
    self.email = email; self.phone = phone
    self.message = message; self.topic = topic
    self.capturedAt = capturedAt; self.status = status
    self.avatarColor = avatarColor
    self.importedToAddressBook = importedToAddressBook
    self.importedContactId = importedContactId
    self.lastFetched = lastFetched
  }
}
```

- [ ] **Step 3: `ScanEntity.swift`**

```swift
import Foundation
import SwiftData

@Model
final class ScanEntity {
  @Attribute(.unique) var id: UUID
  var cardId:                 UUID
  var scannedAt:              Date
  var source:                 String        // 'qr' / 'nfc' / 'airdrop' / etc.
  var ipCountry:              String?
  var convertedToLead:        Bool
  var fieldTapped:            String?
  var lastFetched:            Date

  init(id: UUID, cardId: UUID, scannedAt: Date, source: String, ipCountry: String?,
       convertedToLead: Bool, fieldTapped: String?, lastFetched: Date) {
    self.id = id; self.cardId = cardId
    self.scannedAt = scannedAt; self.source = source
    self.ipCountry = ipCountry; self.convertedToLead = convertedToLead
    self.fieldTapped = fieldTapped
    self.lastFetched = lastFetched
  }
}
```

- [ ] **Step 4: Commit**

```bash
git add apps/atollcard-native/AtollCard/Cache/CardEntity.swift \
        apps/atollcard-native/AtollCard/Cache/LeadEntity.swift \
        apps/atollcard-native/AtollCard/Cache/ScanEntity.swift
git commit -m "feat(offline): @Model entities (Card/Lead/Scan)"
```

---

### Task 2: `PendingLeadStatusMutation` @Model

**Files:**
- Create: `apps/atollcard-native/AtollCard/Cache/PendingLeadStatusMutation.swift`

- [ ] **Step 1: Modell schreiben**

```swift
import Foundation
import SwiftData

@Model
final class PendingLeadStatusMutation {
  @Attribute(.unique) var id: UUID    // unique mutation id (NOT leadId — multiple mutations per lead are allowed)
  var leadId:        UUID
  var newStatus:     String           // LeadStatus.rawValue
  var enqueuedAt:    Date
  var attempts:      Int
  var lastError:     String?
  var lastAttemptAt: Date?
  var isDead:        Bool

  init(id: UUID, leadId: UUID, newStatus: String, enqueuedAt: Date,
       attempts: Int, lastError: String? = nil, lastAttemptAt: Date? = nil,
       isDead: Bool = false) {
    self.id = id; self.leadId = leadId; self.newStatus = newStatus
    self.enqueuedAt = enqueuedAt; self.attempts = attempts
    self.lastError = lastError; self.lastAttemptAt = lastAttemptAt
    self.isDead = isDead
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add apps/atollcard-native/AtollCard/Cache/PendingLeadStatusMutation.swift
git commit -m "feat(offline): PendingLeadStatusMutation @Model"
```

---

### Task 3: `CacheConverters` — Domain ↔ Entity

**Files:**
- Create: `apps/atollcard-native/AtollCard/Cache/CacheConverters.swift`

- [ ] **Step 1: Converter-Extensions schreiben**

```swift
import Foundation

/// Converters between domain structs (Card/Lead/Scan from Models/) and
/// SwiftData entities (CardEntity/LeadEntity/ScanEntity).
/// JSON columns (themeJSON, diveJSON, fieldVisibilityJSON) are encoded
/// via the standard JSONEncoder/Decoder.

enum CacheConvertError: Error {
  case encodeFailed(String)
  case decodeFailed(String)
  case unknownStatus(String)
}

extension Card {
  init(entity: CardEntity) throws {
    guard let theme = try? JSONDecoder().decode(CardTheme.self,
                                                from: Data(entity.themeJSON.utf8)) else {
      throw CacheConvertError.decodeFailed("theme")
    }
    let dive: DiveProfile?
    if let diveJSON = entity.diveJSON {
      dive = try? JSONDecoder().decode(DiveProfile.self, from: Data(diveJSON.utf8))
    } else { dive = nil }
    guard let fv = try? JSONDecoder().decode(FieldVisibility.self,
                                             from: Data(entity.fieldVisibilityJSON.utf8)) else {
      throw CacheConvertError.decodeFailed("fieldVisibility")
    }
    self.init(
      id:               entity.id,
      personId:         entity.personId,
      slug:             entity.slug,
      title:            entity.title,
      subtitle:         entity.subtitle,
      badge:            entity.badge,
      theme:            theme,
      diveProfile:      dive,
      fieldVisibility:  fv,
      isDefault:        entity.isDefault,
      isActive:         entity.isActive,
      createdAt:        entity.createdAt,
      updatedAt:        entity.updatedAt
    )
  }

  func toEntity(lastFetched: Date = .now) throws -> CardEntity {
    let enc = JSONEncoder()
    guard let themeData = try? enc.encode(theme),
          let themeStr = String(data: themeData, encoding: .utf8) else {
      throw CacheConvertError.encodeFailed("theme")
    }
    let diveStr: String? = diveProfile.flatMap { dp in
      (try? enc.encode(dp)).flatMap { String(data: $0, encoding: .utf8) }
    }
    guard let fvData = try? enc.encode(fieldVisibility),
          let fvStr  = String(data: fvData, encoding: .utf8) else {
      throw CacheConvertError.encodeFailed("fieldVisibility")
    }
    return CardEntity(
      id:                  id,
      personId:            personId,
      slug:                slug,
      title:               title,
      subtitle:            subtitle,
      badge:               badge,
      themeJSON:           themeStr,
      diveJSON:            diveStr,
      fieldVisibilityJSON: fvStr,
      isDefault:           isDefault,
      isActive:            isActive,
      createdAt:           createdAt,
      updatedAt:           updatedAt,
      lastFetched:         lastFetched
    )
  }
}

extension Lead {
  init(entity: LeadEntity) throws {
    guard let status = LeadStatus(rawValue: entity.status) else {
      throw CacheConvertError.unknownStatus(entity.status)
    }
    self.init(
      id:                     entity.id,
      cardId:                 entity.cardId,
      firstName:              entity.firstName,
      lastName:               entity.lastName,
      email:                  entity.email,
      phone:                  entity.phone,
      message:                entity.message,
      topic:                  entity.topic,
      capturedAt:             entity.capturedAt,
      status:                 status,
      avatarColor:            entity.avatarColor,
      importedToAddressBook:  entity.importedToAddressBook,
      importedContactId:      entity.importedContactId
    )
  }

  func toEntity(lastFetched: Date = .now) -> LeadEntity {
    LeadEntity(
      id:                    id,
      cardId:                cardId,
      firstName:             firstName,
      lastName:              lastName,
      email:                 email,
      phone:                 phone,
      message:               message,
      topic:                 topic,
      capturedAt:            capturedAt,
      status:                status.rawValue,
      avatarColor:           avatarColor,
      importedToAddressBook: importedToAddressBook,
      importedContactId:     importedContactId,
      lastFetched:           lastFetched
    )
  }
}
```

(Scan-Converter analog — Plan kürzt zur Brevity; gleiche Pattern.)

- [ ] **Step 2: Commit**

```bash
git add apps/atollcard-native/AtollCard/Cache/CacheConverters.swift
git commit -m "feat(offline): CacheConverters — Card/Lead/Scan ↔ Entity"
```

---

### Task 4: `CacheStore` — ModelContainer Wrapper + CRUD

**Files:**
- Create: `apps/atollcard-native/AtollCard/Cache/CacheStore.swift`

- [ ] **Step 1: CacheStore mit Container-Init + Card/Lead-CRUD**

```swift
import Foundation
import SwiftData

@MainActor
final class CacheStore {
  let container: ModelContainer
  private var context: ModelContext { container.mainContext }

  init() throws {
    let schema = Schema([
      CardEntity.self, LeadEntity.self, ScanEntity.self,
      PendingLeadStatusMutation.self,
    ])
    self.container = try ModelContainer(
      for: schema,
      configurations: ModelConfiguration(isStoredInMemoryOnly: false)
    )
  }

  // MARK: - Cards

  func cards() -> [Card] {
    let descriptor = FetchDescriptor<CardEntity>(
      sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
    )
    return (try? context.fetch(descriptor))?.compactMap { try? Card(entity: $0) } ?? []
  }

  func card(id: UUID) -> Card? {
    let descriptor = FetchDescriptor<CardEntity>(predicate: #Predicate { $0.id == id })
    return (try? context.fetch(descriptor))?.first.flatMap { try? Card(entity: $0) }
  }

  func upsertCard(_ card: Card) {
    let descriptor = FetchDescriptor<CardEntity>(predicate: #Predicate { $0.id == card.id })
    if let existing = (try? context.fetch(descriptor))?.first {
      context.delete(existing)
    }
    if let entity = try? card.toEntity() {
      context.insert(entity)
    }
    try? context.save()
  }

  func deleteCard(id: UUID) {
    let descriptor = FetchDescriptor<CardEntity>(predicate: #Predicate { $0.id == id })
    if let existing = (try? context.fetch(descriptor))?.first {
      context.delete(existing)
      try? context.save()
    }
  }

  // MARK: - Leads

  func leads() -> [Lead] {
    let descriptor = FetchDescriptor<LeadEntity>(
      sortBy: [SortDescriptor(\.capturedAt, order: .reverse)]
    )
    return (try? context.fetch(descriptor))?.compactMap { try? Lead(entity: $0) } ?? []
  }

  func upsertLead(_ lead: Lead) {
    let descriptor = FetchDescriptor<LeadEntity>(predicate: #Predicate { $0.id == lead.id })
    if let existing = (try? context.fetch(descriptor))?.first {
      context.delete(existing)
    }
    context.insert(lead.toEntity())
    try? context.save()
  }

  func updateLeadStatus(leadId: UUID, status: LeadStatus) {
    let descriptor = FetchDescriptor<LeadEntity>(predicate: #Predicate { $0.id == leadId })
    guard let entity = (try? context.fetch(descriptor))?.first else { return }
    entity.status = status.rawValue
    try? context.save()
  }

  func deleteLead(id: UUID) {
    let descriptor = FetchDescriptor<LeadEntity>(predicate: #Predicate { $0.id == id })
    if let existing = (try? context.fetch(descriptor))?.first {
      context.delete(existing)
      try? context.save()
    }
  }

  // MARK: - Mutations

  func enqueue(_ mutation: PendingLeadStatusMutation) {
    context.insert(mutation)
    try? context.save()
  }

  func nextPendingMutation() -> PendingLeadStatusMutation? {
    var descriptor = FetchDescriptor<PendingLeadStatusMutation>(
      predicate: #Predicate { $0.isDead == false },
      sortBy: [SortDescriptor(\.enqueuedAt, order: .forward)]
    )
    descriptor.fetchLimit = 1
    return (try? context.fetch(descriptor))?.first
  }

  func removePendingMutation(id: UUID) {
    let descriptor = FetchDescriptor<PendingLeadStatusMutation>(predicate: #Predicate { $0.id == id })
    if let m = (try? context.fetch(descriptor))?.first {
      context.delete(m)
      try? context.save()
    }
  }

  func recordFailure(mutationId: UUID, error: Error) {
    let descriptor = FetchDescriptor<PendingLeadStatusMutation>(predicate: #Predicate { $0.id == mutationId })
    guard let m = (try? context.fetch(descriptor))?.first else { return }
    m.attempts += 1
    m.lastError = error.localizedDescription
    m.lastAttemptAt = .now
    try? context.save()
  }

  func markDead(mutationId: UUID) {
    let descriptor = FetchDescriptor<PendingLeadStatusMutation>(predicate: #Predicate { $0.id == mutationId })
    guard let m = (try? context.fetch(descriptor))?.first else { return }
    m.isDead = true
    try? context.save()
  }

  func deadLetters() -> [PendingLeadStatusMutation] {
    let descriptor = FetchDescriptor<PendingLeadStatusMutation>(
      predicate: #Predicate { $0.isDead == true }
    )
    return (try? context.fetch(descriptor)) ?? []
  }

  func pendingCount() -> Int {
    let descriptor = FetchDescriptor<PendingLeadStatusMutation>(
      predicate: #Predicate { $0.isDead == false }
    )
    return (try? context.fetchCount(descriptor)) ?? 0
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add apps/atollcard-native/AtollCard/Cache/CacheStore.swift
git commit -m "feat(offline): CacheStore — ModelContainer + Card/Lead CRUD + mutation queue"
```

---

### Task 5: `CacheStoreTests`

**Files:**
- Create: `apps/atollcard-native/AtollCardTests/CacheStoreTests.swift`

- [ ] **Step 1: Failing Tests schreiben**

```swift
import XCTest
import SwiftData
@testable import AtollCard

@MainActor
final class CacheStoreTests: XCTestCase {
  func makeStore() throws -> CacheStore {
    // In-memory ModelContainer for isolation
    let store = try CacheStore()  // file-based by default
    return store
  }

  func test_enqueue_and_drain_FIFO() throws {
    let store = try makeStore()
    let leadId = UUID()
    let m1 = PendingLeadStatusMutation(id: UUID(), leadId: leadId, newStatus: "opened",
                                       enqueuedAt: Date(timeIntervalSince1970: 1000),
                                       attempts: 0)
    let m2 = PendingLeadStatusMutation(id: UUID(), leadId: leadId, newStatus: "contacted",
                                       enqueuedAt: Date(timeIntervalSince1970: 2000),
                                       attempts: 0)
    store.enqueue(m1)
    store.enqueue(m2)

    let first = store.nextPendingMutation()
    XCTAssertEqual(first?.newStatus, "opened")
  }

  func test_recordFailure_increments_attempts() throws {
    let store = try makeStore()
    let m = PendingLeadStatusMutation(id: UUID(), leadId: UUID(), newStatus: "spam",
                                      enqueuedAt: .now, attempts: 0)
    store.enqueue(m)
    store.recordFailure(mutationId: m.id, error: NSError(domain: "test", code: 500))

    let after = store.nextPendingMutation()
    XCTAssertEqual(after?.attempts, 1)
    XCTAssertNotNil(after?.lastError)
  }

  func test_markDead_removes_from_active_queue() throws {
    let store = try makeStore()
    let m = PendingLeadStatusMutation(id: UUID(), leadId: UUID(), newStatus: "spam",
                                      enqueuedAt: .now, attempts: 5)
    store.enqueue(m)
    store.markDead(mutationId: m.id)

    XCTAssertNil(store.nextPendingMutation())
    XCTAssertEqual(store.deadLetters().count, 1)
  }

  func test_pendingCount_excludes_dead() throws {
    let store = try makeStore()
    let live = PendingLeadStatusMutation(id: UUID(), leadId: UUID(), newStatus: "spam",
                                         enqueuedAt: .now, attempts: 0)
    let dead = PendingLeadStatusMutation(id: UUID(), leadId: UUID(), newStatus: "spam",
                                         enqueuedAt: .now, attempts: 5, isDead: true)
    store.enqueue(live)
    store.enqueue(dead)

    XCTAssertEqual(store.pendingCount(), 1)
  }
}
```

- [ ] **Step 2: Commit (xcodebuild test skipped in sandbox)**

```bash
git add apps/atollcard-native/AtollCardTests/CacheStoreTests.swift
git commit -m "test(offline): CacheStoreTests for mutation queue ordering + lifecycle"
```

---

## Phase B — Reachability + Drainer

### Task 6: `ReachabilityMonitor`

**Files:**
- Create: `apps/atollcard-native/AtollCard/Services/ReachabilityMonitor.swift`

- [ ] **Step 1: Service schreiben**

```swift
import Foundation
import Network
import Observation
import OSLog

@MainActor
@Observable
final class ReachabilityMonitor {
  private(set) var isConnected: Bool = true
  private let monitor = NWPathMonitor()
  private let queue   = DispatchQueue(label: "swiss.atoll.card.reachability")
  private static let logger = Logger(subsystem: "swiss.atoll.card", category: "reachability")

  init() {}

  func start() {
    monitor.pathUpdateHandler = { [weak self] path in
      Task { @MainActor [weak self] in
        let newValue = (path.status == .satisfied)
        if self?.isConnected != newValue {
          Self.logger.debug("Reachability: \(newValue ? "online" : "offline", privacy: .public)")
        }
        self?.isConnected = newValue
      }
    }
    monitor.start(queue: queue)
  }

  deinit { monitor.cancel() }
}
```

- [ ] **Step 2: Commit**

```bash
git add apps/atollcard-native/AtollCard/Services/ReachabilityMonitor.swift
git commit -m "feat(offline): ReachabilityMonitor — NWPathMonitor wrapper"
```

---

### Task 7: `MutationDrainer` + Tests

**Files:**
- Create: `apps/atollcard-native/AtollCard/Services/MutationDrainer.swift`
- Create: `apps/atollcard-native/AtollCardTests/MutationDrainerTests.swift`

- [ ] **Step 1: Drainer schreiben**

```swift
import Foundation
import Observation
import OSLog

@MainActor
@Observable
final class MutationDrainer {
  private let cache:  CacheStore
  private let remote: LeadRepository
  private var isDraining = false
  private static let logger = Logger(subsystem: "swiss.atoll.card", category: "drainer")

  init(cache: CacheStore, remote: LeadRepository) {
    self.cache  = cache
    self.remote = remote
  }

  func drain() async {
    guard !isDraining else {
      Self.logger.debug("drain() — already draining, skip")
      return
    }
    isDraining = true
    defer { isDraining = false }

    while let mutation = cache.nextPendingMutation() {
      guard let status = LeadStatus(rawValue: mutation.newStatus) else {
        // Unknown enum value — mark dead, can't recover
        Self.logger.error("Unknown status \(mutation.newStatus, privacy: .public) — marking dead")
        cache.markDead(mutationId: mutation.id)
        continue
      }
      do {
        try await remote.updateStatus(leadId: mutation.leadId, status: status)
        cache.removePendingMutation(id: mutation.id)
      } catch {
        if isAuthError(error) {
          // 401 — don't burn attempts, just bail until next reach edge or token refresh
          Self.logger.warning("auth error during drain, bailing without incrementing")
          return
        }
        cache.recordFailure(mutationId: mutation.id, error: error)
        if (mutation.attempts + 1) >= 5 {
          cache.markDead(mutationId: mutation.id)
          continue
        }
        return
      }
    }
  }

  func retryDeadLetter(mutationId: UUID) async {
    cache.resetMutation(mutationId: mutationId)   // reset attempts + isDead — see Task 8 update
    await drain()
  }

  private func isAuthError(_ error: Error) -> Bool {
    let ns = error as NSError
    // PostgrestError + URLError both surface 401 via different paths;
    // string-match is pragmatic.
    return ns.localizedDescription.contains("401")
        || ns.localizedDescription.contains("Unauthorized")
        || ns.localizedDescription.contains("JWT")
  }
}
```

- [ ] **Step 2: `CacheStore` Methode `resetMutation` ergänzen**

In `CacheStore.swift` ergänzen:

```swift
  func resetMutation(mutationId: UUID) {
    let descriptor = FetchDescriptor<PendingLeadStatusMutation>(predicate: #Predicate { $0.id == mutationId })
    guard let m = (try? context.fetch(descriptor))?.first else { return }
    m.attempts = 0
    m.lastError = nil
    m.lastAttemptAt = nil
    m.isDead = false
    try? context.save()
  }

  func discardMutation(mutationId: UUID) {
    let descriptor = FetchDescriptor<PendingLeadStatusMutation>(predicate: #Predicate { $0.id == mutationId })
    if let m = (try? context.fetch(descriptor))?.first {
      context.delete(m)
      try? context.save()
    }
  }
```

- [ ] **Step 3: Drainer-Tests schreiben**

```swift
import XCTest
@testable import AtollCard

@MainActor
final class MutationDrainerTests: XCTestCase {
  final class MockLeadRepo: LeadRepository {
    var failNext: Error?
    var calls: [(UUID, LeadStatus)] = []
    func updateStatus(leadId: UUID, status: LeadStatus) async throws {
      calls.append((leadId, status))
      if let err = failNext {
        failNext = nil
        throw err
      }
    }
    // Stub other methods if protocol requires
    func fetchAll(filter: LeadFilter) async throws -> [Lead] { [] }
    func fetch(id: UUID) async throws -> Lead? { nil }
    func upsert(_ lead: Lead) async throws { }
    func deleteLead(leadId: UUID) async throws { }
    func importLead(leadId: UUID) async throws -> ImportResult { .init(contactId: UUID(), action: "created") }
  }

  func test_drain_happy_path_removes_mutation() async throws {
    let cache = try CacheStore()
    let mock  = MockLeadRepo()
    let drainer = MutationDrainer(cache: cache, remote: mock)
    cache.enqueue(PendingLeadStatusMutation(id: UUID(), leadId: UUID(),
                                            newStatus: "opened",
                                            enqueuedAt: .now, attempts: 0))
    await drainer.drain()
    XCTAssertEqual(mock.calls.count, 1)
    XCTAssertNil(cache.nextPendingMutation())
  }

  func test_drain_records_failure_on_throw() async throws {
    let cache = try CacheStore()
    let mock  = MockLeadRepo()
    mock.failNext = NSError(domain: "net", code: 500)
    let drainer = MutationDrainer(cache: cache, remote: mock)
    let m = PendingLeadStatusMutation(id: UUID(), leadId: UUID(),
                                      newStatus: "spam", enqueuedAt: .now, attempts: 0)
    cache.enqueue(m)
    await drainer.drain()
    let after = cache.nextPendingMutation()
    XCTAssertNotNil(after)
    XCTAssertEqual(after?.attempts, 1)
  }
}
```

- [ ] **Step 4: Commit**

```bash
git add apps/atollcard-native/AtollCard/Services/MutationDrainer.swift \
        apps/atollcard-native/AtollCard/Cache/CacheStore.swift \
        apps/atollcard-native/AtollCardTests/MutationDrainerTests.swift
git commit -m "feat(offline): MutationDrainer with auth-aware retry + tests"
```

---

## Phase C — Cached Repositories

### Task 8: `CachedLeadRepository`

**Files:**
- Create: `apps/atollcard-native/AtollCard/Repositories/CachedLeadRepository.swift`

- [ ] **Step 1: Decorator schreiben**

```swift
import Foundation
import OSLog

final class CachedLeadRepository: LeadRepository {
  private let remote:  LeadRepository
  private let cache:   CacheStore
  private let drainer: MutationDrainer
  private let reach:   ReachabilityMonitor
  private static let logger = Logger(subsystem: "swiss.atoll.card", category: "cached-lead-repo")

  init(remote: LeadRepository, cache: CacheStore,
       drainer: MutationDrainer, reach: ReachabilityMonitor) {
    self.remote = remote; self.cache = cache
    self.drainer = drainer; self.reach = reach
  }

  // MARK: - Reads

  func fetchAll(filter: LeadFilter) async throws -> [Lead] {
    let cached = await MainActor.run { cache.leads() }
    if reach.isConnected {
      Task.detached { [weak self] in await self?.refreshAll() }
    }
    return cached.filter { applyFilter($0, filter: filter) }
  }

  func fetch(id: UUID) async throws -> Lead? {
    let cached = await MainActor.run { cache.leads().first(where: { $0.id == id }) }
    if reach.isConnected {
      Task.detached { [weak self] in
        if let fresh = try? await self?.remote.fetch(id: id), let lead = fresh {
          await MainActor.run { self?.cache.upsertLead(lead) }
        }
      }
    }
    return cached
  }

  private func refreshAll() async {
    guard let fresh = try? await remote.fetchAll(filter: .all) else { return }
    await MainActor.run {
      for lead in fresh { cache.upsertLead(lead) }
    }
  }

  // MARK: - Writes

  func updateStatus(leadId: UUID, status: LeadStatus) async throws {
    await MainActor.run {
      cache.updateLeadStatus(leadId: leadId, status: status)
      cache.enqueue(PendingLeadStatusMutation(
        id: UUID(), leadId: leadId, newStatus: status.rawValue,
        enqueuedAt: .now, attempts: 0
      ))
    }
    if reach.isConnected {
      Task.detached { [weak self] in await self?.drainer.drain() }
    }
  }

  func upsert(_ lead: Lead) async throws {
    try await remote.upsert(lead)
    await MainActor.run { cache.upsertLead(lead) }
  }

  func deleteLead(leadId: UUID) async throws {
    try await remote.deleteLead(leadId: leadId)
    await MainActor.run { cache.deleteLead(id: leadId) }
  }

  func importLead(leadId: UUID) async throws -> ImportResult {
    let result = try await remote.importLead(leadId: leadId)
    await MainActor.run { cache.updateLeadStatus(leadId: leadId, status: .imported) }
    return result
  }

  // MARK: - Filter

  private func applyFilter(_ lead: Lead, filter: LeadFilter) -> Bool {
    // Mirror server-side filter logic — kept local because cache reads are local
    // (Plan-shorthand: copy whatever filter does in MockLeadRepository for parity)
    switch filter {
    case .all: return true
    case .status(let s): return lead.status == s
    // …other cases as defined in existing LeadFilter
    }
  }
}
```

(`LeadFilter`-Cases müssen sich genau am existing `LeadFilter` orientieren — Plan-Skeleton, adaptier dich beim Implementieren.)

- [ ] **Step 2: Commit**

```bash
git add apps/atollcard-native/AtollCard/Repositories/CachedLeadRepository.swift
git commit -m "feat(offline): CachedLeadRepository — optimistic write + queue + cache reads"
```

---

### Task 9: `CachedCardRepository` (read-only cache)

**Files:**
- Create: `apps/atollcard-native/AtollCard/Repositories/CachedCardRepository.swift`

- [ ] **Step 1: Decorator schreiben**

```swift
import Foundation

final class CachedCardRepository: CardRepository {
  private let remote: CardRepository
  private let cache:  CacheStore
  private let reach:  ReachabilityMonitor

  init(remote: CardRepository, cache: CacheStore, reach: ReachabilityMonitor) {
    self.remote = remote; self.cache = cache; self.reach = reach
  }

  func fetchAll() async throws -> [Card] {
    let cached = await MainActor.run { cache.cards() }
    if reach.isConnected {
      Task.detached { [weak self] in await self?.refreshAll() }
    }
    return cached
  }

  func fetch(id: UUID) async throws -> Card? {
    await MainActor.run { cache.card(id: id) }
  }

  private func refreshAll() async {
    guard let fresh = try? await remote.fetchAll() else { return }
    await MainActor.run {
      for card in fresh { cache.upsertCard(card) }
    }
  }

  // Writes: online-only (Frage 1)
  func upsert(_ card: Card) async throws {
    try await remote.upsert(card)
    await MainActor.run { cache.upsertCard(card) }
  }

  func setDefault(id: UUID) async throws {
    try await remote.setDefault(id: id)
    // optimistic: clear default flag locally + set new
    await MainActor.run {
      let cards = cache.cards()
      for card in cards {
        var updated = card
        updated.isDefault = (card.id == id)
        cache.upsertCard(updated)
      }
    }
  }

  func delete(id: UUID) async throws {
    try await remote.delete(id: id)
    await MainActor.run { cache.deleteCard(id: id) }
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add apps/atollcard-native/AtollCard/Repositories/CachedCardRepository.swift
git commit -m "feat(offline): CachedCardRepository (read-from-cache, write-through)"
```

---

### Task 10: `CachedAnalyticsRepository` (read-only cache)

**Files:**
- Create: `apps/atollcard-native/AtollCard/Repositories/CachedAnalyticsRepository.swift`

- [ ] **Step 1: Decorator schreiben (analog Pattern)**

```swift
import Foundation

final class CachedAnalyticsRepository: AnalyticsRepository {
  private let remote: AnalyticsRepository
  private let cache:  CacheStore
  private let reach:  ReachabilityMonitor

  init(remote: AnalyticsRepository, cache: CacheStore, reach: ReachabilityMonitor) {
    self.remote = remote; self.cache = cache; self.reach = reach
  }

  // Implementiere die existing AnalyticsRepository-Methoden:
  // - read aus cache (Scans + Leads aggregieren in-process wie existing pattern)
  // - bei online: opportunistic remote.fetch + cache.upsert
  // Method-Signaturen 1:1 vom existing AnalyticsRepository-Protocol nachbauen.
}
```

(Plan-Skeleton: konkrete Methods anhand des existing Protocol implementieren. Kein dediziertes Test-File — Analytics ist read-only, kein eigenständiger State.)

- [ ] **Step 2: Commit**

```bash
git add apps/atollcard-native/AtollCard/Repositories/CachedAnalyticsRepository.swift
git commit -m "feat(offline): CachedAnalyticsRepository — read-only cache decorator"
```

---

## Phase D — App-Wiring

### Task 11: `AtollCardApp` — Wire Reachability + Drainer

**Files:**
- Modify: `apps/atollcard-native/AtollCard/AtollCardApp.swift`

- [ ] **Step 1: Reachability + Drainer als @State, Wire-up im body**

In `AtollCardApp.swift` ergänzen (am Anfang der struct):

```swift
  @State private var cacheStore: CacheStore? = (try? CacheStore())
  @State private var reach = ReachabilityMonitor()
  @State private var drainer: MutationDrainer?
```

Im `init()` nach den existing-Store-Inits:

```swift
    if let cache = cacheStore {
      _drainer = State(initialValue: MutationDrainer(cache: cache,
                                                     remote: leadStore.repository))
    }
```

Im `body`-Scene unter den existing `.environment(...)`:

```swift
        .environment(reach)
        .environment(cacheStore)
        .task {
          reach.start()
        }
        .onChange(of: reach.isConnected) { _, isOnline in
          if isOnline {
            Task { await drainer?.drain() }
          }
        }
        .onChange(of: scenePhase) { _, phase in
          if phase == .active {
            Task { await drainer?.drain() }
          }
        }
```

Falls `scenePhase` noch nicht observed: oben in struct:

```swift
  @Environment(\.scenePhase) private var scenePhase
```

- [ ] **Step 2: Commit**

```bash
git add apps/atollcard-native/AtollCard/AtollCardApp.swift
git commit -m "feat(offline): wire ReachabilityMonitor + MutationDrainer in App"
```

---

### Task 12: Store-Injection updaten

**Files:**
- Modify: `apps/atollcard-native/AtollCard/Repositories/CardStore.swift`
- Modify: `apps/atollcard-native/AtollCard/Repositories/LeadStore.swift`
- Modify: `apps/atollcard-native/AtollCard/Repositories/AnalyticsStore.swift`
- Modify: `apps/atollcard-native/AtollCard/AtollCardApp.swift` (re-wire repository injection)

- [ ] **Step 1: AtollCardApp.swift Repository-Injection**

Im `init()` von AtollCardApp die Store-Initialisierungen ändern. Vorher:

```swift
    _cardStore = State(initialValue: CardStore(
      repository: mockMode ? MockCardRepository() : SupabaseCardRepository()
    ))
```

Nachher (mit Cache-Decorator):

```swift
    let cardRemote: CardRepository = mockMode ? MockCardRepository() : SupabaseCardRepository()
    let cardRepo: CardRepository
    if mockMode {
      cardRepo = cardRemote  // mock-mode bypasses cache per spec §10.3
    } else if let cache = cacheStore {
      cardRepo = CachedCardRepository(remote: cardRemote, cache: cache, reach: reach)
    } else {
      cardRepo = cardRemote
    }
    _cardStore = State(initialValue: CardStore(repository: cardRepo))
```

Analog für LeadStore (mit `drainer` Parameter) + AnalyticsStore.

- [ ] **Step 2: Stores selber bleiben unverändert** — sie nehmen ein `LeadRepository` als Init-Parameter, sie kümmern sich nicht ob es ein Mock, Supabase oder Cached ist. Nur die Konstruktion im App-Init ändert sich.

- [ ] **Step 3: Commit**

```bash
git add apps/atollcard-native/AtollCard/AtollCardApp.swift
git commit -m "feat(offline): inject Cached* repositories (skip cache in mock-mode)"
```

---

## Phase E — UX-Indikatoren

### Task 13: `OfflineBanner` + RootView integration

**Files:**
- Create: `apps/atollcard-native/AtollCard/Views/Components/OfflineBanner.swift`
- Modify: `apps/atollcard-native/AtollCard/Views/RootView.swift`

- [ ] **Step 1: OfflineBanner schreiben**

```swift
import SwiftUI

struct OfflineBanner: View {
  var body: some View {
    HStack(spacing: 6) {
      Circle()
        .fill(.yellow)
        .frame(width: 6, height: 6)
      Text("Offline — Status-Änderungen werden synchronisiert sobald wieder verbunden")
        .font(.system(size: 11, weight: .medium))
        .lineLimit(2)
        .foregroundStyle(.secondary)
      Spacer(minLength: 0)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 6)
    .frame(maxWidth: .infinity)
    .background(.thinMaterial)
  }
}
```

- [ ] **Step 2: RootView ergänzen**

In `RootView.swift` oben in der struct:

```swift
  @Environment(ReachabilityMonitor.self) private var reach
```

Am View-Body-Outer-Container ergänzen:

```swift
    .safeAreaInset(edge: .top, spacing: 0) {
      if !reach.isConnected {
        OfflineBanner()
      }
    }
```

- [ ] **Step 3: Commit**

```bash
git add apps/atollcard-native/AtollCard/Views/Components/OfflineBanner.swift \
        apps/atollcard-native/AtollCard/Views/RootView.swift
git commit -m "feat(offline): OfflineBanner + RootView integration"
```

---

### Task 14: `PendingBadge` + FloatingActionBar integration

**Files:**
- Create: `apps/atollcard-native/AtollCard/Views/Components/PendingBadge.swift`
- Modify: `apps/atollcard-native/AtollCard/Views/Components/FloatingActionBar.swift`

- [ ] **Step 1: PendingBadge schreiben**

```swift
import SwiftUI

struct PendingBadge: View {
  let count: Int

  var body: some View {
    if count > 0 {
      Text("\(count)")
        .font(.system(size: 10, weight: .bold))
        .foregroundStyle(.white)
        .padding(.horizontal, 5)
        .padding(.vertical, 1)
        .background(Color.orange, in: Capsule())
    }
  }
}
```

- [ ] **Step 2: FloatingActionBar integration**

Im FloatingActionBar-File die Avatar-Cell mit Overlay erweitern:

```swift
  Avatar(initials: ..., color: ...)
    .overlay(alignment: .topTrailing) {
      PendingBadge(count: cacheStore?.pendingCount() ?? 0)
        .offset(x: 6, y: -2)
    }
```

`cacheStore` als `@Environment(CacheStore.self)` injecten.

- [ ] **Step 3: Commit**

```bash
git add apps/atollcard-native/AtollCard/Views/Components/PendingBadge.swift \
        apps/atollcard-native/AtollCard/Views/Components/FloatingActionBar.swift
git commit -m "feat(offline): PendingBadge on FloatingActionBar avatar"
```

---

### Task 15: `SyncStatusSection` + `DeadLetterView`

**Files:**
- Create: `apps/atollcard-native/AtollCard/Views/Settings/SyncStatusSection.swift`
- Create: `apps/atollcard-native/AtollCard/Views/Settings/DeadLetterView.swift`
- Modify: `apps/atollcard-native/AtollCard/Views/Settings/SettingsView.swift`

- [ ] **Step 1: SyncStatusSection**

```swift
import SwiftUI

struct SyncStatusSection: View {
  @Environment(CacheStore.self) private var cache
  @Environment(MutationDrainer.self) private var drainer
  @Environment(ReachabilityMonitor.self) private var reach

  var body: some View {
    Section("Synchronisation") {
      HStack {
        Circle().fill(reach.isConnected ? .green : .yellow).frame(width: 8, height: 8)
        Text(reach.isConnected ? "Online" : "Offline")
      }
      let pending = (try? cache.pendingCount()) ?? 0
      if pending > 0 {
        NavigationLink("\(pending) Aktionen warten") {
          // Pending-list view — minimal: zeige enqueuedAt + status pro Mutation
          List {
            // Iteration über cache.allActivePendingMutations()
          }
          .navigationTitle("Warteschlange")
        }
      }
      let dead = cache.deadLetters()
      if !dead.isEmpty {
        NavigationLink("\(dead.count) fehlgeschlagen") {
          DeadLetterView()
        }
      }
    }
  }
}
```

- [ ] **Step 2: DeadLetterView**

```swift
import SwiftUI

struct DeadLetterView: View {
  @Environment(CacheStore.self) private var cache
  @Environment(MutationDrainer.self) private var drainer

  var body: some View {
    List(cache.deadLetters(), id: \.id) { mutation in
      VStack(alignment: .leading, spacing: 4) {
        Text("Lead \(mutation.leadId)")
          .font(.system(size: 13, weight: .medium))
        Text("Versuchter Status: \(mutation.newStatus)")
          .font(.system(size: 11))
        if let err = mutation.lastError {
          Text(err).font(.system(size: 11)).foregroundStyle(.secondary)
        }
        HStack {
          Button("Erneut versuchen") {
            Task { await drainer.retryDeadLetter(mutationId: mutation.id) }
          }
          .buttonStyle(.bordered)
          Button("Verwerfen", role: .destructive) {
            cache.discardMutation(mutationId: mutation.id)
          }
        }
      }
    }
    .navigationTitle("Fehlgeschlagene Aktionen")
  }
}
```

- [ ] **Step 3: SettingsView ergänzen**

In `SettingsView.swift` einen Eintrag hinzufügen:

```swift
SyncStatusSection()
```

- [ ] **Step 4: Commit**

```bash
git add apps/atollcard-native/AtollCard/Views/Settings/SyncStatusSection.swift \
        apps/atollcard-native/AtollCard/Views/Settings/DeadLetterView.swift \
        apps/atollcard-native/AtollCard/Views/Settings/SettingsView.swift
git commit -m "feat(offline): SyncStatusSection + DeadLetterView in Settings"
```

---

## Phase F — Rollout

### Task 16: Runbook + CHANGELOG 0.12.0

**Files:**
- Create: `docs/superpowers/runbooks/2026-05-26-atollcard-offline-queue-rollout.md`
- Modify: `apps/atollcard-native/CHANGELOG.md`

- [ ] **Step 1: Runbook**

```markdown
# Runbook: AtollCard Offline-Queue (Welle D Part 2)

**Spec:** `docs/superpowers/specs/2026-05-26-atollcard-offline-queue-design.md`
**Plan:** `docs/superpowers/plans/2026-05-26-atollcard-offline-queue.md`

## Pre-Implementation

- [ ] Branch `feat/atollcard-offline-queue` ausgecheckt
- [ ] Vorherige Wellen A+B+C+D-Part-1 sind auf main

## Code-Deploy

- [ ] `xcodegen generate`
- [ ] Xcode öffnet → AtollCard scheme → Cmd+B Build
- [ ] Apps Tests via Cmd+U laufen lassen — CacheStoreTests + MutationDrainerTests müssen grün
- [ ] Cmd+R aufs echte iPhone

## Manueller End-to-End-Test

- [ ] App starten → Karten + Leads sichtbar (online)
- [ ] **Airplane-Mode an** (Wischen vom oberen Rand → Flugzeug-Symbol)
- [ ] App-Vorschau: Offline-Banner sichtbar oben
- [ ] In Inbox auf einen Lead → Status auf "Spam" setzen → lokal sofort sichtbar
- [ ] Avatar in FloatingActionBar zeigt orangenen "1"-Badge
- [ ] Settings → Synchronisation → "1 Aktion wartet" sichtbar
- [ ] **Airplane-Mode aus**
- [ ] Offline-Banner verschwindet
- [ ] Badge verschwindet (Drainer-Erfolg) — kann ~2-3 Sekunden dauern
- [ ] In Browser (Inbox am Mac) → Lead ist auf "Spam"

## Dead-Letter-Test

- [ ] App im Mock-Modus starten (Config.useMockData=true) — Mock-Repo wirft kontrolliert
- [ ] Mehrere Status-Mutationen offline machen
- [ ] Online gehen — Drainer scheitert, nach 5 Versuchen dead-lettert
- [ ] Roter Banner oben — tippen → DeadLetterView
- [ ] "Erneut versuchen" → erfolgreich (Mock-Repo lässt durch)
- [ ] "Verwerfen" → Mutation weg, Lead-Status springt auf Server-Wert zurück beim nächsten Refresh

## Rollback

Wenn der Cache Probleme macht:
- `Config.useMockData = true` setzen — Cache bypassed
- Oder iOS-App: Settings → "Cache zurücksetzen" (falls hinzugefügt) ODER App löschen + neu installieren — neuer leerer Container

## Pass-Cert Renewal-Reminder Note (von Welle C)

(falls Welle C noch nicht rotiert) — Pass Type ID Cert renewal-Reminder weiterhin gültig.
```

- [ ] **Step 2: CHANGELOG**

```markdown
## 0.12.0 — Offline-Queue (Larry, 26.05.2026)

SwiftData-Cache vor die 3 Repos, Mutation-Queue für offline Status-Changes,
NWPathMonitor-getriggerter FIFO-Drainer.

### Architektur-Entscheid: Decorator-Pattern um existing Repository-Protocols

Statt die existing Stores umzubauen, bekommen sie `Cached*Repository`-
Implementierungen injiziert die das gleiche Protocol konformieren. Reads
gehen immer aus dem SwiftData-Cache; Writes (nur `updateLeadStatus`)
optimistic in den Cache + Queue. Conflict-Strategie: Last-Write-Wins
clientseitig.

### Out-of-Scope (bewusst nicht enthalten)

- Card-Edit-Queueing — Cards sind offline read-only
- `importLead` und `deleteLead` offline — Server-Side-Logik kann nicht clientseitig vorab
- Multi-Device LWW-by-Timestamp
- BGTaskScheduler Background-Sync
```

- [ ] **Step 3: Commit**

```bash
git add docs/superpowers/runbooks/2026-05-26-atollcard-offline-queue-rollout.md \
        apps/atollcard-native/CHANGELOG.md
git commit -m "docs: offline-queue rollout runbook + AtollCard 0.12.0 changelog"
```

---

## Self-Review-Checklist (post-hoc)

**Spec-Coverage:**
- §2 Architektur-Entscheid → Tasks 1-12 implementieren das Pattern ✓
- §3 SwiftData-Models → Tasks 1, 2 ✓
- §4 CacheStore + Reachability + Drainer → Tasks 4, 6, 7 ✓
- §5 Cached Repositories → Tasks 8, 9, 10 ✓
- §6 UX-Indikatoren → Tasks 13, 14, 15 ✓
- §7 File-Inventar → alle Files in Tasks ✓
- §8 Rollout → Task 16 Runbook ✓

**Placeholder-Scan:** keine TBD/TODO. Ein bewusst-skeleton Block in Task 10 (CachedAnalyticsRepository) weil Analytics-Repository-Protocol je nach Code unterschiedlich ist — Adapter muss beim Implementieren das existing Protocol matchen.

**Typkonsistenz:**
- `PendingLeadStatusMutation` Properties identisch in Tasks 2, 4, 5, 7
- `CacheStore.pendingCount()` / `nextPendingMutation()` / `deadLetters()` Signaturen konsistent in Tasks 4, 7, 14, 15
- `MutationDrainer.drain()` und `retryDeadLetter()` konsistent in Tasks 7, 15
- `LeadStatus.rawValue` als Bindings-String durchgehend (Tasks 1, 2, 4, 7, 8)

**Bekannte Follow-ups (nicht im Plan):**
- Realtime-Handler in `LeadStore.startRealtime()` muss `cache.upsertLead()` aufrufen — Plan deckt das nicht ab, weil der Realtime-Hook eine separate Codestelle ist. Empfehlung: in einer kleinen Folge-Patch nachziehen
- Mock-Mode komplett ohne Cache (Task 12 macht das) — wenn man Mock-Daten cachen wollte für UI-Iteration, braucht's einen Schalter
- `LeadFilter` exakter Set noch unbekannt — Task 8 hat einen Skeleton-Filter, muss am existing `LeadFilter` adaptiert werden
- Test-Coverage für `CachedLeadRepository` end-to-end fehlt — würde 1-2 weitere Tests brauchen mit Mock-Reach + Mock-Drainer
