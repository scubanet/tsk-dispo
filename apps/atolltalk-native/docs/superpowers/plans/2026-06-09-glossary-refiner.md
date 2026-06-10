# AtollTalk Glossar-Nachbearbeitung (FoundationModels) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use **superpowers:subagent-driven-development** (empfohlen) oder **superpowers:executing-plans**, um diesen Plan Task für Task umzusetzen. Schritte nutzen Checkbox-Syntax (`- [ ]`).

**Goal:** Der **Basic**-Tier (Apple On-Device-MT, das `context`/`glossary` ignoriert) bekommt eine optionale, rein additive **Glossar-Nachbearbeitung** durch das On-Device-Modell von Apple Intelligence (FoundationModels). Die Apple-MT-Übersetzung wird anschließend so überarbeitet, dass Glossar-Begriffe konsistent angewendet werden — ohne Netz, ohne Claude-Kosten.

**Architecture:** Ein **Decorator** `GlossaryRefiner: Translator` umschließt einen beliebigen `Translator`. Er ruft erst `base.translate(...)` (= `AppleTranslator`) und reicht das Ergebnis dann optional durch eine `FoundationModels`-Verfeinerung. Verdrahtet im Composition-Root über `ServiceFactory.translator(...)`: Basic → `GlossaryRefiner(base: AppleTranslator())`, Pro → unverändert `ProxyTranslator` (macht Glossar bereits serverseitig). Jeder Fehler-/Nicht-Verfügbarkeits-Pfad fällt **still auf die MT-Übersetzung zurück** — wie die bestehende „fehlende Stimme blockiert nicht"-Philosophie.

**Tech Stack:** SwiftUI, iOS 26 (Deployment-Target bleibt 26.0), Swift 6 (`SWIFT_STRICT_CONCURRENCY: complete`), **Swift Testing**, **FoundationModels** (System-Framework, seit iOS 26; per `import` autoverlinkt — kein `project.yml`-Eingriff).

**Baut auf:** `docs/superpowers/plans/2026-06-04-free-pro-tiers.md` (Tier-Schalter am Übersetzungsschritt). Das `Translator`-Protokoll führt `context`/`glossary` bereits als Parameter — die saubere Naht für diesen Plan.

---

## Vor dem Start — Realitäts-Check (bitte lesen)

- **Der Code ist aktiv in Entwicklung.** Signaturen können abweichen. **Jede Task beginnt mit dem Lesen der aktuellen Datei**, bevor editiert wird. Code-Blöcke hier sind Referenz.
- **FoundationModels ist KEIN iOS-27-Feature** — es existiert seit iOS 26. Kein `#available`-Gating nötig (Target 26.0). Wirklich neu in 27 ist `PrivateCloudComputeLanguageModel` (Server-Fallback, Entitlement nötig) — **nicht** Teil dieses Plans.
- **Tests:** Swift Testing (`import Testing`, `@Test`, `#expect`, `@Suite`). Muster: `AtollTalkTests/TranslatorTests.swift`, `ServiceFactoryTests.swift`.
- **Build/Test-Command:**
  ```bash
  xcodebuild test -scheme AtollTalk \
    -destination 'platform=iOS Simulator,name=iPhone 17,OS=27.0' -quiet
  ```
- **Echte Qualitäts-/Sprachverifikation braucht ein Apple-Intelligence-Gerät** mit aktivierter AI. Der Simulator deckt FoundationModels nur eingeschränkt ab; die Unit-Tests prüfen daher die **Entscheidungslogik** über einen injizierten Seam, nicht das reale Modell.

---

## Schlüssel-Fakten zum Code (verifiziert 2026-06-09)

