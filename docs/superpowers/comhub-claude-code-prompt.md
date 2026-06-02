# ComHub — Weiterbau in Claude Code (Übergabe-Prompt)

> Diesen ganzen Block in Claude Code im Repo-Root (`~/Desktop/Developer/Dispo`) als erste Nachricht einfügen.

---

Du baust die native **ComHub**-App im Repo `tsk-dispo` Phase für Phase fertig — mit **echter Verifikation** (`swift test` / `xcodebuild`). Lies zuerst die Spec und den Phase-0-Plan, bevor du irgendetwas tust.

## Quellen der Wahrheit (zuerst lesen)
- Design-Spec (Scope, Architektur, Module, Phasen): `docs/superpowers/specs/2026-06-02-comhub-design.md`
- Ausgeführter Phase-0-Plan (Stil/Granularität als Vorlage): `docs/superpowers/plans/2026-06-02-comhub-phase0-foundation.md`

## Stand: Phase 0 ist fertig (Branch `comhub-phase0`, macOS-Build grün)
- Neues Paket `swift-packages/AtollHub` — anbieter-offener Provider-Kern: `UnifiedEvent/Message/Task/Contact`, `Lead`; `Account`/`Capability`; Capability-Protokolle (`CalendarProvider`/`MailProvider`/`TodoProvider`/`ContactsProvider` + Atoll `CommsProvider`/`EventsProvider`/`CardInboxProvider`); `Hub`-Aggregator über `AccountConnection`; reine Hilfen `ContactKey`/`ContactMatcher`/`ComHubModule`/`OTPCode`. XCTest-abgedeckt.
- `AtollCore.AuthState` additiv um `sendEmailCode`/`verifyEmailCode` (OTP-Code-Login) erweitert.
- App `apps/comhub-native` (XcodeGen): OTP-`SignInView`, `AppleAuthorizationService` (EventKit/Contacts-Permissions), `RootView`-Gating, 3-Spalten-`HubShell` mit Modul-Leiste (Platzhalter). Noch **keine** echten Daten-Adapter.

## Verifikation (der Grund, hier statt in der Cloud zu arbeiten — nutze superpowers:verification-before-completion)
- XcodeGen (`.xcodeproj` ist gitignored, immer regenerieren): `cd apps/comhub-native && xcodegen generate` — fehlt das Tool: `brew install xcodegen`.
- App bauen: `xcodebuild -scheme ComHub -destination 'platform=macOS,arch=arm64' build`
- Paket-Tests: `cd swift-packages/AtollHub && swift test` (analog `swift-packages/AtollCore`).
- Nie „fertig" sagen ohne grüne Ausgabe. Erst Test/Build grün, dann committen.

## Konventionen (an bestehende Repo-Muster halten)
- Swift 6, `SWIFT_STRICT_CONCURRENCY: complete`, iOS/macOS 26.
- XcodeGen: **ein** Target via `supportedDestinations: [iOS, macOS]` — NICHT `platform: [iOS, macOS]` (das splittet in `_iOS`/`_macOS` und zerschießt Scheme + Test-Host). Muster: `apps/comhub-native/project.yml` und `apps/atollcal-native/project.yml`.
- App-Test-Targets, die `@testable import <App>` brauchen, sind auf macOS heikel (TEST_HOST-Quirk: `…app/ComHub` statt `…app/Contents/MacOS/ComHub`). Logik daher in Pakete auslagern und dort per `swift test` prüfen; App-Targets nur per Build verifizieren.
- Pakete unter `swift-packages/`, eingebunden über `project.yml`→`packages:`.
- AtollCore-Bootstrap: `AtollCoreConfig.register(AppSupabaseConfig())` MUSS vor jeder `@State`-Init laufen (siehe `swift-packages/README.md` + `ComHub/ComHubApp.swift`).
- Supabase (prod): Projekt-Ref `axnrilhdokkfujzjifhj`; URL + Anon-Key in `apps/comhub-native/ComHub/Config.swift`. **Niemals** Service-Keys/Secrets in Code oder Commits.
- Commit-Stil: knapp, beschreibend, **keine Umlaute** in Messages (ae/oe/ue/ss), keine `feat:`-Prefixe nötig. Häufig committen.
- Auf `comhub-phase0` weiterarbeiten (oder pro Phase ein Branch von dort). **Nicht** auf `main` implementieren.
- Hinweis: auf `comhub-phase0` liegt parallel ein `feat(atolltalk):`-Commit (anderes Projekt) — nicht anfassen, kein Konflikt.

## Vorgehen pro Phase
Für JEDE Phase unten, der Reihe nach:
1. `superpowers:writing-plans` → `docs/superpowers/plans/<YYYY-MM-DD>-comhub-phaseN-<thema>.md` aus der Spec. Bissgroße TDD-Tasks, exakte Pfade, echte Verifikations-Befehle. Plan mir zur Freigabe vorlegen.
2. `superpowers:subagent-driven-development` (oder `executing-plans`) → Task für Task umsetzen, vor jedem Commit `swift test` + `xcodebuild` grün.
3. Phasenabschluss: `superpowers:requesting-code-review` + manueller Smoke-Test; dann `superpowers:finishing-a-development-branch`.

## Phasen-Roadmap (aus der Spec)
- **Phase 1 — Kalender + Kontakte (lesen).** AppleAdapter (EventKit, Contacts) + AtollAdapter (Atoll-Events via supabase-swift, `contacts`) hinter den AtollHub-Protokollen; gemergter Kalender (Tag/Woche/Monat) + kombiniertes Adressbuch (`ContactMatcher`). **Voraussetzung früh klären:** `apps/atollcal-native` ist heute eine App, kein Paket — entweder die Kalender-Views in ein Paket `swift-packages/AtollCalKit` extrahieren oder gezielt adaptieren.
- **Phase 2 — Heute-Cockpit.** Aggregiert Termine + neue Nachrichten + offene Tasks + neue Leads; jede Zeile verlinkt ins Modul.
- **Phase 3 — Kombox (Atoll-Comms voll).** Kontaktliste · Verlauf (WhatsApp/Mail, wie die Web-Mailbox) · Composer; Senden via Edge Function `comms-outbound`; Realtime auf `contact_events`; Antworten/Löschen. Plus **Privat-WhatsApp = WhatsApp-Web-WebView-Tab** (offizieller QR, separater Pane, NICHT in die Atoll-Kombox gemischt).
- **Phase 4 — Tasks + CardInbox.** Apple Erinnerungen + Atoll-Tasks (`contact_events` Typ `task`) gemergt; CardInbox liest `card_leads` (Realtime aktiv), „Lead → Kontakt".
- **Phase 5 — Schreiben + Push.** EventKit/Reminders zurückschreiben; APNs-Push via kleinem Zusatz in `comms-inbound` + Tabelle `device_tokens` (kein neues Backend, nur Ergänzung).
- **Phase 6 — iOS + Google/Microsoft.** iOS-Feinschliff aus demselben Code; Google-/MS-Adapter über den `Account`-Slot.

## Jetzt starten
Lies Spec + Phase-0-Plan, sichte `swift-packages/AtollHub` und `apps/atollcal-native` (wie modular sind die Kalender-Views?), entscheide die AtollCal-Paketierung, dann schreib den **Phase-1-Plan** und leg ihn mir zur Freigabe vor, bevor du implementierst.
