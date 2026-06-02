# AtollTalk Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A native iPhone app that lets Dominik (German) and Maria (Ukrainian) talk in the kitchen — tap to speak, best-in-class recognition auto-detects the language, Claude translates with kitchen context, the translation shows large on screen and reads aloud on tap.

**Architecture:** SwiftUI (iOS 26) turn-based pipeline — `AudioRecorder` (AVAudioEngine → 16 kHz mono WAV) → `SpeechService` (ElevenLabs Scribe, returns text **+ detected language**) → `LanguageRouter` (picks the other language in the active pair) → `TranslationService` (Claude via Anthropic streaming, system prompt = kitchen context + glossary) → `Turn` appended to an in-memory/SwiftData store → big-text UI → `SynthesisService` (ElevenLabs voice, Apple fallback) on “Vorlesen”. API keys live in the iOS Keychain; no backend.

**Tech Stack:** Swift 6 (strict concurrency), SwiftUI, SwiftData, AVFoundation, XcodeGen. Two shared local SPM packages promoted from Tide: `AtollLLM` (Anthropic streaming) and `AtollSpeech` (ElevenLabs STT/TTS + Apple fallback + WAV export). Models: `claude-sonnet-4-6` (default), `claude-haiku-4-5-20251001` (fast option); ElevenLabs `scribe_v1` STT (→ confirm Scribe-v2 model id) + `eleven_multilingual_v2` TTS.

---

## Conventions (match AtollCal / Tide)

- XcodeGen `project.yml`; Swift 6, `SWIFT_STRICT_CONCURRENCY: complete`; `developmentLanguage: de`.
- `bundleIdPrefix: swiss.atoll`, bundle id `swiss.atoll.talk`, `DEVELOPMENT_TEAM: XK8V89P2QV`, `CODE_SIGN_STYLE: Automatic`.
- App lives at `apps/atolltalk-native/`; shared packages at `swift-packages/`.
- Logger subsystem in app code: `swiss.atoll.talk`.
- All commands below assume repo root `Dispo/` (the monorepo). Adjust the iOS Simulator device name to one shown by `xcrun simctl list devices available`.

## Design decisions locked here (deviations from spec, with rationale)

1. **No `AtollDesign` dependency.** `AtollDesign` → `AtollCore` → `supabase-swift`; pulling Supabase into a translator is dead weight. We instead add a tiny local `Theme.swift` that mirrors the few `AtollDesign` brand tokens (`brandBlue` `0x185FA5`, neutrals) so AtollTalk stays visually aligned but lean. Revisit if AtollTalk ever needs shared components.
2. **Copy, don’t move.** Tide keeps its own `Speech`/`LLM` copies for now (so Tide doesn’t break). We copy the sources into new shared `AtollSpeech`/`AtollLLM` packages. Migrating Tide onto the shared packages is a later, separate task (out of scope here).
3. **Skip the streaming `SpeechRecognizer` protocol.** AtollTalk is record→stop→transcribe (no live partials needed), so it calls `ElevenLabsClient.transcribe` directly via `SpeechService`. We still reuse `AudioBufferAccumulator`, `ElevenLabsClient`, `ElevenLabsSynthesizer`, `AppleSynthesizer`, `CompositeSynthesizer`.

## File structure

Shared packages (new, under `swift-packages/`):

- `AtollLLM/` — copy of Tide `LLM` (Anthropic streaming). iOS 26 + macOS 26. No `Core` dep.
  - `Sources/AtollLLM/Protocols/{LLMProvider,LLMMessage,LLMChunk,LLMError,LLMTool}.swift`
  - `Sources/AtollLLM/Anthropic/{AnthropicProvider,AnthropicRequest,SSEParser}.swift`
- `AtollSpeech/` — copy of Tide `Speech` + `AudioBufferAccumulator`. iOS 26 + macOS 26.
  - `Sources/AtollSpeech/ElevenLabs/{ElevenLabsClient,ElevenLabsSynthesizer}.swift`
  - `Sources/AtollSpeech/Apple/AppleSynthesizer.swift`
  - `Sources/AtollSpeech/CompositeSynthesizer.swift`
  - `Sources/AtollSpeech/Protocols/Synthesizer.swift`
  - `Sources/AtollSpeech/Audio/AudioBufferAccumulator.swift`

App (`apps/atolltalk-native/`):

- `project.yml`, `AtollTalk/AtollTalkApp.swift`, `Config.swift`, `Info.plist`, `ATOLL.entitlements`, `Assets.xcassets`
- `AtollTalk/Theme/Theme.swift`
- `AtollTalk/Models/{AppLanguage,LanguageRouter,Turn,GlossaryEntry}.swift`
- `AtollTalk/Services/{Secrets,AudioRecorder,SpeechService,TranslationService,SynthesisService}.swift`
- `AtollTalk/Stores/{ConversationStore,GlossaryStore,Settings}.swift`
- `AtollTalk/ViewModel/AppViewModel.swift`
- `AtollTalk/Views/{ConversationView,TurnCardView,RecordButton,SettingsView,RootView}.swift`
- `AtollTalkTests/{LanguageRouterTests,ScribeDecodeTests,TranslationPromptTests,SecretsTests,WAVExportTests}.swift`

---

## Phase 0 — Shared packages

### Task 1: Create `AtollLLM` shared package (Anthropic streaming)

**Files:**
- Create: `swift-packages/AtollLLM/Package.swift`
- Create (copy + rename module): `swift-packages/AtollLLM/Sources/AtollLLM/...`
- Create: `swift-packages/AtollLLM/Tests/AtollLLMTests/...`

- [ ] **Step 1: Copy the Tide LLM sources into the new package**

```bash
cd "$DISPO"            # repo root
mkdir -p swift-packages/AtollLLM/Sources/AtollLLM
mkdir -p swift-packages/AtollLLM/Tests/AtollLLMTests
cp -R ../tide/Packages/LLM/Sources/LLM/. swift-packages/AtollLLM/Sources/AtollLLM/
cp -R ../tide/Packages/LLM/Tests/LLMTests/. swift-packages/AtollLLM/Tests/AtollLLMTests/
```
(Note: `../tide` assumes `tide` sits beside `Dispo`. If not, use the absolute path to the Tide repo.)

- [ ] **Step 2: Write `Package.swift` (iOS 26 + macOS 26, no `Core` dependency)**

Recon confirmed the LLM sources contain no `import Core` and no `Core.*` usage, so the dependency is dropped.

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "AtollLLM",
  platforms: [.iOS("26.0"), .macOS("26.0")],
  products: [
    .library(name: "AtollLLM", targets: ["AtollLLM"]),
  ],
  targets: [
    .target(name: "AtollLLM"),
    .testTarget(name: "AtollLLMTests", dependencies: ["AtollLLM"]),
  ]
)
```

- [ ] **Step 3: Fix the test target import**

The copied tests `import LLM`. Replace with `import AtollLLM`:

```bash
cd "$DISPO"
grep -rl 'import LLM' swift-packages/AtollLLM/Tests | xargs sed -i '' 's/import LLM/import AtollLLM/g'
```

- [ ] **Step 4: Build + run the package tests (must pass — these are Tide’s own, already green)**

Run: `cd "$DISPO" && swift test --package-path swift-packages/AtollLLM`
Expected: build succeeds, all copied tests (`AnthropicProviderTests`, `SSEParserTests`, …) PASS.

- [ ] **Step 5: Commit**

```bash
cd "$DISPO"
git add swift-packages/AtollLLM
git commit -m "feat(atolltalk): add shared AtollLLM package (Anthropic streaming, copied from Tide)"
```

### Task 2: Create `AtollSpeech` shared package + return detected language from Scribe

**Files:**
- Create: `swift-packages/AtollSpeech/Package.swift`
- Create (copy): `swift-packages/AtollSpeech/Sources/AtollSpeech/{ElevenLabs,Apple,Protocols}/...`, `.../Audio/AudioBufferAccumulator.swift`
- Modify: `swift-packages/AtollSpeech/Sources/AtollSpeech/ElevenLabs/ElevenLabsClient.swift`
- Test: `swift-packages/AtollSpeech/Tests/AtollSpeechTests/ScribeDecodeTests.swift`

- [ ] **Step 1: Copy the reusable Speech sources (skip the streaming recognizers we don’t use)**

```bash
cd "$DISPO"
mkdir -p swift-packages/AtollSpeech/Sources/AtollSpeech/{ElevenLabs,Apple,Protocols,Audio}
mkdir -p swift-packages/AtollSpeech/Tests/AtollSpeechTests
SRC=../tide/Packages/Speech/Sources/TideSpeech
cp "$SRC/ElevenLabs/ElevenLabsClient.swift"       swift-packages/AtollSpeech/Sources/AtollSpeech/ElevenLabs/
cp "$SRC/ElevenLabs/ElevenLabsSynthesizer.swift"  swift-packages/AtollSpeech/Sources/AtollSpeech/ElevenLabs/
cp "$SRC/Apple/AppleSynthesizer.swift"            swift-packages/AtollSpeech/Sources/AtollSpeech/Apple/
cp "$SRC/CompositeSynthesizer.swift"              swift-packages/AtollSpeech/Sources/AtollSpeech/
cp "$SRC/Protocols/Synthesizer.swift"             swift-packages/AtollSpeech/Sources/AtollSpeech/Protocols/
cp ../tide/Tide/Recorder/AudioBufferAccumulator.swift swift-packages/AtollSpeech/Sources/AtollSpeech/Audio/
```

- [ ] **Step 2: Write `Package.swift` (iOS 26 + macOS 26)**

```swift
// swift-tools-version: 6.0
import PackageDescription

