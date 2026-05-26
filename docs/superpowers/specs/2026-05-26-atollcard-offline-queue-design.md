# AtollCard Offline-Queue (SwiftData Cache + Mutation Queue)

**Status:** Draft (User-Review pending)
**Date:** 2026-05-26
**Author:** Dominik Weckherlin (with Claude/Larry)
**Spec Owner:** Dominik
**Target Release:** Welle D Part 2 — Sub-Projekt 6 von 9

---

## 1. Kontext & Problem

### Heutiger Zustand

AtollCard greift auf alle Daten via Supabase-Repositories direkt zu. Wenn die App offline ist:
- Card-Liste leer (kein Cache)
- Lead-Inbox leer
- Analytics nicht berechenbar
- Status-Change-Buttons werfen Netz-Fehler

Realtime-Channel (LeadStore.startRealtime) failed silently bei schlechtem Netz und reconnected oft nicht.

### Pain-Points

1. **Tauchschule Dauin** hat schwankende Connectivity am Pool und Boot.
2. **Lead-Triage offline** (z.B. nach einem Pool-Gespräch "der ist Spam" markieren) ist heute unmöglich.
3. **Beim App-Start ohne Netz** sieht der User leere Listen — irreführend, weil er weiss dass er Cards/Leads hat.

### Zielbild

- App startet **immer** mit den letzten bekannten Daten aus einem lokalen Cache.
- Status-Changes funktionieren offline; werden auf den Server gespiegelt sobald die Verbindung zurück ist.
- Sichtbarer aber nicht störender Indikator wenn offline / wenn Aktionen pending sind.

---

## 2. Architektur-Entscheidung

**Decorator-Pattern um die existing `*Repository`-Protocols.**

```
Store ← CachedRepository ← (RemoteRepository | CacheStore | MutationDrainer)
```

`CachedLeadRepository` (analog Card + Analytics) ist die einzige Klasse die der Store kennt. Sie konformiert dem bestehenden Protocol — keine Store-API-Änderungen.

**SwiftData für den lokalen Cache.** Native iOS-26-Persistence, `@Model`-Klassen, query-fähig. Vermeidet drittes Layer wie GRDB oder CoreData-Boilerplate.

**Mutation-Queue als eigene SwiftData-Entity** — `PendingLeadStatusMutation` — mit FIFO-Drainer, der bei Reachability-Edge `false→true` läuft.

**Conflict: Last-Write-Wins clientseitig.** Status-Mutations sind 6 enums, der User-Klick ist eindeutige Absicht. Komplexere LWW-by-Timestamp erst wenn echte Konflikte auftauchen.

**Scope: nur `updateLeadStatus` queued.** `importLead` (RPC mit Server-Side-Logik) und `deleteLead` (destruktiv) bleiben online-only. Card-Edits sind offline read-only.

---

## 3. SwiftData-Models

### 3.1 Cache-Entities

`apps/atollcard-native/AtollCard/Cache/CardEntity.swift`:

```swift
import Foundation
import SwiftData

@Model
public final class CardEntity {
  @Attribute(.unique) public var id: UUID
  public var personId:   UUID
  public var slug:       String
  public var title:      String
  public var subtitle:   String?
  public var badge:      String?
  public var themeJSON:  String          // Codable round-tripped CardTheme
  public var diveJSON:   String?         // Codable round-tripped DiveProfile?
  public var fieldVisibilityJSON: String // Codable round-tripped FieldVisibility
  public var isDefault:  Bool
  public var isActive:   Bool
  public var createdAt:  Date
  public var updatedAt:  Date
  public var lastFetched: Date           // cache-row freshness
  // …init
}
```

Analog `LeadEntity` (status as raw string for enum-evolution safety) und `ScanEntity` (für Analytics).

### 3.2 Mutation-Queue

`apps/atollcard-native/AtollCard/Cache/PendingLeadStatusMutation.swift`:

