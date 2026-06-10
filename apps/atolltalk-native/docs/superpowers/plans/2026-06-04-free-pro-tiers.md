# AtollTalk Free/Pro Tiers — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use **superpowers:subagent-driven-development** (empfohlen) oder **superpowers:executing-plans**, um diesen Plan Task für Task umzusetzen. Schritte nutzen Checkbox-Syntax (`- [ ]`).

**Goal:** AtollTalk bekommt einen kostenlosen **Basic**-Tier (Apple-On-Device-Übersetzung, keine Claude-Kosten) und einen **Pro**-Tier (Claude-Übersetzung + ElevenLabs-Stimmen) mit Monats-/Jahresabo über StoreKit 2.

**Architecture:** Der Tier-Schalter sitzt am **Übersetzungsschritt**. `isPro` (StoreKit 2) entscheidet im Composition-Root (`RootView.rebuild()`), ob ein `AppleTranslator` (Basic, on-device) oder der bestehende Claude-`TranslationService` (Pro) als `any Translator` injiziert wird. STT (ElevenLabs Scribe) und der Turn-Flow bleiben unverändert. Pro-Sprachen (Tagalog/Bisaya) sind nur mit Pro wählbar; fehlt eine TTS-Stimme, gibt es **still nur Text**.

**Tech Stack:** SwiftUI, iOS 26, Swift 6 (`SWIFT_STRICT_CONCURRENCY: complete`), **Swift Testing**, StoreKit 2, Apple **Translation**-Framework, Packages `AtollLLM`/`AtollSpeech`/`AtollDesign`, Supabase Edge Functions (Phase 4).

**Baut auf:** `docs/superpowers/specs/2026-06-02-atolltalk-design.md` (v1). Dies ist die **v2-Produktisierung** (Tiers + App-Store-Release), die v1 ausdrücklich als Nicht-Ziel führte. Rationale & Markt/Pricing: PKA `Deliverables/2026-06-04-atolltalk-free-pro-architecture.md`.

---

## Vor dem Start — Realitäts-Check (bitte lesen)

- **Der Code ist aktiv in Entwicklung.** Signaturen können seit Planerstellung abweichen. **Jede Task beginnt mit dem Lesen der aktuellen Datei**, bevor du editierst. Code-Blöcke hier sind Referenz, an die reale Signatur anpassen.
- **Package-Interna** (`AtollLLM`/`AtollSpeech` unter `Dispo/swift-packages/`) gegenprüfen — Phase 0 verifiziert die genutzten Typen.
- **Tests:** Swift Testing (`import Testing`, `@Test`, `#expect`, `@Suite(.serialized)`). Muster: `AtollTalkTests/AppViewModelTests.swift` (`StubLLM`, `MockURLProtocol`).
- **Build/Test-Command** (Simulatornamen an einen installierten iOS-26-Sim anpassen):
  ```bash
  xcodegen generate   # nur nötig, wenn project.yml geändert wurde
  xcodebuild test -scheme AtollTalk \
    -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.0' -quiet
  ```
- **DRY · YAGNI · TDD · häufige Commits.** Ein Commit pro abgeschlossener Task.

---

## File Structure

| Neu | Verantwortung |
|---|---|
| `AtollTalk/Models/Tier.swift` | `Tier` (basic/pro) + `AppLanguage.tier` + `appleTranslationSupported` |
| `AtollTalk/Services/Translator.swift` | `protocol Translator` (gemeinsames Interface Basic/Pro) |
| `AtollTalk/Services/AppleTranslator.swift` | On-Device-Übersetzung via `TranslationSession` (Basic) |
| `AtollTalk/Stores/SubscriptionStore.swift` | StoreKit-2-Entitlement, `isPro` |
| `AtollTalk/Views/PaywallView.swift` | Abo-Kauf/Restore (AtollDesign-Tokens) |
| `AtollTalk/Services/ServiceFactory.swift` | wählt Translator + Synth-Provider nach Tier |
| `AtollTalk.storekit` | lokale StoreKit-Testprodukte |
| `supabase/functions/translate/` | Pro-Proxy (Phase 4) · `Services/ProxyLLMProvider.swift` |