// Module name avoids Apple's `Speech.framework` collision (same reason
// Tide named its module `TideSpeech`).
let package = Package(
  name: "AtollSpeech",
  platforms: [.iOS("26.0"), .macOS("26.0")],
  products: [
    .library(name: "AtollSpeech", targets: ["AtollSpeech"]),
  ],
  targets: [
    .target(name: "AtollSpeech"),
    .testTarget(name: "AtollSpeechTests", dependencies: ["AtollSpeech"]),
  ]
)
```

- [ ] **Step 3: Write the failing test — Scribe response must surface text + language**

Create `swift-packages/AtollSpeech/Tests/AtollSpeechTests/ScribeDecodeTests.swift`:

```swift
import Testing
import Foundation
@testable import AtollSpeech

@Suite struct ScribeDecodeTests {
  @Test func decodesTextAndLanguage() throws {
    let json = """
    { "text": "Доброго дня", "language_code": "ukr", "language_probability": 0.99 }
    """.data(using: .utf8)!
    let decoded = try JSONDecoder().decode(ElevenLabsClient.Transcription.self, from: json)
    #expect(decoded.text == "Доброго дня")
    #expect(decoded.languageCode == "ukr")
  }
}
```

- [ ] **Step 4: Run it — must fail to compile (no `Transcription` type yet)**

Run: `cd "$DISPO" && swift test --package-path swift-packages/AtollSpeech`
Expected: FAIL — `Transcription` is not a member of `ElevenLabsClient`.

- [ ] **Step 5: Change `transcribe` to return text + detected language**

In `swift-packages/AtollSpeech/Sources/AtollSpeech/ElevenLabs/ElevenLabsClient.swift`, replace the `transcribe(audioData:)` method and the private `ScribeResponse` with:

```swift
  /// Public result of a Scribe transcription: the text plus the
  /// detected language code (ISO 639-3 like "deu"/"ukr", per Scribe).
  struct Transcription: Sendable, Decodable, Equatable {
    let text: String
    let languageCode: String?
    let languageProbability: Double?

    enum CodingKeys: String, CodingKey {
      case text
      case languageCode = "language_code"
      case languageProbability = "language_probability"
    }
  }

  /// Transcribe audio via Scribe (ElevenLabs Speech-to-Text).
  /// Audio: WAV-encoded (16 kHz mono Int16 recommended). Returns the
  /// transcript **and** the detected language. Throws `ElevenLabsClient.Error`.
  func transcribe(
    audioData: Data,
    modelID: String = "scribe_v1"   // TODO(open point #1): switch to Scribe v2 id once confirmed
  ) async throws -> Transcription {
    let url = URL(string: "https://api.elevenlabs.io/v1/speech-to-text")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")

    let boundary = "Atoll-\(UUID().uuidString)"
    request.setValue(
      "multipart/form-data; boundary=\(boundary)",
      forHTTPHeaderField: "Content-Type"
    )
    request.httpBody = Self.multipartBody(
      boundary: boundary,
      fields: [
        "model_id":               modelID,
        "tag_audio_events":       "false",
        "timestamps_granularity": "none",
        "diarize":                "false",
      ],
      file: (name: "file", filename: "audio.wav", mime: "audio/wav", data: audioData)
    )

    let (data, response) = try await session.data(for: request)
    try Self.checkOK(response)
    return try JSONDecoder().decode(Transcription.self, from: data)
  }
```

Delete the old `private struct ScribeResponse { ... }` at the bottom of the file (its fields now live in `Transcription`).

- [ ] **Step 6: Run the test — must pass**

Run: `cd "$DISPO" && swift test --package-path swift-packages/AtollSpeech`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
cd "$DISPO"
git add swift-packages/AtollSpeech
git commit -m "feat(atolltalk): add shared AtollSpeech package; Scribe returns detected language"
```

---

## Phase 1 — App scaffold

> All shell commands below define `DISPO` = absolute path to the `Dispo` repo root, and run from there unless stated.

### Task 3: XcodeGen project, app entry point, assets — builds & runs

**Files:**
- Create: `apps/atolltalk-native/project.yml`
- Create: `apps/atolltalk-native/AtollTalk/AtollTalkApp.swift`
- Create: `apps/atolltalk-native/AtollTalk/Views/RootView.swift`
- Create: `apps/atolltalk-native/AtollTalk/Assets.xcassets/{Contents.json,AccentColor.colorset/Contents.json,AppIcon.appiconset/Contents.json}`

- [ ] **Step 1: Write `project.yml`**

```yaml
name: AtollTalk
options:
  bundleIdPrefix: swiss.atoll
  deploymentTarget:
    iOS: "26.0"
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
packages:
  AtollLLM:
    path: ../../swift-packages/AtollLLM
  AtollSpeech:
    path: ../../swift-packages/AtollSpeech
targets:
  AtollTalk:
    type: application
    platform: iOS
    sources:
      - path: AtollTalk
    resources:
      - path: AtollTalk/Assets.xcassets
    dependencies:
      - package: AtollLLM
        product: AtollLLM
      - package: AtollSpeech
        product: AtollSpeech
    info:
      path: AtollTalk/Info.plist
      properties:
        CFBundleDisplayName: AtollTalk
        CFBundleShortVersionString: $(MARKETING_VERSION)
        CFBundleVersion: $(CURRENT_PROJECT_VERSION)
        UILaunchScreen:
          UIColorName: AccentColor
        UISupportedInterfaceOrientations:
          - UIInterfaceOrientationPortrait
        ITSAppUsesNonExemptEncryption: false
        NSMicrophoneUsageDescription: "AtollTalk nimmt deine Stimme auf, um sie zu übersetzen."
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: swiss.atoll.talk
        INFOPLIST_KEY_NSMicrophoneUsageDescription: "AtollTalk nimmt deine Stimme auf, um sie zu übersetzen."
  AtollTalkTests:
    type: bundle.unit-test
    platform: iOS
    sources: AtollTalkTests
    dependencies:
      - target: AtollTalk
```

(No entitlements file needed — microphone access on iOS is gated only by the `NSMicrophoneUsageDescription` Info.plist string.)

- [ ] **Step 2: Write the app entry + placeholder root view**

`AtollTalk/AtollTalkApp.swift`:
```swift
import SwiftUI

@main
struct AtollTalkApp: App {
  var body: some Scene {
    WindowGroup { RootView() }
  }
}
```

`AtollTalk/Views/RootView.swift`:
```swift
import SwiftUI

struct RootView: View {
  var body: some View {
    Text("AtollTalk")
      .font(.largeTitle.weight(.semibold))
  }
}
```

- [ ] **Step 3: Create asset catalog**

`AtollTalk/Assets.xcassets/Contents.json`:
```json
{ "info" : { "author" : "xcode", "version" : 1 } }
```
`AtollTalk/Assets.xcassets/AccentColor.colorset/Contents.json`:
```json
{
  "colors" : [
    { "idiom" : "universal",
      "color" : { "color-space" : "srgb",
        "components" : { "red" : "0x18", "green" : "0x5F", "blue" : "0xA5", "alpha" : "1.000" } } }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
```
`AtollTalk/Assets.xcassets/AppIcon.appiconset/Contents.json`:
```json
{ "images" : [ { "idiom" : "universal", "platform" : "ios", "size" : "1024x1024" } ],
  "info" : { "author" : "xcode", "version" : 1 } }
```

- [ ] **Step 4: Generate the Xcode project**

Run: `cd "$DISPO/apps/atolltalk-native" && xcodegen generate`
Expected: `Created project at AtollTalk.xcodeproj`.

- [ ] **Step 5: Build for the simulator**

Run (pick a device from `xcrun simctl list devices available`):
```bash
cd "$DISPO/apps/atolltalk-native"
xcodebuild -project AtollTalk.xcodeproj -scheme AtollTalk \
  -destination 'platform=iOS Simulator,name=iPhone 16' build
```
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 6: Commit**

