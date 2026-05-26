# AtollCard Lock-Screen Widget — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Lock-Screen `accessoryRectangular` Widget für AtollCard, das die Default-Karte zeigt und mit einem Tap die App im Fullscreen-QR öffnet.

**Architecture:** App und Widget teilen sich einen App-Group-Container; App schreibt ein kleines JSON beim Default-Card-Change, Widget liest es beim Timeline-Refresh. Tap → Deep-Link `atollcard://card/<slug>/qr` → App routet auf `FullscreenQRView`. Refresh ist reload-on-write (keine Polling-Timelines).

**Tech Stack:** SwiftUI + WidgetKit + iOS 26 + XcodeGen, App Group `group.swiss.atoll.card`.

**Spec:** `docs/superpowers/specs/2026-05-26-atollcard-widget-design.md`

---

## Phase A — Cross-Target Foundation

### Task 1: `SharedCardSnapshot` Codable struct (Cross-Target)

**Files:**
- Create: `apps/atollcard-native/AtollCardShared/SharedCardSnapshot.swift`

- [ ] **Step 1: Struct schreiben**

Inhalt von `apps/atollcard-native/AtollCardShared/SharedCardSnapshot.swift`:

```swift
import Foundation

/// Snapshot of the default card, shared between the AtollCard app and
/// the AtollCardWidget extension via the App Group container.
///
/// Source: written by `SharedCardSnapshotWriter` in the main app whenever
/// the default card changes.
/// Sink: read by `CardSnapshotProvider` in the Widget extension on every
/// timeline refresh.
///
/// The struct intentionally carries only what the Lock-Screen Widget needs
/// to render — no avatar URLs, no dive profile, no analytics. Keep it small
/// to avoid stale-data confusion when the source card gets richer.
public struct SharedCardSnapshot: Codable, Sendable, Equatable {
  public let slug:           String     // "dominik-cd"
  public let title:          String     // "PADI Course Director"
  public let badge:          String?    // "PADI CD" — nil if no badge set
  public let personInitials: String     // "DW"
  public let publicURL:      URL        // https://atoll-os.com/c/dominik-cd
  public let updatedAt:      Date       // when this snapshot was written

  public init(slug: String, title: String, badge: String?,
              personInitials: String, publicURL: URL, updatedAt: Date) {
    self.slug = slug
    self.title = title
    self.badge = badge
    self.personInitials = personInitials
    self.publicURL = publicURL
    self.updatedAt = updatedAt
  }
}

public extension SharedCardSnapshot {
  /// Standard ISO-8601 encoder used in both app and widget so dates roundtrip
  /// without timezone drift.
  static let encoder: JSONEncoder = {
    let e = JSONEncoder()
    e.dateEncodingStrategy = .iso8601
    return e
  }()

  /// Matching decoder.
  static let decoder: JSONDecoder = {
    let d = JSONDecoder()
    d.dateDecodingStrategy = .iso8601
    return d
  }()
}
```

- [ ] **Step 2: Commit**

```bash
git add apps/atollcard-native/AtollCardShared/SharedCardSnapshot.swift
git commit -m "feat(widget): SharedCardSnapshot Codable struct (cross-target)"
```

---

### Task 2: Codable-Roundtrip Tests

**Files:**
- Create: `apps/atollcard-native/AtollCardTests/SharedCardSnapshotTests.swift`

- [ ] **Step 1: Failing-Test schreiben**

Inhalt von `apps/atollcard-native/AtollCardTests/SharedCardSnapshotTests.swift`:

```swift
import XCTest
@testable import AtollCard

final class SharedCardSnapshotTests: XCTestCase {
  func test_codable_roundtrip_preserves_all_fields() throws {
    let original = SharedCardSnapshot(
      slug:           "dominik-cd",
      title:          "PADI Course Director",
      badge:          "PADI CD",
      personInitials: "DW",
      publicURL:      URL(string: "https://atoll-os.com/c/dominik-cd")!,
      updatedAt:      Date(timeIntervalSince1970: 1_716_739_200)  // 2024-05-26T12:00:00Z
    )

    let data    = try SharedCardSnapshot.encoder.encode(original)
    let decoded = try SharedCardSnapshot.decoder.decode(SharedCardSnapshot.self, from: data)

    XCTAssertEqual(decoded, original)
  }

  func test_badge_nil_roundtrip() throws {
    let original = SharedCardSnapshot(
      slug: "privat",
      title: "Privat",
      badge: nil,
      personInitials: "DW",
      publicURL: URL(string: "https://atoll-os.com/c/privat")!,
      updatedAt: Date(timeIntervalSince1970: 0)
    )

    let data    = try SharedCardSnapshot.encoder.encode(original)
    let decoded = try SharedCardSnapshot.decoder.decode(SharedCardSnapshot.self, from: data)

    XCTAssertEqual(decoded, original)
    XCTAssertNil(decoded.badge)
  }

  func test_iso8601_date_format_is_stable() throws {
    let snapshot = SharedCardSnapshot(
      slug: "x", title: "X", badge: nil, personInitials: "X",
      publicURL: URL(string: "https://x.invalid")!,
      updatedAt: Date(timeIntervalSince1970: 1_716_739_200)
    )
    let data = try SharedCardSnapshot.encoder.encode(snapshot)
    let json = String(data: data, encoding: .utf8)!
    XCTAssertTrue(json.contains("\"updatedAt\":\"2024-05-26T"), "ISO-8601 prefix missing in \(json)")
  }
}
```

- [ ] **Step 2: xcodebuild test (oder skip wenn sandbox)**

```bash
cd ~/Desktop/Developer/Dispo/apps/atollcard-native
xcodebuild test -scheme AtollCard -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 15 Pro' 2>&1 | grep -E "Test Case|Executed"
```

Expected: 3 tests passed.

Falls in Sandbox: Skipped, im Commit-Message vermerken.

- [ ] **Step 3: Commit**

```bash
git add apps/atollcard-native/AtollCardTests/SharedCardSnapshotTests.swift
git commit -m "test(widget): SharedCardSnapshot codable roundtrip"
```

---

### Task 3: `Config.appGroupID` Konstante

**Files:**
- Modify: `apps/atollcard-native/AtollCard/Config.swift`

- [ ] **Step 1: Konstante hinzufügen**

In `Config.swift`, unter `walletPassEndpoint` ergänzen:

```swift
  /// Shared App Group container — both the main app (`swiss.atoll.card`)
  /// and the widget extension (`swiss.atoll.card.widget`) must have this
  /// entitlement.
  static let appGroupID = "group.swiss.atoll.card"
```

- [ ] **Step 2: Commit**

```bash
git add apps/atollcard-native/AtollCard/Config.swift
git commit -m "feat(widget): Config.appGroupID constant"
```

---

## Phase B — Writer Service

### Task 4: `SharedCardSnapshotWriter` Implementation

**Files:**
- Create: `apps/atollcard-native/AtollCard/Services/SharedCardSnapshotWriter.swift`

- [ ] **Step 1: Service schreiben**

Inhalt von `apps/atollcard-native/AtollCard/Services/SharedCardSnapshotWriter.swift`:

```swift
import Foundation
import WidgetKit
import OSLog

/// Writes the default-card snapshot into the App Group container and
/// triggers a Widget timeline reload.
///
/// All writes are atomic (`.atomic` option). Missing-snapshot → file
/// removal, never empty file (Widget code uses `Data(contentsOf:)` which
/// fails on empty file).
///
/// Reload is best-effort — `WidgetCenter.reloadAllTimelines()` is rate-
/// limited by iOS; calling it more often than ~once per minute may not
/// trigger an actual re-render but never errors.
enum SharedCardSnapshotWriter {
  private static let fileName = "default-card.json"
  private static let logger = Logger(subsystem: "swiss.atoll.card",
                                     category: "snapshot-writer")

  static func write(_ snapshot: SharedCardSnapshot?) {
    guard let container = FileManager.default
      .containerURL(forSecurityApplicationGroupIdentifier: Config.appGroupID) else {
      logger.error("App Group container missing for \(Config.appGroupID, privacy: .public)")
      return
    }
    let url = container.appendingPathComponent(fileName)

    if let snapshot {
      do {
        let data = try SharedCardSnapshot.encoder.encode(snapshot)
        try data.write(to: url, options: .atomic)
        logger.debug("Wrote snapshot for slug \(snapshot.slug, privacy: .public)")
      } catch {
        logger.error("Snapshot write failed: \(error.localizedDescription, privacy: .public)")
      }
    } else {
      try? FileManager.default.removeItem(at: url)
      logger.debug("Cleared snapshot file")
    }

    WidgetCenter.shared.reloadAllTimelines()
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add apps/atollcard-native/AtollCard/Services/SharedCardSnapshotWriter.swift
git commit -m "feat(widget): SharedCardSnapshotWriter — write+reload"
```

---