| Ändern | Änderung |
|---|---|
| `AtollTalk/ViewModel/AppViewModel.swift` | `any Translator` statt `TranslationService`; `speak()` still statt Fehler |
| `AtollTalk/Services/TranslationService.swift` | `: Translator` konform (= Pro) |
| `AtollTalk/Services/SynthesisService.swift` | Basic → nur Apple-Stimmen |
| `AtollTalk/Views/RootView.swift` | `rebuild()` nutzt `SubscriptionStore.isPro` via `ServiceFactory` |
| `AtollTalk/Views/SettingsView.swift` | Pro-Sprache ohne Pro → Paywall |
| `AtollTalk/Stores/SettingsStore.swift` | `voices` für alle Sprachen (nicht nur de/uk) |
| `AtollTalk/AtollTalkApp.swift` | `SubscriptionStore` als `@State`, injizieren |
| `AtollTalk/Models/AppLanguage.swift` | (✅ Sprachen vorhanden) ggf. `elevenVoiceID`-Default |
| `project.yml` | StoreKit-Capability; (Translation braucht keine Capability) |

---

## Phase 0 — Branch & Orientierung

### Task 0: Branch, Orientierung, ASC-Produkte

**Files:** keine Code-Änderung.

- [ ] **Schritt 1: Branch anlegen**
  ```bash
  git checkout -b feature/free-pro-tiers
  ```
- [ ] **Schritt 2: Aktuelle Signaturen lesen** (nicht aus dem Gedächtnis arbeiten)
  - `AtollTalk/ViewModel/AppViewModel.swift` — `init(... translator: TranslationService ..., pair: @escaping () -> LanguagePair)` und `speak(_:)`.
  - `AtollTalk/Views/RootView.swift` — `rebuild()` (Composition-Root).
  - `AtollTalk/Services/SynthesisService.swift` — `init(elevenLabsKey:voices:)`, `speak(_:in:) -> Bool`, `appleVoiceIdentifier(for:)`.
  - `AtollTalk/Models/AppLanguage.swift` — Fälle `de,uk,en,it,es,fr,tl,ceb`, `appleLocale`, `init?(scribeCode:)`.
- [ ] **Schritt 3: Package-APIs verifizieren** in `Dispo/swift-packages/`:
  - `AtollLLM`: `LLMProvider.streamChat(messages:tools:model:systemPrompt:) -> AsyncThrowingStream<LLMChunk, Error>`, `LLMChunk.text/.done`, `LLMMessage(role:content:)`.
  - `AtollSpeech`: `CompositeSynthesizer(apple:elevenLabs:provider:)`, `AppleSynthesizer()`, `ElevenLabsSynthesizer(client:defaultVoiceID:)`, `ElevenLabsClient(apiKey:session:)`, `Synthesizer.Provider` (`.apple`/`.elevenLabs`).
  - Notiere Abweichungen; alle Code-Blöcke unten daran anpassen.
- [ ] **Schritt 4: App Store Connect** — Abo-Gruppe „AtollTalk Pro"; Produkte `swiss.atoll.talk.pro.monthly` (CHF 4.90), `swiss.atoll.talk.pro.yearly` (CHF 34.90) + 7-Tage-Intro-Gratis aufs Jahr; **Non-Consumable** `swiss.atoll.talk.pro.lifetime` (CHF 199, einmalig — Lifetime). (Kann parallel zu Phase 1 laufen.)
- [ ] **Schritt 5: Spikes** (½ h): `TranslationSession` DE↔UA offline; ElevenLabs-Stimme `fil` für Tagalog. Ergebnis notieren.

**Akzeptanz:** Branch steht; reale Signaturen + Package-APIs notiert; Produkte in ASC „Ready to Submit".

---

## Phase 1 — Tier-Modell + StoreKit 2 *(parallel zu Phase 2)*

### Task 1: `Tier` + `AppLanguage.tier` (TDD)

**Files:** Create `AtollTalk/Models/Tier.swift` · Test `AtollTalkTests/TierTests.swift`