```bash
cd "$DISPO"
printf '%s\n' 'AtollTalk.xcodeproj/' 'DerivedData/' '.DS_Store' > apps/atolltalk-native/.gitignore
git add apps/atolltalk-native
git commit -m "feat(atolltalk): scaffold XcodeGen iOS app (builds & runs)"
```

### Task 4: `Config` + local `Theme`

**Files:**
- Create: `apps/atolltalk-native/AtollTalk/Config.swift`
- Create: `apps/atolltalk-native/AtollTalk/Theme/Theme.swift`

- [ ] **Step 1: Write `Config.swift`**

```swift
import Foundation

enum Config {
  static let appName = "AtollTalk"

  // Claude (Anthropic) models
  static let defaultModel = "claude-sonnet-4-6"
  static let fastModel    = "claude-haiku-4-5-20251001"

  // ElevenLabs
  static let scribeModelID = "scribe_v1"            // open point #1: confirm Scribe v2 id
  static let ttsModelID    = "eleven_multilingual_v2"

  /// Default translation context (editable later in Settings).
  static let defaultContext = """
  Du übersetzt ein lockeres, gesprochenes Gespräch in einer Restaurantküche \
  zwischen Dominik (Deutsch) und seiner Küchenhilfe Maria (Ukrainisch). \
  Übersetze natürlich und umgangssprachlich, nicht wörtlich. Gib NUR die \
  Übersetzung aus — ohne Anführungszeichen, ohne Erklärungen.
  """
}
```

- [ ] **Step 2: Write `Theme.swift` (mirrors AtollDesign brand tokens, no dependency)**

```swift
import SwiftUI

/// Minimal brand tokens mirrored from AtollDesign/BrandColors so AtollTalk
/// stays visually aligned without pulling in AtollCore/Supabase.
extension Color {
  init(hex: UInt32) {
    let r = Double((hex >> 16) & 0xFF) / 255
    let g = Double((hex >>  8) & 0xFF) / 255
    let b = Double( hex        & 0xFF) / 255
    self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
  }
  static let brandBlue     = Color(hex: 0x185FA5)
  static let brandBlue50   = Color(hex: 0xE6F1FB)
  static let textPrimary   = Color(hex: 0x1A1A1A)
  static let textSecondary = Color(hex: 0x4A4A4A)
  static let textTertiary  = Color(hex: 0x888780)
}
```

- [ ] **Step 3: Commit**

```bash
cd "$DISPO"
git add apps/atolltalk-native/AtollTalk/Config.swift apps/atolltalk-native/AtollTalk/Theme/Theme.swift
git commit -m "feat(atolltalk): add Config + local Theme tokens"
```

---

## Phase 2 — Domain

### Task 5: `AppLanguage` + `LanguageRouter` (TDD)

**Files:**
- Create: `apps/atolltalk-native/AtollTalk/Models/AppLanguage.swift`
- Create: `apps/atolltalk-native/AtollTalk/Models/LanguageRouter.swift`
- Test: `apps/atolltalk-native/AtollTalkTests/LanguageRouterTests.swift`

- [ ] **Step 1: Write the failing tests**

```swift
import Testing
@testable import AtollTalk

@Suite struct LanguageRouterTests {
  let pair = LanguagePair(a: .de, b: .uk)

  @Test func germanRoutesToUkrainian() {
    let r = LanguageRouter.route(detected: .de, in: pair)
    #expect(r?.source == .de)
    #expect(r?.target == .uk)
  }
  @Test func ukrainianRoutesToGerman() {
    let r = LanguageRouter.route(detected: .uk, in: pair)
    #expect(r?.source == .uk)
    #expect(r?.target == .de)
  }
  @Test func scribeCodesMapToLanguages() {
    #expect(AppLanguage(scribeCode: "deu") == .de)
    #expect(AppLanguage(scribeCode: "de")  == .de)
    #expect(AppLanguage(scribeCode: "ukr") == .uk)
    #expect(AppLanguage(scribeCode: "uk")  == .uk)
    #expect(AppLanguage(scribeCode: "fra") == nil)
  }
}
```

- [ ] **Step 2: Run — must fail (types undefined)**

Run: `cd "$DISPO/apps/atolltalk-native" && xcodebuild -project AtollTalk.xcodeproj -scheme AtollTalk -destination 'platform=iOS Simulator,name=iPhone 16' test`
Expected: FAIL (compile errors — `AppLanguage`, `LanguagePair`, `LanguageRouter` not found).

- [ ] **Step 3: Implement `AppLanguage.swift`**

```swift
import Foundation

enum AppLanguage: String, CaseIterable, Sendable, Codable, Identifiable {
  case de
  case uk

  var id: String { rawValue }
  var displayName: String { self == .de ? "Deutsch" : "Українська" }
  var flag: String { self == .de ? "🇩🇪" : "🇺🇦" }

  /// BCP-47 locale used to pick an Apple fallback voice.
  var appleLocale: String { self == .de ? "de-DE" : "uk-UA" }

  /// Map a Scribe language code (ISO 639-1 "de"/"uk" or 639-3 "deu"/"ukr").
  init?(scribeCode raw: String) {
    let c = raw.lowercased()
    if c.hasPrefix("de") || c.hasPrefix("ger") { self = .de }
    else if c.hasPrefix("uk") || c.hasPrefix("ukr") { self = .uk }
    else { return nil }
  }
}
```

- [ ] **Step 4: Implement `LanguageRouter.swift`**

```swift
import Foundation

struct LanguagePair: Equatable, Sendable, Codable {
  var a: AppLanguage
  var b: AppLanguage

  func contains(_ lang: AppLanguage) -> Bool { lang == a || lang == b }
  func other(than lang: AppLanguage) -> AppLanguage? {
    if lang == a { return b }
    if lang == b { return a }
    return nil
  }
}

enum LanguageRouter {
  /// (source, target) for the detected language within the active pair,
  /// or nil if the detected language isn't part of the pair.
  static func route(
    detected: AppLanguage, in pair: LanguagePair
  ) -> (source: AppLanguage, target: AppLanguage)? {
    guard let target = pair.other(than: detected) else { return nil }
    return (detected, target)
  }
}
```

- [ ] **Step 5: Run — must pass**

Run: same `xcodebuild ... test` command.
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
cd "$DISPO"
git add apps/atolltalk-native/AtollTalk/Models apps/atolltalk-native/AtollTalkTests/LanguageRouterTests.swift
git commit -m "feat(atolltalk): language model + auto-direction router (TDD)"
```

### Task 6: Secrets storage (`SecretStore` + Keychain + in-memory) (TDD)

**Files:**
- Create: `apps/atolltalk-native/AtollTalk/Services/Secrets.swift`
- Test: `apps/atolltalk-native/AtollTalkTests/SecretsTests.swift`

- [ ] **Step 1: Write the failing test (in-memory store semantics)**

```swift
import Testing
@testable import AtollTalk

@Suite struct SecretsTests {
  @Test func setGetClear() {
    let store = InMemorySecretStore()
    #expect(store.value(for: .anthropicAPIKey) == nil)
    store.set("sk-ant-123", for: .anthropicAPIKey)
    #expect(store.value(for: .anthropicAPIKey) == "sk-ant-123")
    store.set(nil, for: .anthropicAPIKey)
    #expect(store.value(for: .anthropicAPIKey) == nil)
  }
}
```

- [ ] **Step 2: Run — must fail (types undefined).** Same `xcodebuild ... test`. Expected: FAIL.

- [ ] **Step 3: Implement `Secrets.swift` (protocol + Keychain + in-memory)**

```swift
import Foundation
import Security

enum SecretKey: String, CaseIterable, Sendable {
  case elevenLabsAPIKey = "swiss.atoll.talk.elevenLabsAPIKey"
  case anthropicAPIKey  = "swiss.atoll.talk.anthropicAPIKey"
}

protocol SecretStore: Sendable {
  func value(for key: SecretKey) -> String?
  func set(_ value: String?, for key: SecretKey)
}

/// Test/double store — no Keychain.
final class InMemorySecretStore: SecretStore, @unchecked Sendable {
  private let lock = NSLock()
  private var dict: [SecretKey: String] = [:]
  func value(for key: SecretKey) -> String? { lock.lock(); defer { lock.unlock() }; return dict[key] }
  func set(_ value: String?, for key: SecretKey) {
    lock.lock(); defer { lock.unlock() }
    if let value { dict[key] = value } else { dict[key] = nil }
  }
}