```swift
import Foundation
import SwiftData

@Model
public final class PendingLeadStatusMutation {
  @Attribute(.unique) public var id: UUID    // unique mutation id
  public var leadId:        UUID
  public var newStatus:     String           // raw enum
  public var enqueuedAt:    Date
  public var attempts:      Int
  public var lastError:     String?
  public var lastAttemptAt: Date?
  public var isDead:        Bool             // true after attempts >= 5
  // …init
}
```

**Why a separate model**: queue is its own concern. Adding pending-mutation columns to `LeadEntity` would conflate cache state with sync state.

**Why id != leadId**: multiple status changes on the same lead while offline (e.g. user clicks "opened" then "contacted") create separate mutations. Drainer processes them in FIFO so the final server state matches the last user click.

### 3.3 Domain ↔ Entity Mapping

`CacheStore` exposes converters between SwiftData entities and the existing domain structs (`Card`, `Lead`):

```swift
extension Card {
  init(entity: CardEntity) throws { /* decode JSON fields */ }
  func toEntity() throws -> CardEntity { /* encode JSON fields */ }
}
```

JSON-Felder (`themeJSON`, `diveJSON`) statt SwiftData-Composite-Models — weil `CardTheme` und `DiveProfile` viele Sub-Felder haben und SwiftData-Relationship-Modellierung Overkill ist für 5-10 Karten total.

---

## 4. Cache + Drainer + Reachability

### 4.1 `CacheStore`

`apps/atollcard-native/AtollCard/Cache/CacheStore.swift` ist der ModelContainer-Wrapper:

```swift
@MainActor
public final class CacheStore {
  private let container: ModelContainer

  init() throws {
    let schema = Schema([CardEntity.self, LeadEntity.self,
                         ScanEntity.self, PendingLeadStatusMutation.self])
    self.container = try ModelContainer(for: schema,
                                        configurations: ModelConfiguration(isStoredInMemoryOnly: false))
  }

  // Cards
  func cards(filter: CardFilter = .all) -> [Card]
  func upsertCard(_ card: Card)
  func deleteCard(id: UUID)

  // Leads
  func leads(filter: LeadFilter) -> [Lead]
  func upsertLead(_ lead: Lead)
  func updateLeadStatus(leadId: UUID, status: LeadStatus)

  // Mutations
  func enqueue(_ mutation: PendingLeadStatusMutation)
  func nextPendingMutation() -> PendingLeadStatusMutation?     // FIFO, isDead=false
  func removePendingMutation(id: UUID)
  func recordFailure(mutationId: UUID, error: Error)
  func markDead(mutationId: UUID)
  func deadLetters() -> [PendingLeadStatusMutation]
  func pendingCount() -> Int
}
```

### 4.2 `ReachabilityMonitor`

`apps/atollcard-native/AtollCard/Services/ReachabilityMonitor.swift`:

```swift
import Network
import Observation

@MainActor
@Observable
public final class ReachabilityMonitor {
  public private(set) var isConnected: Bool = true
  private let monitor = NWPathMonitor()
  private let queue = DispatchQueue(label: "swiss.atoll.card.reachability")

  public init() {}

  public func start() {
    monitor.pathUpdateHandler = { [weak self] path in
      Task { @MainActor in self?.isConnected = (path.status == .satisfied) }
    }
    monitor.start(queue: queue)
  }
}
```

### 4.3 `MutationDrainer`

`apps/atollcard-native/AtollCard/Services/MutationDrainer.swift`:

```swift
@MainActor
@Observable
public final class MutationDrainer {
  private let cache:  CacheStore
  private let remote: LeadRepository      // existing protocol
  private var isDraining = false

  public init(cache: CacheStore, remote: LeadRepository) {
    self.cache  = cache
    self.remote = remote
  }

  public func drain() async {
    guard !isDraining else { return }
    isDraining = true
    defer { isDraining = false }

    while let mutation = cache.nextPendingMutation() {
      do {
        let status = LeadStatus(rawValue: mutation.newStatus)!
        try await remote.updateStatus(leadId: mutation.leadId, status: status)
        cache.removePendingMutation(id: mutation.id)
      } catch {
        // 401 = token expired, don't increment attempts
        if isAuthError(error) { return }
        cache.recordFailure(mutationId: mutation.id, error: error)
        if (mutation.attempts + 1) >= 5 {
          cache.markDead(mutationId: mutation.id)
          continue   // process remaining queue
        }
        return       // bail until next reach-edge
      }
    }
  }

  private func isAuthError(_ error: Error) -> Bool {
    // inspect PostgrestError code or HTTP status
    // …
  }
}
```

### 4.4 Trigger-Points für `drain()`

| Wann | Wie |
|---|---|
| `ReachabilityMonitor.isConnected` flippt `false → true` | observer in `AtollCardApp` |
| `.scenePhase` flippt zu `.active` | observer in `AtollCardApp` |
| Direkt nach jedem `updateStatus`-Call wenn online | inline im `CachedLeadRepository.updateStatus` |

---

## 5. Cached Repositories

### 5.1 `CachedLeadRepository`

Implementiert das existing `LeadRepository`-Protocol. Reads gehen immer aus Cache + opportunistischem Background-Refresh. Writes sind Optimistic + Queue.

```swift
public final class CachedLeadRepository: LeadRepository {
  private let remote:  LeadRepository
  private let cache:   CacheStore
  private let drainer: MutationDrainer
  private let reach:   ReachabilityMonitor

  // MARK: - Reads

  public func fetchAll(filter: LeadFilter) async -> [Lead] {
    let cached = cache.leads(filter: filter)
    if reach.isConnected {
      Task.detached { @Sendable [weak self] in
        await self?.refreshLeads(filter: filter)
      }
    }
    return cached
  }

  private func refreshLeads(filter: LeadFilter) async {
    do {
      let fresh = try await remote.fetchAll(filter: filter)
      await MainActor.run {
        for lead in fresh { cache.upsertLead(lead) }
      }
    } catch {
      // silent — UI keeps showing cached
    }
  }

  // MARK: - Writes (status only)

  public func updateStatus(leadId: UUID, status: LeadStatus) async throws {
    cache.updateLeadStatus(leadId: leadId, status: status)            // optimistic
    cache.enqueue(.init(
      id: UUID(), leadId: leadId, newStatus: status.rawValue,
      enqueuedAt: .now, attempts: 0, isDead: false
    ))
    if reach.isConnected {
      Task.detached { @Sendable [weak self] in await self?.drainer.drain() }
    }
  }

  // MARK: - Online-only delegates

  public func deleteLead(leadId: UUID) async throws {
    try await remote.deleteLead(leadId: leadId)                       // online-only
    cache.deleteLead(id: leadId)
  }

  public func importLead(leadId: UUID) async throws -> ImportResult {
    let result = try await remote.importLead(leadId: leadId)          // online-only
    cache.updateLeadStatus(leadId: leadId, status: .imported)
    return result
  }
}
```

### 5.2 `CachedCardRepository`

Read-only cache (per Frage 1). Writes delegate straight to remote + cache-update:

```swift
public final class CachedCardRepository: CardRepository {
  // fetchAll/fetch return cache + background-refresh
  // upsert/setDefault/delete are online-only; cache mirrors after success
}
```

### 5.3 `CachedAnalyticsRepository`

Read-only — Analytics werden serverside aus card_scans + card_leads aggregiert. Cache speichert die letzten Roh-Daten (`ScanEntity` rows) und rolled clientseitig. Identisch zum existing in-process-Aggregation-Pattern aus dem CHANGELOG.

---

## 6. UX-Indikatoren

### 6.1 Offline-Banner (oben, transient)

24pt schmaler Streifen unter der Statusbar wenn `reach.isConnected == false`:

```
🟡 Offline — Status-Änderungen werden synchronisiert sobald wieder verbunden
```