- [ ] **Schritt 1: Failing test**
  ```swift
  import Testing
  @testable import AtollTalk

  @Suite struct TierTests {
    @Test func proLanguagesArePro() {
      #expect(AppLanguage.tl.tier == .pro)
      #expect(AppLanguage.ceb.tier == .pro)
    }
    @Test func standardLanguagesAreBasic() {
      for l in [AppLanguage.de, .uk, .en, .it, .es, .fr] { #expect(l.tier == .basic) }
    }
    @Test func basicEqualsAppleTranslatable() {
      #expect(AppLanguage.de.appleTranslationSupported == true)
      #expect(AppLanguage.tl.appleTranslationSupported == false)
    }
  }
  ```
- [ ] **Schritt 2: Test fails** — `xcodebuild test ... -only-testing:AtollTalkTests/TierTests` → FAIL („tier not a member").
- [ ] **Schritt 3: Implementierung**
  ```swift
  import Foundation

  enum Tier: String, Sendable, Codable { case basic, pro }

  extension AppLanguage {
    /// Pro languages are the ones Apple can't translate on-device (→ require Claude).
    var tier: Tier {
      switch self {
      case .tl, .ceb: .pro
      default: .basic
      }
    }
    /// True when Apple's on-device Translation framework can translate this language.
    /// (Confirm at runtime via `LanguageAvailability`; this is the static expectation.)
    var appleTranslationSupported: Bool { tier == .basic }
  }
  ```
- [ ] **Schritt 4: Test passes** — erneut ausführen → PASS.
- [ ] **Schritt 5: Commit** — `git commit -am "feat(tier): add Tier + AppLanguage.tier classification"`

### Task 2: `SubscriptionStore` (StoreKit 2)

**Files:** Create `AtollTalk/Stores/SubscriptionStore.swift` · Create `AtollTalk.storekit` · Test `AtollTalkTests/SubscriptionStoreTests.swift`

- [ ] **Schritt 1: StoreKit-Configfile** in Xcode anlegen (File ▸ New ▸ StoreKit Configuration File `AtollTalk.storekit`), Abo-Gruppe „pro" mit `swiss.atoll.talk.pro.monthly` + `.yearly`, Intro-Offer 7 Tage gratis aufs Jahr, **plus Non-Consumable** `swiss.atoll.talk.pro.lifetime` (CHF 199). Scheme ▸ Run ▸ Options ▸ StoreKit Configuration = `AtollTalk.storekit`.
- [ ] **Schritt 2: Failing test** (StoreKitTest)
  ```swift
  import Testing
  import StoreKitTest
  @testable import AtollTalk

  @MainActor @Suite(.serialized) struct SubscriptionStoreTests {
    @Test func purchasingYearlySetsPro() async throws {
      let session = try SKTestSession(configurationFileNamed: "AtollTalk")
      session.resetToDefaults(); session.clearTransactions()
      let store = SubscriptionStore(productIDs: ["swiss.atoll.talk.pro.yearly"])
      await store.load()
      #expect(store.isPro == false)
      try await session.buyProduct(identifier: "swiss.atoll.talk.pro.yearly")
      await store.refreshEntitlements()
      #expect(store.isPro == true)
    }
  }
  ```
- [ ] **Schritt 3: Test fails** — `SubscriptionStore` existiert nicht → FAIL.
- [ ] **Schritt 4: Implementierung**
  ```swift
  import Foundation
  import StoreKit
  import Observation

  @MainActor @Observable
  final class SubscriptionStore {
    private(set) var products: [Product] = []
    private(set) var isPro = false
    private let productIDs: Set<String>
    private var updates: Task<Void, Never>?

    init(productIDs: Set<String> = ["swiss.atoll.talk.pro.monthly",
                                    "swiss.atoll.talk.pro.yearly",
                                    "swiss.atoll.talk.pro.lifetime"]) {  // Lifetime = Non-Consumable
      self.productIDs = productIDs
      updates = observeTransactions()
    }
    deinit { updates?.cancel() }

    func load() async {
      products = (try? await Product.products(for: productIDs)) ?? []
      await refreshEntitlements()
    }

    func purchase(_ product: Product) async throws {
      let result = try await product.purchase()
      if case let .success(verification) = result,
         case let .verified(transaction) = verification {
        await transaction.finish()
        await refreshEntitlements()
      }
    }

    func restore() async { try? await AppStore.sync(); await refreshEntitlements() }

    func refreshEntitlements() async {
      var active = false
      for await result in Transaction.currentEntitlements {
        if case let .verified(t) = result, productIDs.contains(t.productID),
           t.revocationDate == nil { active = true }
      }
      isPro = active
    }

    private func observeTransactions() -> Task<Void, Never> {
      Task { [weak self] in
        for await update in Transaction.updates {
          if case let .verified(t) = update { await t.finish() }
          await self?.refreshEntitlements()
        }
      }
    }
  }
  ```
- [ ] **Schritt 5: Test passes** — ausführen → PASS (Sandbox-Kauf flippt `isPro`).
- [ ] **Schritt 6: Commit** — `git commit -am "feat(store): StoreKit2 SubscriptionStore with isPro entitlement"`

> **Lifetime (Non-Consumable) — weitgehend abgedeckt:** Mit `…pro.lifetime` in `productIDs` lädt `Product.products(for:)` ihn in die Paywall, und `refreshEntitlements()` setzt `isPro = true`, sobald er besessen ist — ein Non-Consumable bleibt **dauerhaft** in `Transaction.currentEntitlements` (kein Ablauf) → **lebenslang Pro**, ohne Zusatzlogik. Nur Kosmetik: in der Paywall als **„Einmalig — Lifetime" (CHF 199)** kennzeichnen (nicht als Abo). Optionaler Test: Lifetime kaufen → `isPro` bleibt auch nach `store.refreshEntitlements()`/Neustart `true`. Gratis an Freunde = **Offer Codes** (Submission-Package §3) — kein App-Code nötig.

### Task 3: `PaywallView` + App-Verdrahtung

**Files:** Create `AtollTalk/Views/PaywallView.swift` · Modify `AtollTalk/AtollTalkApp.swift`

- [ ] **Schritt 1: Store injizieren** in `AtollTalkApp.swift`
  ```swift
  @State private var subscription = SubscriptionStore()
  // ...
  RootView(settings: settings, glossary: glossary, subscription: subscription)
    .modelContainer(container)
    .task { await subscription.load() }
  ```
- [ ] **Schritt 2: PaywallView** (AtollDesign-Tokens nutzen; Pflicht-Links Terms + Datenschutz)
  ```swift
  import SwiftUI
  import StoreKit

  struct PaywallView: View {
    let subscription: SubscriptionStore
    @Environment(\.dismiss) private var dismiss
    var body: some View {
      VStack(spacing: 20) {
        Text("AtollTalk Pro").font(.largeTitle.bold())
        Text("Premium-Übersetzung (Claude) + natürliche Stimmen. Alle Sprachen, inkl. Tagalog & Bisaya.")
          .multilineTextAlignment(.center).foregroundStyle(.secondary)
        ForEach(subscription.products.sorted { $0.price < $1.price }, id: \.id) { p in
          Button { Task { try? await subscription.purchase(p) ; if subscription.isPro { dismiss() } } } label: {
            HStack { Text(p.displayName); Spacer(); Text(p.displayPrice) }
              .padding().frame(maxWidth: .infinity)
              .background(Color.brandBlue50).clipShape(.rect(cornerRadius: 12))
          }
        }
        Button("Käufe wiederherstellen") { Task { await subscription.restore(); if subscription.isPro { dismiss() } } }
          .font(.footnote)
        HStack(spacing: 16) {
          Link("Nutzungsbedingungen", destination: URL(string: "https://atoll-os.com/terms")!)
          Link("Datenschutz", destination: URL(string: "https://atoll-os.com/privacy")!)
        }.font(.caption).foregroundStyle(.secondary)
      }.padding()
    }
  }
  ```
  *(Farb-/Token-Namen wie `Color.brandBlue50` gegen `AtollDesign`/`Theme.swift` prüfen.)*
- [ ] **Schritt 3: Build** — `xcodebuild build ...` → kompiliert.
- [ ] **Schritt 4: Manueller Test** — Paywall zeigt Monat/Jahr + Preise aus der StoreKit-Config; Kauf flippt `isPro`; „Wiederherstellen" funktioniert.
- [ ] **Schritt 5: Commit** — `git commit -am "feat(paywall): PaywallView + SubscriptionStore wired into app"`

---

## Phase 2 — Translator-Abstraktion + Apple-MT *(parallel zu Phase 1)*

### Task 4: `Translator`-Protokoll + `TranslationService`-Konformität (TDD)

**Files:** Create `AtollTalk/Services/Translator.swift` · Modify `AtollTalk/Services/TranslationService.swift` · Test `AtollTalkTests/TranslatorTests.swift`

- [ ] **Schritt 1: Failing test** (Mock-Translator erfüllt das Protokoll, AppViewModel nimmt es)
  ```swift
  import Testing
  @testable import AtollTalk

  private struct EchoTranslator: Translator {
    func translate(_ text: String, to: AppLanguage, context: String, glossary: String) async throws -> String { "echo:\(text)" }
  }

  @Suite struct TranslatorTests {
    @Test func protocolIsSatisfiedByService() {
      let _: any Translator = EchoTranslator()    // compiles
      #expect(Bool(true))
    }
  }
  ```
- [ ] **Schritt 2: Test fails** — `Translator` existiert nicht → FAIL (compile).
- [ ] **Schritt 3: Protokoll + Konformität**
  ```swift
  // Translator.swift
  protocol Translator: Sendable {
    func translate(_ text: String, to target: AppLanguage, context: String, glossary: String) async throws -> String
  }
  ```
  In `TranslationService.swift` die Deklaration ergänzen: `struct TranslationService: Translator {` (Signatur von `translate(...)` ist bereits identisch).
- [ ] **Schritt 4: Test passes** — PASS.
- [ ] **Schritt 5: Commit** — `git commit -am "refactor(translate): introduce Translator protocol; TranslationService conforms"`

### Task 5: `AppleTranslator` (On-Device, Basic)

**Files:** Create `AtollTalk/Services/AppleTranslator.swift` · Test `AtollTalkTests/AppleTranslatorTests.swift`

- [ ] **Schritt 1: Implementierung** (Translation-Framework; `context`/`glossary` werden bei MT ignoriert)
  ```swift
  import Foundation
  import Translation

  /// On-device machine translation for the Basic tier. No context/glossary (pure MT).
  @available(iOS 18.0, *)
  struct AppleTranslator: Translator {
    /// Map AppLanguage → BCP-47 the Translation framework expects.
    private func lang(_ l: AppLanguage) -> Locale.Language {
      Locale.Language(identifier: String(l.appleLocale.prefix(2)))  // de, uk, en, it, es, fr
    }
    func translate(_ text: String, to target: AppLanguage, context: String, glossary: String) async throws -> String {
      // NOTE: TranslationSession is normally vended via the `.translationTask` SwiftUI
      // modifier. Confirm the iOS 26 programmatic entry point in Phase 0 and adjust.
      let session = try await TranslationSession.makeSession(/* source: nil for auto, target: */)
      let response = try await session.translate(text)
      return response.targetText
    }
  }
  ```
  > ⚠️ **Verify-Schritt:** Die programmatische `TranslationSession`-Erzeugung unterscheidet sich je iOS-Version (oft über `.translationTask(_:action:)` im View). Prüfe die iOS-26-API in Phase 0; ggf. `AppleTranslator` als `@MainActor`-Komponente an eine View hängen, die die Session bereitstellt, statt frei zu instanziieren.
- [ ] **Schritt 2: Integrationstest** (nur Geräte/Sim mit geladenem Sprachpaket; sonst skip)
  ```swift
  import Testing
  @testable import AtollTalk

  @Suite struct AppleTranslatorTests {
    @available(iOS 18.0, *)
    @Test func translatesGermanToUkrainian() async throws {
      let out = try await AppleTranslator().translate("Guten Tag", to: .uk, context: "", glossary: "")
      #expect(!out.isEmpty)
    }
  }
  ```
- [ ] **Schritt 3: Build + Test** — auf Sim mit DE/UA-Paket → PASS (oder dokumentiertes Skip).
- [ ] **Schritt 4: Commit** — `git commit -am "feat(translate): AppleTranslator (on-device MT) for Basic tier"`

### Task 6: `AppViewModel` nutzt `any Translator`

**Files:** Modify `AtollTalk/ViewModel/AppViewModel.swift` · Modify `AtollTalkTests/AppViewModelTests.swift`

- [ ] **Schritt 1: Test anpassen** — im bestehenden `makeVM` Typ ändern: `translator:` akzeptiert jetzt `any Translator`. Bestehender `StubLLM`-Pfad über `TranslationService(provider:)` bleibt gültig (konform). Test erneut grün erwartet.
- [ ] **Schritt 2: Signatur ändern**
  ```swift
  private let translator: any Translator
  // init-Parameter: translator: any Translator
  ```
- [ ] **Schritt 3: Test/Build** — `xcodebuild test ...` → bestehende `AppViewModelTests` bleiben PASS.
- [ ] **Schritt 4: Commit** — `git commit -am "refactor(vm): AppViewModel depends on any Translator"`

---

## Phase 3 — Tier-Routing + Stimme/Output-Regeln *(braucht 1 + 2)*

### Task 7: `speak()` — stiller Text-only statt Fehler (TDD)

**Files:** Modify `AtollTalk/ViewModel/AppViewModel.swift:87` · Test `AtollTalkTests/SpeakFallbackTests.swift`

- [ ] **Schritt 1: Failing test** — defensiver Fall „keine Stimme konfiguriert" (kein ElevenLabs-Key + keine Apple-Stimme für die Locale) darf **nicht** in `.error` gehen. *(Hinweis: `.ceb` spricht im Pro-Tier normal via ElevenLabs „Filipino"/`fil`, Cebuano-Dialekt — dieser Test prüft nur den unkonfigurierten Pfad mit `elevenLabsKey: nil`.)*
  ```swift
  import Testing
  import Foundation
  import SwiftData
  @testable import AtollTalk

  @MainActor @Suite(.serialized) struct SpeakFallbackTests {
    @Test func missingVoiceStaysSilentNotError() throws {
      let container = try ModelContainer(for: Turn.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true))
      let vm = AppViewModel(
        recorder: AudioRecorder(),
        speech: SpeechService(apiKey: ""),
        translator: TranslationService(provider: StubLLM(chunks: [.done])),
        synthesis: SynthesisService(elevenLabsKey: nil, voices: [:]),
        store: ConversationStore(context: container.mainContext),
        context: "", glossaryLines: { "" }, pair: { LanguagePair(a: .de, b: .ceb) })
      vm.speak(Turn(sourceText: "hi", sourceLang: .de, targetText: "uy", targetLang: .ceb))
      #expect(vm.phase == .idle)   // not .error
    }
  }
  ```
  *(`StubLLM` ist als Test-Helper in `AppViewModelTests.swift` definiert — ggf. in eine geteilte Testdatei ziehen.)*