### Task 5: `CardStore` integration — Snapshot bei jedem default-relevanten Update schreiben

**Files:**
- Modify: `apps/atollcard-native/AtollCard/Repositories/CardStore.swift`

- [ ] **Step 1: Helper-Methode + Call-Sites identifizieren**

```bash
grep -n "refresh\|upsert\|setDefault\|isDefault" apps/atollcard-native/AtollCard/Repositories/CardStore.swift | head -20
```

- [ ] **Step 2: Helper + Call-Sites einfügen**

In `CardStore.swift` als `private` extension oder direkt in der Klasse:

```swift
  /// Re-derives the current default card from `cards` and pushes a snapshot
  /// to the App Group + Widget. Safe to call repeatedly — the writer is
  /// idempotent.
  private func writeSnapshotForDefault() {
    guard let defaultCard = cards.first(where: { $0.isDefault && $0.isActive }),
          let person      = persons[defaultCard.personId] else {
      SharedCardSnapshotWriter.write(nil)
      return
    }
    let snapshot = SharedCardSnapshot(
      slug:           defaultCard.slug,
      title:          defaultCard.title,
      badge:          defaultCard.badge,
      personInitials: person.initials,
      publicURL:      defaultCard.publicURL,
      updatedAt:      defaultCard.updatedAt
    )
    SharedCardSnapshotWriter.write(snapshot)
  }
```

Aufruf nach jeder dieser bestehenden Methoden (am Ende ergänzen, nach State-Mutation):

- `refresh()`
- `upsert(card:)`
- `setDefault(cardId:)`
- `delete(cardId:)` — falls die gelöschte Karte die Default war

Falls `CardStore` keine zentrale `persons`-Map hat, sondern Person über LeadStore oder einen externen Lookup besorgt, den Snapshot-Builder mit der entsprechenden Lookup-Logik adaptieren (Plan kann das nicht 100% vorhersagen — gegen den existierenden Code adaptieren).

- [ ] **Step 3: Commit**

```bash
git add apps/atollcard-native/AtollCard/Repositories/CardStore.swift
git commit -m "feat(widget): CardStore writes snapshot on default-relevant updates"
```

---

### Task 6: Initial-Write beim App-Launch

**Files:**
- Modify: `apps/atollcard-native/AtollCard/AtollCardApp.swift`

- [ ] **Step 1: Stelle finden wo CardStore.refresh aufgerufen wird**

```bash
grep -n "cardStore.refresh\|await cardStore" apps/atollcard-native/AtollCard/AtollCardApp.swift
```

- [ ] **Step 2: Initial-Snapshot-Write nach Refresh sicherstellen**

`refresh()` selber schreibt ja schon (per Task 5), aber der erste Aufruf passiert beim App-Start. Wenn der User offline ist beim Start und `refresh()` failed, sollte das Widget trotzdem den letzten bekannten Stand (aus der App-Group) behalten. Das ist schon der Default — nichts extra zu tun.

Edge Case Logout: in der Auth-State-onChange-Handler des Apps, wenn `auth.session == nil`, einmal explizit clearen:

```swift
.task(id: auth.session?.user.id) {
  if auth.session == nil {
    SharedCardSnapshotWriter.write(nil)
  }
}
```

(Diesen Block direkt unter den existing `.task`-Blocks in `AtollCardApp.swift` ergänzen.)

- [ ] **Step 3: Commit**

```bash
git add apps/atollcard-native/AtollCard/AtollCardApp.swift
git commit -m "feat(widget): clear snapshot on logout"
```

---

## Phase C — Widget Extension Target

### Task 7: `project.yml` Widget-Target + Entitlements

**Files:**
- Modify: `apps/atollcard-native/project.yml`
- Create: `apps/atollcard-native/AtollCardWidget/AtollCardWidget.entitlements`
- Create: `apps/atollcard-native/AtollCardWidget/Info.plist`
- Modify: `apps/atollcard-native/AtollCard/AtollCard.entitlements` (add app group)

- [ ] **Step 1: Widget-Entitlements**

Inhalt von `apps/atollcard-native/AtollCardWidget/AtollCardWidget.entitlements`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>com.apple.security.application-groups</key>
  <array>
    <string>group.swiss.atoll.card</string>
  </array>
</dict>
</plist>
```

- [ ] **Step 2: Widget Info.plist**

Inhalt von `apps/atollcard-native/AtollCardWidget/Info.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDisplayName</key>
  <string>AtollCard</string>
  <key>NSExtension</key>
  <dict>
    <key>NSExtensionPointIdentifier</key>
    <string>com.apple.widgetkit-extension</string>
  </dict>
