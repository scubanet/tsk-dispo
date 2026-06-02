# AtollTalk — Design-Spec v1

- **Stand:** 2026-06-02
- **Autoren:** Sierra (iOS/macOS), Vex (Schlüssel-Sicherheit), Larry (Orchestrierung)
- **Status:** Entwurf zur Freigabe

## 1. Zweck & Kontext
Zwei-Wege-Live-Sprachübersetzung **Deutsch ↔ Ukrainisch** für Gespräche in der Küche (Dominik ↔ Maria, Küchenhilfe) — lockerer, gesprochener Alltag. **Qualität über allem:** behebt Apples zwei Schwachstellen (mittelmäßige Spracherkennung *und* mittelmäßige Übersetzung) durch Spitzen-Cloud-Dienste. iPhone-only, native SwiftUI, reine Eigennutzung. Architektur von Anfang an mehrsprachig erweiterbar.

## 2. Nicht-Ziele (v1)
- Kein Dauer-Freisprechmodus (Turn-by-Turn per Knopf).
- Kein iCloud-Sync, kein Backend, kein App-Store-Release.
- Kein macOS-Target (später trivial nachrüstbar, da SwiftUI + geteilte Packages).
- Nur DE/UA vorinstalliert (weitere Sprachen über die Registry).

## 3. Plattform & Konventionen (wie AtollCal)
- SwiftUI, **iOS 26.0**, Swift 6.0, `SWIFT_STRICT_CONCURRENCY: complete`.
- XcodeGen (`project.yml`): `name: AtollTalk`, `bundleIdPrefix: swiss.atoll`, Bundle-ID `swiss.atoll.talk`.
- `DEVELOPMENT_TEAM: XK8V89P2QV`, `CODE_SIGN_STYLE: Automatic`, `developmentLanguage: de`.
- `platform: [iOS]` (nur iPhone, Portrait).
- **Ort:** `Dispo/apps/atolltalk-native/` (Geschwister: `atollcal-native`, `atollcard-native`).
- App-Struktur wie AtollCal: `AtollTalkApp.swift`, `Config.swift`, `Models/`, `Services/`, `Views/`, `Assets.xcassets`, `Info.plist`, `ATOLL.entitlements`.
- `Info.plist`: `NSMicrophoneUsageDescription` (deutscher Text).