Implementiert als Modifier auf `RootView`:

```swift
.safeAreaInset(edge: .top) {
  if !reach.isConnected {
    OfflineBanner()
  }
}
```

### 6.2 Pending-Badge (FloatingActionBar Avatar)

Wenn `cache.pendingCount() > 0` UND `reach.isConnected == false`: kleines Badge mit Zahl.

Tap auf Avatar → SettingsView → Section "Synchronisation":
- Liste der pending Mutations (Lead-Name + neuer Status + Wartedauer)

### 6.3 Dead-Letter-Banner (selten, persistenter)

Wenn `cache.deadLetters().count > 0`: roter Banner:

```
⚠️ N Status-Updates konnten nicht synchronisiert werden — antippen für Details
```

Tap → DeadLetterView mit Per-Mutation:
- Lead-Name + versuchter Status
- `lastError`-String
- "Erneut versuchen" → resetted `attempts = 0`, `isDead = false`, ruft `drain()`
- "Verwerfen" → entfernt Pending; nächster `refreshLeads()` setzt UI auf Server-Wert zurück

### 6.4 Was es NICHT gibt

- Kein Modal-Block wenn offline
- Kein Sync-Spinner während Drainer läuft
- Keine Pull-to-Refresh-Geste (gibt's heute nicht im Inbox-Design)

---

## 7. File-Inventar

### Neu

```
apps/atollcard-native/AtollCard/
├── Cache/
│   ├── CacheStore.swift                       ModelContainer wrapper + CRUD helpers
│   ├── CardEntity.swift                       @Model
│   ├── LeadEntity.swift                       @Model
│   ├── ScanEntity.swift                       @Model
│   ├── PendingLeadStatusMutation.swift        @Model
│   └── CacheConverters.swift                  Card ↔ CardEntity helpers
├── Services/
│   ├── ReachabilityMonitor.swift              @Observable NWPathMonitor wrapper
│   └── MutationDrainer.swift                  @Observable drain loop
├── Repositories/
│   ├── CachedCardRepository.swift             decorator
│   ├── CachedLeadRepository.swift             decorator (the main goal)
│   └── CachedAnalyticsRepository.swift        decorator
└── Views/
    ├── Components/OfflineBanner.swift         24pt yellow strip
    ├── Components/DeadLetterBanner.swift      red strip
    ├── Components/PendingBadge.swift          avatar badge
    ├── Settings/SyncStatusSection.swift       pending list
    └── Settings/DeadLetterView.swift          per-mutation detail + retry/discard
```

### Geändert

```
apps/atollcard-native/AtollCard/
├── AtollCardApp.swift                         + ReachabilityMonitor + MutationDrainer
│                                              + .scenePhase trigger
│                                              + reach.isConnected observer
├── Repositories/
│   ├── CardStore.swift                        injection via CachedCardRepository
│   ├── LeadStore.swift                        injection via CachedLeadRepository
│   └── AnalyticsStore.swift                   injection via CachedAnalyticsRepository
├── Views/RootView.swift                       + .safeAreaInset banner + pending badge
└── CHANGELOG.md                               + 0.12.0 entry
```

### Test-Coverage

- `CacheStoreTests.swift` — in-memory ModelContainer, full CRUD + queue ordering + dead-letter
- `MutationDrainerTests.swift` — mock LeadRepository, drain happy-path + fail-path + 401-exception
- `ReachabilityMonitorTests.swift` — start/stop smoke (real NWPathMonitor not mockable)
- Manual end-to-end im Runbook: Airplane-Mode-Toggle, FIFO-Reihenfolge, Dead-Letter-Recovery

---

## 8. Rollout-Plan

1. SwiftData-Models + CacheStore + CacheConverters
2. CacheStoreTests
3. ReachabilityMonitor + Smoke-Test
4. MutationDrainer + Tests
5. CachedLeadRepository
6. CachedCardRepository + CachedAnalyticsRepository
7. Store-Injection updaten (CardStore/LeadStore/AnalyticsStore)
8. AtollCardApp wiring (reach + drainer + .scenePhase)
9. UX-Indikatoren (Banner + Badge + Settings)
10. Manueller iPhone-Airplane-Mode-Test

---

## 9. Out-of-Scope

- **Card-Edit-Queueing** (Frage 1 → read-only offline)
- **`importLead`-RPC offline** (Server-side Logik nicht clientseitig vorab)
- **`deleteLead` offline** (destruktiv)
- **Multi-Device LWW-by-Timestamp** (heute LWW-client)
- **Web-Inbox offline** (PWA-Konzept, separates Sub-Projekt)
- **BGTaskScheduler Background-Sync** (drainen nur bei reach-edge + foreground)

---

## 10. Open Risiken & Annahmen

1. **SwiftData JSON-Spalten:** Theme/Dive-Profile als JSON-Strings. Wenn Domain-Schema sich ändert, Cache hat alten Format. Mitigation: `lastFetched > 7 Tage` triggert re-fetch; Decode-Fehler wirft die Cache-Row weg.
2. **Realtime + Cache:** APNs-Push triggert `leadStore.startRealtime()`. Realtime-Handler muss `cache.upsertLead(...)` aufrufen, sonst zeigt App alten Status während Lock-Screen-Push den neuen anzeigt.
3. **Mock-Mode:** `Config.useMockData == true` → Cache wird nicht benutzt (MockRepo direkt im Store). Sonst landen Mock-Daten im Cache, was beim Wechsel zu Live verwirren kann.
4. **App-Group + Widget:** Widget liest `default-card.json` aus App-Group. Card-Edits sind per Frage 1 read-only offline → kein Konflikt.
5. **5-Attempts-Threshold willkürlich.** 401 wird ausgenommen (Token-Refresh, nicht inkrementieren). Andere Server-5xx werden incrementiert.
6. **`LeadStatus(rawValue: ...)!` force-unwrap** in MutationDrainer — wenn Enum sich ändert, könnte ein in-flight raw-string nicht mehr matchen. Mitigation: defensive `guard let`, mark-dead bei unknown raw value.

---

## 11. Akzeptanzkriterien

- [ ] SwiftData-Cache wird beim ersten online-Refresh gefüllt
- [ ] App offline gestartet: Cards + Leads sichtbar (aus Cache)
- [ ] Status-Change offline: lokal sofort sichtbar, beim Reconnect auf Server gespiegelt
- [ ] Mehrere offline-Mutations: alle FIFO drainet
- [ ] Permanent-Fail (auth revoked): dead-lettert nach 5 attempts, Banner sichtbar
- [ ] 401-Errors inkrementieren `attempts` NICHT
- [ ] Retry via Dead-Letter-View funktioniert
- [ ] Verwerfen via Dead-Letter-View entfernt Pending + setzt UI auf Server-Wert zurück
- [ ] Realtime-Push (APNs) updated Cache + UI
- [ ] Cache-Storage < 1 MB bei 100 Leads + 5 Cards
- [ ] Offline-Banner sichtbar wenn `reach.isConnected == false`
- [ ] Pending-Badge zählt korrekt wenn offline + Mutations queued

---

## 12. Referenzen

- [Apple SwiftData Documentation](https://developer.apple.com/documentation/swiftdata)
- [Network Framework NWPathMonitor](https://developer.apple.com/documentation/network/nwpathmonitor)
- Existing repository protocols: `CardRepository.swift`, `LeadRepository.swift`, `AnalyticsRepository.swift`
- Existing realtime hook: `LeadStore.startRealtime()`
- Welle A Spec (für Lead-Status-Enum-Defines): `docs/superpowers/specs/2026-05-25-atollcard-web-inbox-design.md` §6.1
- AtollCard CHANGELOG Architektur-Entscheid Welle A "Analytics in-process, kein SQL-View" — selbes Pattern fürs CachedAnalyticsRepository