</dict>
</plist>
```

- [ ] **Step 3: Haupt-App-Entitlements ergänzen**

In `apps/atollcard-native/AtollCard/AtollCard.entitlements`, vor dem `</dict>`-Tag am Ende einfügen:

```xml
  <key>com.apple.security.application-groups</key>
  <array>
    <string>group.swiss.atoll.card</string>
  </array>
```

- [ ] **Step 4: `project.yml` Target hinzufügen**

In `apps/atollcard-native/project.yml`, unter dem bestehenden `AtollCard:`-Target ergänzen (gleicher Indent-Level):

```yaml
  AtollCardWidget:
    type: app-extension
    platform: iOS
    deploymentTarget: "17.0"
    sources:
      - AtollCardWidget
      - AtollCardShared
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: swiss.atoll.card.widget
        DEVELOPMENT_TEAM: XK8V89P2QV
        CODE_SIGN_ENTITLEMENTS: AtollCardWidget/AtollCardWidget.entitlements
        SWIFT_VERSION: "6.0"
        INFOPLIST_KEY_NSExtensionPointIdentifier: com.apple.widgetkit-extension
    dependencies:
      - sdk: SwiftUI.framework
      - sdk: WidgetKit.framework
```

Im bestehenden `AtollCard:`-Target ergänzen unter `dependencies:`:

```yaml
      - target: AtollCardWidget
        embed: true
```

Im bestehenden `AtollCard:`-Target unter `sources:` `AtollCardShared` ergänzen, damit das SharedCardSnapshot-File auch in der App-Target-Membership ist:

```yaml
    sources:
      - AtollCard
      - AtollCardShared    # NEW — cross-target source
```

- [ ] **Step 5: `xcodegen generate` als Smoke-Compile-Check**

```bash
cd ~/Desktop/Developer/Dispo/apps/atollcard-native
xcodegen generate
```

Expected: "Created project at AtollCard.xcodeproj"

Falls in Sandbox kein xcodegen: skip + im Commit-Message vermerken.

- [ ] **Step 6: Commit**

```bash
git add apps/atollcard-native/project.yml \
        apps/atollcard-native/AtollCardWidget/AtollCardWidget.entitlements \
        apps/atollcard-native/AtollCardWidget/Info.plist \
        apps/atollcard-native/AtollCard/AtollCard.entitlements
git commit -m "feat(widget): project.yml widget target + app group entitlements"
```

---

### Task 8: `AtollCardWidgetBundle` Entry Point

**Files:**
- Create: `apps/atollcard-native/AtollCardWidget/AtollCardWidgetBundle.swift`

- [ ] **Step 1: Bundle-Entry schreiben**

Inhalt von `apps/atollcard-native/AtollCardWidget/AtollCardWidgetBundle.swift`:

```swift
import SwiftUI
import WidgetKit

/// Widget Extension entry — registers all WidgetKit configurations.
/// Today: only the Lock-Screen rectangular widget.
@main
struct AtollCardWidgetBundle: WidgetBundle {
  var body: some Widget {
    LockScreenCardWidget()
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add apps/atollcard-native/AtollCardWidget/AtollCardWidgetBundle.swift
git commit -m "feat(widget): AtollCardWidgetBundle @main entry"
```

---

### Task 9: `LockScreenCardWidget` + `CardSnapshotProvider`

**Files:**
- Create: `apps/atollcard-native/AtollCardWidget/LockScreenCardWidget.swift`

- [ ] **Step 1: Widget-Config + Provider + Entry**

Inhalt von `apps/atollcard-native/AtollCardWidget/LockScreenCardWidget.swift`:

```swift
import SwiftUI
import WidgetKit

// MARK: - Widget configuration

struct LockScreenCardWidget: Widget {
  let kind: String = "swiss.atoll.card.lockscreen"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: CardSnapshotProvider()) { entry in
      LockScreenCardView(entry: entry)
    }
    .configurationDisplayName("AtollCard Quick-QR")
    .description("Default-Karte mit One-Tap zum Vollbild-QR.")
    .supportedFamilies([.accessoryRectangular])
  }
}

// MARK: - Timeline entry

struct CardSnapshotEntry: TimelineEntry {
  let date:     Date
  let snapshot: SharedCardSnapshot?
}

// MARK: - Timeline provider

struct CardSnapshotProvider: TimelineProvider {
  func placeholder(in context: Context) -> CardSnapshotEntry {
    CardSnapshotEntry(date: .now, snapshot: nil)
  }

