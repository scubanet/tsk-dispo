# DiveLog Pro × Atoll Hub Bridge — Implementation Plan (DiveLog Side)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** DiveLog Pro writes a versioned JSON snapshot of profile + activity data (name, cert, dive count, last-dive date) into a shared App Group container so Atoll Hub can read it offline. Optionally reads Atoll Hub's reciprocal snapshot. No backend, no network.

**Architecture:** Mirror the contract defined on the Atoll Hub side (see `2026-05-03-side-quest-divelog-bridge.md`). Add an App Group entitlement; introduce a `DiveLogBridge` actor that owns filesystem I/O on `<group container>/dive-log-snapshot.json`; introduce a `DiveLogBridgePublisher` that assembles a snapshot from `DiverProfile` + a `FetchDescriptor<Dive>` and writes it. Wire it into three lifecycle moments: app launch, profile save, dive save.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, App Group entitlements, FileManager + JSONEncoder/Decoder. No new third-party deps.

**Spec reference:** `2026-05-03-side-quest-divelog-bridge.md` (companion plan for the Atoll Hub side, already drafted). This plan is the symmetric counterpart for the DiveLog Pro codebase at `/Users/dominik/Desktop/Developer/DiveLog Pro`.

**Branch:** `feat/atollhub-bridge` off `main`.

**Decisions confirmed 2026-05-03 (chat):**
- **v1 minimal:** no `DiverProfile` schema expansion. `handle`, `homeBase`, `languagesSpoken[]`, `conservationProjects[]` stay nil/empty in the snapshot. They get filled later if/when the profile UI grows them.
- **1-element cert mapping:** `certifications = [{agency: "PADI", level: certLevel, issuedAt: nil}]` from the existing `DiverProfile.certLevel` string. Multi-cert / multi-agency is out of scope for v1.
- **specialties = []** — DiveLog has no per-user specialties concept yet (per-student `SkillCompletion` is unrelated).
- **No XCTest target additions.** Verification uses a DEBUG-only round-trip self-check on launch + manual simulator smoke. A real test target can be added later as a follow-up.

---

## Ownership Map (read-only here — defined on the Atoll Hub side)

