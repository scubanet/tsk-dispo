# FIT Direct Import (Phase B) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal.** User shares a `.fit` file from a Garmin Descent MK3i (or any FIT-producing dive computer); the app parses it directly using Garmin's official Swift FIT SDK, converts to the same internal `UDDFFile` struct that Phase A produces, and reuses Phase A's mapper + UI to land dives in the logbook. Subsurface as a bridge becomes optional.

**Architecture.** Four layers; Layer 2/3/4 are reused from Phase A untouched. Only Layer 1 (decode) + Layer 1.5 (FIT→UDDF mapping) are new.

```
.fit (binary) ─► Garmin Swift FIT SDK ─► [Mesg]  ─► FITToUDDFMapper ─► UDDFFile ─► UDDFDiveMapper ─► [Dive]
                  (Layer 1, SPM dep)      (raw)    (Layer 1.5, ~200 LoC)  (Phase A)  (Phase A)
```

**Deviation from spec.** The spec proposed vendoring **FitDataProtocol** (third-party, last updated 2020, no dive-message support). After re-checking sources, Garmin publishes an **official Swift SDK** at `https://github.com/garmin/fit-swift-sdk.git`, available via SwiftPM and listed on [developer.garmin.com/fit/get-the-sdk/](https://developer.garmin.com/fit/get-the-sdk/). It is maintained by Garmin, ships with the full FIT Profile (including all dive messages: Session sub-sport 53 = `single_gas_diving` through 57 = `apnea_diving`, plus `dive_summary`, `dive_gas`, `dive_settings`, `dive_alarm`, `tank_summary`, `tank_update`), and supports both encoding and decoding. **We use the official SDK.** No fork, no in-house decoder, no third-party-library maintenance risk.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, SwiftPM (`github.com/garmin/fit-swift-sdk`), Swift Testing framework (`@Suite`, `@Test`, `#expect`).

**Branch:** continues `feat/divecomputer-import` from Phase A HEAD `b6b261c`. Plan A is **not** merged to `main` yet — both UDDF and FIT ship together when Plan B completes.

**Test fixtures already in repo:** `DiveLog ProTests/Fixtures/fit/` contains the 7 raw FIT files (8753…8763) that produced Phase A's `test.uddf`. They are the golden-comparison input — for the same physical dive, our FIT-parsed values must match the Subsurface-produced UDDF values to within rounding tolerance.

---

## API Discovery Task (run before Task 3)

The Garmin Swift SDK's exact public API surface (type names, decoder entry point, message accessor pattern) is not documented in this plan because it was published after the spec was written. **Before writing the mapper tests, the engineer must spend ≤30 min spelunking the SDK to find:**

1. The decoder entry point — likely `FITDecoder().decode(from: Data)` or `Decode().read(URL)` (mirrors the Java/C# SDK pattern: a `Decode` class with a `read` method).
2. The Mesg type — likely a polymorphic `Mesg` class or per-type structs like `SessionMesg`, `RecordMesg`, `DiveSummaryMesg`, `DiveGasMesg`, `TankSummaryMesg`. Garmin's other SDKs use the latter.
3. How field access works — likely typed accessors (`.maxDepth`, `.startTime`) or generic `.getField(num:)`.
4. The exact Swift module name (likely `FitSDK` or `FIT`).

This task is captured below as Task 2 ("API smoke test"). All later tasks reference SDK types via placeholders (`SessionMesg`, `RecordMesg`, etc.) that the engineer replaces with the actual names discovered in Task 2. If a placeholder name differs from the real name, search-and-replace before each later task.

---

## File Structure

**New production files:**
```
DiveLog Pro/Utils/FIT/
  FITToUDDFMapper.swift   # Layer 1.5: [SDK Mesg] → UDDFFile
```
(That's it. Garmin's SDK is the entire FIT parser. No in-house decoder.)

**New test files:**
```
DiveLog ProTests/
  FITSDKSmokeTests.swift          # Task 2 — proves the SDK decodes our fixtures
  FITToUDDFMapperTests.swift      # Tasks 3-8
```

**Modified files:**
```
DiveLog Pro/Utils/UDDF/UDDFImportCoordinator.swift  # dispatcher by extension
DiveLog Pro/Views/Screens/UDDFImportSheet.swift     # rename → DiveComputerImportSheet
DiveLog Pro/Views/Tabs/ProfileTab.swift             # .fileImporter accepts .fit too
DiveLog Pro/Utils/DiveLogProApp.swift               # .onOpenURL handles .fit too
DiveLog Pro/Info.plist                              # CFBundleDocumentTypes adds com.garmin.fit
DiveLog Pro.xcodeproj/...                           # SPM dep added (one-time Xcode UI step)
```

---

## Task 1: Add Garmin Swift FIT SDK via SwiftPM

**Files:**
- Modify: `DiveLog Pro.xcodeproj/project.pbxproj` (via Xcode UI — the only way to add an SPM package cleanly)

- [ ] **Step 1: Add the package in Xcode**

Open the project in Xcode. File → Add Package Dependencies… → enter URL:

```
https://github.com/garmin/fit-swift-sdk.git
```

Branch / version: pick "Up to Next Major Version" with the latest release tag Xcode discovers. Add to target **DiveLog Pro** (production code) — *not* to DiveLog ProTests (the test target imports `DiveLog_Pro` transitively).

- [ ] **Step 2: Verify the package resolves and builds**

Run:
```bash
xcodebuild -resolvePackageDependencies -project "DiveLog Pro.xcodeproj" -scheme "DiveLog Pro" 2>&1 | tail -20
```
Expected: a line like `Resolved source packages: fit-swift-sdk @ <version>`.

Then:
```bash
xcodebuild build -project "DiveLog Pro.xcodeproj" -scheme "DiveLog Pro" -destination 'generic/platform=iOS' 2>&1 | tail -20
```
Expected: BUILD SUCCEEDED. The Garmin module shows up in the build log but isn't imported anywhere yet — that comes in Task 2.

- [ ] **Step 3: Commit**

```bash
git add "DiveLog Pro.xcodeproj/project.pbxproj" "DiveLog Pro.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
git commit -m "deps(fit): add Garmin Swift FIT SDK via SwiftPM"
```

---

## Task 2: SDK smoke test — discover API, verify decoding works

**Files:**
- Create: `DiveLog ProTests/FITSDKSmokeTests.swift`

This task is intentionally **exploratory**. Its purpose is twofold: prove the SDK works end-to-end on our fixtures, **and** record the exact API surface in code so subsequent tasks can use real type names.

- [ ] **Step 1: Read the SDK's public surface**

In Xcode, open the resolved `fit-swift-sdk` package (left navigator → Package Dependencies → fit-swift-sdk → Sources). Note:

- The module name to `import` (probably `FitSDK`).
- The decoder entry point (probably `Decode` class with `read(_:)` method, or `FITDecoder` with `decode(_:)`).
- The Mesg base type, and concrete subclasses for our use case (`SessionMesg`, `RecordMesg`, `DiveSummaryMesg`, `DiveGasMesg`, `TankSummaryMesg`, `FileIdMesg`, `DeviceInfoMesg`).
- Field accessor pattern (typed getters like `.maxDepth`, or generic `.getField(globalNumber:)`).

Record findings as a header comment in the test file so future readers see it without re-discovering. If any expected type is *missing* from the SDK, **stop and report to the user** — we'll need a different approach.

- [ ] **Step 2: Write the smoke test (using real SDK names from Step 1)**

Replace `<MODULE>` and `<DECODER>` below with the actual names you discovered. The structure is independent of those names.

```swift
// DiveLog ProTests/FITSDKSmokeTests.swift
//
// API surface (recorded 2026-05-XX):
//   Module:    <MODULE>             (replace after Task 2/Step 1)
//   Decoder:   <DECODER>            (e.g. FITDecoder().decode(_:Data))
//   Mesg type: <Mesg base type>     (e.g. Mesg, FitMessage)
//   Diving subtypes: <list>         (e.g. SessionMesg, RecordMesg, DiveSummaryMesg)
//
import Testing
import Foundation
import <MODULE>
@testable import DiveLog_Pro

@Suite("FIT SDK smoke")
struct FITSDKSmokeTests {

    private func loadFixture(_ name: String) throws -> Data {
        let url = Bundle(for: BundleSentinel.self)
            .url(forResource: name, withExtension: "fit", subdirectory: "Fixtures/fit")!
        return try Data(contentsOf: url)
    }

    @Test func decodes_smallest_fixture_withoutThrowing() throws {
        let data = try loadFixture("8762 Singlegas-Tauchgang")
        // Replace with the actual SDK call discovered in Step 1:
        let messages = try <DECODER>.decode(data)
        #expect(messages.count > 0)
    }

    @Test func decodes_contains_session_mesg() throws {
        let data = try loadFixture("8762 Singlegas-Tauchgang")
        let messages = try <DECODER>.decode(data)
        // Replace SessionMesg with the SDK's actual type. If type-filtering
        // uses casting instead of an enum, adjust accordingly.
        let sessions = messages.compactMap { $0 as? SessionMesg }
        #expect(sessions.count >= 1)
    }

    @Test func decodes_contains_dive_summary() throws {
        let data = try loadFixture("8757 Mamutic Island")
        let messages = try <DECODER>.decode(data)
        let summaries = messages.compactMap { $0 as? DiveSummaryMesg }
        #expect(summaries.count >= 1, "expected at least one DiveSummary in a dive fixture")
    }

    @Test func decodes_all_seven_fixtures() throws {
        for name in ["8753 IDC 126", "8754 IDC 126",
                     "8756 Mamutic Island", "8757 Mamutic Island",
                     "8758 OWD Dry Tg1", "8762 Singlegas-Tauchgang",
                     "8763 OWD Dry Tg2"] {
            let data = try loadFixture(name)
            let messages = try <DECODER>.decode(data)
            #expect(messages.count > 0, "fixture \(name) produced 0 messages")
        }
    }

    @Test func sessionMesg_exposes_diving_fields() throws {
        let data = try loadFixture("8757 Mamutic Island")
        let messages = try <DECODER>.decode(data)
        let session = messages.compactMap { $0 as? SessionMesg }.first!
        // Validate the diving fields are accessible. Replace property names
        // if the SDK uses different naming (e.g. .max_depth → .maxDepth).
        #expect(session.maxDepth != nil)         // Float, meters
        #expect(session.startTime != nil)        // Date or FITDate
        #expect(session.totalElapsedTime != nil) // TimeInterval
    }
}

private final class BundleSentinel {}
```

- [ ] **Step 3: Run the smoke tests**

Run:
```bash
xcodebuild test \
  -project "DiveLog Pro.xcodeproj" \
  -scheme "DiveLog Pro" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  -only-testing:"DiveLog ProTests/FITSDKSmokeTests" 2>&1 | tail -40
```
Expected: 5 tests pass.

If a test fails because a property name or type name doesn't exist: **update the test to match the SDK's actual API**, *don't* invent fields. The SDK's source under Package Dependencies → fit-swift-sdk is the source of truth.

- [ ] **Step 4: Commit**

```bash
git add "DiveLog ProTests/FITSDKSmokeTests.swift"
git commit -m "test(fit): SDK smoke tests — verify decoding + record API surface"
```

---

## Task 3: FITToUDDFMapper — skeleton + generator

**Files:**
- Create: `DiveLog Pro/Utils/FIT/FITToUDDFMapper.swift`
- Create: `DiveLog ProTests/FITToUDDFMapperTests.swift`

From here on, all tasks assume the type names settled in Task 2. The placeholders `<MODULE>`, `SessionMesg`, `RecordMesg`, etc. should be the **real** names. Search-and-replace before pasting code blocks.

- [ ] **Step 1: Write the failing tests**

```swift
// DiveLog ProTests/FITToUDDFMapperTests.swift
import Testing
import Foundation
import <MODULE>
@testable import DiveLog_Pro

@Suite("FITToUDDFMapper — generator")
struct FITToUDDFMapperGeneratorTests {

    private func decode(_ name: String) throws -> [<MesgBase>] {
        let url = Bundle(for: BundleSentinel.self)
            .url(forResource: name, withExtension: "fit", subdirectory: "Fixtures/fit")!
        let data = try Data(contentsOf: url)
        return try <DECODER>.decode(data)
    }

    @Test func generator_isGarmin() throws {
        let messages = try decode("8762 Singlegas-Tauchgang")
        let file = FITToUDDFMapper.makeUDDFFile(from: messages)
        #expect(file.generator.lowercased().contains("garmin"))
    }

    @Test func generator_isNonEmpty_forAllFixtures() throws {
        for name in ["8753 IDC 126", "8757 Mamutic Island", "8762 Singlegas-Tauchgang"] {
            let messages = try decode(name)
            let file = FITToUDDFMapper.makeUDDFFile(from: messages)
            #expect(!file.generator.isEmpty, "fixture \(name) had empty generator")
        }
    }
}

private final class BundleSentinel {}
```

- [ ] **Step 2: Verify failing**

Run: `xcodebuild test … -only-testing:"DiveLog ProTests/FITToUDDFMapperGeneratorTests"`
Expected: FAIL — `FITToUDDFMapper` undefined.

- [ ] **Step 3: Implement skeleton + generator**

```swift
// DiveLog Pro/Utils/FIT/FITToUDDFMapper.swift
import Foundation
import <MODULE>

/// Layer 1.5: collapses a flat list of FIT-SDK Mesgs into the same
/// UDDFFile structure that Phase A's UDDFParser produces. Everything
/// downstream (UDDFDiveMapper, UDDFImportSheet) treats them identically.
enum FITToUDDFMapper {

    static func makeUDDFFile(from messages: [<MesgBase>]) -> UDDFFile {
        let generator = extractGenerator(messages)
        let gasDefs   = extractGasDefinitions(messages)
        let sites     = extractDiveSites(messages)
        let dives     = extractDives(messages, gasDefs: gasDefs, siteId: sites.keys.first)
        return UDDFFile(
            generator: generator,
            gasDefinitions: gasDefs,
            diveSites: sites,
            dives: dives)
    }

    // MARK: - Generator

    /// Prefer device-info productName (e.g. "Descent Mk3i"); fall back
    /// to file-id manufacturer code; final fallback "FIT".
    static func extractGenerator(_ messages: [<MesgBase>]) -> String {
        if let di = messages.compactMap({ $0 as? DeviceInfoMesg }).first,
           let name = di.productName, !name.isEmpty {
            return "Garmin \(name)"
        }
        if let fid = messages.compactMap({ $0 as? FileIdMesg }).first,
           let mfr = fid.manufacturer {
            // Manufacturer constant 1 = Garmin in the FIT Profile.
            return mfr == .garmin ? "Garmin" : "Manufacturer \(mfr)"
        }
        return "FIT"
    }

    // MARK: - Stubs filled by Tasks 4-8
    static func extractGasDefinitions(_ messages: [<MesgBase>]) -> [String: UDDFGas] { [:] }
    static func extractDiveSites(_ messages: [<MesgBase>]) -> [String: UDDFSite] { [:] }
    static func extractDives(_ messages: [<MesgBase>],
                             gasDefs: [String: UDDFGas],
                             siteId: String?) -> [UDDFDive] { [] }
}
```

> **Note on API mismatch.** If the SDK uses optional-getters with a different signature (e.g. `getProductName() -> String?` instead of a property, or an enum that doesn't have `.garmin` as a case), adjust the body to match. The intent — prefer DeviceInfo's productName, fall back to FileId's manufacturer — stays the same regardless of the spelling.

- [ ] **Step 4: Run tests, verify pass**

Run: same as Step 2.
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add "DiveLog Pro/Utils/FIT/FITToUDDFMapper.swift" "DiveLog ProTests/FITToUDDFMapperTests.swift"
git commit -m "feat(fit): FITToUDDFMapper skeleton + generator extraction"
```

---

## Task 4: FITToUDDFMapper — gas definitions

**Files:**
- Modify: `DiveLog Pro/Utils/FIT/FITToUDDFMapper.swift` (extractGasDefinitions stub)
- Modify: `DiveLog ProTests/FITToUDDFMapperTests.swift` (append suite)

- [ ] **Step 1: Add failing tests**

```swift
// Append to FITToUDDFMapperTests.swift:

@Suite("FITToUDDFMapper — gases")
struct FITToUDDFMapperGasTests {

    private func decode(_ name: String) throws -> [<MesgBase>] {
        let url = Bundle(for: BundleSentinel.self)
            .url(forResource: name, withExtension: "fit", subdirectory: "Fixtures/fit")!
        return try <DECODER>.decode(Data(contentsOf: url))
    }

    @Test func singleGasDive_hasOneAirGas() throws {
        let messages = try decode("8762 Singlegas-Tauchgang")
        let file = FITToUDDFMapper.makeUDDFFile(from: messages)
        #expect(file.gasDefinitions.count >= 1)
        let firstGas = file.gasDefinitions.values.first!
        #expect(firstGas.o2 >= 0.19 && firstGas.o2 <= 0.23)
        #expect(firstGas.he == 0)
    }

    @Test func gasIds_areStableAndUnique() throws {
        let messages = try decode("8757 Mamutic Island")
        let file = FITToUDDFMapper.makeUDDFFile(from: messages)
        #expect(Set(file.gasDefinitions.keys).count == file.gasDefinitions.count)
    }
}
```

- [ ] **Step 2: Verify failing**

Run: `xcodebuild test … -only-testing:"DiveLog ProTests/FITToUDDFMapperGasTests"`
Expected: FAIL — gasDefinitions empty.

- [ ] **Step 3: Replace stub**

```swift
// In FITToUDDFMapper.swift, replace extractGasDefinitions(_:):

/// Build UDDFGas entries from `DiveGasMesg`. FIT carries O2/He as integer
/// percents; we convert to fractions and classify the name string.
static func extractGasDefinitions(_ messages: [<MesgBase>]) -> [String: UDDFGas] {
    var result: [String: UDDFGas] = [:]
    let gasMsgs = messages.compactMap { $0 as? DiveGasMesg }

    for (i, msg) in gasMsgs.enumerated() {
        // Field-name placeholders: the SDK may expose these as
        // `.oxygenContent` (Int? in percent) or as `getOxygenContent()`.
        let o2Percent = Double(msg.oxygenContent ?? 21)
        let hePercent = Double(msg.heliumContent ?? 0)
        let id = "fit-gas-\(i)"
        let o2 = o2Percent / 100.0
        let he = hePercent / 100.0

        let name: String
        if he > 0.001 {
            name = "trimix"
        } else if o2 < 0.22 {
            name = "air"
        } else {
            name = "ean\(Int(o2Percent.rounded()))"
        }

        result[id] = UDDFGas(id: id, name: name, o2: o2, he: he)
    }

    if result.isEmpty {
        // Synthetic default — keeps the downstream pipeline simple when
        // a FIT file shipped without DiveGas messages.
        result["fit-gas-default"] = UDDFGas(
            id: "fit-gas-default", name: "air", o2: 0.21, he: 0)
    }
    return result
}
```

- [ ] **Step 4: Run tests, verify pass**

Run: same as Step 2.
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add "DiveLog Pro/Utils/FIT/FITToUDDFMapper.swift" "DiveLog ProTests/FITToUDDFMapperTests.swift"
git commit -m "feat(fit): gas extraction — DiveGasMesg → UDDFGas with name classification"
```

---

## Task 5: FITToUDDFMapper — dive sites (GPS)

**Files:**
- Modify: `DiveLog Pro/Utils/FIT/FITToUDDFMapper.swift` (extractDiveSites stub)
- Modify: `DiveLog ProTests/FITToUDDFMapperTests.swift`

- [ ] **Step 1: Add failing tests**

```swift
// Append to FITToUDDFMapperTests.swift:

@Suite("FITToUDDFMapper — sites")
struct FITToUDDFMapperSiteTests {

    private func decode(_ name: String) throws -> [<MesgBase>] {
        let url = Bundle(for: BundleSentinel.self)
            .url(forResource: name, withExtension: "fit", subdirectory: "Fixtures/fit")!
        return try <DECODER>.decode(Data(contentsOf: url))
    }

    @Test func mamuticIsland_hasPhilippinesGPS() throws {
        let messages = try decode("8757 Mamutic Island")
        let file = FITToUDDFMapper.makeUDDFFile(from: messages)
        guard let site = file.diveSites.values.first else {
            Issue.record("no dive site extracted"); return
        }
        guard let lat = site.latitude, let lon = site.longitude else {
            Issue.record("site missing lat/lon"); return
        }
        #expect(lat > 5 && lat < 15, "lat \(lat) not in PH range")
        #expect(lon > 120 && lon < 130, "lon \(lon) not in PH range")
    }

    @Test func dryPoolDive_noGPS() throws {
        let messages = try decode("8763 OWD Dry Tg2")
        let file = FITToUDDFMapper.makeUDDFFile(from: messages)
        for site in file.diveSites.values {
            if site.latitude != nil || site.longitude != nil {
                Issue.record("dry pool dive should not have GPS")
            }
        }
    }
}
```

- [ ] **Step 2: Verify failing**

Run: `xcodebuild test … -only-testing:"DiveLog ProTests/FITToUDDFMapperSiteTests"`
Expected: FAIL.

- [ ] **Step 3: Replace stub**

The Garmin Swift SDK most likely already converts semicircles → degrees when you read `.startPositionLat` / `.startPositionLong` as `Double?`. Verify in Task 2's exploration — if the SDK returns raw `Int32` semicircles, multiply by `180 / 2^31` ourselves. Otherwise just read the value.

```swift
// In FITToUDDFMapper.swift, replace extractDiveSites(_:):

/// Build dive-site entries from SessionMesg's start_position fields.
/// The SDK exposes these as Double? in decimal degrees (it handles
/// the semicircles→degrees conversion internally — see Task-2 notes).
/// One site per session is the norm.
static func extractDiveSites(_ messages: [<MesgBase>]) -> [String: UDDFSite] {
    var result: [String: UDDFSite] = [:]
    let sessions = messages.compactMap { $0 as? SessionMesg }

    for (i, session) in sessions.enumerated() {
        guard let lat = session.startPositionLat,
              let lon = session.startPositionLong,
              lat.isFinite, lon.isFinite,
              lat != 0 || lon != 0 else { continue }
        let id = "fit-site-\(i)"
        result[id] = UDDFSite(
            id: id,
            name: "",   // FIT has no site-name; user can edit post-import
            latitude: lat,
            longitude: lon)
    }
    return result
}
```

> **If the SDK returns Int32 semicircles**, change the body to:
> ```swift
> guard let rawLat = session.startPositionLat,
>       let rawLon = session.startPositionLong,
>       rawLat != Int32.max, rawLon != Int32.max else { continue }
> let lat = Double(rawLat) * 180.0 / 2147483648.0
> let lon = Double(rawLon) * 180.0 / 2147483648.0
> ```

- [ ] **Step 4: Run tests, verify pass**

Run: same as Step 2.
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add "DiveLog Pro/Utils/FIT/FITToUDDFMapper.swift" "DiveLog ProTests/FITToUDDFMapperTests.swift"
git commit -m "feat(fit): dive-site extraction from SessionMesg start-position"
```

---

## Task 6: FITToUDDFMapper — dive header (Session + DiveSummary)

**Files:**
- Modify: `DiveLog Pro/Utils/FIT/FITToUDDFMapper.swift`
- Modify: `DiveLog ProTests/FITToUDDFMapperTests.swift`

- [ ] **Step 1: Add failing tests**

```swift
// Append to FITToUDDFMapperTests.swift:

@Suite("FITToUDDFMapper — dive header")
struct FITToUDDFMapperDiveHeaderTests {

    private func decode(_ name: String) throws -> [<MesgBase>] {
        let url = Bundle(for: BundleSentinel.self)
            .url(forResource: name, withExtension: "fit", subdirectory: "Fixtures/fit")!
        return try <DECODER>.decode(Data(contentsOf: url))
    }

    @Test func produces_exactlyOneDive_perFITFile() throws {
        for name in ["8753 IDC 126", "8762 Singlegas-Tauchgang", "8757 Mamutic Island"] {
            let messages = try decode(name)
            let file = FITToUDDFMapper.makeUDDFFile(from: messages)
            #expect(file.dives.count == 1, "expected 1 dive in \(name), got \(file.dives.count)")
        }
    }

    @Test func dive_datetime_isReasonable() throws {
        let messages = try decode("8757 Mamutic Island")
        let file = FITToUDDFMapper.makeUDDFFile(from: messages)
        let dive = file.dives.first!
        let lower = Date(timeIntervalSince1970: 1_704_067_200)  // 2024-01-01
        let upper = Date(timeIntervalSince1970: 1_780_617_600)  // 2026-06-04
        #expect(dive.datetime > lower)
        #expect(dive.datetime < upper)
    }

    @Test func dive_maxDepth_isPositive_andRecreational() throws {
        let messages = try decode("8757 Mamutic Island")
        let file = FITToUDDFMapper.makeUDDFFile(from: messages)
        let dive = file.dives.first!
        #expect(dive.maxDepthMeters > 0)
        #expect(dive.maxDepthMeters < 100)
    }

    @Test func dive_duration_isPositive() throws {
        let messages = try decode("8762 Singlegas-Tauchgang")
        let file = FITToUDDFMapper.makeUDDFFile(from: messages)
        let dive = file.dives.first!
        #expect(dive.durationSeconds > 0)
        #expect(dive.durationSeconds < 7200)
    }
}
```

- [ ] **Step 2: Verify failing**

Run: `xcodebuild test … -only-testing:"DiveLog ProTests/FITToUDDFMapperDiveHeaderTests"`
Expected: FAIL — `dives` empty.

- [ ] **Step 3: Replace stub**

```swift
// In FITToUDDFMapper.swift, replace extractDives(_:gasDefs:siteId:):

/// Build UDDFDive structs from SessionMesg + DiveSummaryMesg pairs.
/// Samples are filled by Task 7; tank pressures by Task 8.
static func extractDives(_ messages: [<MesgBase>],
                         gasDefs: [String: UDDFGas],
                         siteId: String?) -> [UDDFDive] {
    let sessions = messages.compactMap { $0 as? SessionMesg }
    let summaries = messages.compactMap { $0 as? DiveSummaryMesg }
    let firstGasId = gasDefs.keys.sorted().first

    return sessions.enumerated().map { i, session in
        let startTime: Date = session.startTime ?? session.timestamp ?? Date()

        // The SDK typically returns totalElapsedTime as TimeInterval (already
        // descaled by the SDK from the underlying uint32×1000). If it returns
        // raw seconds instead, this still works because TimeInterval=Double.
        let durationSec = Int((session.totalElapsedTime ?? 0).rounded())

        // Prefer DiveSummary's maxDepth (post-processed); fall back to Session.
        let maxDepth: Double = {
            if let s = summaries.first, let d = s.maxDepth { return Double(d) }
            if let d = session.maxDepth { return Double(d) }
            return 0
        }()

        let avgDepth: Double = {
            if let s = summaries.first, let d = s.avgDepth { return Double(d) }
            if let d = session.avgDepth { return Double(d) }
            return 0
        }()

        return UDDFDive(
            datetime: startTime,
            siteRef: siteId,
            gasRef: firstGasId,
            leadKg: nil,
            tankVolumeLiters: nil,
            maxDepthMeters: maxDepth,
            avgDepthMeters: avgDepth,
            durationSeconds: durationSec,
            notes: nil,
            samples: buildSamples(for: session, in: messages),  // filled by Task 7
            tankStartBar: extractTankStart(messages),           // filled by Task 8
            tankEndBar: extractTankEnd(messages))               // filled by Task 8
    }
}

// MARK: - Stubs filled by Tasks 7-8
private static func buildSamples(for session: SessionMesg, in messages: [<MesgBase>]) -> [UDDFSample] { [] }
private static func extractTankStart(_ messages: [<MesgBase>]) -> Int? { nil }
private static func extractTankEnd(_ messages: [<MesgBase>]) -> Int? { nil }
```

- [ ] **Step 4: Run tests, verify pass**

Run: same as Step 2.
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add "DiveLog Pro/Utils/FIT/FITToUDDFMapper.swift" "DiveLog ProTests/FITToUDDFMapperTests.swift"
git commit -m "feat(fit): dive header — datetime/duration/maxDepth/avgDepth from Session+DiveSummary"
```

---

## Task 7: FITToUDDFMapper — depth-profile samples

**Files:**
- Modify: `DiveLog Pro/Utils/FIT/FITToUDDFMapper.swift`
- Modify: `DiveLog ProTests/FITToUDDFMapperTests.swift`

- [ ] **Step 1: Add failing tests**

```swift
// Append to FITToUDDFMapperTests.swift:

@Suite("FITToUDDFMapper — samples")
struct FITToUDDFMapperSampleTests {

    private func decode(_ name: String) throws -> [<MesgBase>] {
        let url = Bundle(for: BundleSentinel.self)
            .url(forResource: name, withExtension: "fit", subdirectory: "Fixtures/fit")!
        return try <DECODER>.decode(Data(contentsOf: url))
    }

    @Test func samples_areNotEmpty() throws {
        let messages = try decode("8762 Singlegas-Tauchgang")
        let file = FITToUDDFMapper.makeUDDFFile(from: messages)
        let dive = file.dives.first!
        #expect(dive.samples.count > 100)
    }

    @Test func sample_timeSeconds_isMonotonic() throws {
        let messages = try decode("8762 Singlegas-Tauchgang")
        let file = FITToUDDFMapper.makeUDDFFile(from: messages)
        let times = file.dives.first!.samples.map(\.timeSeconds)
        for i in 1..<times.count {
            #expect(times[i] >= times[i - 1])
        }
    }

    @Test func sample_atTime0_shallow() throws {
        let messages = try decode("8762 Singlegas-Tauchgang")
        let file = FITToUDDFMapper.makeUDDFFile(from: messages)
        for d in file.dives.first!.samples.prefix(5).map(\.depthMeters) {
            #expect(d < 5)
        }
    }

    @Test func sample_temperatures_tropical() throws {
        let messages = try decode("8757 Mamutic Island")
        let file = FITToUDDFMapper.makeUDDFFile(from: messages)
        for t in file.dives.first!.samples.compactMap(\.temperatureCelsius) {
            #expect(t > 15 && t < 35)
        }
    }
}
```

- [ ] **Step 2: Verify failing**

Run: `xcodebuild test … -only-testing:"DiveLog ProTests/FITToUDDFMapperSampleTests"`
Expected: FAIL — samples empty.

- [ ] **Step 3: Replace the buildSamples stub**

```swift
// Replace the stub at the bottom of FITToUDDFMapper.swift:

/// Walk RecordMesg messages chronologically (FIT files are already
/// chronologically ordered by spec; we re-sort defensively). Sample-time
/// is computed relative to the session's startTime.
private static func buildSamples(for session: SessionMesg, in messages: [<MesgBase>]) -> [UDDFSample] {
    guard let start = session.startTime else { return [] }

    let records = messages
        .compactMap { $0 as? RecordMesg }
        .compactMap { rec -> (Date, RecordMesg)? in
            guard let ts = rec.timestamp, ts >= start else { return nil }
            return (ts, rec)
        }
        .sorted { $0.0 < $1.0 }

    return records.map { (ts, rec) in
        UDDFSample(
            depthMeters: Double(rec.depth ?? 0),
            timeSeconds: Int(ts.timeIntervalSince(start)),
            // Temperature in RecordMesg is Int8 (°C) per the FIT spec;
            // the SDK should expose it as Int? or Float?. Either casts to Double.
            temperatureCelsius: rec.temperature.map { Double($0) },
            gasSwitchRef: nil)
    }
}
```

- [ ] **Step 4: Run tests, verify pass**

Run: same as Step 2.
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add "DiveLog Pro/Utils/FIT/FITToUDDFMapper.swift" "DiveLog ProTests/FITToUDDFMapperTests.swift"
git commit -m "feat(fit): depth-profile samples from RecordMesg — monotonic timing, °C-aware"
```

---

## Task 8: FITToUDDFMapper — tank start/end pressures (FIT-only)

**Files:**
- Modify: `DiveLog Pro/Utils/FIT/FITToUDDFMapper.swift`
- Modify: `DiveLog ProTests/FITToUDDFMapperTests.swift`

This is the field that justifies the entire FIT-direct effort: Garmin MK3i records tank pressure via AirIntegration; Subsurface drops it on UDDF round-trip.

- [ ] **Step 1: Add failing tests**

```swift
// Append to FITToUDDFMapperTests.swift:

@Suite("FITToUDDFMapper — tank pressures")
struct FITToUDDFMapperTankTests {

    private func decode(_ name: String) throws -> [<MesgBase>] {
        let url = Bundle(for: BundleSentinel.self)
            .url(forResource: name, withExtension: "fit", subdirectory: "Fixtures/fit")!
        return try <DECODER>.decode(Data(contentsOf: url))
    }

    @Test func tankPressures_realistic_whenAvailable() throws {
        for name in ["8753 IDC 126", "8757 Mamutic Island", "8762 Singlegas-Tauchgang"] {
            let messages = try decode(name)
            let file = FITToUDDFMapper.makeUDDFFile(from: messages)
            let dive = file.dives.first!

            if let s = dive.tankStartBar, let e = dive.tankEndBar {
                #expect(s > 0 && s <= 300, "fixture \(name) start \(s) bar implausible")
                #expect(e > 0 && e <= 300, "fixture \(name) end \(e) bar implausible")
                #expect(s >= e, "start (\(s)) must be ≥ end (\(e)) for \(name)")
            }
        }
    }

    @Test func atLeastOneFixture_hasTankData() throws {
        var anyPopulated = false
        for name in ["8753 IDC 126", "8754 IDC 126", "8756 Mamutic Island",
                     "8757 Mamutic Island", "8758 OWD Dry Tg1",
                     "8762 Singlegas-Tauchgang", "8763 OWD Dry Tg2"] {
            let messages = try decode(name)
            let file = FITToUDDFMapper.makeUDDFFile(from: messages)
            if file.dives.first?.tankStartBar != nil { anyPopulated = true; break }
        }
        #expect(anyPopulated, "no fixture carried AirIntegration TankSummary data")
    }
}
```

- [ ] **Step 2: Verify failing**

Run: `xcodebuild test … -only-testing:"DiveLog ProTests/FITToUDDFMapperTankTests"`
Expected: FAIL — tankStartBar always nil.

- [ ] **Step 3: Replace the stubs**

```swift
// Replace the two stubs at the bottom of FITToUDDFMapper.swift:

/// Tank start pressure from the first TankSummaryMesg. The SDK should
/// return pressures as Float? in bar (descaled from FIT's uint16×100).
private static func extractTankStart(_ messages: [<MesgBase>]) -> Int? {
    guard let ts = messages.compactMap({ $0 as? TankSummaryMesg }).first,
          let bar = ts.startPressure else { return nil }
    return Int(Double(bar).rounded())
}

private static func extractTankEnd(_ messages: [<MesgBase>]) -> Int? {
    guard let ts = messages.compactMap({ $0 as? TankSummaryMesg }).first,
          let bar = ts.endPressure else { return nil }
    return Int(Double(bar).rounded())
}
```

- [ ] **Step 4: Run tests, verify pass**

Run: same as Step 2.
Expected: PASS for `tankPressures_realistic_whenAvailable`. The `atLeastOneFixture_hasTankData` test depends on whether the MK3i firmware that produced our fixtures actually emits TankSummary. If it fails, **don't fudge the test**: comment it out with `// TODO Phase-B follow-up — confirm MK3i emits TankSummary for AirIntegration; verify against fresh recording` and note it in the smoke-test doc (Task 11).

- [ ] **Step 5: Commit**

```bash
git add "DiveLog Pro/Utils/FIT/FITToUDDFMapper.swift" "DiveLog ProTests/FITToUDDFMapperTests.swift"
git commit -m "feat(fit): tank start/end pressure from TankSummaryMesg (bar) — FIT-only payload"
```

---

## Task 9: Golden-soll cross-check against test.uddf

**Files:**
- Modify: `DiveLog ProTests/FITToUDDFMapperTests.swift`

Confidence test: the same physical dive recorded as both `.fit` and (via Subsurface) `.uddf`. Both pipelines must agree on date, depth, duration within rounding.

- [ ] **Step 1: Write the golden test**

```swift
// Append to FITToUDDFMapperTests.swift:

@Suite("FITToUDDFMapper — golden soll vs test.uddf")
struct FITToUDDFMapperGoldenTests {

    private func decodeFIT(_ name: String) throws -> [<MesgBase>] {
        let url = Bundle(for: BundleSentinel.self)
            .url(forResource: name, withExtension: "fit", subdirectory: "Fixtures/fit")!
        return try <DECODER>.decode(Data(contentsOf: url))
    }

    private func loadUDDF() throws -> UDDFFile {
        let url = Bundle(for: BundleSentinel.self)
            .url(forResource: "test", withExtension: "uddf", subdirectory: "Fixtures/uddf")!
        return try UDDFParser().parse(url: url)
    }

    /// Match by date proximity (±10 min — Subsurface/Garmin round differently).
    private func findCounterpart(of fitDate: Date, in uddf: UDDFFile) -> UDDFDive? {
        uddf.dives.first { abs($0.datetime.timeIntervalSince(fitDate)) < 600 }
    }

    @Test func fixture_8757_matches_UDDF_within_tolerances() throws {
        let fitMessages = try decodeFIT("8757 Mamutic Island")
        let fitFile = FITToUDDFMapper.makeUDDFFile(from: fitMessages)
        let fitDive = fitFile.dives.first!

        let uddfFile = try loadUDDF()
        guard let uddfDive = findCounterpart(of: fitDive.datetime, in: uddfFile) else {
            Issue.record("no UDDF dive matched FIT 8757 within 10 min")
            return
        }

        let dateDelta = abs(fitDive.datetime.timeIntervalSince(uddfDive.datetime))
        #expect(dateDelta < 600, "date delta \(dateDelta)s > 10 min")

        let depthDelta = abs(fitDive.maxDepthMeters - uddfDive.maxDepthMeters)
        #expect(depthDelta < 0.5, "maxDepth FIT=\(fitDive.maxDepthMeters) UDDF=\(uddfDive.maxDepthMeters) Δ=\(depthDelta)")

        let durDelta = abs(fitDive.durationSeconds - uddfDive.durationSeconds)
        #expect(durDelta < 60, "duration delta \(durDelta)s > 60s")
    }

    @Test func allMatchableFixtures_passGolden() throws {
        let uddf = try loadUDDF()
        var matched = 0
        for name in ["8753 IDC 126", "8754 IDC 126", "8756 Mamutic Island",
                     "8757 Mamutic Island", "8758 OWD Dry Tg1",
                     "8762 Singlegas-Tauchgang", "8763 OWD Dry Tg2"] {
            let fitMsgs = try decodeFIT(name)
            let fitFile = FITToUDDFMapper.makeUDDFFile(from: fitMsgs)
            guard let fitDive = fitFile.dives.first,
                  let uddfDive = findCounterpart(of: fitDive.datetime, in: uddf) else {
                continue
            }
            if abs(fitDive.maxDepthMeters - uddfDive.maxDepthMeters) < 0.5
                && abs(fitDive.durationSeconds - uddfDive.durationSeconds) < 60 {
                matched += 1
            }
        }
        #expect(matched >= 3, "only \(matched)/7 FIT fixtures matched UDDF within tolerance")
    }
}
```

- [ ] **Step 2: Run the golden tests**

Run: `xcodebuild test … -only-testing:"DiveLog ProTests/FITToUDDFMapperGoldenTests"`
Expected: PASS. If a fixture fails on `depthDelta` or `durDelta`: log the actual values, check which side is wrong (FIT or UDDF), and fix the source. Don't loosen the tolerance.

- [ ] **Step 3: Commit**

```bash
git add "DiveLog ProTests/FITToUDDFMapperTests.swift"
git commit -m "test(fit): golden-soll cross-check FIT pipeline vs UDDF baseline"
```

---

## Task 10: ImportCoordinator dispatcher by file extension

**Files:**
- Modify: `DiveLog Pro/Utils/UDDF/UDDFImportCoordinator.swift`
- Create: `DiveLog ProTests/DiveComputerImportDispatchTests.swift`

- [ ] **Step 1: Write the failing test**

```swift
// DiveLog ProTests/DiveComputerImportDispatchTests.swift
import Testing
import Foundation
@testable import DiveLog_Pro

@Suite("ImportCoordinator dispatch")
struct DiveComputerImportDispatchTests {

    @Test @MainActor
    func dispatch_uddf_yieldsCandidates() async throws {
        let url = Bundle(for: BundleSentinel.self)
            .url(forResource: "test", withExtension: "uddf", subdirectory: "Fixtures/uddf")!
        let (file, candidates) = try await UDDFImportCoordinator.prepareImport(
            from: url, existingDives: [])
        #expect(file.dives.count == 7)
        #expect(candidates.count == 7)
    }

    @Test @MainActor
    func dispatch_fit_yieldsCandidates() async throws {
        let url = Bundle(for: BundleSentinel.self)
            .url(forResource: "8762 Singlegas-Tauchgang", withExtension: "fit", subdirectory: "Fixtures/fit")!
        let (file, candidates) = try await UDDFImportCoordinator.prepareImport(
            from: url, existingDives: [])
        #expect(file.dives.count == 1)
        #expect(candidates.count == 1)
        #expect(file.generator.lowercased().contains("garmin"))
    }

    @Test @MainActor
    func dispatch_unknownExtension_throws() async {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("garbage.xyz")
        try? "<garbage>".write(to: url, atomically: true, encoding: .utf8)
        await #expect(throws: Error.self) {
            try await UDDFImportCoordinator.prepareImport(from: url, existingDives: [])
        }
    }
}

private final class BundleSentinel {}
```

- [ ] **Step 2: Verify failing**

Run: `xcodebuild test … -only-testing:"DiveLog ProTests/DiveComputerImportDispatchTests"`
Expected: FAIL — the FIT-path test fails because `prepareImport` always treats input as UDDF.

- [ ] **Step 3: Update prepareImport**

```swift
// In DiveLog Pro/Utils/UDDF/UDDFImportCoordinator.swift, replace the body of prepareImport:

@MainActor
static func prepareImport(from url: URL, existingDives: [Dive]) async throws -> (UDDFFile, [ImportCandidate]) {
    let ext = url.pathExtension.lowercased()
    let file: UDDFFile

    switch ext {
    case "uddf", "xml":
        file = try await Task.detached(priority: .userInitiated) {
            try UDDFParser().parse(url: url)
        }.value
    case "fit":
        file = try await Task.detached(priority: .userInitiated) { () throws -> UDDFFile in
            // SecurityScoped — required when URL comes from .fileImporter
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: url)
            let messages = try <DECODER>.decode(data)
            return FITToUDDFMapper.makeUDDFFile(from: messages)
        }.value
    default:
        throw UDDFParseError.fileUnreadable
    }

    let candidates: [ImportCandidate] = file.dives.map { uddf in
        let dive = UDDFDiveMapper.makeDive(from: uddf, in: file)
        let conflict = findConflict(for: dive, in: existingDives)
        return ImportCandidate(dive: dive,
                               conflictWith: conflict,
                               selected: conflict == nil)
    }
    return (file, candidates)
}
```

> The `import <MODULE>` line at the top of `UDDFImportCoordinator.swift` brings the Garmin SDK into scope.

- [ ] **Step 4: Run tests, verify pass**

Run: same as Step 2.
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add "DiveLog Pro/Utils/UDDF/UDDFImportCoordinator.swift" "DiveLog ProTests/DiveComputerImportDispatchTests.swift"
git commit -m "feat(import): coordinator dispatches by extension — .uddf, .xml, .fit"
```

---

## Task 11: Rename UDDFImportSheet → DiveComputerImportSheet + format-neutral copy

**Files:**
- Rename + modify: `DiveLog Pro/Views/Screens/UDDFImportSheet.swift` → `DiveComputerImportSheet.swift`
- Modify: `DiveLog Pro/Utils/DiveLogProApp.swift` (3 references: `@State`, `.onOpenURL`, `.sheet`)
- Modify: `DiveLog Pro/Views/Tabs/ProfileTab.swift` (`.sheet` reference)

- [ ] **Step 1: Rename via git**

```bash
git mv "DiveLog Pro/Views/Screens/UDDFImportSheet.swift" \
       "DiveLog Pro/Views/Screens/DiveComputerImportSheet.swift"
```

Then in Xcode: drag the renamed file into the right group if Xcode doesn't pick up the rename automatically.

- [ ] **Step 2: Update struct + format-aware copy**

In the renamed file:

```swift
// 1) Rename the struct:
struct DiveComputerImportSheet: View {

// 2) navigationTitle becomes format-neutral:
.navigationTitle(L10n.currentLanguage == "de" ? "Import" : "Import")
.navigationBarTitleDisplayMode(.inline)

// 3) Add a private helper at the bottom of the struct:
/// Human-readable name of the source format, derived from the file's extension.
private var formatName: String {
    fileURL.pathExtension.lowercased() == "fit" ? "FIT" : "UDDF"
}

// 4) Update the loading state body:
if loading {
    VStack(spacing: DSSpacing.l) {
        ProgressView()
        Text(L10n.currentLanguage == "de"
             ? "\(formatName)-Datei wird gelesen…"
             : "Reading \(formatName) file…")
            .foregroundStyle(.secondary)
    }
}
```

- [ ] **Step 3: Update DiveLogProApp.swift**

In `DiveLog Pro/Utils/DiveLogProApp.swift`:

```swift
// Rename the @State on line 28:
//   @State private var pendingUDDFURL: URL?
// becomes:
@State private var pendingImportURL: URL?

// Update .onOpenURL (around line 155):
.onOpenURL { url in
    if let token = RemoteSignatureService.token(fromURL: url) {
        remoteSignToken = token
    } else if url.isFileURL {
        let ext = url.pathExtension.lowercased()
        if ext == "uddf" || ext == "fit" {
            pendingImportURL = url
        }
    }
}

// Update the second .sheet(item:):
.sheet(item: Binding(
    get: { pendingImportURL.map { IdentifiableURL(url: $0) } },
    set: { pendingImportURL = $0?.url }
)) { wrapper in
    DiveComputerImportSheet(fileURL: wrapper.url) { _, _ in
        pendingImportURL = nil
    }
}
```

- [ ] **Step 4: Update ProfileTab.swift**

Search for `UDDFImportSheet` in ProfileTab.swift and replace with `DiveComputerImportSheet` (single reference inside the second `.sheet(item:)`).

- [ ] **Step 5: Build & verify no stragglers**

Run:
```bash
xcodebuild build -project "DiveLog Pro.xcodeproj" -scheme "DiveLog Pro" -destination 'generic/platform=iOS' 2>&1 | tail -20
```
Expected: BUILD SUCCEEDED. If failures, grep for `UDDFImportSheet` and `pendingUDDFURL` and fix.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "refactor(import): UDDFImportSheet → DiveComputerImportSheet (format-neutral copy + state)"
```

---

## Task 12: Info.plist — register .fit + extend .fileImporter

**Files:**
- Modify: `DiveLog Pro/Info.plist`
- Modify: `DiveLog Pro/Views/Tabs/ProfileTab.swift`

- [ ] **Step 1: Extend Info.plist**

Edit `DiveLog Pro/Info.plist`. Append a `<dict>` to `CFBundleDocumentTypes` for FIT, and append a UTI declaration to `UTImportedTypeDeclarations`:

```xml
<key>CFBundleDocumentTypes</key>
<array>
    <!-- existing UDDF entry stays -->
    <dict>
        <key>CFBundleTypeName</key>
        <string>Universal Dive Data Format</string>
        <key>CFBundleTypeRole</key>
        <string>Viewer</string>
        <key>LSHandlerRank</key>
        <string>Alternate</string>
        <key>LSItemContentTypes</key>
        <array>
            <string>org.streit.uddf</string>
        </array>
    </dict>
    <!-- new FIT entry -->
    <dict>
        <key>CFBundleTypeName</key>
        <string>Garmin FIT Activity</string>
        <key>CFBundleTypeRole</key>
        <string>Viewer</string>
        <key>LSHandlerRank</key>
        <string>Alternate</string>
        <key>LSItemContentTypes</key>
        <array>
            <string>com.garmin.fit</string>
        </array>
    </dict>
</array>
<key>UTImportedTypeDeclarations</key>
<array>
    <!-- existing UDDF declaration stays -->
    <dict>
        <key>UTTypeIdentifier</key>
        <string>org.streit.uddf</string>
        <key>UTTypeDescription</key>
        <string>Universal Dive Data Format</string>
        <key>UTTypeConformsTo</key>
        <array><string>public.xml</string></array>
        <key>UTTypeTagSpecification</key>
        <dict>
            <key>public.filename-extension</key>
            <array><string>uddf</string></array>
            <key>public.mime-type</key>
            <array><string>application/vnd.uddf+xml</string></array>
        </dict>
    </dict>
    <!-- new FIT declaration -->
    <dict>
        <key>UTTypeIdentifier</key>
        <string>com.garmin.fit</string>
        <key>UTTypeDescription</key>
        <string>Garmin FIT Activity</string>
        <key>UTTypeConformsTo</key>
        <array><string>public.data</string></array>
        <key>UTTypeTagSpecification</key>
        <dict>
            <key>public.filename-extension</key>
            <array><string>fit</string></array>
            <key>public.mime-type</key>
            <array><string>application/vnd.ant.fit</string></array>
        </dict>
    </dict>
</array>
```

- [ ] **Step 2: Update ProfileTab .fileImporter**

Find the existing `.fileImporter` in ProfileTab.swift (added in Phase A) — its `allowedContentTypes` is `[.xml]`. Replace with:

```swift
.fileImporter(
    isPresented: $showingUDDFPicker,
    allowedContentTypes: [
        .xml,                                       // UDDF inherits from XML
        UTType(filenameExtension: "uddf") ?? .xml,
        UTType(filenameExtension: "fit") ?? .data,
        UTType("com.garmin.fit") ?? .data
    ]
) { result in
    switch result {
    case .success(let url):
        pendingImportURL = IdentifiableImportURL(url: url)
    case .failure(let error):
        print("FileImporter error: \(error)")
    }
}
```

(If `import UniformTypeIdentifiers` is missing at the top of ProfileTab.swift, add it — Phase A's Task 12 already did this, but verify.)

Optionally rename `showingUDDFPicker` → `showingImportPicker` for clarity (find/replace all 3 references in ProfileTab.swift).

- [ ] **Step 3: Build & verify**

Run:
```bash
xcodebuild build -project "DiveLog Pro.xcodeproj" -scheme "DiveLog Pro" -destination 'generic/platform=iOS' 2>&1 | tail -10
```
Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
git add "DiveLog Pro/Info.plist" "DiveLog Pro/Views/Tabs/ProfileTab.swift"
git commit -m "feat(fit): register com.garmin.fit UTI + extend .fileImporter to accept .fit"
```

---

## Task 13: End-to-end sanity build + test pass

**Files:** none — verification only.

- [ ] **Step 1: Full clean build**

```bash
xcodebuild clean build \
  -project "DiveLog Pro.xcodeproj" \
  -scheme "DiveLog Pro" \
  -destination 'generic/platform=iOS' 2>&1 | tail -30
```
Expected: BUILD SUCCEEDED, no deprecation warnings in our new files. The Garmin SDK may emit its own warnings — those are upstream issues, ignore.

- [ ] **Step 2: Full test run**

```bash
xcodebuild test \
  -project "DiveLog Pro.xcodeproj" \
  -scheme "DiveLog Pro" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' 2>&1 | tail -60
```
Expected:
- All FIT tests pass (Tasks 2, 3, 4, 5, 6, 7, 8, 9, 10).
- All UDDF tests still pass (Phase A: 23 tests).
- Numbering + PhotoStore tests still pass.
- Test count total: ≥ 45.

If anything failed, **stop and fix before moving on** — Task 14 (smoke test) is human time.

---

## Task 14: Manual smoke test on the user's iPhone 16 Pro Max

**Files:** create `docs/operational/2026-05-11-fit-import-smoke-test.md` (use the actual run date).

- [ ] **Step 1: Run on device**

```bash
xcodebuild -project "DiveLog Pro.xcodeproj" -scheme "DiveLog Pro" \
  -destination 'platform=iOS,name=<USER-IPHONE>' build
```

User performs:

- **Path A — File-Picker.** Profile → Datenverwaltung → "Tauchgänge importieren". Pick `8757 Mamutic Island.fit` from Files. Expected: sheet opens, 1 dive, generator says "Garmin Descent Mk3i" or similar, depth ~25m, duration ~50min, Mamutic GPS shows after import.

- **Path B — Share-Sheet from Files app.** Long-press a `.fit` file in Files, Share → DiveLog Pro. Expected: same sheet opens.

- **Path C — AirDrop from Garmin Connect (optional, if user has it set up).** Export a recent dive from Connect, AirDrop to phone, select DiveLog Pro. Expected: same sheet.

- **Tank-pressure check.** If any imported dive shows tankStartBar/EndBar ≠ defaults (200/50) in DiveDetail's data card, the AirIntegration path works end-to-end. If always 200/50, file an issue noting which fixtures lacked TankSummary.

- **Cross-format conflict-detection.** After importing the FIT version, re-import the corresponding UDDF dive from Phase A's test.uddf. Expected: that dive is flagged as a duplicate (datetime + depth match within tolerance).

- [ ] **Step 2: Document the result**

Append to `docs/operational/follow-ups-stabilize-2026-05-09.md` (or create `docs/operational/2026-05-11-fit-import-smoke-test.md`):

```markdown
# FIT Import (Plan B) — Manual Smoke Test (YYYY-MM-DD)

**Device:** iPhone 16 Pro Max, iOS X.Y
**Build:** feat/divecomputer-import @ <commit-sha>
**FIT SDK:** garmin/fit-swift-sdk @ <version>

**Path A:** [Pass / Fail — description]
**Path B:** [Pass / Fail — description]
**Path C:** [Pass / N/A — description]

**Tank-pressure:** [populated for which fixtures]
**Cross-format conflict-detection:** [Pass / Fail]
```

- [ ] **Step 3: Commit**

```bash
git add docs/operational/2026-05-11-fit-import-smoke-test.md
git commit -m "docs(fit): manual smoke-test log for Phase B"
```

---

## Task 15: Final verification — branch diff review

**Files:** none.

- [ ] **Step 1: List Plan-B commits**

```bash
git log --oneline b6b261c..HEAD
```
Expected: ~14 commits (one per task, plus SPM `Package.resolved`).

- [ ] **Step 2: Total diff size**

```bash
git diff --stat b6b261c..HEAD
```
Expected: ~600-900 LoC production + tests (much smaller than the in-house-decoder plan would have been — the Garmin SDK does the heavy lifting). If significantly higher, scan for accidental file changes (xcuserdata, .DS_Store).

- [ ] **Step 3: Sanity-check SDK exposure**

```bash
grep -r "import <MODULE>\|<DECODER>" "DiveLog Pro/" "DiveLog ProTests/" | wc -l
```
Replace `<MODULE>` and `<DECODER>` with the real names. Expected: 4-6 references. The Garmin SDK should only be `import`ed inside `Utils/FIT/` files + the coordinator + the test files. UI never sees it directly.

- [ ] **Step 4: Decide on merge strategy**

Both Phase A and Phase B are now on `feat/divecomputer-import`. Options:

- **Squash-merge to main** — Phase A's 14 commits + Phase B's ~14 commits collapse to one "feat: dive-computer import (UDDF + FIT)". Loses history but cleaner. **Recommended.**
- **Rebase-merge** — preserves all task-granularity commits.
- **Keep the branch open** — if user wants more hardening (more fixtures, MK3i firmware variants) before mainline.

Ask the user. Don't merge unilaterally.

- [ ] **Step 5: Final commit (allow-empty)**

```bash
git commit --allow-empty -m "feat(import): Plan B complete — FIT-direct import working end-to-end

Phase B adds direct .fit-file import alongside .uddf, using Garmin's
official Swift FIT SDK as the parser. The Subsurface bridge is now
optional; users can share files straight from Garmin Connect, Files,
or AirDrop. A thin FIT→UDDF mapper produces the same internal
UDDFFile struct as Phase A's UDDF parser, so downstream Dive-mapping
and UI are reused identically. Tank-pressure (AirIntegration)
populates Dive.tankStartBar / tankEndBar where MK3i provides it."
```

---

## Self-Review Notes

**Spec coverage** — every Phase-B spec section is implemented:
- Layer 1 FIT parser → Garmin's official SDK (Task 1, deviation from spec's FitDataProtocol justified in plan header)
- Layer 1.5 FIT → UDDF mapper → Tasks 3-8 (~200 LoC total instead of the spec's larger scope)
- Dive-message types → covered by Garmin SDK's first-class types (`SessionMesg`, `DiveSummaryMesg`, `DiveGasMesg`, `TankSummaryMesg`, `RecordMesg`, `FileIdMesg`, `DeviceInfoMesg`)
- Tank-pressure (FIT-only) → Task 8
- Coordinator dispatch → Task 10
- Sheet rename + format-neutral copy → Task 11
- UTI registration → Task 12
- File-picker UTType list → Task 12
- Golden-soll test → Task 9
- Manual smoke-test → Task 14

**Placeholder scan** — every `<MODULE>`, `<DECODER>`, `<MesgBase>` in this plan is a deliberate placeholder the engineer resolves in **Task 2 / Step 1** by reading the SDK. These are not "TODO"s — they are typed holes that get filled exactly once, then all subsequent tasks search-and-replace before running. The plan is explicit about this in the "API Discovery Task" section near the top.

**Type consistency** — `UDDFDive.tankStartBar/EndBar` reused from Phase A's `UDDFFile.swift` (added in Plan A Task 1). `IdentifiableImportURL` reused from Phase A's ProfileTab (commit `356b7a9`). `UDDFParseError.fileUnreadable` reused from Phase A's `UDDFParser.swift`.

**Test target & module** — the Garmin SDK is added to the **DiveLog Pro** target only. The test target imports `DiveLog_Pro` and reaches the SDK transitively. If a test file fails to find the SDK module, add it to the test target's "Frameworks and Libraries" too — but that's only a fallback.

---

**Plan complete and saved to `docs/superpowers/plans/2026-05-10-fit-direct-import.md`.**

Two execution options:

1. **Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration.
2. **Inline Execution** — I execute tasks sequentially in this session with batch checkpoints for review.

Which approach?