  func getSnapshot(in context: Context, completion: @escaping (CardSnapshotEntry) -> Void) {
    completion(CardSnapshotEntry(date: .now, snapshot: loadFromAppGroup()))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<CardSnapshotEntry>) -> Void) {
    let entry = CardSnapshotEntry(date: .now, snapshot: loadFromAppGroup())
    completion(Timeline(entries: [entry], policy: .never))
  }

  // MARK: - App-Group I/O

  private func loadFromAppGroup() -> SharedCardSnapshot? {
    guard let container = FileManager.default
      .containerURL(forSecurityApplicationGroupIdentifier: "group.swiss.atoll.card") else {
      return nil
    }
    let url = container.appendingPathComponent("default-card.json")
    guard let data = try? Data(contentsOf: url) else { return nil }
    return try? SharedCardSnapshot.decoder.decode(SharedCardSnapshot.self, from: data)
  }
}
```

(Note: App-Group-ID ist hier hardcoded weil die Widget-Extension keinen Zugriff auf `Config.appGroupID` aus dem App-Target hat — sie sind separate Targets. Wenn nötig könnte man eine `WidgetConfig.swift` analog anlegen.)

- [ ] **Step 2: Commit**

```bash
git add apps/atollcard-native/AtollCardWidget/LockScreenCardWidget.swift
git commit -m "feat(widget): LockScreenCardWidget + CardSnapshotProvider with app-group read"
```

---

### Task 10: `LockScreenCardView` — Have-Card State

**Files:**
- Create: `apps/atollcard-native/AtollCardWidget/LockScreenCardView.swift`

- [ ] **Step 1: View schreiben**

Inhalt von `apps/atollcard-native/AtollCardWidget/LockScreenCardView.swift`:

```swift
import SwiftUI
import WidgetKit

/// Rectangular Lock-Screen widget view (~158×54pt visible).
/// Renders in iOS vibrancy/tinted mode — keep visuals monochrome,
/// no gradients, no images.
struct LockScreenCardView: View {
  let entry: CardSnapshotEntry

  var body: some View {
    if let snapshot = entry.snapshot {
      Link(destination: deepLink(for: snapshot)) {
        haveCardLayout(snapshot)
      }
    } else {
      Link(destination: URL(string: "atollcard://")!) {
        fallbackLayout
      }
    }
  }

  // MARK: - Have-card layout

  private func haveCardLayout(_ snapshot: SharedCardSnapshot) -> some View {
    HStack(spacing: 8) {
      Image(systemName: "qrcode")
        .font(.system(size: 22, weight: .regular))
        .widgetAccentable()

      VStack(alignment: .leading, spacing: 2) {
        Text(headerLine(snapshot))
          .font(.system(size: 13, weight: .semibold))
          .lineLimit(1)
          .truncationMode(.tail)
        Text("Tippen → QR")
          .font(.system(size: 11))
          .foregroundStyle(.secondary)
      }
      Spacer(minLength: 0)
    }
    .containerBackground(.clear, for: .widget)
  }

  private func headerLine(_ snapshot: SharedCardSnapshot) -> String {
    if let badge = snapshot.badge, !badge.isEmpty {
      return "\(snapshot.title) · \(badge)"
    }
    return snapshot.title
  }

  // MARK: - Fallback layout

  private var fallbackLayout: some View {
    HStack(spacing: 8) {
      Image(systemName: "qrcode")
        .font(.system(size: 22, weight: .regular))
        .widgetAccentable()

      VStack(alignment: .leading, spacing: 2) {
        Text("AtollCard")
          .font(.system(size: 13, weight: .semibold))
        Text("Karte einrichten")
          .font(.system(size: 11))
          .foregroundStyle(.secondary)
      }
      Spacer(minLength: 0)
    }
    .containerBackground(.clear, for: .widget)
  }

  // MARK: - Deep link

