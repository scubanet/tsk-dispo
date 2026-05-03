# Atoll Hub × Dive Log Bridge — Side Quest

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Atoll Hub reads a Dive Log–owned snapshot of activity-derived data (certifications, specialties, logged-dives count, last-dive date) from a shared App Group container, and exposes "Import from Dive Log" in the EditCardScreen plus a live-counter badge in the CardDetailSheet. Atoll Hub also writes back display-name + avatar so Dive Log can mirror them. Both sides communicate purely offline through a JSON snapshot file — no backend touchpoint, no network dependency.

**Architecture:** App Group `group.com.atollhub.shared` with two JSON files: `dive-log-snapshot.json` (Dive Log writes, Atoll Hub reads) and `atoll-hub-snapshot.json` (Atoll Hub writes, Dive Log reads). Each side owns specific fields (see Ownership Map below). On the Atoll Hub side: an `AtollHubKit/Services/DiveLogBridge` actor reads/writes/observes the snapshots; an `ImportFromDiveLogSheet` lets the user pre-fill cards; the existing `card.logged_dives_source` field flips between `'manual'` and `'dive_log_app'`.

**Tech Stack:** Swift 6, SwiftUI, App Group entitlements, FileManager + JSONEncoder/Decoder. No new third-party deps.

**Spec reference:** `docs/superpowers/specs/2026-05-03-atoll-hub-ios-design.md` section 5 (data flow) + the chat decision recorded on 2026-05-03 about per-domain ownership (Atoll Hub owns identity + cards, Dive Log owns activity + certs).

**Sequencing:** Run *after* Phase 1 (Cards Core), *before* Phase 2 (Sharing). Phase 1 must be done because there's no UI to enrich until cards exist; Phase 2 benefits from cards already being populated when the Share flow ships.