/// Production store — iOS Keychain (generic password, this app only).
final class KeychainSecretStore: SecretStore, @unchecked Sendable {
  func value(for key: SecretKey) -> String? {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrAccount as String: key.rawValue,
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne,
    ]
    var item: CFTypeRef?
    guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
          let data = item as? Data,
          let str = String(data: data, encoding: .utf8) else { return nil }
    return str
  }

  func set(_ value: String?, for key: SecretKey) {
    let base: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrAccount as String: key.rawValue,
    ]
    SecItemDelete(base as CFDictionary)
    guard let value, let data = value.data(using: .utf8) else { return }
    var add = base
    add[kSecValueData as String] = data
    add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
    SecItemAdd(add as CFDictionary, nil)
  }
}
```

- [ ] **Step 4: Run — must pass.** Same `xcodebuild ... test`. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
cd "$DISPO"
git add apps/atolltalk-native/AtollTalk/Services/Secrets.swift apps/atolltalk-native/AtollTalkTests/SecretsTests.swift
git commit -m "feat(atolltalk): Keychain-backed secret store (+ in-memory double, TDD)"
```

### Task 7: `Turn` model + `ConversationStore` (SwiftData) (TDD)

**Files:**
- Create: `apps/atolltalk-native/AtollTalk/Models/Turn.swift`
- Create: `apps/atolltalk-native/AtollTalk/Stores/ConversationStore.swift`
- Test: `apps/atolltalk-native/AtollTalkTests/ConversationStoreTests.swift`

- [ ] **Step 1: Write the failing test (in-memory SwiftData container)**

```swift
import Testing
import SwiftData
@testable import AtollTalk

@MainActor @Suite struct ConversationStoreTests {
  @Test func addPersistsAndFetchesNewestFirst() throws {
    let container = try ModelContainer(
      for: Turn.self,
      configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let store = ConversationStore(context: container.mainContext)
    store.add(Turn(sourceText: "Hallo", sourceLang: .de, targetText: "Привіт", targetLang: .uk))
    let turns = try store.allNewestFirst()
    #expect(turns.count == 1)
    #expect(turns.first?.targetText == "Привіт")
    #expect(turns.first?.targetLang == .uk)
  }
}
```

- [ ] **Step 2: Run — must fail.** Same `xcodebuild ... test`. Expected: FAIL.

- [ ] **Step 3: Implement `Turn.swift`**

```swift
import Foundation
import SwiftData

@Model
final class Turn {
  @Attribute(.unique) var id: UUID
  var createdAt: Date
  var sourceText: String
  var sourceLangCode: String
  var targetText: String
  var targetLangCode: String

  init(
    id: UUID = UUID(),
    createdAt: Date = .now,
    sourceText: String,
    sourceLang: AppLanguage,
    targetText: String,
    targetLang: AppLanguage
  ) {
    self.id = id
    self.createdAt = createdAt
    self.sourceText = sourceText
    self.sourceLangCode = sourceLang.rawValue
    self.targetText = targetText
    self.targetLangCode = targetLang.rawValue
  }

  var sourceLang: AppLanguage { AppLanguage(rawValue: sourceLangCode) ?? .de }
  var targetLang: AppLanguage { AppLanguage(rawValue: targetLangCode) ?? .uk }
}
```

- [ ] **Step 4: Implement `ConversationStore.swift`**

```swift
import Foundation
import SwiftData

@MainActor
struct ConversationStore {
  let context: ModelContext

  func add(_ turn: Turn) {
    context.insert(turn)
    try? context.save()
  }

  func allNewestFirst() throws -> [Turn] {
    try context.fetch(
      FetchDescriptor<Turn>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
    )
  }

  func clear() throws {
    try context.delete(model: Turn.self)
    try context.save()
  }
}
```

- [ ] **Step 5: Run — must pass.** Same `xcodebuild ... test`. Expected: PASS.

- [ ] **Step 6: Commit**

```bash
cd "$DISPO"
git add apps/atolltalk-native/AtollTalk/Models/Turn.swift apps/atolltalk-native/AtollTalk/Stores/ConversationStore.swift apps/atolltalk-native/AtollTalkTests/ConversationStoreTests.swift
git commit -m "feat(atolltalk): Turn model + ConversationStore (SwiftData, TDD)"
```

### Task 8: Glossary (`GlossaryEntry` + `GlossaryStore`) (TDD)

**Files:**
- Create: `apps/atolltalk-native/AtollTalk/Models/GlossaryEntry.swift`
- Create: `apps/atolltalk-native/AtollTalk/Stores/GlossaryStore.swift`
- Test: `apps/atolltalk-native/AtollTalkTests/GlossaryStoreTests.swift`

- [ ] **Step 1: Write the failing test (round-trips through UserDefaults)**

```swift
import Testing
import Foundation
@testable import AtollTalk

@MainActor @Suite struct GlossaryStoreTests {
  @Test func addPersistsAndRendersPromptLines() {
    let defaults = UserDefaults(suiteName: "atolltalk.test.\(UUID())")!
    let store = GlossaryStore(defaults: defaults)
    store.add(de: "Maria", uk: "Марія")
    store.add(de: "Schnittlauch", uk: "Цибуля-різанець")
    #expect(store.entries.count == 2)

    let reopened = GlossaryStore(defaults: defaults)
    #expect(reopened.entries.count == 2)
    #expect(reopened.promptLines().contains("Maria ↔ Марія"))
  }
}
```

- [ ] **Step 2: Run — must fail.** Same `xcodebuild ... test`. Expected: FAIL.

- [ ] **Step 3: Implement `GlossaryEntry.swift`**

```swift
import Foundation

struct GlossaryEntry: Codable, Identifiable, Equatable, Sendable {
  var id: UUID = UUID()
  var de: String
  var uk: String
}
```

- [ ] **Step 4: Implement `GlossaryStore.swift`**

```swift
import Foundation
import Observation

@MainActor @Observable
final class GlossaryStore {
  private let defaults: UserDefaults
  private let key = "swiss.atoll.talk.glossary"
  private(set) var entries: [GlossaryEntry]

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    if let data = defaults.data(forKey: key),
       let decoded = try? JSONDecoder().decode([GlossaryEntry].self, from: data) {
      entries = decoded
    } else {
      entries = []
    }
  }

  func add(de: String, uk: String) {
    entries.append(GlossaryEntry(de: de, uk: uk)); persist()
  }
  func remove(_ entry: GlossaryEntry) {
    entries.removeAll { $0.id == entry.id }; persist()
  }

  /// Glossary rendered for the translation system prompt.
  func promptLines() -> String {
    entries.map { "\($0.de) ↔ \($0.uk)" }.joined(separator: "\n")
  }

  private func persist() {
    if let data = try? JSONEncoder().encode(entries) {
      defaults.set(data, forKey: key)
    }
  }
}
```

- [ ] **Step 5: Run — must pass.** Same `xcodebuild ... test`. Expected: PASS.

- [ ] **Step 6: Commit**

```bash
cd "$DISPO"
git add apps/atolltalk-native/AtollTalk/Models/GlossaryEntry.swift apps/atolltalk-native/AtollTalk/Stores/GlossaryStore.swift apps/atolltalk-native/AtollTalkTests/GlossaryStoreTests.swift
git commit -m "feat(atolltalk): editable glossary store (TDD)"
```
---

## Phase 3 — Services

### Task 9: `AudioRecorder` (iOS) + WAV-export characterization test

**Files:**
- Create: `apps/atolltalk-native/AtollTalk/Services/AudioRecorder.swift`
- Test: `swift-packages/AtollSpeech/Tests/AtollSpeechTests/WAVExportTests.swift`

- [ ] **Step 1: Lock `exportWAV` behavior with a characterization test (no mic needed)**

`swift-packages/AtollSpeech/Tests/AtollSpeechTests/WAVExportTests.swift`:
```swift
import Testing
import AVFoundation
@testable import AtollSpeech

@Suite struct WAVExportTests {
  @Test func exportsRiffWavHeaderAt16k() throws {
    let acc = AudioBufferAccumulator()
    let fmt = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 1)!
    let frames: AVAudioFrameCount = 4800            // 0.1s
    let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: frames)!
    buf.frameLength = frames
    for i in 0..<Int(frames) {
      buf.floatChannelData![0][i] = sinf(Float(i) * 0.05) * 0.2
    }
    acc.append(buf)

    let wav = try #require(acc.exportWAV(sampleRate: 16000, channels: 1))
    #expect(wav.count > 44)
    #expect(wav.prefix(4) == Data("RIFF".utf8))
    #expect(wav.subdata(in: 8..<12) == Data("WAVE".utf8))
  }
}
```

- [ ] **Step 2: Run the AtollSpeech package tests — must pass**

Run: `cd "$DISPO" && swift test --package-path swift-packages/AtollSpeech`
Expected: PASS (locks the 16 kHz mono WAV contract AudioRecorder relies on).

- [ ] **Step 3: Implement the iOS `AudioRecorder`**