  private func deepLink(for snapshot: SharedCardSnapshot) -> URL {
    URL(string: "atollcard://card/\(snapshot.slug)/qr")!
  }
}
```

(Note: `Image(systemName: "qrcode")` ist ein SF Symbol — vibrancy-friendly, kein eigenes Asset nötig. Plan-spec sagt "ATOLL-Glyph-Icon", aber für MVP ist SF-Symbol `qrcode` semantisch besser und garantiert lesbar nach Vibrancy-Filter. Falls später eigenes Glyph gewünscht: `Image("AtollGlyph")` mit Vector-Asset in den Widget-Assets.)

- [ ] **Step 2: Commit**

```bash
git add apps/atollcard-native/AtollCardWidget/LockScreenCardView.swift
git commit -m "feat(widget): LockScreenCardView with have-card + fallback layouts"
```

---

### Task 11: Widget Preview (Xcode-Hilfe)

**Files:**
- Modify: `apps/atollcard-native/AtollCardWidget/LockScreenCardView.swift`

- [ ] **Step 1: Preview-Block am Ende des Files anfügen**

Am Ende von `LockScreenCardView.swift` ergänzen:

```swift
#Preview("Have card", as: .accessoryRectangular) {
  LockScreenCardWidget()
} timeline: {
  CardSnapshotEntry(date: .now, snapshot: SharedCardSnapshot(
    slug: "dominik-cd",
    title: "PADI Course Director",
    badge: "PADI CD",
    personInitials: "DW",
    publicURL: URL(string: "https://atoll-os.com/c/dominik-cd")!,
    updatedAt: .now
  ))
}

#Preview("No card", as: .accessoryRectangular) {
  LockScreenCardWidget()
} timeline: {
  CardSnapshotEntry(date: .now, snapshot: nil)
}
```

- [ ] **Step 2: Commit**

```bash
git add apps/atollcard-native/AtollCardWidget/LockScreenCardView.swift
git commit -m "feat(widget): #Preview blocks for both states"
```

---

## Phase D — Deep-Link Routing

### Task 12: `AtollCardApp` Deep-Link-Handler erweitern

**Files:**
- Modify: `apps/atollcard-native/AtollCard/AtollCardApp.swift`

- [ ] **Step 1: Bestehenden onOpenURL inspizieren**

```bash
grep -n "onOpenURL\|atollcard" apps/atollcard-native/AtollCard/AtollCardApp.swift
```

- [ ] **Step 2: Deep-Link um `atollcard://card/<slug>/qr` erweitern**

Im bestehenden `.onOpenURL { url in ... }`-Block (vor irgendeinem `return` oder am sinnvollen Ort) ergänzen:

```swift
      // Widget-Deep-Link: atollcard://card/<slug>/qr → Fullscreen-QR
      if url.scheme == "atollcard",
         url.host == "card",
         url.pathComponents.count >= 3,
         url.pathComponents.last == "qr" {
        let slug = url.pathComponents[1]
        Task { @MainActor in
          // Wait briefly for CardStore to load if it's still hydrating
          for _ in 0..<10 {
            if let card = cardStore.cards.first(where: { $0.slug == slug }) {
              cardStore.presentingFullscreenQR = card
              return
            }
            try? await Task.sleep(nanoseconds: 200_000_000)  // 200ms
          }
        }
        return
      }
```

Wenn `cardStore` keine `presentingFullscreenQR`-Property hat, hinzufügen — siehe Task 13.

`url.pathComponents` für `atollcard://card/dominik-cd/qr` ist `["/", "card", "dominik-cd", "qr"]` (Apple-Quirk: erstes Element ist "/"). Daher index 1 = "card" (host), index 1 von pathComponents = "dominik-cd", last = "qr". Sicher mit count-check.

Wait — Korrektur: `host` ist "card", `pathComponents` ist `["/", "dominik-cd", "qr"]`. Also slug = `pathComponents[1]`, last = `pathComponents[2]`. Code so anpassen:

```swift
      if url.scheme == "atollcard",
         url.host == "card",
         url.pathComponents.count >= 3,
         url.pathComponents.last == "qr" {
        let slug = url.pathComponents[1]   // skip the leading "/"
        // ...
      }
```

- [ ] **Step 3: Commit**

```bash
git add apps/atollcard-native/AtollCard/AtollCardApp.swift
git commit -m "feat(widget): handle atollcard://card/<slug>/qr deep link"
```

---

### Task 13: `CardStore.presentingFullscreenQR` State + RootView-Sheet

**Files:**
- Modify: `apps/atollcard-native/AtollCard/Repositories/CardStore.swift`
- Modify: `apps/atollcard-native/AtollCard/Views/RootView.swift`

- [ ] **Step 1: Property in CardStore**

In `CardStore.swift` als observable property ergänzen (am Anfang, neben den anderen `@Observable`-Properties):

```swift
  /// Set non-nil to trigger RootView to present Fullscreen-QR for this card.
  /// Cleared by RootView when the sheet dismisses.
  var presentingFullscreenQR: Card?
```

- [ ] **Step 2: Sheet in RootView**

