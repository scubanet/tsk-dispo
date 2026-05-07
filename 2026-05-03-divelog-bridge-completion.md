# DiveLog Pro — Atoll Hub Bridge Completion Notes

**Date completed:** 2026-05-03
**Commit at completion:** `41e9a34` (post-final-review fix)
**Branch:** `feat/atollhub-bridge`
**Tag:** `divelog-bridge-v1` (at `22dd88e` — moved to HEAD before merge)

## What works

- App Group `group.com.atollhub.shared` activated on `com.weckherlin.DiveLogPro`
- `divelog://` URL scheme registered alongside `divelogpro://` (the existing remote-signature scheme)
- `SharedDiveLogSnapshot` + `SharedAtollHubSnapshot` Codable models match Atoll Hub's contract byte-for-byte
- `JSONEncoder.atollBridge()` / `JSONDecoder.atollBridge()` helpers — snake_case keys + ISO8601 dates + sorted, pretty-printed output. Scoped to the bridge wire format (commented to prevent repurposing)
- `DiveLogBridge` actor handles atomic writes + defensive reads against the App Group container; logs to OSLog `category: AtollBridge`
- `DiveLogBridgePublisher` assembles the snapshot from `DiverProfile` + `Dive` count + last-dive date; no-ops when not signed in
- Snapshot republishes on: app launch, profile save (ProfileEditView), dive save (DiveFormView)
- DEBUG round-trip self-check fires once per launch (in DEBUG only) and logs PASS/FAIL with `assertionFailure` on contract drift
- Dates in the producer are truncated to whole seconds before assembly so the `.iso8601`-encoded snapshot round-trips losslessly (the encoder strategy itself drops fractional seconds, and Atoll Hub's `.iso8601` decoder doesn't accept them — truncation in the producer keeps the wire format unchanged and Atoll Hub-compatible)

## v1 minimal mappings (intentional)

- `certifications` = `[{agency: "PADI", level: DiverProfile.certLevel, issuedAt: nil}]` — single PADI cert mirrored from existing `certLevel` string
- `specialties` = `[]` — DiveLog has no per-user specialties concept (per-student `SkillCompletion` is unrelated and intentionally not exposed)
- `languagesSpoken` = `[DiverProfile.language]` — single-language preference mirrored as a 1-element array
- `homeBase`, `diveLogHandle`, `avatarFileName`, `conservationProjects` = nil/empty — fields exist on the wire format for forward-compat but not yet populated

## v1 deferred (intentional, not blocking)

- `DiverProfile` schema expansion (`handle`, `homeBase`, `languagesSpoken[]`, `conservationProjects[]`)
- Multi-cert / multi-agency `certifications[]` (currently 1-element PADI mapping from a single `certLevel` string)
- Surfacing `SharedAtollHubSnapshot` content in DiveLog's UI (the decoder is shipped via `DiveLogBridge.readAtollHubSnapshot()`, but no view consumes it yet)
- Avatar file copy into the App Group container
- `NSFileCoordinator`-based change notifications across apps
- Schema v2 migration path
- Formal XCTest unit test target (replaced by the inline DEBUG self-check)

## Manual user actions still required

**Apple Developer Account registration (Task 1, Step 2 — skipped during automation):**

Before deploying to a real device or TestFlight, register the App Group at developer.apple.com:
1. Visit https://developer.apple.com/account/resources/identifiers/list/applicationGroup
2. If `group.com.atollhub.shared` doesn't already exist (Atoll Hub may have created it), create it (Description: "Atoll Hub Shared", Identifier: `group.com.atollhub.shared`)
3. Open the App ID `com.weckherlin.DiveLogPro` → App Groups → Configure → tick `group.com.atollhub.shared` → Save

Simulator builds work without this registration (verified during implementation).

**Apple Team ID match:** Confirm DiveLog Pro and Atoll Hub are both signed under the same Apple Team (Atoll Hub spec specifies `XK8V89P2QV`). Without a shared team, the App Group container won't be visible across apps.

## Code-review minor suggestions noted but not applied (for follow-up)

These were rated as Suggestions (not Critical/Important) by the code-quality reviewer. None block the bridge from working; revisit if/when the corresponding code paths grow:

- **`SharedDiveLogSnapshot.swift`:** doc comment could mention that the struct must be encoded/decoded with `JSONEncoder.atollBridge()` to get correct snake_case keys — not a runtime issue today because all current call sites already use the helper. Triple-slash doc comments on the nested `Certification` / `Project` types would be a minor consistency nicety.
- **`DiveLogBridgePublisher.swift`:** three sequential SwiftData fetches (profile, last-dive, count) on the main thread are acceptable for a typical logbook size; if it ever scales to many thousands of dives, batching them on a background context is the natural v2 refactor. A `// TODO(v2)` comment would acknowledge it.
- **`DiveLogBridgePublisher.swift`:** the hardcoded `agency: "PADI"` is an explicit v1 decision (documented in this file). A one-line cross-reference to this completion doc on the line where the cert is constructed would shorten the trail when the multi-agency upgrade lands.
- **`DiveLogBridge.swift` self-check:** fires on every WindowGroup `.task` re-fire, not just cold start. Acceptable in DEBUG (the check is cheap and side-effect-free) but a private `_selfCheckRan` boolean would short-circuit duplicate runs if ever annoying.

## Notes for the Atoll Hub side

- The Atoll Hub plan's `AtollHubSnapshotPublisher` writes `appleUserId: profile.id.uuidString` (their internal Supabase profile ID), not the Apple-provided user identifier. DiveLog correctly writes the actual `ASAuthorizationAppleIDCredential.user` value (via `AppleSignInService.shared.currentUserID`). For Atoll Hub to match DiveLog's snapshot to its current user, Atoll Hub should either also use the SIWA user identifier OR maintain a mapping table from `apple_user_id` to its internal profile ID. **Flag this when you next touch that codebase.**
- Atoll Hub uses helper names `JSONDecoder.snake()` / `JSONEncoder.snake()`. DiveLog uses `JSONDecoder.atollBridge()` / `JSONEncoder.atollBridge()`. Names differ; the wire format is identical. If both sides ever extract a shared Swift Package, unify the names there (the more descriptive `atollBridge()` is the better target).
- The Atoll Hub plan recommends `NSFileCoordinator`-based notifications for live updates. DiveLog's v1 leaves this out — both sides poll on appear/launch. If Atoll Hub later adds coordinator-based observation, DiveLog should match.

## Next

- Decide whether the deferred `DiverProfile` schema expansion (handle, homeBase, languagesSpoken[]) is in v2 scope or stays deferred indefinitely. The wire format already accepts these as optional fields, so DiveLog can fill them later without breaking Atoll Hub.
- Optional: extract `SharedDiveLogSnapshot` + the JSON helpers into a Swift Package consumed by both DiveLog Pro and Atoll Hub. Two byte-identical Codable structs are easier to maintain than they are to mismatch — but a shared module would unify the helpers' names and provide a single source of truth.

## Commit list (in order)

```
0b7a9b0  feat(entitlements): activate App Group group.com.atollhub.shared
ca78bdc  feat(deeplink): register divelog:// URL scheme alongside divelogpro://
ae631c9  feat(bridge): SharedDiveLogSnapshot Codable model
e8c3d38  feat(bridge): SharedAtollHubSnapshot model + shared JSON encoder/decoder
d019ff1  docs(bridge): scope comments on shared JSON helpers
999af5b  feat(bridge): DiveLogBridge actor for App Group snapshot IO
b03409a  refactor(bridge): use URL.appending(component:) instead of deprecated API
52bdfc9  feat(bridge): DiveLogBridgePublisher assembles snapshot from SwiftData
ae5ca83  refactor(bridge): mark displayName as private in OSLog interpolation
b26a01e  feat(bridge): publish DiveLog snapshot on app launch
2f21f43  feat(bridge): re-publish snapshot after ProfileEdit save
9b17862  docs(bridge): explain intentional pre-persistence read in republish helper
a051489  feat(bridge): re-publish snapshot after a dive is saved
28323cc  feat(bridge): DEBUG round-trip self-check for the JSON contract
22dd88e  docs: DiveLog × Atoll Hub bridge completion notes
41e9a34  fix(bridge): truncate snapshot dates to whole seconds for ISO8601 lossless round-trip
```