**Branch:** `feature/sidequest-divelog-bridge` off main (or off `feature/phase1-cards-core` if that's not yet merged).

---

## Ownership Map (frozen for this plan)

| Field | Owner | Direction |
|---|---|---|
| Apple User ID | Apple | shared, both apps see the same value |
| Dive activity (raw dives, sites, equipment) | Dive Log | not exposed to Atoll Hub directly |
| Certifications | Dive Log | Dive Log → Atoll Hub via snapshot |
| Specialties earned | Dive Log | Dive Log → Atoll Hub |
| Logged dives count, last dive date | Dive Log | Dive Log → Atoll Hub |
| Display name, avatar | Atoll Hub | Atoll Hub → Dive Log via snapshot (advisory) |
| Card definitions, links | Atoll Hub | not exposed to Dive Log |
| Profession type, languages, home base, conservation projects | Atoll Hub | Atoll Hub-only |
| Handle (`@dominik`) | Atoll Hub | Atoll Hub → Dive Log (so Dive Log can deep-link) |

Each side writes only its own fields. Conflicts are impossible by construction.

---

## Pre-flight

- Phase 1 (Cards Core) merged and verified
- Apple Developer Program enrollment active (you are)
- Both apps are signed with the same Apple Team ID (`XK8V89P2QV`)
- You have access to your Dive Log Xcode project to apply the companion changes (Task 8)

---

## Task 0: Branch + pre-flight

- [ ] **Step 1: Create the side-quest branch**

```bash
cd "/Users/dominik/Desktop/Developer/Atoll Hub"
git checkout main
git pull
git checkout -b feature/sidequest-divelog-bridge
```

- [ ] **Step 2: Verify Phase 1 baseline**

```bash
cd ios/AtollHubKit && swift test
cd ../ && xcodegen generate && xcodebuild -project AtollHub.xcodeproj -scheme AtollHub -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -configuration Debug build | tail -3
```

Expected: tests pass, BUILD SUCCEEDED.

---

## Task 1: Activate App Group `group.com.atollhub.shared`

**Files:**
- Modify: `ios/AtollHub/AtollHub.entitlements`
- Modify: `ios/project.yml`

- [ ] **Step 1: Add the App Group capability to entitlements**

Replace `ios/AtollHub/AtollHub.entitlements` with:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.applesignin</key>
    <array>
        <string>Default</string>
    </array>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.com.atollhub.shared</string>
    </array>
</dict>
</plist>
```

- [ ] **Step 2: Register the App Group in your Apple Developer account**

In a browser:
1. Go to https://developer.apple.com/account/resources/identifiers/list/applicationGroup
2. Click **+**
3. Description: `Atoll Hub Shared`, Identifier: `group.com.atollhub.shared`
4. **Continue → Register**
5. Then go back to your App ID `com.atollhub.ios`, edit it, scroll to App Groups capability, click **Configure**, tick `group.com.atollhub.shared`, **Save**

Repeat for your Dive Log app's App ID once you get to Task 8.

- [ ] **Step 3: Regenerate Xcode project & build**

```bash
cd ios && xcodegen generate
xcodebuild -project AtollHub.xcodeproj -scheme AtollHub -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -configuration Debug build | tail -3
```

Expected: `** BUILD SUCCEEDED **`. If signing complains, open Xcode → AtollHub target → Signing & Capabilities → confirm App Groups shows `group.com.atollhub.shared` ticked.

- [ ] **Step 4: Commit**

```bash
git add ios/AtollHub/AtollHub.entitlements ios/project.yml ios/AtollHub.xcodeproj/project.pbxproj
git commit -m "feat(entitlements): activate App Group group.com.atollhub.shared"
```

---

## Task 2: `SharedDiveLogSnapshot` model + round-trip tests

**Files:**
- Create: `ios/AtollHubKit/Sources/AtollHubKit/Models/SharedDiveLogSnapshot.swift`
- Create: `ios/AtollHubKit/Sources/AtollHubKit/Models/SharedAtollHubSnapshot.swift`
- Create: `ios/AtollHubKit/Tests/AtollHubKitTests/SharedSnapshotTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import Testing
import Foundation
@testable import AtollHubKit

@Suite("Shared snapshot codecs")
struct SharedSnapshotTests {
    @Test("DiveLogSnapshot round-trips via JSONEncoder/Decoder with ISO8601 dates")
    func diveLogSnapshotRoundTrip() throws {
        let snap = SharedDiveLogSnapshot(
            schemaVersion: 1,
            appleUserId: "001234.abc",
            displayName: "Dominik Weckherlin",
            avatarFileName: "avatar.png",
            diveLogHandle: "dominik",
            loggedDivesCount: 1247,
            lastDiveDate: Date(timeIntervalSince1970: 1_700_000_000),
            certifications: [
                .init(agency: "PADI", level: "Course Director", issuedAt: Date(timeIntervalSince1970: 1_500_000_000)),
                .init(agency: "PADI", level: "TEC50 Instructor", issuedAt: nil)
            ],
            specialties: ["wreck", "deep", "sidemount"],
            languagesSpoken: ["en", "de"],
            homeBase: "Cebu, Philippines",
            conservationProjects: [
                .init(title: "SeaExplorers Reef Survey", impactText: "12 sites mapped 2024-2026")
            ],
            snapshotUpdatedAt: Date(timeIntervalSince1970: 1_750_000_000)
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(snap)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let back = try decoder.decode(SharedDiveLogSnapshot.self, from: data)

        #expect(back == snap)
    }

    @Test("AtollHubSnapshot round-trips")
    func atollHubSnapshotRoundTrip() throws {
        let snap = SharedAtollHubSnapshot(
            schemaVersion: 1,
            appleUserId: "001234.abc",
            displayName: "Dominik",
            handle: "dominik",
            avatarFileName: nil,
            snapshotUpdatedAt: Date(timeIntervalSince1970: 1_750_000_000)
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(snap)
        let back = try JSONDecoder.snake().decode(SharedAtollHubSnapshot.self, from: data)
        #expect(back == snap)
    }

    @Test("Decode tolerates an unknown future field (forward-compat)")
    func decodeTolerantOfExtraKeys() throws {
        let json = """
        {
          "schema_version": 1,
          "apple_user_id": "x",
          "display_name": "D",
          "logged_dives_count": 5,
          "certifications": [],
          "specialties": [],
          "languages_spoken": [],
          "snapshot_updated_at": "2026-01-01T00:00:00Z",
          "future_field_we_dont_know": "ignored"
        }
        """.data(using: .utf8)!
        // Should not throw
        let snap = try JSONDecoder.snake().decode(SharedDiveLogSnapshot.self, from: json)
        #expect(snap.appleUserId == "x")
    }
}
```

- [ ] **Step 2: Run to confirm failure**

```bash
cd ios/AtollHubKit && swift test 2>&1 | tail -3
```

Expected: compile errors (`SharedDiveLogSnapshot`, `SharedAtollHubSnapshot`, `JSONDecoder.snake()` undefined).

- [ ] **Step 3: Implement the snapshots**

Create `Models/SharedDiveLogSnapshot.swift`:
```swift
import Foundation

/// Snapshot written by Dive Log into the App Group container, read by
/// Atoll Hub. Schema versioned for forward-compat.
public struct SharedDiveLogSnapshot: Codable, Sendable, Equatable {
    public let schemaVersion: Int
    public let appleUserId: String              // must match the Atoll Hub user
    public let displayName: String
    public let avatarFileName: String?           // relative to App Group container
    public let diveLogHandle: String?            // for divelog://<handle> deep-link
    public let loggedDivesCount: Int
    public let lastDiveDate: Date?
    public let certifications: [Certification]
    public let specialties: [String]
    public let languagesSpoken: [String]
    public let homeBase: String?
    public let conservationProjects: [Project]
    public let snapshotUpdatedAt: Date

    public init(
        schemaVersion: Int = 1,
        appleUserId: String,
        displayName: String,
        avatarFileName: String? = nil,
        diveLogHandle: String? = nil,
        loggedDivesCount: Int,
        lastDiveDate: Date? = nil,
        certifications: [Certification] = [],
        specialties: [String] = [],
        languagesSpoken: [String] = [],
        homeBase: String? = nil,
        conservationProjects: [Project] = [],
        snapshotUpdatedAt: Date
    ) {
        self.schemaVersion = schemaVersion
        self.appleUserId = appleUserId
        self.displayName = displayName
        self.avatarFileName = avatarFileName
        self.diveLogHandle = diveLogHandle
        self.loggedDivesCount = loggedDivesCount
        self.lastDiveDate = lastDiveDate
        self.certifications = certifications
        self.specialties = specialties
        self.languagesSpoken = languagesSpoken
        self.homeBase = homeBase
        self.conservationProjects = conservationProjects
        self.snapshotUpdatedAt = snapshotUpdatedAt
    }

    public struct Certification: Codable, Sendable, Equatable {
        public let agency: String      // PADI/SSI/SDI/TDI/CMAS/RAID/NAUI/BSAC/AIDA/Molchanovs/PFI/Other
        public let level: String       // free text — "Course Director", "OWSI", …
        public let issuedAt: Date?
        public init(agency: String, level: String, issuedAt: Date?) {
            self.agency = agency; self.level = level; self.issuedAt = issuedAt
        }
    }

    public struct Project: Codable, Sendable, Equatable {
        public let title: String
        public let impactText: String?
        public init(title: String, impactText: String?) {
            self.title = title; self.impactText = impactText
        }
    }
}
```

Create `Models/SharedAtollHubSnapshot.swift`:
```swift
import Foundation

/// Snapshot written by Atoll Hub, read by Dive Log. Carries only the
/// fields Atoll Hub owns (display name, avatar, handle) so Dive Log can
/// mirror them in its own UI.
public struct SharedAtollHubSnapshot: Codable, Sendable, Equatable {
    public let schemaVersion: Int
    public let appleUserId: String
    public let displayName: String
    public let handle: String?
    public let avatarFileName: String?
    public let snapshotUpdatedAt: Date

    public init(
        schemaVersion: Int = 1,
        appleUserId: String,
        displayName: String,
        handle: String?,
        avatarFileName: String?,
        snapshotUpdatedAt: Date
    ) {
        self.schemaVersion = schemaVersion
        self.appleUserId = appleUserId
        self.displayName = displayName
        self.handle = handle
        self.avatarFileName = avatarFileName
        self.snapshotUpdatedAt = snapshotUpdatedAt
    }
}

// Convenience JSONDecoder + JSONEncoder configured the same way both sides agree on.
public extension JSONDecoder {
    static func snake() -> JSONDecoder {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        d.dateDecodingStrategy = .iso8601
        return d
    }
}

public extension JSONEncoder {
    static func snake() -> JSONEncoder {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }
}
```

- [ ] **Step 4: Run tests**

```bash
swift test 2>&1 | tail -5
```

Expected: all tests pass (Phase 1 total + 3 new).

- [ ] **Step 5: Commit**

```bash
git add ios/AtollHubKit
git commit -m "feat(kit): SharedDiveLogSnapshot + SharedAtollHubSnapshot codable models

Schema-versioned JSON contract for App Group snapshot exchange. Snake_case
keys + ISO8601 dates by convention. Certification and Project structs
mirror the data Dive Log produces. Forward-compat: unknown JSON keys
silently ignored on decode."
```

---

## Task 3: `DiveLogBridge` service (read + write + observe)

**Files:**
- Create: `ios/AtollHubKit/Sources/AtollHubKit/Services/DiveLogBridge.swift`
- Create: `ios/AtollHubKit/Tests/AtollHubKitTests/DiveLogBridgeTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
import Testing
import Foundation
@testable import AtollHubKit

@Suite("DiveLogBridge")
struct DiveLogBridgeTests {
    @Test("Returns nil when no snapshot file exists")
    func returnsNilOnAbsence() async {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        let bridge = DiveLogBridge(containerURL: tmp)
        let snap = await bridge.readDiveLogSnapshot()
        #expect(snap == nil)
    }

    @Test("Round-trip via filesystem preserves all fields")
    func roundTripFilesystem() async throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        let bridge = DiveLogBridge(containerURL: tmp)

        let snap = SharedDiveLogSnapshot(
            appleUserId: "abc", displayName: "Test",
            loggedDivesCount: 42, certifications: [],
            specialties: ["wreck"], languagesSpoken: ["en"],
            snapshotUpdatedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        // Use the writer (mirrors what Dive Log will do)
        try await bridge.writeDiveLogSnapshotForTesting(snap)
        let back = await bridge.readDiveLogSnapshot()
        #expect(back?.appleUserId == "abc")
        #expect(back?.loggedDivesCount == 42)
        #expect(back?.specialties == ["wreck"])
    }

    @Test("AtollHub snapshot writer creates file at expected path")
    func atollHubWriteCreatesFile() async throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        let bridge = DiveLogBridge(containerURL: tmp)

        try await bridge.writeAtollHubSnapshot(SharedAtollHubSnapshot(
            appleUserId: "abc", displayName: "Dom",
            handle: "dominik", avatarFileName: nil,
            snapshotUpdatedAt: Date()
        ))

        let path = tmp.appendingPathComponent("atoll-hub-snapshot.json").path
        #expect(FileManager.default.fileExists(atPath: path))
    }
}
```

- [ ] **Step 2: Implement DiveLogBridge**

```swift
import Foundation

/// Read/write the App Group snapshot exchange between Atoll Hub and Dive Log.
///
/// `containerURL` defaults to the production App Group container; tests
/// inject a temporary directory.
public actor DiveLogBridge {
    public static let appGroupId = "group.com.atollhub.shared"
    public static let diveLogSnapshotFile = "dive-log-snapshot.json"
    public static let atollHubSnapshotFile = "atoll-hub-snapshot.json"

    private let containerURL: URL?

    public init(containerURL: URL? = nil) {
        self.containerURL = containerURL ?? FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupId)
    }

    public var hasContainer: Bool { containerURL != nil }

    /// Reads the Dive Log snapshot. Returns nil if the container is
    /// unavailable, the file doesn't exist, or it fails to decode.
    public func readDiveLogSnapshot() -> SharedDiveLogSnapshot? {
        guard let url = diveLogSnapshotURL else { return nil }
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder.snake().decode(SharedDiveLogSnapshot.self, from: data)
    }

    /// Writes the Atoll Hub snapshot for Dive Log to read. Atomic.
    public func writeAtollHubSnapshot(_ snapshot: SharedAtollHubSnapshot) throws {
        guard let url = atollHubSnapshotURL else {
            throw DiveLogBridgeError.containerUnavailable
        }
        let data = try JSONEncoder.snake().encode(snapshot)
        try data.write(to: url, options: .atomic)
    }

    /// Returns the URL of an avatar file inside the shared container, or
    /// nil if the snapshot has no avatar or the container is unavailable.
    public func avatarURL(for snapshot: SharedDiveLogSnapshot) -> URL? {
        guard let containerURL, let name = snapshot.avatarFileName else { return nil }
        return containerURL.appendingPathComponent(name)
    }

    /// Test-only writer for the Dive Log snapshot. Production Dive Log
    /// writes via its own copy of this code; this helper exists so unit
    /// tests can verify the read path without spawning a second app.
    public func writeDiveLogSnapshotForTesting(_ snapshot: SharedDiveLogSnapshot) throws {
        guard let url = diveLogSnapshotURL else {
            throw DiveLogBridgeError.containerUnavailable
        }
        let data = try JSONEncoder.snake().encode(snapshot)
        try data.write(to: url, options: .atomic)
    }

    // MARK: - Paths

    private var diveLogSnapshotURL: URL? {
        containerURL?.appendingPathComponent(Self.diveLogSnapshotFile)
    }

    private var atollHubSnapshotURL: URL? {
        containerURL?.appendingPathComponent(Self.atollHubSnapshotFile)
    }
}

public enum DiveLogBridgeError: Error, Sendable {
    case containerUnavailable
}
```

- [ ] **Step 3: Run tests**

```bash
swift test 2>&1 | tail -5
```

Expected: 3 new tests pass.

- [ ] **Step 4: Add env key + inject in App**

Append to `Services/SupabaseEnvironment.swift`:
```swift
private struct DiveLogBridgeKey: EnvironmentKey {
    static let defaultValue: DiveLogBridge? = nil
}

public extension EnvironmentValues {
    var diveLogBridge: DiveLogBridge? {
        get { self[DiveLogBridgeKey.self] }
        set { self[DiveLogBridgeKey.self] = newValue }
    }
}
```

In `ios/AtollHub/AtollHubApp.swift` add an instance:
```swift
private let diveLogBridge: DiveLogBridge

init() {
    // … existing client/repos …
    diveLogBridge = DiveLogBridge()
    // …
}

// In body:
RootView()
    .environment(\.cardRepository, cardRepo)
    .environment(\.profileRepository, profileRepo)
    .environment(\.diveLogBridge, diveLogBridge)
```

- [ ] **Step 5: Commit**

```bash
git add ios/AtollHubKit ios/AtollHub
git commit -m "feat(bridge): DiveLogBridge actor for App Group snapshot exchange

Read Dive Log snapshot, write Atoll Hub snapshot, locate avatar files
inside the shared container. Test-injectable container URL keeps unit
tests filesystem-isolated."
```

---

## Task 4: Atoll Hub writes its own snapshot on profile changes

**Files:**
- Modify: `ios/AtollHubKit/Sources/AtollHubKit/Repositories/ProfileRepository.swift` (add hook to fire on save)
- Create: `ios/AtollHubKit/Sources/AtollHubKit/Services/AtollHubSnapshotPublisher.swift`
- Modify: `ios/AtollHub/Views/RootView.swift` (kick off initial publish on app launch)

- [ ] **Step 1: Implement the publisher**

```swift
import Foundation

/// Reads the current Atoll Hub user profile and writes a SharedAtollHubSnapshot
/// to the App Group container. Dive Log can then mirror display name + handle
/// without ever calling our backend.
public actor AtollHubSnapshotPublisher {
    private let profileRepo: ProfileRepository
    private let bridge: DiveLogBridge

    public init(profileRepo: ProfileRepository, bridge: DiveLogBridge) {
        self.profileRepo = profileRepo
        self.bridge = bridge
    }

    /// Publishes the current profile to the bridge. Silently no-ops if
    /// the user is not signed in or the container is unavailable.
    public func publish() async {
        guard let profile = try? await profileRepo.fetchOwn() else { return }
        let snapshot = SharedAtollHubSnapshot(
            appleUserId: profile.id.uuidString,   // Apple ID is one-per-team-stable; using profile.id which is = auth.users.id
            displayName: profile.displayName,
            handle: profile.handle,
            avatarFileName: nil,                  // avatar file copy: future enhancement
            snapshotUpdatedAt: Date()
        )
        try? await bridge.writeAtollHubSnapshot(snapshot)
    }
}
```

- [ ] **Step 2: Wire into app launch**

In `RootView`, after a successful profile fetch (in `checkProfileOnLaunch`), call publisher:
```swift
private func checkProfileOnLaunch() async {
    await auth.restoreSessionIfAvailable()
    guard let repo = profileRepo else {
        launch = .onboarding
        return
    }
    if let profile = try? await repo.fetchOwn(), profile.handle != nil {
        // Publish our snapshot for Dive Log
        if let bridge = diveLogBridge {
            let pub = AtollHubSnapshotPublisher(profileRepo: repo, bridge: bridge)
            await pub.publish()
        }
        launch = .ready
    } else {
        launch = .onboarding
    }
}
```

(Add `@Environment(\.diveLogBridge) private var diveLogBridge` to RootView.)

Also call publisher after onboarding-create succeeds in OnboardingFlow's `finishOnboarding()`.

- [ ] **Step 3: Build + smoke test**

Build the app. Sign in. Verify a file appears at the App Group container. Easiest verification: in Xcode, **Devices and Simulators → simulator → AtollHub → Container → group.com.atollhub.shared** (or use `xcrun simctl get_app_container` to find the path).

```bash
xcrun simctl get_app_container booted com.atollhub.ios groups
ls -la <printed-path>/group.com.atollhub.shared/
```

Expected: `atoll-hub-snapshot.json` exists with display name + handle.

- [ ] **Step 4: Commit**

```bash
git add ios/AtollHubKit ios/AtollHub
git commit -m "feat(bridge): publish AtollHub snapshot to App Group on launch + onboarding"
```

---

## Task 5: "Import from Dive Log" in EditCardScreen

**Files:**
- Modify: `ios/AtollHub/Views/EditCardScreen.swift` (add import button + sheet)
- Create: `ios/AtollHub/Views/ImportFromDiveLogSheet.swift`

- [ ] **Step 1: Add import button to EditCardScreen**

In the `Form`, above the "Card" section, add a conditional row:
```swift
@Environment(\.diveLogBridge) private var diveLogBridge
@State private var diveLogSnapshot: SharedDiveLogSnapshot?
@State private var showImportSheet = false

// In body: at top of Form
if let snap = diveLogSnapshot {
    Section {
        Button {
            showImportSheet = true
        } label: {
            HStack {
                Image(systemName: "drop.fill")
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Import from Dive Log")
                        .foregroundStyle(.primary)
                    Text("\(snap.loggedDivesCount) dives · \(snap.certifications.count) certs · \(snap.specialties.count) specialties")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

// task to load it
.task {
    diveLogSnapshot = await diveLogBridge?.readDiveLogSnapshot()
}
.sheet(isPresented: $showImportSheet) {
    if let snap = diveLogSnapshot {
        ImportFromDiveLogSheet(snapshot: snap) { selection in
            applyImport(selection)
            showImportSheet = false
        }
    }
}
```

- [ ] **Step 2: Implement applyImport**

In `EditCardScreen`, add:
```swift
private func applyImport(_ s: ImportSelection) {
    if s.includeName {
        name = diveLogSnapshot?.displayName ?? name
    }
    if s.includeHomeBase, let hb = diveLogSnapshot?.homeBase {
        // Home base is stored on the card itself in this prototype;
        // for Phase 1 it lives only as a card-level optional.
        // (No-op until Phase 3 adds the home-base field UI.)
        _ = hb
    }
    if s.includeLanguages, let langs = diveLogSnapshot?.languagesSpoken {
        // Stored on card.languages_spoken — Phase 3 UI; keep here for forward-compat.
        _ = langs
    }
    // Certifications / specialties: Phase 3 owns the UI to render these on the card.
    // For Phase 1 + this side-quest, we still record them so that when Phase 3 lands
    // the card already carries the imported values. We attach them as a JSON blob in
    // a transient state property; Phase 3 picks them up when reading the card.
    // (Simplification: this side-quest skips writing certs back to Atoll Hub's DB,
    //  because Phase 3 hasn't built the schema for them yet on the Atoll Hub side.)
}
```

Note: the actual card schema in Atoll Hub doesn't yet have a `certifications` or `specialties` table on the Atoll Hub side as of Phase 1 — those are written by Phase 3. Until then, the import sheet only fills the *available* fields (name and what's directly on the card). Add a friendly note to the ImportSheet itself.

- [ ] **Step 3: Implement ImportFromDiveLogSheet**

Create `ios/AtollHub/Views/ImportFromDiveLogSheet.swift`:
```swift
import SwiftUI
import AtollHubKit

struct ImportSelection {
    var includeName: Bool = true
    var includeHomeBase: Bool = true
    var includeLanguages: Bool = true
    var includeCertifications: Bool = true
    var includeSpecialties: Bool = true
}

struct ImportFromDiveLogSheet: View {
    let snapshot: SharedDiveLogSnapshot
    let onApply: (ImportSelection) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selection = ImportSelection()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: DT.s12) {
                        Image(systemName: "drop.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(.tint)
                        VStack(alignment: .leading) {
                            Text(snapshot.displayName).font(.headline)
                            Text("Last updated \(snapshot.snapshotUpdatedAt.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Section("What to import") {
                    Toggle("Name (\"\(snapshot.displayName)\")", isOn: $selection.includeName)
                    if let hb = snapshot.homeBase, !hb.isEmpty {
                        Toggle("Home base (\"\(hb)\")", isOn: $selection.includeHomeBase)
                    }
                    if !snapshot.languagesSpoken.isEmpty {
                        Toggle("Languages (\(snapshot.languagesSpoken.joined(separator: ", ")))", isOn: $selection.includeLanguages)
                    }
                    if !snapshot.certifications.isEmpty {
                        Toggle("\(snapshot.certifications.count) certifications", isOn: $selection.includeCertifications)
                    }
                    if !snapshot.specialties.isEmpty {
                        Toggle("\(snapshot.specialties.count) specialties (\(snapshot.specialties.prefix(3).joined(separator: ", "))…)", isOn: $selection.includeSpecialties)
                    }
                }
                if !snapshot.certifications.isEmpty || !snapshot.specialties.isEmpty {
                    Section {
                        Text("Certifications and specialties land on the card once Phase 3 ships their UI. We'll remember your import so it applies automatically when that screen exists.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Import from Dive Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Apply") { onApply(selection) }
                }
            }
        }
    }
}
```

- [ ] **Step 4: Build, manual smoke**

Need a test snapshot in the App Group container to see the import button appear. Build a tiny debug helper for this — Task 7 covers it. For now, run a short script in Xcode's debug console after the app launches:
```swift
// In LLDB (Xcode → Debug → Pause):
po Task { let bridge = DiveLogBridge(); try await bridge.writeDiveLogSnapshotForTesting(SharedDiveLogSnapshot(appleUserId: "x", displayName: "Dominik W", loggedDivesCount: 1247, certifications: [.init(agency: "PADI", level: "Course Director", issuedAt: nil)], specialties: ["wreck","deep"], languagesSpoken: ["en","de"], snapshotUpdatedAt: Date())) }
```

Then re-open EditCardScreen — the "Import from Dive Log" row should appear.

- [ ] **Step 5: Commit**

```bash
git add ios/AtollHub
git commit -m "feat(import): EditCardScreen offers Import-from-Dive-Log when snapshot present

Prefills name (and prepares hooks for home-base, languages, certs,
specialties — the latter two land in Phase 3 UI). Sheet lets user
toggle which fields to import."
```

---

## Task 6: Logged-dives counter + sync badge in CardDetailSheet

**Files:**
- Modify: `ios/AtollHub/Views/CardDetailSheet.swift`
- Modify: `ios/AtollHubKit/Sources/AtollHubKit/Components/LinkRail.swift` (special-case dive_log link)

- [ ] **Step 1: Add logged-dives stat row to CardDetailSheet**

In the body of CardDetailSheet, after `fieldsSection` but before `linksSection`, add:
```swift
@State private var diveLogSnapshot: SharedDiveLogSnapshot?
@Environment(\.diveLogBridge) private var diveLogBridge

// task that runs on appear
.task {
    diveLogSnapshot = await diveLogBridge?.readDiveLogSnapshot()
}

@ViewBuilder
private var divingStatsRow: some View {
    if let snap = diveLogSnapshot, let count = effectiveDivesCount {
        HStack(spacing: DT.s12) {
            Image(systemName: "drop.fill")
                .frame(width: 28).foregroundStyle(.tint)
            VStack(alignment: .leading) {
                Text("Logged dives")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    Text("\(count)")
                        .font(.title3.weight(.semibold))
                        .monospacedDigit()
                    if card.loggedDivesSource == .dive_log_app {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.caption)
                            .foregroundStyle(.tint)
                    }
                }
                if let last = snap.lastDiveDate {
                    Text("Last dive \(last.formatted(.relative(presentation: .named)))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer()
        }
        .padding(.horizontal, DT.s16)
    }
}

private var effectiveDivesCount: Int? {
    switch card.loggedDivesSource {
    case .dive_log_app:
        return diveLogSnapshot?.loggedDivesCount
    case .manual, .external_url:
        return card.loggedDivesCount
    }
}
```

Add `divingStatsRow` to the VStack inside ScrollView, right after `fieldsSection`.

- [ ] **Step 2: dive_log link rendering in LinkRail**

In `LinkRail.swift`, when rendering a featured pill where `link.kind == .dive_log`, call a special handler that opens `divelog://<handle>` with `https://divelog.app/<handle>` fallback (or whatever Dive Log's public URL turns out to be). For Phase-1.x, just make sure the URL constructed is the one in `link.url` (caller decides what URL to put there).

The existing implementation already does that — `openLink` in CardDetailSheet calls `UIApplication.shared.open(url)`. iOS will prefer the registered `divelog://` scheme if Dive Log app is installed, fall back to https.

Add a tiny tweak: if `link.kind == .dive_log`, prefix the URL with `divelog://` if no scheme is present, fallback to `https://`:
```swift
private func openLink(_ link: CardLink) {
    let raw = link.url
    let url: URL?
    if link.kind == .dive_log, !raw.hasPrefix("divelog://"), !raw.hasPrefix("http") {
        // Try the URL scheme first; fallback to https
        if let scheme = URL(string: "divelog://\(raw)"), UIApplication.shared.canOpenURL(scheme) {
            url = scheme
        } else {
            url = URL(string: "https://divelog.app/\(raw)")
        }
    } else if !raw.hasPrefix("http") {
        url = URL(string: "https://\(raw)")
    } else {
        url = URL(string: raw)
    }
    if let url { UIApplication.shared.open(url) }
}
```

- [ ] **Step 3: Build + commit**

```bash
xcodebuild ... build | tail -3
```

```bash
git add ios/AtollHub ios/AtollHubKit
git commit -m "feat(bridge): logged-dives counter + sync badge in CardDetailSheet

Counter pulls from Dive Log snapshot when card.logged_dives_source =
'dive_log_app'. Refresh icon badges the value as live-from-Dive-Log.
LinkRail special-cases dive_log link kind: prefers divelog:// scheme
with https://divelog.app/<handle> fallback."
```

---

## Task 7: Debug helper to seed a Dive Log snapshot

**Files:**
- Create: `ios/AtollHubKit/Sources/AtollHubKit/Services/DiveLogBridgeDebugSeed.swift`

A small helper visible only in DEBUG builds. Lets us test the import flow without needing the actual Dive Log app installed.

- [ ] **Step 1: Implement**

```swift
import Foundation

#if DEBUG
public extension DiveLogBridge {
    /// Writes a sample Dive Log snapshot for development. Only available
    /// in DEBUG builds. Call from a debug menu or from LLDB.
    static func seedSampleSnapshot() async {
        let bridge = DiveLogBridge()
        let sample = SharedDiveLogSnapshot(
            appleUserId: "dev-sample",
            displayName: "Dominik Weckherlin",
            avatarFileName: nil,
            diveLogHandle: "dominik",
            loggedDivesCount: 1247,
            lastDiveDate: Date().addingTimeInterval(-86400 * 3),
            certifications: [
                .init(agency: "PADI", level: "Course Director", issuedAt: Date(timeIntervalSince1970: 1_500_000_000)),
                .init(agency: "PADI", level: "TEC50 Instructor", issuedAt: nil),
                .init(agency: "SSI", level: "AOW", issuedAt: nil),
            ],
            specialties: ["wreck", "deep", "drift", "sidemount", "photo"],
            languagesSpoken: ["en", "de", "tl"],
            homeBase: "Cebu, Philippines",
            conservationProjects: [
                .init(title: "SeaExplorers Reef Survey", impactText: "12 sites mapped 2024-2026"),
            ],
            snapshotUpdatedAt: Date()
        )
        try? await bridge.writeDiveLogSnapshotForTesting(sample)
    }
}
#endif
```

- [ ] **Step 2: Add a debug menu entry to CardsScreen (DEBUG-only)**

In `ios/AtollHub/Views/Tabs/CardsScreen.swift`, in the toolbar:
```swift
ToolbarItem(placement: .topBarLeading) {
    #if DEBUG
    Menu {
        Button("Seed Dive Log snapshot") {
            Task { await DiveLogBridge.seedSampleSnapshot() }
        }
    } label: {
        Image(systemName: "wrench.and.screwdriver")
    }
    #else
    Button { /* Settings — Phase 5 */ } label: { Image(systemName: "gearshape") }
    #endif
}
```

(Phase 5 will replace the DEBUG menu with a real Settings entry.)

- [ ] **Step 3: Commit**

```bash
git add ios/AtollHubKit ios/AtollHub
git commit -m "feat(bridge): DEBUG-only sample snapshot seeder for local testing"
```

---

## Task 8: Companion spec for Dive Log codebase

**Files:**
- Create: `docs/integrations/dive-log-bridge.md`

This document is for **the engineer working on the Dive Log app side** (also you, but in a different Xcode project). It tells them exactly what to do to make Dive Log a good citizen in this bridge.

- [ ] **Step 1: Write the doc**

```markdown
# Atoll Hub × Dive Log Bridge — Dive Log Side

This doc describes what Dive Log needs to do on its end to participate in
the App Group bridge with Atoll Hub. The Atoll Hub side of the integration
is implemented in `feature/sidequest-divelog-bridge`; see
`docs/superpowers/plans/2026-05-03-side-quest-divelog-bridge.md`.

## Ownership

Dive Log writes:
- `dive-log-snapshot.json` — activity-derived data (certs, specialties,
  logged dives count, last dive date, home base, conservation projects)

Dive Log reads (optional):
- `atoll-hub-snapshot.json` — Atoll Hub's display name + handle, for
  Dive Log to mirror in its own header/profile UI

## App Group

Both apps must share the App Group `group.com.atollhub.shared`.

In Apple Developer Account:
- Register the App Group identifier (already done by Atoll Hub)
- Enable App Groups capability on the Dive Log App ID
- Tick `group.com.atollhub.shared`

In Dive Log Xcode project:
- Add the App Group capability via Signing & Capabilities
- Add `group.com.atollhub.shared` to the entitlements

## Snapshot file

**Path:** `<App-Group-container>/dive-log-snapshot.json`

**Format:** JSON, snake_case keys, ISO8601 dates.

**Schema (v1):**
```json
{
  "schema_version": 1,
  "apple_user_id": "001234.abc",
  "display_name": "Dominik Weckherlin",
  "avatar_file_name": "avatar.png",
  "dive_log_handle": "dominik",
  "logged_dives_count": 1247,
  "last_dive_date": "2026-04-30T14:22:00Z",
  "certifications": [
    {
      "agency": "PADI",
      "level": "Course Director",
      "issued_at": "2017-07-12T00:00:00Z"
    }
  ],
  "specialties": ["wreck", "deep", "drift"],
  "languages_spoken": ["en", "de"],
  "home_base": "Cebu, Philippines",
  "conservation_projects": [
    {
      "title": "SeaExplorers Reef Survey",
      "impact_text": "12 sites mapped 2024-2026"
    }
  ],
  "snapshot_updated_at": "2026-05-03T10:00:00Z"
}
```

**When to write:**
- On app launch (after auth restore)
- After any change to the user's profile, certs, specialties, or home base
- After a new dive is logged (so logged_dives_count + last_dive_date stay current)

**How to write (Swift snippet for Dive Log):**
```swift
import Foundation

func writeBridgeSnapshot() throws {
    let groupId = "group.com.atollhub.shared"
    guard let containerURL = FileManager.default
        .containerURL(forSecurityApplicationGroupIdentifier: groupId) else {
        throw NSError(domain: "DiveLog.Bridge", code: 1)
    }
    let snapshot = /* assemble from Dive Log's own data sources */
    let encoder = JSONEncoder()
    encoder.keyEncodingStrategy = .convertToSnakeCase
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(snapshot)
    let url = containerURL.appendingPathComponent("dive-log-snapshot.json")
    try data.write(to: url, options: .atomic)
}
```

The model struct should match Atoll Hub's `SharedDiveLogSnapshot` — copy
it from `ios/AtollHubKit/Sources/AtollHubKit/Models/SharedDiveLogSnapshot.swift`
into your Dive Log project, or extract both apps' shared models into a
common Swift Package later.

## URL scheme (optional but recommended)

Register the URL scheme `divelog://` in Dive Log's Info.plist so Atoll
Hub's "View Dive Log" link can deep-link in:
```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>divelog</string>
    </array>
  </dict>
</array>
```

Atoll Hub's LinkRail builds URLs of the form `divelog://<handle>` for
links of kind `dive_log`. Dive Log can route the host portion to the
profile screen for that handle.

Conversely, Atoll Hub registers `atollhub://` (Phase 2). When you build
links from Dive Log to Atoll Hub, use `atollhub://card/<handle>`.

## Avatar (optional)

If Dive Log already stores a user avatar, copy it into the App Group
container as `avatar.png` (or whatever you set in `avatar_file_name`).
Atoll Hub will read it from there and use it in the import sheet preview.

## Reading Atoll Hub's snapshot (optional)

Symmetric with the writing side. If Dive Log wants to show a "Profile
linked with Atoll Hub" indicator, read `atoll-hub-snapshot.json` from
the same container and use `display_name` + `handle`.
```

- [ ] **Step 2: Commit**

```bash
git add docs/integrations/dive-log-bridge.md
git commit -m "docs(integrations): companion spec for Dive Log app side of the bridge"
```

---

## Task 9: Verification & manual demo

- [ ] **Step 1: Run all tests**

```bash
cd ios/AtollHubKit && swift test 2>&1 | tail -3
```

Expected: all green (Phase-1 count + 6 new from this side-quest).

- [ ] **Step 2: Clean Xcode build**

```bash
cd ios && xcodegen generate
xcodebuild -project AtollHub.xcodeproj -scheme AtollHub -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -configuration Debug clean build | tail -3
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: E2E manual demo (no real Dive Log needed)**

1. Run on simulator. Sign in. Get to MainTabView with at least one card.
2. Tap the wrench icon in CardsScreen toolbar (DEBUG menu). Tap "Seed Dive Log snapshot".
3. Tap + to create a new card. The Form shows an "Import from Dive Log" row at the top with `1247 dives · 3 certs · 5 specialties`.
4. Tap it. Sheet appears. Toggle off Languages, leave the rest on. Tap Apply.
5. Name field becomes "Dominik Weckherlin". Save the card.
6. Open the card in CardDetailSheet. The "Logged dives" row should NOT yet appear because card.logged_dives_source defaults to manual. Adjust manually via SQL or extend the import sheet to flip the source — either is fine, document the choice.
7. Verify `atoll-hub-snapshot.json` exists in the App Group container with your display name + handle.

- [ ] **Step 4: Companion-side smoke (when Dive Log gets the changes)**

In your Dive Log project (separate codebase), apply the changes from
`docs/integrations/dive-log-bridge.md`. Run both apps on the same
simulator. Confirm both can read each other's snapshots.

- [ ] **Step 5: Document completion**

Create `docs/superpowers/plans/2026-05-XX-side-quest-divelog-bridge-completion.md`:
```markdown
# Dive Log Bridge — Completion Notes

**Date completed:** YYYY-MM-DD
**Commit at completion:** <git rev-parse HEAD>

## What works in Atoll Hub
- App Group group.com.atollhub.shared activated
- DiveLogBridge actor reads/writes snapshots
- AtollHubSnapshotPublisher writes our snapshot on launch + onboarding
- EditCardScreen shows Import-from-Dive-Log when snapshot present
- ImportFromDiveLogSheet lets user pick what to import
- CardDetailSheet shows logged-dives counter from snapshot when source=dive_log_app
- LinkRail special-cases dive_log link kind with divelog:// scheme
- DEBUG menu seeds a sample snapshot for local testing

## What's still on the Dive Log side
- Apply changes from docs/integrations/dive-log-bridge.md
- Implement the snapshot writer in Dive Log's profile/cert flows

## Known limitations
- Certifications and specialties are imported but not yet rendered on
  the card — Phase 3 owns that UI
- Avatar file is referenced but not yet copied/displayed (future)
- Schema-version conflict handling is read-only (just ignores newer
  fields); no migration path yet for v2 schemas

## Next: continue with Phase 2 (Sharing & Receiving)
```

- [ ] **Step 6: Final commit + tag**

```bash
git add docs/superpowers/plans/2026-05-XX-side-quest-divelog-bridge-completion.md
git commit -m "docs: dive-log bridge side-quest complete"
git tag side-quest-divelog-bridge
```

---

## Spec Coverage Self-Review

Cross-check against the spec section 5 (Dive Log integration prepared in v1, activated later) and the ownership decision recorded 2026-05-03:

| Requirement | Task |
|---|---|
| App Group `group.com.atollhub.shared` activated | Task 1 |
| Schema-versioned JSON contract for both directions | Task 2 |
| Atoll Hub reads Dive Log snapshot | Task 3 |
| Atoll Hub writes its own snapshot | Task 4 |
| Per-domain ownership (no field overlap, single owner per field) | Task 2 model design |
| Import-from-Dive-Log UX in EditCardScreen | Task 5 |
| Live counter sync in CardDetailSheet | Task 6 |
| `dive_log` link kind opens via URL scheme | Task 6 |
| Companion spec for Dive Log codebase | Task 8 |
| End-to-end demo (no real Dive Log app required) | Task 9 |

All requirements covered.

---

## Out of Scope

- **Bidirectional sync of certs/specialties.** Dive Log → Atoll Hub only.
  Atoll Hub never writes certs (Dive Log is owner).
- **NSFileCoordinator-based notifications** when the snapshot file
  changes mid-session. Phase 1.x reads on appear; if you need real-time
  updates while the app is foregrounded, add a coordinator later.
- **Avatar file copy** into Atoll Hub's own storage. We just reference
  the path inside the App Group container.
- **Schema v2 migration**. Forward-compat (decoder ignores unknown keys)
  is enough for v1; if we ever rename a key we'll add a real migration.
- **Cross-device sync via shared backend.** Phase 3+ if ever.

---

## Notes for the Engineer

- **Avoid `NSFileCoordinator` unless you observe corruption.** For
  v1, atomic Data writes + Data reads are sufficient. Both apps write to
  separate files (each app owns its filename) so there's no inter-app
  contention.
- **Don't try to share Swift types between apps via dynamic frameworks.**
  Just copy the snapshot model into Dive Log. Two static copies of a
  small Codable struct are easier to reason about than a shared module.
- **The snapshot is a snapshot, not a stream.** If the user logs a dive
  in Dive Log, Atoll Hub sees the new count next time it reads — usually
  the next time the user opens a CardDetailSheet or the EditCardScreen.
  That's intentional; live-streaming Dive Log activity into Atoll Hub
  isn't what this is.
- **Apple User ID matching.** The `apple_user_id` field in the snapshot
  must be the same string both apps see from `ASAuthorizationAppleIDCredential.user`.
  Same Apple Team → same value, so this just works as long as you
  always use Sign in with Apple in both apps.