- `Translator` (`Services/Translator.swift`): `func translate(_ text:from:to:context:glossary:) async throws -> String`, `Sendable`.
- `AppleTranslator` (`Services/AppleTranslator.swift`): ignoriert `context`/`glossary` (Apples `TranslationSession` nimmt beides nicht). **Genau die Lücke.**
- `ServiceFactory.translator(isPro:model:jws:)` wählt `ProxyTranslator` (Pro) bzw. `AppleTranslator` (Basic). Aufgerufen in `RootView.rebuild()`; `glossaryLines` = `glossary.promptLines(for: settings.pair)`.
- Sprachen (`AppLanguage`): `de, uk, en, it, es, fr, tl (Tagalog), ceb (Bisaya)`. `appleLocale` liefert BCP-47 (z. B. `de-DE`, `uk-UA`, `fil-PH`, `ceb`).
- **Apple-Intelligence-Sprachabdeckung:** de/en/es/fr/it sehr wahrscheinlich JA; **uk/tl/ceb wahrscheinlich NEIN** → per `supportsLocale()` zur Laufzeit prüfen und sonst überspringen (real auf Gerät verifizieren).

---

## Task 1 — `Config`-Feature-Flag

- [ ] In `Config.swift` ergänzen (Default `false`, bis auf Gerät getestet):
  ```swift
  /// On-Device-Glossar-Nachbearbeitung der Basic-Übersetzung (FoundationModels).
  /// Default aus, bis auf einem Apple-Intelligence-Gerät verifiziert.
  static let glossaryRefinementEnabled = false
  ```

## Task 2 — `GlossaryRefiner` Decorator

- [ ] Neue Datei `Services/GlossaryRefiner.swift`. Aktuelle Signatur von `Translator` zuerst lesen und angleichen.
  ```swift
  import Foundation
  import FoundationModels

  /// Decorator: übersetzt via `base` (Apple-MT) und wendet anschließend optional
  /// das Glossar mit dem On-Device-Modell konsistent an. Jeder Fehler-/
  /// Nicht-Verfügbarkeits-Pfad gibt die MT-Übersetzung unverändert zurück.
  struct GlossaryRefiner: Translator {
    let base: any Translator
    /// Test-Seam: Default = echte FoundationModels-Verfeinerung.
    let refine: @Sendable (_ mt: String, _ target: AppLanguage, _ glossary: String) async -> String

    init(base: any Translator,
         refine: (@Sendable (String, AppLanguage, String) async -> String)? = nil) {
      self.base = base
      self.refine = refine ?? GlossaryRefiner.modelRefine
    }

    func translate(_ text: String, from source: AppLanguage, to target: AppLanguage,
                   context: String, glossary: String) async throws -> String {
      let mt = try await base.translate(text, from: source, to: target,
                                        context: context, glossary: glossary)
      guard Config.glossaryRefinementEnabled,
            !glossary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      else { return mt }
      return await refine(mt, target, glossary)
    }

    /// Echte On-Device-Verfeinerung. Skip bei nicht verfügbarem Modell oder nicht
    /// unterstützter Zielsprache; alle Fehler ⇒ Rückgabe von `mt`.
    @Sendable static func modelRefine(_ mt: String, target: AppLanguage,
                                      glossary: String) async -> String {
      let model = SystemLanguageModel.default
      guard case .available = model.availability,
            model.supportsLocale(Locale(identifier: target.appleLocale))
      else { return mt }
      do {
        let session = LanguageModelSession(instructions: """
          Du bist ein Übersetzungs-Lektor. Wende das Glossar konsistent auf die \
          vorhandene Übersetzung an. Ändere nichts anderes an Bedeutung oder Stil. \
          Gib NUR die korrigierte Übersetzung aus, ohne Kommentar.
          """)
        let prompt = """
          Zielsprache: \(target.displayName)
          Glossar:
          \(glossary)
          Übersetzung:
          \(mt)
          """
        let out = try await session.respond(to: prompt).content
          .trimmingCharacters(in: .whitespacesAndNewlines)
        return out.isEmpty ? mt : out
      } catch {
        return mt   // unsupportedLanguageOrLocale, refusal, exceededContextWindowSize, assetsUnavailable …
      }
    }
  }
  ```