`apps/atolltalk-native/AtollTalk/Services/AudioRecorder.swift`:
```swift
import Foundation
import AVFoundation
import AtollSpeech
import OSLog

@MainActor
final class AudioRecorder {
  enum RecorderError: Error { case permissionDenied, inputUnavailable }

  private let engine = AVAudioEngine()
  private let accumulator = AudioBufferAccumulator()
  private var isRunning = false
  private let log = Logger(subsystem: "swiss.atoll.talk", category: "audio")

  /// iOS 17+ permission request.
  func requestPermission() async -> Bool {
    await AVAudioApplication.requestRecordPermission()
  }

  func start() async throws {
    guard !isRunning else { return }
    guard await requestPermission() else { throw RecorderError.permissionDenied }

    let session = AVAudioSession.sharedInstance()
    try session.setCategory(.playAndRecord, mode: .spokenAudio,
                            options: [.defaultToSpeaker, .allowBluetooth])
    try session.setActive(true)

    accumulator.reset()
    let input = engine.inputNode
    let format = input.outputFormat(forBus: 0)
    guard format.sampleRate > 0, format.channelCount > 0 else {
      throw RecorderError.inputUnavailable
    }

    let acc = accumulator
    let block: @Sendable (AVAudioPCMBuffer, AVAudioTime) -> Void = { buffer, _ in
      acc.append(buffer)        // accumulator is @unchecked Sendable + lock-guarded
    }
    input.installTap(onBus: 0, bufferSize: 1024, format: format, block: block)
    engine.prepare()
    try engine.start()
    isRunning = true
    log.debug("recording started")
  }

  /// Stop and return 16 kHz mono WAV ready for Scribe (nil if no audio).
  func stop() -> Data? {
    guard isRunning else { return nil }
    engine.stop()
    engine.inputNode.removeTap(onBus: 0)
    isRunning = false
    try? AVAudioSession.sharedInstance()
      .setActive(false, options: [.notifyOthersOnDeactivation])
    return accumulator.exportWAV(sampleRate: 16000, channels: 1)
  }
}
```

- [ ] **Step 4: Build the app (recorder needs a device/mic for real audio — verified manually in Task 16 device run)**

Run: `cd "$DISPO/apps/atolltalk-native" && xcodegen generate && xcodebuild -project AtollTalk.xcodeproj -scheme AtollTalk -destination 'platform=iOS Simulator,name=iPhone 16' build`
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 5: Commit**

```bash
cd "$DISPO"
git add apps/atolltalk-native/AtollTalk/Services/AudioRecorder.swift swift-packages/AtollSpeech/Tests/AtollSpeechTests/WAVExportTests.swift
git commit -m "feat(atolltalk): iOS AudioRecorder (16kHz mono WAV) + WAV export test"
```

### Task 10: `SpeechService` — transcribe → text + detected language (TDD)

**Files:**
- Create: `apps/atolltalk-native/AtollTalk/Services/SpeechService.swift`
- Test: `apps/atolltalk-native/AtollTalkTests/SpeechServiceTests.swift`
- Test helper: `apps/atolltalk-native/AtollTalkTests/MockURLProtocol.swift`

- [ ] **Step 1: Add the `MockURLProtocol` test helper**

`apps/atolltalk-native/AtollTalkTests/MockURLProtocol.swift`:
```swift
import Foundation

final class MockURLProtocol: URLProtocol {
  nonisolated(unsafe) static var responder: ((URLRequest) -> (Data, Int))?

  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for r: URLRequest) -> URLRequest { r }
  override func startLoading() {
    let (data, status) = Self.responder?(request) ?? (Data(), 500)
    let resp = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
    client?.urlProtocol(self, didReceive: resp, cacheStoragePolicy: .notAllowed)
    client?.urlProtocol(self, didLoad: data)
    client?.urlProtocolDidFinishLoading(self)
  }
  override func stopLoading() {}

  static func session() -> URLSession {
    let cfg = URLSessionConfiguration.ephemeral
    cfg.protocolClasses = [MockURLProtocol.self]
    return URLSession(configuration: cfg)
  }
}
```

- [ ] **Step 2: Write the failing test**

`apps/atolltalk-native/AtollTalkTests/SpeechServiceTests.swift`:
```swift
import Testing
import Foundation
import AtollSpeech
@testable import AtollTalk

@Suite struct SpeechServiceTests {
  @Test func transcribeMapsTextAndLanguage() async throws {
    MockURLProtocol.responder = { _ in
      let body = #"{"text":"Доброго дня","language_code":"ukr","language_probability":0.98}"#
      return (Data(body.utf8), 200)
    }
    let client = ElevenLabsClient(apiKey: "x", session: MockURLProtocol.session())
    let service = SpeechService(client: client)
    let result = try await service.transcribe(wav: Data([0,1,2,3]))
    #expect(result.text == "Доброго дня")
    #expect(result.language == .uk)
  }
}
```

- [ ] **Step 3: Run — must fail (no `SpeechService`).** Same `xcodebuild ... test`. Expected: FAIL.

- [ ] **Step 4: Implement `SpeechService.swift`**

```swift
import Foundation
import AtollSpeech

struct SpeechResult: Equatable, Sendable {
  let text: String
  let language: AppLanguage?
}

struct SpeechService: Sendable {
  let client: ElevenLabsClient
  let modelID: String

  init(apiKey: String, modelID: String = Config.scribeModelID, session: URLSession = .shared) {
    self.client = ElevenLabsClient(apiKey: apiKey, session: session)
    self.modelID = modelID
  }

  /// Test seam — inject a client wired to a mocked URLSession.
  init(client: ElevenLabsClient, modelID: String = Config.scribeModelID) {
    self.client = client
    self.modelID = modelID
  }

  func transcribe(wav: Data) async throws -> SpeechResult {
    let t = try await client.transcribe(audioData: wav, modelID: modelID)
    let lang = t.languageCode.flatMap { AppLanguage(scribeCode: $0) }
    return SpeechResult(text: t.text, language: lang)
  }
}
```

- [ ] **Step 5: Run — must pass.** Same `xcodebuild ... test`. Expected: PASS.

- [ ] **Step 6: Commit**

```bash
cd "$DISPO"
git add apps/atolltalk-native/AtollTalk/Services/SpeechService.swift apps/atolltalk-native/AtollTalkTests/SpeechServiceTests.swift apps/atolltalk-native/AtollTalkTests/MockURLProtocol.swift
git commit -m "feat(atolltalk): SpeechService (Scribe → text + detected language, TDD)"
```

### Task 11: `TranslationService` — Claude with kitchen context + glossary (TDD)

**Files:**
- Create: `apps/atolltalk-native/AtollTalk/Services/TranslationService.swift`
- Test: `apps/atolltalk-native/AtollTalkTests/TranslationServiceTests.swift`

- [ ] **Step 1: Write the failing tests (prompt builder + stream accumulation)**

`apps/atolltalk-native/AtollTalkTests/TranslationServiceTests.swift`:
```swift
import Testing
import Foundation
import AtollLLM
@testable import AtollTalk

private struct MockLLMProvider: LLMProvider {
  let chunks: [LLMChunk]
  func streamChat(messages: [LLMMessage], tools: [LLMTool], model: String, systemPrompt: String?)
    -> AsyncThrowingStream<LLMChunk, Error> {
    AsyncThrowingStream { cont in
      for c in chunks { cont.yield(c) }
      cont.finish()
    }
  }
}

@Suite struct TranslationServiceTests {
  @Test func systemPromptCarriesTargetAndGlossary() {
    let p = TranslationService.systemPrompt(
      context: "KÜCHENKONTEXT", glossary: "Maria ↔ Марія", target: .uk)
    #expect(p.contains("KÜCHENKONTEXT"))
    #expect(p.contains("Українська"))
    #expect(p.contains("Maria ↔ Марія"))
  }

  @Test func translateAccumulatesTextChunks() async throws {
    let provider = MockLLMProvider(chunks: [.text("При"), .text("віт"), .done])
    let service = TranslationService(provider: provider)
    let out = try await service.translate("Hallo", to: .uk, context: "x", glossary: "")
    #expect(out == "Привіт")
  }
}
```

- [ ] **Step 2: Run — must fail.** Same `xcodebuild ... test`. Expected: FAIL.

- [ ] **Step 3: Implement `TranslationService.swift`**