In `RootView.swift` am View-Body-Container (vermutlich `ZStack` oder `VStack`) ergänzen:

```swift
    .sheet(item: $cardStore.presentingFullscreenQR) { card in
      FullscreenQRView(card: card, person: lookupPerson(for: card))
    }
```

Wo `cardStore` ein `@Environment(CardStore.self)`-Bindung ist und `lookupPerson(for:)` der existing Person-Lookup im RootView ist.

Achtung: `Card` muss `Identifiable` sein (vermutlich ist es schon, sonst `extension Card: Identifiable {}` mit der `id`-Property dazu).

- [ ] **Step 3: Commit**

```bash
git add apps/atollcard-native/AtollCard/Repositories/CardStore.swift \
        apps/atollcard-native/AtollCard/Views/RootView.swift
git commit -m "feat(widget): CardStore.presentingFullscreenQR + RootView sheet trigger"
```

---

## Phase E — Rollout + Runbook + CHANGELOG

### Task 14: Rollout-Runbook + CHANGELOG 0.11.0

**Files:**
- Create: `docs/superpowers/runbooks/2026-05-26-atollcard-widget-welle-d-rollout.md`
- Modify: `apps/atollcard-native/CHANGELOG.md`

- [ ] **Step 1: Runbook schreiben**

Inhalt von `docs/superpowers/runbooks/2026-05-26-atollcard-widget-welle-d-rollout.md`:

```markdown
# Runbook: AtollCard Lock-Screen Widget (Welle D Part 1)

**Spec:** `docs/superpowers/specs/2026-05-26-atollcard-widget-design.md`
**Plan:** `docs/superpowers/plans/2026-05-26-atollcard-widget.md`

## Pre-Implementation

- [ ] Branch `feat/atollcard-widget` ausgecheckt
- [ ] AtollCard auf Branch `main` ist bei letztem Merge (Welle A+B+C)

## Apple Developer Portal (einmalig, ~5 Min)

### App Group registrieren

- [ ] [developer.apple.com](https://developer.apple.com/account) → Identifiers → oben Dropdown auf **App Groups** → **+**
- [ ] Description: "AtollCard shared container"
- [ ] Identifier: `group.swiss.atoll.card`
- [ ] Continue → Register

### App Group beiden Bundle-IDs zuweisen

- [ ] Identifiers → Filter "App IDs" → `swiss.atoll.card` anklicken
- [ ] Capabilities → **App Groups** ankreuzen → **Configure** → `group.swiss.atoll.card` ankreuzen → Save
- [ ] Falls `swiss.atoll.card.widget` nicht in der Liste ist (kommt erst nach erstem Xcode-Build): warten bis nach Schritt "Generate" unten, dann Schritt wiederholen für widget-ID

### Provisioning Profiles

- [ ] In Xcode: Code-Sign-Sektion fürs Widget-Target → "Update Settings" / "Try Again" wenn Cert-Fehler erscheint

## Code-Deploy

- [ ] `xcodegen generate` im `apps/atollcard-native/` Verzeichnis
- [ ] Xcode öffnet sich mit neuem `AtollCardWidget`-Target
- [ ] Schema "AtollCard" wählen, Build (Cmd+B) — beide Targets sollten grün durchbauen
- [ ] Aufs **echte iPhone** deployen (Cmd+R)

## Lock-Screen-Widget hinzufügen

- [ ] Auf iPhone-Lock-Screen: lang drücken
- [ ] Unten "**Anpassen**" tippen
- [ ] "**Sperrbildschirm**" wählen
- [ ] Unter der Uhr auf das `+ Widget`-Slot tippen
- [ ] App-Liste runter scrollen, **AtollCard** wählen
- [ ] Rectangular Widget tippen → wird platziert
- [ ] Oben **Fertig** rechts

## End-to-End-Test

- [ ] Lock-Screen anschauen — Widget zeigt deinen Default-Karten-Title (z.B. "PADI Course Director · PADI CD")
- [ ] Widget tippen → Phone wird entsperrt → AtollCard öffnet → Fullscreen-QR ist sofort sichtbar
- [ ] In der App eine andere Karte als Default setzen (Karten-Editor → "Als Standard")
- [ ] Lock-Screen-Widget zeigt innert 2-3 Sekunden die neue Karte (Apple kann bis zu ~30s delayen falls Drosselung greift)
- [ ] Logout in der App → Widget zeigt "AtollCard / Karte einrichten" als Fallback

## Rollback

Wenn was bricht:

- App-Group-Eintrag in `AtollCard.entitlements` entfernen → Widget kann nicht mehr lesen → zeigt Fallback (kein Crash)
- Widget-Target aus `project.yml` rauswerfen + `xcodegen generate` → Widget verschwindet aus der App-Bundle, Sperrbildschirm-Widget bleibt aber als "leerer Slot" sichtbar bis User es manuell entfernt
```