## 4. Engine-Entscheidungen
- **STT:** ElevenLabs Scribe v2 (Ukrainisch in Top-Genauigkeitsklasse ≤5 % WER; liefert Transkript **+ erkannte Sprache** → treibt die Auto-Richtung).
- **MT:** Claude über Anthropic-API. Default `claude-sonnet-4-6` (Qualität + Tempo), Option `claude-haiku-4-5` (schneller/günstiger). System-Prompt mit Küchen-Kontext + editierbarem Glossar (Namen wie „Maria", Koch-Begriffe). Claude darf offensichtliche STT-Hörfehler beim Übersetzen glätten.
- **TTS:** ElevenLabs Multilingual-Stimme, **nur auf „Vorlesen"-Tippen**. Apple `AVSpeechSynthesizer` als kostenloser Offline-Fallback.
- **Schlüssel:** ElevenLabs + Anthropic, ausschließlich im **iOS-Keychain** (Eingabe im Einstellungs-Screen). Kein Backend.
- `APIClient`-Abstraktion: zentrale Base-URL/Header → späterer Proxy-Umbau trivial.

## 5. Wiederverwendung aus Tide (großer Hebel)
Tide enthält zwei Packages, die fast die ganze Pipeline schon abdecken:
- **`Speech` (TideSpeech):** `ElevenLabsClient`, `ElevenLabsRecognizer`, `ElevenLabsSynthesizer`, `AppleSpeechRecognizer`, `AppleSynthesizer`, `HybridRecognizer`, `CompositeSynthesizer`, Protokolle `SpeechRecognizer`/`Synthesizer`. → ElevenLabs STT **und** TTS + Apple-Fallback existieren bereits.
- **`LLM`:** `AnthropicProvider`, `AnthropicRequest`, `SSEParser`, Protokolle `LLMProvider`/`LLMMessage`/`LLMChunk`. → Claude-Anbindung inkl. Streaming existiert bereits, inkl. Tests (`AnthropicProviderTests`, `MockURLProtocol`).

**Entscheidung (zur Freigabe):** beide Packages nach `Dispo/swift-packages/` als geteilte `AtollSpeech` + `AtollLLM` heben (umbenannt), AtollTalk hängt sich dran. Tide-Migration auf die geteilten Packages später, außerhalb v1. Vorteil: kein fragiler Cross-Repo-Pfad, sauber im Atoll-Monorepo. Alternative (schneller, schmutziger): vorerst per relativem Pfad auf die Tide-Packages zeigen.

Zusätzlich: **`AtollDesign`** (BrandColors, AtollGlass, Components) für einheitliches Look-&-Feel; **`AtollCore`** optional (`LocaleStore`).

## 6. UI (nach Dominiks Mockup)
Der Mockup-Entwurf wird übernommen (besser als symmetrische Chat-Blasen): die **Übersetzung steht groß im Vordergrund**, das Original klein/gedämpft darüber — perfekt zum Rüberreichen des Telefons an Maria.

**Haupt-Screen**
- Kopf: `[DE] ↔ [UA] Automatisch` — aktives Paar + Auto-Modus; tippbar → Einstellungen/Paarwahl.
- Verlauf (scrollbar), der **neueste Turn** groß:
  - Quelle (gesprochener Satz) klein, gedämpft, mit kleinem Sprach-Chip.
  - Ziel-Label: Flagge + Sprache in Großbuchstaben, farbig (z. B. „УКРАЇНСЬКА").
  - **Übersetzung in großer, fetter Schrift.**
  - „Vorlesen"-Button (Lautsprecher-Icon) darunter.
  - Ältere Turns scrollen nach oben, kompakter.
- Unten: großer Primär-Button **„Sprechen"** (Mikrofon). Während Aufnahme: Zustand „Höre zu…" + Stopp; danach „Übersetze…".
- **Richtung kippt automatisch:** Spricht Maria Ukrainisch, ist die große Schrift Deutsch (für Dominik); spricht Dominik Deutsch, ist sie Ukrainisch (für Maria). Die große Schrift ist immer die Sprache des Zuhörers.

**Einstellungen:** API-Schlüssel (ElevenLabs, Anthropic), Stimmenwahl je Sprache, Glossar-Editor, Sprachpaar/Registry, Modellwahl (Sonnet/Haiku).

**Design-Tokens** aus `AtollDesign`; Akzentblau wie im Mockup. Sprach-Chips mit Flagge + Kürzel (für „Deutsch" eine klare DE-Kennzeichnung statt rotem Block).

## 7. Datenfluss & Komponenten
Zustandsmaschine: `idle → recording → transcribing → translating → ready` (Fehler → `error`).

Ablauf: `AudioRecorder` nimmt auf (Stille-Stopp/Tippen) → `SpeechRecognizer` (ElevenLabs) liefert Text + Sprache → `LanguageRouter` bestimmt Zielsprache → `TranslationService` (Claude, Prompt aus Kontext + Glossar) → `Turn` wird angehängt & groß gerendert → „Vorlesen" ruft `Synthesizer` (ElevenLabs, Fallback Apple).

Neue, dünne App-Ebene auf den Packages:
- `AppViewModel` (`@MainActor`, `@Observable`): Zustandsmaschine, aktueller + vergangene Turns.
- `Turn` (SwiftData-Modell): `id`, `sourceText`, `sourceLang`, `targetText`, `targetLang`, `timestamp`.
- `ConversationStore`: lokale Persistenz der Turns.
- `LanguageRouter`: erkannte Sprache → (Quelle, Ziel) im aktiven Paar; Sonderfall „Sprache außerhalb Paar".
- `TranslationService`: nutzt `AtollLLM`-`AnthropicProvider`; baut System-Prompt (Kontext + Glossar) + User-Message.
- `GlossaryStore`: editierbare Begriffspaare.
- `Settings` + `KeychainStore` (Vex): Schlüssel, Stimmen, Modell, Paar.

Wiederverwendet: `AtollSpeech` (STT/TTS), `AtollLLM` (Claude), `AtollDesign` (UI).

## 8. Sprach-Erweiterung
`Language`-Registry (Code, Flagge, Anzeigename, ElevenLabs-Voice-ID, optionale Apple-Voice). Neue Sprache = ein Eintrag. STT erkennt automatisch, Claude übersetzt jedes Paar, ElevenLabs spricht; Apple-Fallback wenn Stimme vorhanden. Zwei-Wege-Auto funktioniert für jedes Paar, weil die Erkennung die Sprache liefert.

## 9. Fehler & Edge-Cases
- Kein Netz → klarer Hinweis + „Erneut" (Apple-Fallback-TTS funktioniert offline).
- Mikrofon-Erlaubnis fehlt → Anleitung zu den Einstellungen.
- Leere/unsichere Erkennung → „Bitte nochmal sprechen".
- Erkannte Sprache nicht im Paar → Hinweis + Option, das Paar zu erweitern.
- API-Fehler/Limit/Timeout → verständliche Meldung + Retry.
- Keine ElevenLabs-Stimme/kein Schlüssel → automatischer Apple-Fallback.

## 10. Sicherheit (Vex)
- Schlüssel nur im Keychain (kein Hardcode, nicht in `Info.plist`/Git). Eingabe im Settings-Screen.
- TLS; keine Server-Logs (kein Backend). Lokale Historie bleibt auf dem Gerät; löschbar.
- Je ein **Ausgabelimit** bei ElevenLabs und Anthropic als Sicherheitsnetz.
- `.gitignore` für lokale Configs. Wenn später verteilt: Proxy + Key-Rotation (Hexa/Vex).

## 11. Tests (Vera)
- **Unit:** `LanguageRouter` (Richtungslogik), Prompt-Bau + Glossar-Injektion, Response-Mapping; `SSEParser` ist in Tide bereits getestet; `MockURLProtocol` (aus Tide) für Netz-Mocks.
- **Manuell:** echte DE/UA-Audioproben in lauter Küche (Benchmark-Erkenntnis: immer mit echtem Audio testen, nicht nur saubere Studio-Samples).
- **UI:** Snapshot des „neuester-Turn-groß"-Layouts; VoiceOver-Check.

## 12. Kosten (grobe Größenordnung)
Pro Turn: STT (Scribe, nach Audiodauer) + Claude (kurze Sätze, sehr wenige Tokens) + optional TTS (ElevenLabs nach Zeichen, nur auf Tippen). Realistisch wenige Cent pro Gespräch. Genaue Zahlen vor Release aus den ElevenLabs-/Anthropic-Dashboards bestätigen.

## 13. Offene Punkte
1. **Freigabe:** Packages `Speech`/`LLM` nach `swift-packages/` heben (empfohlen) vs. vorerst Cross-Repo-Pfad.
2. **Default-Modell:** `claude-sonnet-4-6` (empfohlen) vs. `claude-haiku-4-5`.
3. Konkrete ElevenLabs-Voice-IDs für DE und UA.