- [ ] **Schritt 2: Test fails** — heute setzt `speak()` `.error` → FAIL.
- [ ] **Schritt 3: Implementierung** — `speak()` ohne Fehler:
  ```swift
  func speak(_ turn: Turn) {
    _ = synthesis.speak(turn.targetText, in: turn.targetLang)   // false → still: nur Text, kein Alert
  }
  ```
- [ ] **Schritt 4: Test passes** — PASS. (Optional: `Turn`/UI ein dezentes „🔇" geben, wenn `false`.)
- [ ] **Schritt 5: Commit** — `git commit -am "fix(tts): silent text-only when no voice (no error alert)"`

### Task 8: `SynthesisService` — Basic nur Apple-Stimmen

**Files:** Modify `AtollTalk/Services/SynthesisService.swift`

- [ ] **Schritt 1: Tier durchreichen** — `init(elevenLabsKey:voices:tier:)` (oder `allowElevenLabs: Bool`). Bei `tier == .basic` ElevenLabs **nicht** verdrahten (wie heute der `nil`-Key-Pfad → `CompositeSynthesizer(apple:elevenLabs:nil)`).
- [ ] **Schritt 2: Build** — kompiliert.
- [ ] **Schritt 3: Test** — Basic-Instanz mit gesetztem Key spricht trotzdem via Apple (Provider `.apple`); Pro nutzt ElevenLabs. (Unit-Test über `appleVoiceIdentifier(for:)`-Pfad / Provider-Auswahl.)
- [ ] **Schritt 4: Commit** — `git commit -am "feat(tts): ElevenLabs voices are Pro-only; Basic uses Apple voices"`

### Task 9: `ServiceFactory` + `RootView.rebuild()` gaten

**Files:** Create `AtollTalk/Services/ServiceFactory.swift` · Modify `AtollTalk/Views/RootView.swift`

- [ ] **Schritt 1: Factory**
  ```swift
  enum ServiceFactory {
    static func translator(isPro: Bool, anthropicKey: String, model: String) -> any Translator {
      if isPro { return TranslationService(apiKey: anthropicKey, model: model) }
      if #available(iOS 18.0, *) { return AppleTranslator() }
      return TranslationService(apiKey: anthropicKey, model: model) // Fallback < iOS 18
    }
  }
  ```
- [ ] **Schritt 2: `rebuild()`** liest `subscription.isPro`, baut `translator` über die Factory und `SynthesisService(... tier: subscription.isPro ? .pro : .basic)`. `RootView` bekommt `subscription` als Property (siehe Task 3, Schritt 1).
- [ ] **Schritt 3: Build + manueller Test** — ohne Pro: DE→UA via Apple, Apple-Stimme. Mit Pro (Sandbox): Claude + ElevenLabs. Settings-Dismiss → `rebuild()` schaltet live.
- [ ] **Schritt 4: Commit** — `git commit -am "feat(routing): tier-based translator/synth selection in composition root"`

### Task 10: Pro-Sprache im Picker gaten

**Files:** Modify `AtollTalk/Views/SettingsView.swift`

- [ ] **Schritt 1:** Beim Wählen einer Sprache mit `.tier == .pro` und `!subscription.isPro` → `PaywallView` als Sheet, Auswahl nicht übernehmen.
- [ ] **Schritt 2: Build + manueller Test** — Basic-Nutzer kann Tagalog/Bisaya nicht aktivieren ohne Paywall.
- [ ] **Schritt 3: Commit** — `git commit -am "feat(gating): selecting a Pro language prompts paywall"`

> **Meilenstein MVP:** Nach Phase 3 läuft Free vs. Pro lokal vollständig (StoreKit-Sandbox). Phase 4 vor öffentlichem Launch.

---

## Phase 4 — Claude-Backend-Proxy (Pro) *(eigenständig; kann nach Phase 2 starten — Hexa/Mack)*

> Ziel: Anthropic-Key raus aus der App; Pro-Übersetzung serverseitig, Entitlement-geprüft. Nutzt die in der Design-Spec §4 vorgesehene `APIClient`-Abstraktion (zentrale Base-URL/Header).

### Task 11: Supabase Edge Function `translate`
**Files:** Create `supabase/functions/translate/index.ts`
- [ ] **Schritt 1:** Function hält `ANTHROPIC_API_KEY` (Secret); nimmt `{text, target, context, glossary, jws}`; validiert Abo über **App Store Server API** (JWS-Transaktion) oder Supabase-Auth-Token; ruft Anthropic; gibt Übersetzung.
- [ ] **Schritt 2:** **Rate-Limit pro Konto** (Fair-Use; schützt Claude-Kosten) — Tabelle `usage(account, day, count)`.
- [ ] **Schritt 3:** Deploy `supabase functions deploy translate`; mit gültigem/ungültigem Entitlement testen (200 vs 402/403).
- [ ] **Schritt 4: Commit** (Backend-Repo).

### Task 12: `ProxyLLMProvider` + Key-Entfernung
**Files:** Create `AtollTalk/Services/ProxyLLMProvider.swift` · Modify `TranslationService.swift`, `Services/Secrets.swift`, `Views/SettingsView.swift`
- [ ] **Schritt 1:** `ProxyLLMProvider: LLMProvider` (oder `Translator`) ruft die Edge Function statt `api.anthropic.com`; Pro-Pfad darauf umstellen.
- [ ] **Schritt 2:** Anthropic-Key aus App/Settings/Keychain entfernen (`SecretKey.anthropicAPIKey` raus); BYO-Key-UI nur noch hinter Dev-Flag.
- [ ] **Schritt 3: Verify** — `grep -ri "anthropic" AtollTalk | grep -i key` → keine Klartext-Keys; Pro-Übersetzung läuft über Proxy; Basic ruft nie Claude.
- [ ] **Schritt 4: Commit** — `git commit -am "feat(proxy): route Pro translation through Supabase; drop in-app Anthropic key"`

---

## Phase 5 — Consent, Fair-Use, Labels, Lokalisierung, Tests

### Task 13: KI-Consent (Pflicht seit App-Review-Update 13.11.2025)
**Files:** Create `AtollTalk/Views/ConsentView.swift` · Modify `Stores/SettingsStore.swift` (Flag)
- [ ] **Schritt 1:** Beim ersten Start Consent (Daten an Anthropic/ElevenLabs); ohne Zustimmung kein Cloud-Call. Flag in `SettingsStore`.
- [ ] **Schritt 2: Test** — ohne Consent kein STT/MT/TTS-Cloud-Call (Unit über ein Gate-Flag). **Commit.**

### Task 14: Fair-Use-Cap (Basic) + Qualitäts-Labels
**Files:** Modify `Stores/SettingsStore.swift`, `Views/SettingsView.swift`
- [ ] **Schritt 1:** Tageszähler für Basic (z. B. X Übersetzungen/Tag) in SwiftData/`SettingsStore`; bei Erreichen → Paywall.
- [ ] **Schritt 2:** Settings zeigen Tier + Upgrade + „Abo verwalten"; Labels „Standard-Übersetzung" (Basic) / „Premium (Claude) + natürliche Stimme" (Pro). **Commit.**

### Task 15: Lokalisierung + Test-Sweep
**Files:** `AtollTalk/Localizable.xcstrings` · `AtollTalkTests/*`
- [ ] **Schritt 1:** Neue Strings DE/UK/EN lokalisieren.
- [ ] **Schritt 2:** Volllauf `xcodebuild test ...` grün; Free- und Pro-Pfad abgedeckt. **Commit.**

---

## Self-Review (vom Plan-Autor)

- **Spec-Coverage:** Tier-Modell (T1), Entitlement/StoreKit (T2–3), Free-MT (T4–5), VM-Entkopplung (T6), Stimme-Regel/stiller Fallback (T7–8), Routing/Gating (T9–10), Proxy (T11–12), Consent/Fair-Use/L10n (T13–15) → deckt die Architektur-Deliverable-Punkte ab.
- **Placeholder-Scan:** Eine bewusste Unschärfe verbleibt: `TranslationSession`-Instanziierung (iOS-26-API) — explizit als **Verify-Schritt** in Task 5 markiert, kein stiller TODO. Begründung: programmatische API ist versionsabhängig und hier nicht kompilierbar.
- **Typ-Konsistenz:** `Translator.translate(_:to:context:glossary:)` identisch in Protokoll (T4), `TranslationService`, `AppleTranslator`, `EchoTranslator`. `SubscriptionStore.isPro` einheitlich in T2/T3/T9. `AppLanguage.tier` in T1/T9/T10.

## Ausführung in Claude Code (Handoff)

Im Repo öffnen und mit dem Sub-Skill starten — empfohlen **subagent-driven-development** (frischer Subagent pro Task, Review dazwischen). Kickoff-Prompt:

> „Lies `docs/superpowers/plans/2026-06-04-free-pro-tiers.md` und setze **Phase 0 + Phase 1** um. Nach jeder Task: `xcodebuild test` laufen lassen, bei Grün committen, dann stoppen und zusammenfassen, bevor du weitermachst. Beginne damit, die in Phase 0 genannten realen Signaturen und Package-APIs zu verifizieren."

**Reihenfolge:** Phase 1 ∥ Phase 2 → Phase 3 (Meilenstein MVP) → Phase 4 (Backend, vor Launch) → Phase 5. Tests sind die Sicherheitsnetze; bei abweichenden realen Signaturen die Code-Blöcke anpassen, nicht den Test verbiegen.