- [ ] **Step 2: CHANGELOG-Eintrag**

In `apps/atollcard-native/CHANGELOG.md` oben über dem aktuellen Top-Eintrag (`0.10.0`):

```markdown
## 0.11.0 — Lock-Screen-Widget (Larry, 26.05.2026)

Neues Widget Extension Target `AtollCardWidget` mit einem rectangular
Lock-Screen-Widget. Zeigt Title + Badge der Default-Karte, Tap öffnet
die App direkt im Fullscreen-QR-Screen.

### Architektur-Entscheid: App-Group-File statt direkter Repository-Call

Widget-Extensions haben harte Timeout-Limits (~30s) und keine
Auth-State-Garantie. Statt der Widget einen eigenen Supabase-Call
machen zu lassen, schreibt die Haupt-App ein kleines JSON
(`default-card.json`) in den shared App-Group-Container immer wenn
die Default-Karte sich ändert. Widget liest aus dem File — sub-
Millisekunden, kein Netz, immer last-known-good.

Reload-Trigger: `WidgetCenter.shared.reloadAllTimelines()` nach jedem
Write. Apple drosselt das, aber für seltene Default-Wechsel ist die
Latenz von 2-3 Sekunden akzeptabel.

### Tap-Target

`Link(destination: "atollcard://card/<slug>/qr")` — wenn das iPhone
gerade gelockt ist, fragt iOS einmal nach FaceID, dann landet der
User direkt im FullscreenQRView mit Brightness-Boost.

### Out-of-Scope (für spätere Sub-Projekte)

- Home-Screen Widget (separater Form-Faktor + Layout)
- Configuration-Intent für Multi-Card-Auswahl pro Widget-Instanz
- StandBy-Mode-Widget
- Push-getriggertes Widget-Refresh (z.B. Live-Lead-Count)
```

- [ ] **Step 3: Commit**

```bash
git add docs/superpowers/runbooks/2026-05-26-atollcard-widget-welle-d-rollout.md \
        apps/atollcard-native/CHANGELOG.md
git commit -m "docs: widget rollout runbook + AtollCard 0.11.0 changelog"
```

---

## Self-Review-Checklist (post-hoc)

**Spec-Coverage:**
- §2 Architektur-Entscheid → Tasks 1-9 implementieren das Pattern ✓
- §3 Widget-Inhalt + Layout → Tasks 10 + 11 ✓
- §4 App Group + Snapshot + Writer → Tasks 1, 3, 4, 5, 6 ✓
- §5 Deep-Link → Tasks 12 + 13 ✓
- §6 File-Inventar → über alle Tasks verteilt ✓
- §7 Apple-Setup → Runbook in Task 14 ✓
- §8 Rollout-Plan → Runbook in Task 14 ✓
- §11 Akzeptanzkriterien → durch Tests in Task 2 + E2E im Runbook abgedeckt ✓

**Placeholder-Scan:** keine TBD/TODO. Ein bewusst dokumentierter "Falls in Sandbox: skip" Marker in xcodegen-Schritten (Task 2 + 7) — kein Plan-Failure, sondern Sandbox-Boundary.

**Typkonsistenz:**
- `SharedCardSnapshot` mit denselben Properties in Task 1, 2, 5, 9
- `appGroupID` Konstante in Task 3, hardcoded in Task 9 (vermerkt warum: cross-target reach)
- `SharedCardSnapshotWriter.write(_:)` Signature identisch in Tasks 4, 5, 6
- `CardSnapshotProvider`/`CardSnapshotEntry` in Tasks 9, 11 konsistent

**Bekannte Follow-ups (nicht im Plan):**
- Eigenes ATOLL-Glyph statt SF-Symbol qrcode (Task 10 nutzt SF-Symbol; spec wollte Glyph) — pragmatischer MVP-Trade-off, getrennt nachziehen wenn echtes Asset vorhanden
- App-Group-ID-Konstante auch im Widget-Target (heute hardcoded in Task 9) — nice-to-have-Refactor
- Persons-Lookup im CardStore (Task 5) hängt vom existing Code-Pattern ab — Plan ist explizit "adaptier dich"