```swift
import Foundation
import AtollLLM

struct TranslationService: Sendable {
  let provider: any LLMProvider
  let model: String

  init(apiKey: String, model: String = Config.defaultModel, session: URLSession = .shared) {
    self.provider = AnthropicProvider(apiKey: apiKey, session: session)
    self.model = model
  }

  /// Test seam — inject a mock provider.
  init(provider: any LLMProvider, model: String = Config.defaultModel) {
    self.provider = provider
    self.model = model
  }

  static func systemPrompt(context: String, glossary: String, target: AppLanguage) -> String {
    var p = context
    p += "\n\nÜbersetze den folgenden Text nach \(target.displayName) (Code: \(target.rawValue))."
    if !glossary.isEmpty {
      p += "\n\nGlossar — diese Begriffe immer so übersetzen:\n\(glossary)"
    }
    return p
  }

  func translate(
    _ text: String, to target: AppLanguage, context: String, glossary: String
  ) async throws -> String {
    let system = Self.systemPrompt(context: context, glossary: glossary, target: target)
    let stream = provider.streamChat(
      messages: [LLMMessage(role: .user, content: text)],
      tools: [],
      model: model,
      systemPrompt: system
    )
    var out = ""
    for try await chunk in stream {
      if case let .text(t) = chunk { out += t }
    }
    return out.trimmingCharacters(in: .whitespacesAndNewlines)
  }
}
```

- [ ] **Step 4: Run — must pass.** Same `xcodebuild ... test`. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
cd "$DISPO"
git add apps/atolltalk-native/AtollTalk/Services/TranslationService.swift apps/atolltalk-native/AtollTalkTests/TranslationServiceTests.swift
git commit -m "feat(atolltalk): TranslationService (Claude + kitchen context + glossary, TDD)"
```

### Task 12: `SynthesisService` — ElevenLabs voice with Apple fallback

**Files:**
- Create: `apps/atolltalk-native/AtollTalk/Services/SynthesisService.swift`

(No unit test — audio playback is verified manually on device in Task 16. Logic is thin routing over the already-tested `CompositeSynthesizer`.)

- [ ] **Step 1: Implement `SynthesisService.swift`**

```swift
import Foundation
import AVFoundation
import AtollSpeech

@MainActor
final class SynthesisService {
  private let composite: CompositeSynthesizer
  private let elevenVoiceByLang: [AppLanguage: String]

  /// - elevenLabsKey: ElevenLabs API key; empty/nil → Apple-only fallback.
  /// - voices: ElevenLabs voice id per language (from Settings).
  init(elevenLabsKey: String?, voices: [AppLanguage: String], session: URLSession = .shared) {
    self.elevenVoiceByLang = voices
    let apple = AppleSynthesizer()
    if let key = elevenLabsKey, !key.isEmpty {
      let client = ElevenLabsClient(apiKey: key, session: session)
      let seed = voices[.uk] ?? voices[.de] ?? ""
      let eleven = ElevenLabsSynthesizer(client: client, defaultVoiceID: seed)
      composite = CompositeSynthesizer(
        apple: apple, elevenLabs: eleven,
        provider: seed.isEmpty ? .apple : .elevenLabs)
    } else {
      composite = CompositeSynthesizer(apple: apple, elevenLabs: nil, provider: .apple)
    }
  }

  func speak(_ text: String, in lang: AppLanguage) {
    switch composite.currentProvider {
    case .elevenLabs:
      if let v = elevenVoiceByLang[lang], !v.isEmpty {
        composite.setVoice(identifier: v)
      }
    case .apple:
      if let id = Self.appleVoiceIdentifier(for: lang) {
        composite.setVoice(identifier: id)
      }
    }
    composite.speak(text)
  }

  func stop() { composite.stop() }

  /// Resolve a concrete installed Apple voice for the language, if any.
  /// Returns nil when no voice for that locale is installed (e.g. no
  /// Ukrainian voice) — surfaced to the user in Task 16's error handling.
  static func appleVoiceIdentifier(for lang: AppLanguage) -> String? {
    AVSpeechSynthesisVoice.speechVoices()
      .first { $0.language.hasPrefix(lang.appleLocale) }?
      .identifier
  }
}
```

- [ ] **Step 2: Build the app**

Run: `cd "$DISPO/apps/atolltalk-native" && xcodegen generate && xcodebuild -project AtollTalk.xcodeproj -scheme AtollTalk -destination 'platform=iOS Simulator,name=iPhone 16' build`
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Commit**

```bash
cd "$DISPO"
git add apps/atolltalk-native/AtollTalk/Services/SynthesisService.swift
git commit -m "feat(atolltalk): SynthesisService (ElevenLabs voice + Apple fallback)"
```
---

## Phase 4 — ViewModel, UI, wiring

### Task 13: `AppViewModel` — pipeline state machine (TDD)

**Files:**
- Create: `apps/atolltalk-native/AtollTalk/ViewModel/AppViewModel.swift`
- Test: `apps/atolltalk-native/AtollTalkTests/AppViewModelTests.swift`

- [ ] **Step 1: Write the failing test (core process pipeline with mocks)**

`apps/atolltalk-native/AtollTalkTests/AppViewModelTests.swift`:
```swift
import Testing
import Foundation
import SwiftData
import AtollSpeech
import AtollLLM
@testable import AtollTalk

private struct StubLLM: LLMProvider {
  let chunks: [LLMChunk]
  func streamChat(messages: [LLMMessage], tools: [LLMTool], model: String, systemPrompt: String?)
    -> AsyncThrowingStream<LLMChunk, Error> {
    AsyncThrowingStream { c in chunks.forEach { c.yield($0) }; c.finish() }
  }
}