- [ ] Sicherstellen, dass die `respond(...)`-Property zum Auslesen des Texts korrekt ist (`.content`). Bei Abweichung Doku via `DocumentationSearch` prüfen.

## Task 3 — Verdrahtung in `ServiceFactory`

- [ ] `Services/ServiceFactory.swift`: Basic-Pfad umhüllen, Pro unverändert.
  ```swift
  isPro ? ProxyTranslator(model: model, jws: jws)
        : GlossaryRefiner(base: AppleTranslator())
  ```
- [ ] Doc-Kommentar des `ServiceFactory` um den Refiner-Hinweis ergänzen.

## Task 4 — Tests anpassen/ergänzen

- [ ] `ServiceFactoryTests.basicReturnsAppleTranslator`: erwartet jetzt `GlossaryRefiner`, dessen `.base is AppleTranslator`.
  ```swift
  let t = ServiceFactory.translator(isPro: false, model: "m", jws: { nil })
  let refiner = try #require(t as? GlossaryRefiner)
  #expect(refiner.base is AppleTranslator)
  ```
- [ ] Neu `AtollTalkTests/GlossaryRefinerTests.swift` mit Stub-`base` (Echo) und injiziertem `refine`-Seam — **kein echtes Modell**:
  - leeres Glossar ⇒ gibt `base`-Output zurück, `refine` wird **nie** aufgerufen.
  - `Config.glossaryRefinementEnabled == false` ⇒ Passthrough (Hinweis: Flag ist `let`; Test deckt damit nur den jeweils kompilierten Zustand ab — siehe Risiko unten).
  - nicht-leeres Glossar + Flag an ⇒ `refine` wird mit dem MT-Output aufgerufen, dessen Rückgabe durchgereicht.
  - Test-Seam-Beispiel:
    ```swift
    let spy = …  // Aktor/Box, der die refine-Aufrufe sammelt
    let refiner = GlossaryRefiner(base: EchoTranslator()) { mt, _, _ in "refined:\(mt)" }
    ```

## Task 5 — Build & Verifikation

- [ ] `BuildProject` (iOS-27-SDK) muss grün sein, keine Warnungen.
- [ ] `xcodebuild test` grün.
- [ ] **Manuell auf Apple-Intelligence-Gerät** (Flag temporär `true`): Glossar-Begriff in de/en/es/fr/it-Paar erscheint konsistent; uk/tl/ceb bleiben unverändert (MT); ohne AI/altes Gerät bleibt alles MT.

---

## Risiken / offene Punkte

| Punkt | Umgang |
|---|---|
| **uk / tl / ceb** evtl. nicht von Apple Intelligence unterstützt | `supportsLocale()`-Check ⇒ MT unverändert. Real auf Gerät verifizieren. |
| Modell „über-editiert" / ändert Bedeutung | Strikte Instructions; Flag erst nach manuellem Test an. |
| Zusätzliche Latenz (Modell-Call) | Nur bei nicht-leerem Glossar + unterstützter Sprache; sonst sofortiger Return. |
| Refusal / leere Antwort | Fallback auf MT-Output. |
| `glossaryRefinementEnabled` als `let` | Bewusst: kein UI-Toggle in v1. Für Tests beider Zweige ggf. später auf injizierbare Bedingung heben. |
| Unit-Tests prüfen kein echtes FM | `refine`-Seam testet Entscheidungslogik; Qualität nur manuell. |

## Nicht-Ziele

- Pro-Pfad (`ProxyTranslator`) — Glossar läuft dort serverseitig.
- `PrivateCloudComputeLanguageModel` (iOS-27, Entitlement) — eigenes späteres Vorhaben.
- Voll-Übersetzung on-device (Option B) — Übersetzung ist keine Kern-Stärke des Modells.
- Anhebung des Deployment-Targets auf 27.

## Aufwand

~½ Tag inkl. Tests. Echte Sprach-/Qualitätsverifikation braucht ein Apple-Intelligence-Gerät.