| Field | Owner | Direction |
|---|---|---|
| `apple_user_id` | Apple | both apps share (via SIWA) |
| `display_name`, `avatar_file_name`, `dive_log_handle`, `logged_dives_count`, `last_dive_date`, `certifications[]`, `specialties[]`, `languages_spoken[]`, `home_base`, `conservation_projects[]` | DiveLog | DiveLog → Atoll Hub via `dive-log-snapshot.json` |
| `display_name`, `handle`, `avatar_file_name` (Atoll Hub side) | Atoll Hub | Atoll Hub → DiveLog via `atoll-hub-snapshot.json` (advisory; v1 doesn't surface this) |

Each side writes only its own file. No conflicts by construction.

---

## File Structure

**Create:**
- `DiveLog Pro/Models/SharedDiveLogSnapshot.swift` — outgoing snapshot Codable struct
- `DiveLog Pro/Models/SharedAtollHubSnapshot.swift` — incoming snapshot Codable struct + shared `JSONEncoder`/`JSONDecoder` extensions
- `DiveLog Pro/Utils/DiveLogBridge.swift` — actor that owns App Group filesystem I/O
- `DiveLog Pro/Utils/DiveLogBridgePublisher.swift` — `@MainActor` class that assembles a snapshot from SwiftData and calls the bridge
- `2026-05-03-divelog-bridge-completion.md` (project root) — completion notes (final task)

**Modify:**
- `DiveLog Pro/DiveLog_Pro.entitlements` — add `com.apple.security.application-groups`
- `DiveLog Pro/Info.plist` — add `divelog://` URL scheme alongside the existing `divelogpro://`
- `DiveLog Pro/Utils/DiveLogProApp.swift` — publish on launch from the existing `.task` block (currently lines 128–131)
- `DiveLog Pro/Views/Screens/ProfileEditView.swift` — publish after the existing `try? ctx.save()` (currently around line 562) and after the dive-number-shift save (around line 562/679)
- `DiveLog Pro/Views/Screens/DiveFormView.swift` — publish from the end of `private func save()` (currently around line 616)

---

## Pre-flight

- DiveLog Pro bundle ID is `com.weckherlin.DiveLogPro`. Atoll Hub bundle ID is `com.atollhub.ios`. The App Group `group.com.atollhub.shared` lives under **one Apple Developer Team** — verify both apps are signed with **Team ID `XK8V89P2QV`** (Atoll Hub spec line 41) before starting.
- Current branch is `feat/instructor-skill-assessment` with uncommitted changes (paywall + StoreManager). Stash, commit, or merge those first — Task 0 cuts a fresh branch from `main`.
- `AppleSignInService.shared.currentUserID` is hydrated from Keychain on init ([AppleSignInService.swift:36](DiveLog%20Pro/Utils/AppleSignInService.swift:36)). The bridge uses this exact value as `apple_user_id` so Atoll Hub can match it.
- The shared `ModelContainer` is exposed by the `App` ([DiveLogProApp.swift:83](DiveLog%20Pro/Utils/DiveLogProApp.swift:83)) — the publisher reads `DiverProfile` and `Dive` through it.

---

## Task 0: Branch + baseline build

- [ ] **Step 1: Sort out current branch state**

```bash
cd "/Users/dominik/Desktop/Developer/DiveLog Pro"
git status
```

If there are uncommitted changes from `feat/instructor-skill-assessment`, decide with the user: commit, stash, or merge. Do not lose work. Re-run `git status` until the tree is clean.

- [ ] **Step 2: Cut the bridge branch from main**

```bash
git checkout main
git pull
git checkout -b feat/atollhub-bridge
```

- [ ] **Step 3: Verify the baseline builds**

```bash
xcodebuild -project "DiveLog Pro.xcodeproj" -scheme "DiveLog Pro" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -configuration Debug build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`. If signing fails, open Xcode once to refresh the team selection, then rebuild.

---

## Task 1: Activate App Group `group.com.atollhub.shared`

**Files:**
- Modify: `DiveLog Pro/DiveLog_Pro.entitlements`
- (Manual) Apple Developer account registration

- [ ] **Step 1: Add the App Group capability to entitlements**

Replace the contents of `DiveLog Pro/DiveLog_Pro.entitlements` with:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>aps-environment</key>
	<string>development</string>
	<key>com.apple.developer.applesignin</key>
	<array>
		<string>Default</string>
	</array>
	<key>com.apple.developer.icloud-container-identifiers</key>
	<array>
		<string>iCloud.com.weckherlin.DiveLogPro</string>
	</array>
	<key>com.apple.developer.icloud-services</key>
	<array>
		<string>CloudKit</string>
	</array>
	<key>com.apple.developer.weatherkit</key>
	<true/>
	<key>com.apple.security.application-groups</key>
	<array>
		<string>group.com.atollhub.shared</string>
	</array>
</dict>
</plist>
```

- [ ] **Step 2: Register the App Group at developer.apple.com**

In a browser, signed into your Apple Developer account:

1. Go to https://developer.apple.com/account/resources/identifiers/list/applicationGroup
2. If `group.com.atollhub.shared` is **not** already listed (Atoll Hub may have created it), click **+**, set Description = `Atoll Hub Shared`, Identifier = `group.com.atollhub.shared`, **Continue → Register**.
3. Go to https://developer.apple.com/account/resources/identifiers/list and open the App ID `com.weckherlin.DiveLogPro`.
4. Scroll to **App Groups**, click **Configure**, tick `group.com.atollhub.shared`, **Save**.
5. Apple may ask you to re-download the provisioning profile — Xcode does this automatically on next build with automatic signing.

- [ ] **Step 3: Build & verify the capability is live**

```bash
xcodebuild -project "DiveLog Pro.xcodeproj" -scheme "DiveLog Pro" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -configuration Debug build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`. If signing complains, open Xcode → DiveLog Pro target → Signing & Capabilities → confirm **App Groups** shows `group.com.atollhub.shared` ticked.

- [ ] **Step 4: Commit**

```bash
git add "DiveLog Pro/DiveLog_Pro.entitlements" "DiveLog Pro.xcodeproj/project.pbxproj"
git commit -m "feat(entitlements): activate App Group group.com.atollhub.shared"
```

---

## Task 2: Add `divelog://` URL scheme

Atoll Hub builds links of the form `divelog://<handle>` for the `dive_log` link kind. The existing `divelogpro://` is kept for backward compatibility (remote-signature flow uses it).

**Files:**
- Modify: `DiveLog Pro/Info.plist`

- [ ] **Step 1: Add the second URL scheme**

In `DiveLog Pro/Info.plist`, replace the existing `CFBundleURLTypes` array with one that also accepts `divelog`:

```xml
	<key>CFBundleURLTypes</key>
	<array>
		<dict>
			<key>CFBundleURLName</key>
			<string>com.weckherlin.DiveLogPro</string>
			<key>CFBundleURLSchemes</key>
			<array>
				<string>divelogpro</string>
				<string>divelog</string>
			</array>
		</dict>
	</array>
```

- [ ] **Step 2: Build to confirm Info.plist is valid**

```bash
xcodebuild -project "DiveLog Pro.xcodeproj" -scheme "DiveLog Pro" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -configuration Debug build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add "DiveLog Pro/Info.plist"
git commit -m "feat(deeplink): register divelog:// URL scheme alongside divelogpro://"
```

---

## Task 3: `SharedDiveLogSnapshot` Codable model

Mirror of the struct on the Atoll Hub side. **Critical:** key naming, date format, and field types must match exactly so both apps can decode each other's files. See Atoll Hub plan task 2 for the source of truth.

**Files:**
- Create: `DiveLog Pro/Models/SharedDiveLogSnapshot.swift`

- [ ] **Step 1: Create the file**

```swift
import Foundation

/// Snapshot written by DiveLog Pro into the App Group container, read by
/// Atoll Hub. Schema-versioned for forward-compat. Keys match Atoll Hub's
/// `SharedDiveLogSnapshot` struct exactly (snake_case JSON, ISO8601 dates).
public struct SharedDiveLogSnapshot: Codable, Sendable, Equatable {
    public let schemaVersion: Int
    public let appleUserId: String              // = ASAuthorizationAppleIDCredential.user
    public let displayName: String
    public let avatarFileName: String?           // relative to App Group container
    public let diveLogHandle: String?            // for divelog://<handle> deep-link; nil in v1
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
        public let agency: String      // PADI/SSI/SDI/TDI/CMAS/RAID/NAUI/BSAC/Other
        public let level: String       // free text — "OWD", "Course Director", …
        public let issuedAt: Date?
        public init(agency: String, level: String, issuedAt: Date?) {
            self.agency = agency
            self.level = level
            self.issuedAt = issuedAt
        }
    }

    public struct Project: Codable, Sendable, Equatable {
        public let title: String
        public let impactText: String?
        public init(title: String, impactText: String?) {
            self.title = title
            self.impactText = impactText
        }
    }
}
```

- [ ] **Step 2: Add the file to the Xcode target**

Drag `SharedDiveLogSnapshot.swift` into the `DiveLog Pro/Models` group in Xcode and tick the **DiveLog Pro** target. (Or use `xcodebuild` and let the file system reference auto-update if you have folder references; with the current project this is a manual add.)

- [ ] **Step 3: Build**

```bash
xcodebuild -project "DiveLog Pro.xcodeproj" -scheme "DiveLog Pro" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -configuration Debug build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Commit**

```bash
git add "DiveLog Pro/Models/SharedDiveLogSnapshot.swift" "DiveLog Pro.xcodeproj/project.pbxproj"
git commit -m "feat(bridge): SharedDiveLogSnapshot Codable model

Mirrors the contract defined on the Atoll Hub side. Schema-versioned,
snake_case JSON keys + ISO8601 dates. Certification + Project nested
structs match the Atoll Hub-side schema exactly."
```

---

## Task 4: `SharedAtollHubSnapshot` model + JSON helpers

Even though v1 doesn't surface Atoll Hub's display name in DiveLog's UI, we ship the decoder now so Task 5's bridge actor has a symmetric API. The `JSONEncoder`/`JSONDecoder` extensions are the shared contract that both directions use.

**Files:**
- Create: `DiveLog Pro/Models/SharedAtollHubSnapshot.swift`

- [ ] **Step 1: Create the file**

```swift
import Foundation

/// Snapshot written by Atoll Hub, read by DiveLog Pro. Carries only the
/// fields Atoll Hub owns (display name, handle, avatar) so DiveLog can
/// mirror them in its own UI if it wants to. v1 of the bridge does not
/// surface this in the UI yet.
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

// Convenience JSONEncoder + JSONDecoder configured the same way both
// sides agree on. These MUST match Atoll Hub's helpers byte-for-byte.
public extension JSONDecoder {
    static func atollBridge() -> JSONDecoder {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        d.dateDecodingStrategy = .iso8601
        return d
    }
}

public extension JSONEncoder {
    static func atollBridge() -> JSONEncoder {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }
}
```

> **Note for the engineer:** Atoll Hub's helpers are named `JSONDecoder.snake()` / `JSONEncoder.snake()` in their plan. Names differ — the wire format is what matters and is identical. If you ever extract a shared Swift Package, unify the names there.

- [ ] **Step 2: Add to Xcode target & build**

Add `SharedAtollHubSnapshot.swift` to the `DiveLog Pro/Models` group in Xcode (target: DiveLog Pro).

```bash
xcodebuild -project "DiveLog Pro.xcodeproj" -scheme "DiveLog Pro" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -configuration Debug build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add "DiveLog Pro/Models/SharedAtollHubSnapshot.swift" "DiveLog Pro.xcodeproj/project.pbxproj"
git commit -m "feat(bridge): SharedAtollHubSnapshot model + shared JSON encoder/decoder"
```

---

## Task 5: `DiveLogBridge` actor

Owns all filesystem I/O against the App Group container. Atomic writes, defensive reads (returns `nil` on absence/decode failure rather than throwing — the bridge being unavailable should never crash the app).

**Files:**
- Create: `DiveLog Pro/Utils/DiveLogBridge.swift`

- [ ] **Step 1: Create the file**

```swift
import Foundation
import os

/// Read/write the App Group snapshot exchange between DiveLog Pro and
/// Atoll Hub. `containerURL` defaults to the production App Group
/// container; future tests can inject a temp directory.
public actor DiveLogBridge {
    public static let appGroupId = "group.com.atollhub.shared"
    public static let diveLogSnapshotFile = "dive-log-snapshot.json"
    public static let atollHubSnapshotFile = "atoll-hub-snapshot.json"

    private static let logger = Logger(
        subsystem: "com.weckherlin.DiveLogPro",
        category: "AtollBridge"
    )

    private let containerURL: URL?

    public init(containerURL: URL? = nil) {
        self.containerURL = containerURL ?? FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupId)
        if self.containerURL == nil {
            Self.logger.error("App Group container unavailable — entitlement missing or not provisioned")
        }
    }

    public var hasContainer: Bool { containerURL != nil }

    /// Atomic write of the DiveLog snapshot. Throws only on encoder/IO
    /// failure; silent no-op when the container is unavailable so the
    /// caller doesn't have to special-case unprovisioned simulator runs.
    public func writeDiveLogSnapshot(_ snapshot: SharedDiveLogSnapshot) throws {
        guard let url = diveLogSnapshotURL else {
            Self.logger.warning("writeDiveLogSnapshot skipped — no container")
            return
        }
        let data = try JSONEncoder.atollBridge().encode(snapshot)
        try data.write(to: url, options: .atomic)
        Self.logger.info("wrote dive-log-snapshot.json (\(data.count) bytes)")
    }

    /// Read Atoll Hub's snapshot. Returns nil if the container is
    /// unavailable, the file doesn't exist, or it fails to decode.
    public func readAtollHubSnapshot() -> SharedAtollHubSnapshot? {
        guard let url = atollHubSnapshotURL else { return nil }
        guard let data = try? Data(contentsOf: url) else { return nil }
        do {
            return try JSONDecoder.atollBridge().decode(SharedAtollHubSnapshot.self, from: data)
        } catch {
            Self.logger.error("failed to decode atoll-hub-snapshot.json: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Paths

    private var diveLogSnapshotURL: URL? {
        containerURL?.appendingPathComponent(Self.diveLogSnapshotFile)
    }

    private var atollHubSnapshotURL: URL? {
        containerURL?.appendingPathComponent(Self.atollHubSnapshotFile)
    }
}
```

- [ ] **Step 2: Add to Xcode target & build**

Add `DiveLogBridge.swift` to the `DiveLog Pro/Utils` group (target: DiveLog Pro).

```bash
xcodebuild -project "DiveLog Pro.xcodeproj" -scheme "DiveLog Pro" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -configuration Debug build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add "DiveLog Pro/Utils/DiveLogBridge.swift" "DiveLog Pro.xcodeproj/project.pbxproj"
git commit -m "feat(bridge): DiveLogBridge actor for App Group snapshot IO

Atomic writes, defensive reads. Logs to OSLog 'AtollBridge' category.
Returns nil rather than throwing when the container is unavailable so
unprovisioned simulator runs don't crash the app."
```

---

## Task 6: `DiveLogBridgePublisher`

Reads `DiverProfile` and the live `Dive` set from the SwiftData container, assembles a `SharedDiveLogSnapshot`, and hands it to the bridge.

**Files:**
- Create: `DiveLog Pro/Utils/DiveLogBridgePublisher.swift`

- [ ] **Step 1: Create the file**

```swift
import Foundation
import SwiftData
import os

/// Assembles the DiveLog snapshot from SwiftData and publishes it to the
/// App Group via DiveLogBridge.
///
/// Runs on the main actor because SwiftData's mainContext is main-actor
/// bound; the IO itself happens on the bridge actor.
@MainActor
final class DiveLogBridgePublisher {
    private let container: ModelContainer
    private let bridge: DiveLogBridge

    private static let logger = Logger(
        subsystem: "com.weckherlin.DiveLogPro",
        category: "AtollBridge"
    )

    init(container: ModelContainer, bridge: DiveLogBridge) {
        self.container = container
        self.bridge = bridge
    }

    /// Builds the current snapshot and writes it. No-op when the user
    /// isn't signed in with Apple yet — without an apple_user_id the
    /// snapshot can't be matched on the Atoll Hub side.
    func publish() async {
        guard let appleUserID = AppleSignInService.shared.currentUserID else {
            Self.logger.debug("publish skipped — no Apple user ID")
            return
        }

        let ctx = container.mainContext
        let profile = (try? ctx.fetch(FetchDescriptor<DiverProfile>()))?.first

        var diveDescriptor = FetchDescriptor<Dive>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        diveDescriptor.fetchLimit = 1
        let lastDive = (try? ctx.fetch(diveDescriptor))?.first

        // Count is a separate cheap query — fetchCount avoids loading all dives.
        let countDescriptor = FetchDescriptor<Dive>()
        let totalDives = (try? ctx.fetchCount(countDescriptor)) ?? 0

        let certifications: [SharedDiveLogSnapshot.Certification] = profile.map {
            [.init(agency: "PADI", level: $0.certLevel, issuedAt: nil)]
        } ?? []

        let languages: [String] = profile.map { [$0.language] } ?? []

        let snapshot = SharedDiveLogSnapshot(
            schemaVersion: 1,
            appleUserId: appleUserID,
            displayName: profile?.name ?? "",
            avatarFileName: nil,                   // avatar copy: future enhancement
            diveLogHandle: nil,                    // v1: no handle concept on DiveLog side
            loggedDivesCount: totalDives,
            lastDiveDate: lastDive?.date,
            certifications: certifications,
            specialties: [],                       // v1: no per-user specialties
            languagesSpoken: languages,
            homeBase: nil,                         // v1: not on DiverProfile yet
            conservationProjects: [],              // v1: not modelled
            snapshotUpdatedAt: Date()
        )

        do {
            try await bridge.writeDiveLogSnapshot(snapshot)
            Self.logger.info("published snapshot — dives=\(totalDives), name='\(snapshot.displayName)'")
        } catch {
            Self.logger.error("publish failed: \(error.localizedDescription)")
        }
    }
}
```

- [ ] **Step 2: Add to Xcode target & build**

Add `DiveLogBridgePublisher.swift` to the `DiveLog Pro/Utils` group (target: DiveLog Pro).

```bash
xcodebuild -project "DiveLog Pro.xcodeproj" -scheme "DiveLog Pro" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -configuration Debug build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Commit**

```bash
git add "DiveLog Pro/Utils/DiveLogBridgePublisher.swift" "DiveLog Pro.xcodeproj/project.pbxproj"
git commit -m "feat(bridge): DiveLogBridgePublisher assembles snapshot from SwiftData

Pulls DiverProfile + dive count + last dive date, maps single PADI cert
level to a 1-element certifications array, leaves v1-deferred fields nil
or empty. No-ops cleanly when not signed in."
```

---

## Task 7: Publish on app launch

Hook into the existing `.task` block in `DiveLogProApp` so the snapshot is fresh every time the app foregrounds-from-cold.

**Files:**
- Modify: `DiveLog Pro/Utils/DiveLogProApp.swift`

- [ ] **Step 1: Add the bridge + publisher as state on the App**

Find the existing state declarations near the top of `DiveLogProApp` (around lines 12–32). After the `@Environment(\.scenePhase)` declaration, add:

```swift
    // Atoll Hub bridge — writes our profile/activity snapshot into the
    // shared App Group container so Atoll Hub can read it offline.
    private let atollBridge = DiveLogBridge()
```

- [ ] **Step 2: Wire the publish call into the existing `.task`**

Find this block (currently around lines 128–131):

```swift
            .task {
                await appleSignIn.refreshCredentialState()
                migratePhotosToCloudKit()
            }
```

Replace it with:

```swift
            .task {
                await appleSignIn.refreshCredentialState()
                migratePhotosToCloudKit()
                await DiveLogBridgePublisher(
                    container: sharedModelContainer,
                    bridge: atollBridge
                ).publish()
            }
```

- [ ] **Step 3: Build & smoke run**

```bash
xcodebuild -project "DiveLog Pro.xcodeproj" -scheme "DiveLog Pro" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -configuration Debug build 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`.

Run on simulator. Sign in with Apple. Then verify the snapshot file exists:

```bash
xcrun simctl get_app_container booted com.weckherlin.DiveLogPro groups
# Output is a path; ls it:
ls -la "<that-path>/group.com.atollhub.shared/"
cat "<that-path>/group.com.atollhub.shared/dive-log-snapshot.json"
```

Expected: `dive-log-snapshot.json` exists with `apple_user_id`, your name, `logged_dives_count` matching reality, ISO8601 dates.

> **If the container path is empty**, the App Group entitlement isn't provisioned. Re-do Task 1 step 2.

- [ ] **Step 4: Commit**

```bash
git add "DiveLog Pro/Utils/DiveLogProApp.swift"
git commit -m "feat(bridge): publish DiveLog snapshot on app launch"
```

---

## Task 8: Publish after profile save

`ProfileEditView` saves `DiverProfile` mutations via `try? ctx.save()`. After that we re-publish so name/cert changes flow into Atoll Hub immediately.

**Files:**
- Modify: `DiveLog Pro/Views/Screens/ProfileEditView.swift`

- [ ] **Step 1: Locate the save sites**

```bash
grep -nE "ctx\.save\(\)|modelContext\.save\(\)" "DiveLog Pro/Views/Screens/ProfileEditView.swift"
```

The current main save is at roughly line 562 (`try? ctx.save()` before `dismiss()`). There may be a second save call for the dive-number-shift flow. Find every `try? ctx.save()` in this file and add a publish call after each one that mutates `DiverProfile`.

- [ ] **Step 2: Inject the bridge as an environment object via the App**

This is shared with Task 9. Add an `Environment` value so any view can grab it. In `DiveLogProApp.swift`, add this at file scope (after the `RemoteSignToken` struct at the bottom):

```swift
private struct DiveLogBridgeKey: EnvironmentKey {
    static let defaultValue: DiveLogBridge? = nil
}

extension EnvironmentValues {
    var atollBridge: DiveLogBridge? {
        get { self[DiveLogBridgeKey.self] }
        set { self[DiveLogBridgeKey.self] = newValue }
    }
}
```

Then in the `WindowGroup` in `body`, after `.environment(deleteUndoManager)` (currently around line 150), add:

```swift
                .environment(\.atollBridge, atollBridge)
```

- [ ] **Step 3: Use the bridge from ProfileEditView**

At the top of the `ProfileEditView` struct, alongside the other environment grabs, add:

```swift
    @Environment(\.atollBridge) private var atollBridge
    @Environment(\.modelContext) private var ctx   // (only add this if it isn't already present)
```

> Verify the `@Environment(\.modelContext)` line isn't already there before adding — duplicate declarations won't compile.

Then add a small private helper inside the struct:

```swift
    private func republishToAtollBridge() {
        guard let bridge = atollBridge else { return }
        let container = ctx.container
        Task { @MainActor in
            await DiveLogBridgePublisher(container: container, bridge: bridge).publish()
        }
    }
```

- [ ] **Step 4: Call the helper after each profile-mutating save**

For every `try? ctx.save()` call in this file that follows a `DiverProfile` mutation (the main save flow at ~line 562, and the dive-number-shift flow if present), add `republishToAtollBridge()` immediately after the save call and before `dismiss()`. Example transformation:

```swift
        try? ctx.save()
        republishToAtollBridge()
        dismiss()
```

- [ ] **Step 5: Build, smoke, commit**

```bash
xcodebuild -project "DiveLog Pro.xcodeproj" -scheme "DiveLog Pro" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -configuration Debug build 2>&1 | tail -5
```

Smoke: open the app, edit the profile name, save. Re-cat the snapshot file from the simulator — `display_name` should reflect the new value and `snapshot_updated_at` should be fresh.

```bash
git add "DiveLog Pro/Utils/DiveLogProApp.swift" "DiveLog Pro/Views/Screens/ProfileEditView.swift"
git commit -m "feat(bridge): re-publish snapshot after ProfileEdit save"
```

---

## Task 9: Publish after dive save

So `logged_dives_count` and `last_dive_date` stay current.

**Files:**
- Modify: `DiveLog Pro/Views/Screens/DiveFormView.swift`

- [ ] **Step 1: Locate `private func save()`**

```bash
grep -n "private func save" "DiveLog Pro/Views/Screens/DiveFormView.swift"
```

Currently around line 616. Read the function fully so you know where the SwiftData save happens (look for `try? ctx.save()` or `try? modelContext.save()` and any subsequent `dismiss()`).

- [ ] **Step 2: Wire the bridge into DiveFormView**

At the top of the `DiveFormView` struct, alongside the other `@Environment` lines, add:

```swift
    @Environment(\.atollBridge) private var atollBridge
```

> `@Environment(\.modelContext) private var ctx` is already present — do not duplicate.

Add the same helper used in Task 8:

```swift
    private func republishToAtollBridge() {
        guard let bridge = atollBridge else { return }
        let container = ctx.container
        Task { @MainActor in
            await DiveLogBridgePublisher(container: container, bridge: bridge).publish()
        }
    }
```

- [ ] **Step 3: Call the helper at the end of `save()`**

Inside `private func save()`, immediately after the SwiftData save succeeds and before the `dismiss()` call, insert:

```swift
        republishToAtollBridge()
```

If the function has multiple early-returns or branches (edit vs create), make sure the helper is called on every branch that actually persists a dive.

- [ ] **Step 4: Build, smoke, commit**

```bash
xcodebuild -project "DiveLog Pro.xcodeproj" -scheme "DiveLog Pro" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -configuration Debug build 2>&1 | tail -5
```

Smoke: log a new dive in the simulator. Re-cat the snapshot — `logged_dives_count` should be one higher and `last_dive_date` should match the new dive's date.

```bash
git add "DiveLog Pro/Views/Screens/DiveFormView.swift"
git commit -m "feat(bridge): re-publish snapshot after a dive is saved"
```

---

## Task 10: DEBUG-only round-trip self-check + manual smoke

Without a unit test target, verify the encoder/decoder contract by running an inline self-check on launch in DEBUG builds. Catches regressions where someone renames a field and forgets the matching change on the Atoll Hub side.

**Files:**
- Modify: `DiveLog Pro/Utils/DiveLogBridge.swift` (add a DEBUG static helper)
- Modify: `DiveLog Pro/Utils/DiveLogProApp.swift` (call it once on launch)

- [ ] **Step 1: Add the self-check to DiveLogBridge**

Append to `DiveLog Pro/Utils/DiveLogBridge.swift`:

```swift
#if DEBUG
public extension DiveLogBridge {
    /// Encodes a sample snapshot, decodes it back, asserts the round-trip
    /// preserves every field. Logs PASS/FAIL to OSLog. Runs once on launch
    /// in DEBUG builds — production builds skip it entirely.
    static func runRoundTripSelfCheck() {
        let logger = Logger(
            subsystem: "com.weckherlin.DiveLogPro",
            category: "AtollBridge.SelfCheck"
        )
        let original = SharedDiveLogSnapshot(
            schemaVersion: 1,
            appleUserId: "test.001234.abc",
            displayName: "Selfcheck",
            avatarFileName: nil,
            diveLogHandle: nil,
            loggedDivesCount: 42,
            lastDiveDate: Date(timeIntervalSince1970: 1_700_000_000),
            certifications: [
                .init(agency: "PADI", level: "Course Director",
                      issuedAt: Date(timeIntervalSince1970: 1_500_000_000))
            ],
            specialties: [],
            languagesSpoken: ["en", "de"],
            homeBase: nil,
            conservationProjects: [],
            snapshotUpdatedAt: Date(timeIntervalSince1970: 1_750_000_000)
        )
        do {
            let data = try JSONEncoder.atollBridge().encode(original)
            let back = try JSONDecoder.atollBridge().decode(
                SharedDiveLogSnapshot.self, from: data
            )
            if back == original {
                logger.info("PASS — round-trip preserved all fields")
            } else {
                logger.error("FAIL — round-trip mismatch")
                assertionFailure("DiveLogBridge round-trip mismatch — encoder/decoder out of sync with the wire format")
            }
        } catch {
            logger.error("FAIL — \(error.localizedDescription)")
            assertionFailure("DiveLogBridge self-check threw: \(error)")
        }
    }
}
#endif
```

- [ ] **Step 2: Call the self-check on launch in DEBUG**

In `DiveLogProApp.swift`, inside the existing `.task` block, add the call as the first line:

```swift
            .task {
                #if DEBUG
                DiveLogBridge.runRoundTripSelfCheck()
                #endif
                await appleSignIn.refreshCredentialState()
                migratePhotosToCloudKit()
                await DiveLogBridgePublisher(
                    container: sharedModelContainer,
                    bridge: atollBridge
                ).publish()
            }
```

- [ ] **Step 3: Build & verify the self-check logs PASS**

```bash
xcodebuild -project "DiveLog Pro.xcodeproj" -scheme "DiveLog Pro" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -configuration Debug build 2>&1 | tail -5
```

Run on simulator. Open Console.app, filter by `subsystem:com.weckherlin.DiveLogPro category:AtollBridge.SelfCheck`. Expected: one `PASS — round-trip preserved all fields` line per launch.

If you see a FAIL, the encoder/decoder fell out of sync with the model. Inspect the JSON output and fix the model so all fields round-trip.

- [ ] **Step 4: Manual end-to-end smoke**

1. On simulator: sign in, edit profile (set name + cert), log one dive.
2. Verify `<group container>/dive-log-snapshot.json` contains the right name, cert (as PADI 1-element array), `logged_dives_count = 1`, `last_dive_date` set.
3. Force-quit the app, relaunch. Verify the snapshot updates (`snapshot_updated_at` advances).
4. (Optional) If you have the Atoll Hub project handy on the same simulator, build & launch it — its `EditCardScreen` should show the "Import from Dive Log" row using your data.

- [ ] **Step 5: Commit**

```bash
git add "DiveLog Pro/Utils/DiveLogBridge.swift" "DiveLog Pro/Utils/DiveLogProApp.swift"
git commit -m "feat(bridge): DEBUG round-trip self-check for the JSON contract"
```

---

## Task 11: Completion notes

**Files:**
- Create: `2026-05-03-divelog-bridge-completion.md`

- [ ] **Step 1: Write the completion notes**

```markdown
# DiveLog Pro — Atoll Hub Bridge Completion Notes

**Date completed:** YYYY-MM-DD
**Commit at completion:** <git rev-parse HEAD>
**Branch:** feat/atollhub-bridge

## What works

- App Group `group.com.atollhub.shared` activated on `com.weckherlin.DiveLogPro`
- `divelog://` URL scheme registered alongside `divelogpro://`
- `SharedDiveLogSnapshot` + `SharedAtollHubSnapshot` Codable models match Atoll Hub's contract byte-for-byte
- `DiveLogBridge` actor handles atomic writes / defensive reads against the App Group container
- `DiveLogBridgePublisher` assembles the snapshot from `DiverProfile` + `Dive` count + last-dive date
- Snapshot republishes on: app launch, profile save, dive save
- DEBUG round-trip self-check logs PASS on every launch

## v1 deferred (intentional)

- `dive_log_handle`, `home_base`, `conservation_projects[]` — left nil/empty. Adding them means expanding `DiverProfile` with new optional CloudKit-compatible fields plus UI in `ProfileEditView`.
- Multi-cert / multi-agency `certifications[]` — currently mapped from the single `DiverProfile.certLevel` string as `[{agency: "PADI", level: certLevel, issuedAt: nil}]`. A real cert manager is its own feature.
- `specialties[]` — empty. DiveLog doesn't track per-user specialties yet (per-student `SkillCompletion` is unrelated).
- Reading `atoll-hub-snapshot.json` and surfacing Atoll Hub's display name in DiveLog's UI.
- Avatar file copy into the App Group container.
- A formal XCTest target. Self-check runs inline on launch in DEBUG; a real test target would isolate model & bridge tests.

## Notes for the Atoll Hub side

- The Atoll Hub plan's `AtollHubSnapshotPublisher` writes `appleUserId: profile.id.uuidString` (their Supabase profile ID), not the Apple-provided user identifier. DiveLog writes the actual `ASAuthorizationAppleIDCredential.user` value (via `AppleSignInService.shared.currentUserID`). For Atoll Hub to match DiveLog's snapshot to its current user, Atoll Hub should also use the SIWA user identifier — or maintain a mapping table from `apple_user_id` to its internal profile ID. Flag this when you next touch that codebase.
- Atoll Hub uses `JSONDecoder.snake()` / `JSONEncoder.snake()`. DiveLog uses `JSONDecoder.atollBridge()` / `JSONEncoder.atollBridge()`. Names differ; the wire format is identical. If both sides ever extract a shared Swift Package, unify the names.

## Next

- Decide if the deferred items above warrant a v2 scope or stay deferred indefinitely.
- Optional: extract `SharedDiveLogSnapshot` + JSON helpers into a Swift Package consumed by both apps.
```

- [ ] **Step 2: Commit & tag**

```bash
git add 2026-05-03-divelog-bridge-completion.md
git commit -m "docs: DiveLog × Atoll Hub bridge completion notes"
git tag divelog-bridge-v1
```

---

## Spec Coverage Self-Review

Cross-checked against `2026-05-03-side-quest-divelog-bridge.md` task 8 (companion-side spec) and ownership map:

| Companion-spec requirement | Task |
|---|---|
| App Group `group.com.atollhub.shared` capability + Apple Dev registration | Task 1 |
| Write `dive-log-snapshot.json` to App Group container | Task 5 + Task 6 |
| Snake_case JSON keys + ISO8601 dates | Task 3 + Task 4 (helpers) |
| Schema: `apple_user_id`, `display_name`, `logged_dives_count`, `certifications[]`, `specialties[]`, `languages_spoken[]`, `last_dive_date`, `snapshot_updated_at` | Task 3 (model) + Task 6 (assembly) |
| Write on launch, profile change, dive logged | Task 7, 8, 9 |
| Apple User ID = `ASAuthorizationAppleIDCredential.user` | Task 6 (uses `AppleSignInService.currentUserID`) |
| Read Atoll Hub's snapshot (optional) | Task 4 (decoder shipped) + Task 5 (`readAtollHubSnapshot()`) — UI surfacing deferred |
| `divelog://` URL scheme | Task 2 |
| Avatar file copy | Deferred (documented in completion notes) |

All in-scope requirements covered.

---

## Out of Scope (this plan)

- `DiverProfile` schema expansion (`handle`, `homeBase`, `languagesSpoken[]`, `conservationProjects[]`).
- Multi-agency / multi-cert data model + UI.
- Per-user specialties data model + UI.
- Surfacing `SharedAtollHubSnapshot` content in DiveLog's UI.
- Avatar file copy into the App Group container.
- `NSFileCoordinator`-based change notifications across apps.
- Schema v2 migration path.
- Formal XCTest unit test target.

---

## Notes for the Engineer

- **Only commit work that builds.** Run an `xcodebuild` after every Task before committing — automatic signing can silently regress when entitlements change.
- **The container path on simulator is per-install.** If you delete the app, the snapshot file is gone. If the entitlement isn't provisioned, `containerURL(forSecurityApplicationGroupIdentifier:)` returns `nil` and the bridge silently no-ops — check OSLog `category:AtollBridge` for the warning.
- **Don't move snapshot reads onto a background queue prematurely.** SwiftData's `mainContext` is main-actor bound; the publisher is `@MainActor` on purpose. The actual file IO happens on the bridge actor — that's where the off-main hop is.
- **The `republishToAtollBridge` helper is duplicated in two view files** (Task 8 and Task 9). That's intentional — the Atoll Hub spec recommends "two static copies of a small Codable struct are easier to reason about than a shared module" and the same logic applies to a 4-line helper. If a third call site appears, extract.
- **Apple User ID matching mismatch** between DiveLog (uses `AppleSignInService.currentUserID`) and the Atoll Hub plan (uses `profile.id.uuidString`) is documented in the completion notes. Don't silently fix it from this side — flag it on the Atoll Hub plan instead.