@MainActor @Suite struct AppViewModelTests {
  private func makeVM(scribeJSON: String, llm: [LLMChunk]) throws -> (AppViewModel, ConversationStore) {
    MockURLProtocol.responder = { _ in (Data(scribeJSON.utf8), 200) }
    let client = ElevenLabsClient(apiKey: "x", session: MockURLProtocol.session())
    let container = try ModelContainer(for: Turn.self,
      configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let store = ConversationStore(context: container.mainContext)
    let vm = AppViewModel(
      recorder: AudioRecorder(),
      speech: SpeechService(client: client),
      translator: TranslationService(provider: StubLLM(chunks: llm)),
      synthesis: SynthesisService(elevenLabsKey: nil, voices: [:]),
      store: store,
      context: "ctx",
      glossaryLines: { "" }
    )
    return (vm, store)
  }

  @Test func ukrainianInputProducesGermanTurn() async throws {
    let (vm, store) = try makeVM(
      scribeJSON: #"{"text":"Доброго дня","language_code":"ukr"}"#,
      llm: [.text("Guten Tag"), .done])
    await vm.process(wav: Data([1,2,3]))
    let turns = try store.allNewestFirst()
    #expect(turns.count == 1)
    #expect(turns.first?.sourceLang == .uk)
    #expect(turns.first?.targetLang == .de)
    #expect(turns.first?.targetText == "Guten Tag")
    #expect(vm.phase == .idle)
  }

  @Test func emptyTranscriptSurfacesError() async throws {
    let (vm, _) = try makeVM(scribeJSON: #"{"text":"","language_code":"deu"}"#, llm: [.done])
    await vm.process(wav: Data([1]))
    if case .error = vm.phase { } else { Issue.record("expected .error phase") }
  }
}
```

- [ ] **Step 2: Run — must fail.** Same `xcodebuild ... test`. Expected: FAIL.

- [ ] **Step 3: Implement `AppViewModel.swift`**

```swift
import Foundation
import Observation

@MainActor @Observable
final class AppViewModel {
  enum Phase: Equatable { case idle, recording, transcribing, translating, error(String) }

  private(set) var phase: Phase = .idle
  var pair = LanguagePair(a: .de, b: .uk)

  private let recorder: AudioRecorder
  private let speech: SpeechService
  private let translator: TranslationService
  private let synthesis: SynthesisService
  private let store: ConversationStore
  private let context: String
  private let glossaryLines: () -> String

  init(
    recorder: AudioRecorder,
    speech: SpeechService,
    translator: TranslationService,
    synthesis: SynthesisService,
    store: ConversationStore,
    context: String,
    glossaryLines: @escaping () -> String
  ) {
    self.recorder = recorder
    self.speech = speech
    self.translator = translator
    self.synthesis = synthesis
    self.store = store
    self.context = context
    self.glossaryLines = glossaryLines
  }

  func toggleRecording() async {
    switch phase {
    case .idle:      await startRecording()
    case .recording: await stopAndProcess()
    default:         break
    }
  }

  func startRecording() async {
    do { try await recorder.start(); phase = .recording }
    catch { phase = .error(Self.message(for: error)) }
  }

  func stopAndProcess() async {
    guard let wav = recorder.stop() else {
      phase = .error("Keine Aufnahme erkannt — bitte nochmal."); return
    }
    await process(wav: wav)
  }

  /// Testable core: transcribe → route → translate → persist.
  func process(wav: Data) async {
    phase = .transcribing
    do {
      let result = try await speech.transcribe(wav: wav)
      guard !result.text.isEmpty else {
        phase = .error("Nichts verstanden — bitte nochmal sprechen."); return
      }
      guard let detected = result.language,
            let route = LanguageRouter.route(detected: detected, in: pair) else {
        phase = .error("Sprache nicht erkannt oder nicht im Paar."); return
      }
      phase = .translating
      let translated = try await translator.translate(
        result.text, to: route.target, context: context, glossary: glossaryLines())
      store.add(Turn(
        sourceText: result.text, sourceLang: route.source,
        targetText: translated, targetLang: route.target))
      phase = .idle
    } catch {
      phase = .error(Self.message(for: error))
    }
  }

  func speak(_ turn: Turn) { synthesis.speak(turn.targetText, in: turn.targetLang) }

  static func message(for error: Error) -> String {
    if let e = error as? AudioRecorder.RecorderError {
      switch e {
      case .permissionDenied: return "Mikrofon-Zugriff fehlt. Bitte in den iOS-Einstellungen erlauben."
      case .inputUnavailable: return "Mikrofon ist nicht verfügbar."
      }
    }
    return "Ein Fehler ist aufgetreten: \(error.localizedDescription)"
  }
}
```

- [ ] **Step 4: Run — must pass.** Same `xcodebuild ... test`. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
cd "$DISPO"
git add apps/atolltalk-native/AtollTalk/ViewModel/AppViewModel.swift apps/atolltalk-native/AtollTalkTests/AppViewModelTests.swift
git commit -m "feat(atolltalk): AppViewModel pipeline state machine (TDD)"
```

### Task 14: Conversation UI (mockup) — header, big-text turn cards, record button

**Files:**
- Create: `apps/atolltalk-native/AtollTalk/Views/ConversationView.swift`
- Create: `apps/atolltalk-native/AtollTalk/Views/TurnCardView.swift`
- Create: `apps/atolltalk-native/AtollTalk/Views/RecordButton.swift`

(SwiftUI views — verified visually in the simulator build here, fully on device in Task 16.)

- [ ] **Step 1: Implement `TurnCardView.swift`**

```swift
import SwiftUI

struct TurnCardView: View {
  let turn: Turn
  let prominent: Bool
  let onSpeak: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 6) {
        Text(turn.sourceLang.flag)
        Text(turn.sourceText)
          .foregroundStyle(Color.textTertiary)
          .lineLimit(prominent ? 3 : 1)
      }
      .font(prominent ? .body : .footnote)

      Text("\(turn.targetLang.flag) \(turn.targetLang.displayName.uppercased())")
        .font(.caption.weight(.semibold))
        .foregroundStyle(Color.brandBlue)

      Text(turn.targetText)
        .font(prominent ? .system(size: 30, weight: .bold) : .headline)
        .foregroundStyle(Color.textPrimary)
        .fixedSize(horizontal: false, vertical: true)

      if prominent {
        Button(action: onSpeak) {
          Label("Vorlesen", systemImage: "speaker.wave.2.fill")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(Color.brandBlue)
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .opacity(prominent ? 1 : 0.55)
  }
}
```

- [ ] **Step 2: Implement `RecordButton.swift`**

```swift
import SwiftUI

struct RecordButton: View {
  let phase: AppViewModel.Phase
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 10) {
        Image(systemName: phase == .recording ? "stop.fill" : "mic.fill")
        Text(label)
      }
      .font(.title3.weight(.semibold))
      .frame(maxWidth: .infinity)
      .padding(.vertical, 18)
      .background(background, in: .rect(cornerRadius: 18))
      .foregroundStyle(.white)
    }
    .disabled(isBusy)
  }

  private var label: String {
    switch phase {
    case .recording:    "Stopp"
    case .transcribing: "Höre zu…"
    case .translating:  "Übersetze…"
    default:            "Sprechen"
    }
  }
  private var background: Color { phase == .recording ? Color(hex: 0xA32D2D) : .brandBlue }
  private var isBusy: Bool {
    switch phase { case .transcribing, .translating: return true; default: return false }
  }
}
```

- [ ] **Step 3: Implement `ConversationView.swift`**

```swift
import SwiftUI
import SwiftData

struct ConversationView: View {
  @Query(sort: \Turn.createdAt, order: .reverse) private var turns: [Turn]
  let vm: AppViewModel
  let onSettings: () -> Void

  var body: some View {
    VStack(spacing: 0) {
      header
      Divider()
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 26) {
          ForEach(Array(turns.enumerated()), id: \.element.id) { idx, turn in
            TurnCardView(turn: turn, prominent: idx == 0) { vm.speak(turn) }
          }
        }
        .padding(20)
      }
      .overlay { if turns.isEmpty { hint } }
      RecordButton(phase: vm.phase) { Task { await vm.toggleRecording() } }
        .padding(20)
    }
    .background(Color(hex: 0xFAF9F4))
  }

  private var header: some View {
    HStack(spacing: 8) {
      Text(vm.pair.a.flag)
      Image(systemName: "arrow.left.arrow.right").foregroundStyle(Color.textTertiary)
      Text(vm.pair.b.flag)
      Text("Automatisch").font(.subheadline.weight(.medium)).foregroundStyle(Color.textSecondary)
      Spacer()
      Button(action: onSettings) { Image(systemName: "gearshape.fill").foregroundStyle(Color.textSecondary) }
    }
    .padding(.horizontal, 16).padding(.vertical, 10)
  }

  private var hint: some View {
    VStack(spacing: 8) {
      Image(systemName: "mic.circle").font(.system(size: 44)).foregroundStyle(Color.brandBlue)
      Text("Tippe auf „Sprechen" und leg los.").foregroundStyle(Color.textSecondary)
    }
  }
}
```

- [ ] **Step 4: Build (simulator) to confirm the views compile & lay out**

Run: `cd "$DISPO/apps/atolltalk-native" && xcodegen generate && xcodebuild -project AtollTalk.xcodeproj -scheme AtollTalk -destination 'platform=iOS Simulator,name=iPhone 16' build`
Expected: `BUILD SUCCEEDED`.

- [ ] **Step 5: Commit**

```bash
cd "$DISPO"
git add apps/atolltalk-native/AtollTalk/Views/ConversationView.swift apps/atolltalk-native/AtollTalk/Views/TurnCardView.swift apps/atolltalk-native/AtollTalk/Views/RecordButton.swift
git commit -m "feat(atolltalk): conversation UI per mockup (big translation, Vorlesen, Sprechen)"
```

### Task 15: `SettingsStore` + `SettingsView` (keys, model, voices, glossary)

**Files:**
- Create: `apps/atolltalk-native/AtollTalk/Stores/SettingsStore.swift`
- Create: `apps/atolltalk-native/AtollTalk/Views/SettingsView.swift`

- [ ] **Step 1: Implement `SettingsStore.swift`**

```swift
import Foundation
import Observation

@MainActor @Observable
final class SettingsStore {
  private let defaults: UserDefaults
  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    model     = defaults.string(forKey: "model") ?? Config.defaultModel
    voiceDE   = defaults.string(forKey: "voice.de") ?? ""
    voiceUK   = defaults.string(forKey: "voice.uk") ?? ""
    context   = defaults.string(forKey: "context") ?? Config.defaultContext
  }

  var model: String   { didSet { defaults.set(model, forKey: "model") } }
  var voiceDE: String { didSet { defaults.set(voiceDE, forKey: "voice.de") } }
  var voiceUK: String { didSet { defaults.set(voiceUK, forKey: "voice.uk") } }
  var context: String { didSet { defaults.set(context, forKey: "context") } }

  var voices: [AppLanguage: String] { [.de: voiceDE, .uk: voiceUK] }
  var modelOptions: [String] { [Config.defaultModel, Config.fastModel] }
}
```

- [ ] **Step 2: Implement `SettingsView.swift`**

```swift
import SwiftUI

struct SettingsView: View {
  @Environment(\.dismiss) private var dismiss
  let secrets: SecretStore
  let settings: SettingsStore
  let glossary: GlossaryStore

  @State private var elevenKey = ""
  @State private var anthropicKey = ""
  @State private var newDE = ""
  @State private var newUK = ""

  var body: some View {
    NavigationStack {
      Form {
        Section("API-Schlüssel") {
          SecureField("ElevenLabs API-Key", text: $elevenKey)
          SecureField("Anthropic API-Key", text: $anthropicKey)
        }
        Section("Übersetzungsmodell") {
          Picker("Claude-Modell", selection: Binding(
            get: { settings.model }, set: { settings.model = $0 })) {
            ForEach(settings.modelOptions, id: \.self) { Text($0).tag($0) }
          }
        }
        Section("Stimmen (ElevenLabs Voice-IDs)") {
          TextField("Voice-ID Deutsch", text: Binding(
            get: { settings.voiceDE }, set: { settings.voiceDE = $0 }))
          TextField("Voice-ID Ukrainisch", text: Binding(
            get: { settings.voiceUK }, set: { settings.voiceUK = $0 }))
        }
        Section("Glossar") {
          ForEach(glossary.entries) { e in
            HStack { Text(e.de); Spacer(); Text(e.uk).foregroundStyle(.secondary) }
          }
          .onDelete { idx in idx.map { glossary.entries[$0] }.forEach(glossary.remove) }
          HStack {
            TextField("Deutsch", text: $newDE)
            TextField("Українська", text: $newUK)
            Button("＋") {
              guard !newDE.isEmpty, !newUK.isEmpty else { return }
              glossary.add(de: newDE, uk: newUK); newDE = ""; newUK = ""
            }
          }
        }
        Section("Kontext") {
          TextEditor(text: Binding(get: { settings.context }, set: { settings.context = $0 }))
            .frame(minHeight: 100)
        }
      }
      .navigationTitle("Einstellungen")
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Fertig") {
            secrets.set(elevenKey.isEmpty ? nil : elevenKey, for: .elevenLabsAPIKey)
            secrets.set(anthropicKey.isEmpty ? nil : anthropicKey, for: .anthropicAPIKey)
            dismiss()
          }
        }
      }
      .onAppear {
        elevenKey = secrets.value(for: .elevenLabsAPIKey) ?? ""
        anthropicKey = secrets.value(for: .anthropicAPIKey) ?? ""
      }
    }
  }
}
```

- [ ] **Step 3: Build (simulator).** Same `xcodegen generate && xcodebuild ... build`. Expected: `BUILD SUCCEEDED`.

- [ ] **Step 4: Commit**

```bash
cd "$DISPO"
git add apps/atolltalk-native/AtollTalk/Stores/SettingsStore.swift apps/atolltalk-native/AtollTalk/Views/SettingsView.swift
git commit -m "feat(atolltalk): settings (keys, model, voices, glossary, context)"
```

### Task 16: Wire `AtollTalkApp` (SwiftData + DI + Settings + error alert) — full device run

**Files:**
- Modify: `apps/atolltalk-native/AtollTalk/AtollTalkApp.swift`
- Modify: `apps/atolltalk-native/AtollTalk/Views/RootView.swift`

- [ ] **Step 1: Implement `AtollTalkApp.swift` (SwiftData container + shared stores)**

```swift
import SwiftUI
import SwiftData

@main
struct AtollTalkApp: App {
  @State private var settings = SettingsStore()
  @State private var glossary = GlossaryStore()
  let container: ModelContainer

  init() {
    container = try! ModelContainer(for: Turn.self)
  }

  var body: some Scene {
    WindowGroup {
      RootView(settings: settings, glossary: glossary)
        .modelContainer(container)
    }
  }
}
```

- [ ] **Step 2: Implement `RootView.swift` (build VM from current secrets, Settings sheet, error alert, key-missing nudge)**

```swift
import SwiftUI
import SwiftData

struct RootView: View {
  @Environment(\.modelContext) private var modelContext
  let settings: SettingsStore
  let glossary: GlossaryStore

  private let secrets: SecretStore = KeychainSecretStore()
  @State private var vm: AppViewModel?
  @State private var showSettings = false

  var body: some View {
    Group {
      if let vm {
        ConversationView(vm: vm) { showSettings = true }
          .alert("Hinweis", isPresented: errorBinding(vm)) {
            Button("OK", role: .cancel) {}
          } message: { Text(errorText(vm)) }
      } else {
        ProgressView()
      }
    }
    .task { rebuild() }
    .sheet(isPresented: $showSettings, onDismiss: rebuild) {
      SettingsView(secrets: secrets, settings: settings, glossary: glossary)
    }
    .overlay(alignment: .top) {
      if !hasKeys { keyBanner }
    }
  }

  private var hasKeys: Bool {
    (secrets.value(for: .elevenLabsAPIKey)?.isEmpty == false) &&
    (secrets.value(for: .anthropicAPIKey)?.isEmpty == false)
  }

  private var keyBanner: some View {
    Button { showSettings = true } label: {
      Text("API-Schlüssel fehlen — hier eintragen")
        .font(.footnote.weight(.medium))
        .padding(8).frame(maxWidth: .infinity)
        .background(Color.brandBlue50)
        .foregroundStyle(Color.brandBlue)
    }
    .buttonStyle(.plain)
  }

  private func rebuild() {
    let el = secrets.value(for: .elevenLabsAPIKey) ?? ""
    let an = secrets.value(for: .anthropicAPIKey) ?? ""
    vm = AppViewModel(
      recorder: AudioRecorder(),
      speech: SpeechService(apiKey: el),
      translator: TranslationService(apiKey: an, model: settings.model),
      synthesis: SynthesisService(elevenLabsKey: el, voices: settings.voices),
      store: ConversationStore(context: modelContext),
      context: settings.context,
      glossaryLines: { glossary.promptLines() }
    )
  }

  private func errorBinding(_ vm: AppViewModel) -> Binding<Bool> {
    Binding(get: { if case .error = vm.phase { return true } else { return false } },
            set: { if !$0 { vm.phaseResetToIdle() } })
  }
  private func errorText(_ vm: AppViewModel) -> String {
    if case let .error(msg) = vm.phase { return msg }; return ""
  }
}
```

- [ ] **Step 3: Add `phaseResetToIdle()` to `AppViewModel`**

Append to `AppViewModel`:
```swift
  func phaseResetToIdle() { if case .error = phase { phase = .idle } }
```

- [ ] **Step 4: Build + run all tests**

Run: `cd "$DISPO/apps/atolltalk-native" && xcodegen generate && xcodebuild -project AtollTalk.xcodeproj -scheme AtollTalk -destination 'platform=iOS Simulator,name=iPhone 16' test`
Expected: `BUILD SUCCEEDED`, all unit suites PASS.

- [ ] **Step 5: Manual device verification (the spec's real-audio test)**

On a physical iPhone (Scribe/Claude need network; mic needs a device):
1. Run the app, open Settings, paste the ElevenLabs + Anthropic keys, add a glossary entry `Maria ↔ Марія`, tap Fertig.
2. Tap "Sprechen", say a German sentence, tap "Stopp". Expect: Ukrainian appears large, German small above; tap "Vorlesen" → hears Ukrainian.
3. Tap "Sprechen", speak Ukrainian, stop. Expect: German large; direction flipped automatically.
4. Test in the noisy kitchen with Maria. Note any mis-recognitions to tune the context/glossary.
5. Revoke mic permission in iOS Settings → confirm the friendly permission error appears.

- [ ] **Step 6: Commit**

```bash
cd "$DISPO"
git add apps/atolltalk-native/AtollTalk/AtollTalkApp.swift apps/atolltalk-native/AtollTalk/Views/RootView.swift apps/atolltalk-native/AtollTalk/ViewModel/AppViewModel.swift
git commit -m "feat(atolltalk): wire app (SwiftData, DI, settings, error alert, key nudge)"
```

---

## Self-Review (spec coverage)

- Two-way auto (spec §6, §7) → Task 2 (Scribe language) + Task 5 (`LanguageRouter`) + Task 13 (`process`).
- ElevenLabs STT (spec §4) → Task 2 + Task 10. Claude MT with context+glossary (spec §4) → Task 8 + Task 11. ElevenLabs TTS + Apple fallback (spec §4) → Task 12.
- Mockup UI: big translation, muted source, per-turn Vorlesen, Sprechen button, header (spec §6) → Task 14.
- Keychain keys, no backend, `APIClient`-style seam (spec §4, §10) → Task 6 + service `init`s (URLSession-injectable) + Task 16.
- Language extensibility (spec §8) → `AppLanguage` enum + `LanguagePair`; adding a case + voice id extends the app. (`AppLanguage(scribeCode:)` covers de/uk; extend the prefix map per language.)
- Errors (spec §9) → Task 13 messages + Task 16 alert/permission/key-missing banner.
- Tests (spec §11) → Tasks 2,5,6,7,8,9,10,11,13 (unit) + Task 16 step 5 (manual real-audio).
- Open points carried forward: (1) confirm Scribe-v2 `model_id` (Config.scribeModelID / `transcribe(modelID:)`); (3) real ElevenLabs voice IDs for DE & UA (Settings). (2 resolved: default `claude-sonnet-4-6`.)

## Notes for the implementer

- Two `swiss.weckherlin.tide` logger subsystem strings remain in the copied `AtollSpeech` files — cosmetic; leave or rename to `swiss.atoll` in a cleanup pass.
- If the repo's test standard is XCTest rather than Swift Testing, mirror that — the assertions map 1:1 (`#expect` → `XCTAssert`).
- Keep network calls flowing through the service `init(apiKey:…, session:)` seam so the future Supabase proxy is a one-file change.
