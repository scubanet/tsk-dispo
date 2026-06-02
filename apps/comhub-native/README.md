# ComHub — anbieter-offener macOS/iOS-Hub

Native SwiftUI-App (iOS 26 / macOS 26, Swift 6, Strict Concurrency Complete).
Outlook-artiger Hub: Heute-Cockpit, Kalender, Kombox, Kontakte, Aufgaben,
CardInbox — anbieter-offen (Apple/iCloud + Atoll zuerst; Google/Microsoft
später). Baut auf `AtollCore`, `AtollDesign` und `AtollHub` auf.

- Bundle-ID: `swiss.atoll.hub`
- URL-Scheme: `comhub://`
- Single-Tenant: TSK Zürich

## Setup

```bash
cd apps/comhub-native
xcodegen generate
open ComHub.xcodeproj
```

`ComHub.xcodeproj` ist gitignored — wird aus `project.yml` regeneriert.

## Build & Test

```bash
# macOS-App: nur Build verifizieren (kein App-Test-Target — TEST_HOST-Quirk
# auf macOS; testbare Logik liegt in den Paketen).
xcodebuild -scheme ComHub -destination 'platform=macOS,arch=arm64' build

# Kern-Logik (schnell, ohne Xcode) — hier liegen die Unit-Tests.
cd ../../swift-packages/AtollHub && swift test
```

## Phasen-Stand

**Phase 0** — Magic-Link-Login (Supabase, Redirect `comhub://auth/callback`),
leere 3-Spalten-Shell, getesteter Provider-Kern (`AtollHub`).

**Phase 1** — Gemergter, lese-only **Kalender** (Tag/Woche/Monat) aus Apple/iCloud
(EventKit) + Atoll-Events (`course_assignments`) und ein **kombiniertes Adressbuch**
(Apple-Kontakte + Atoll-`contacts`, gematcht/dedupliziert über `ContactMatcher`).
Adapter im App-Target (`ComHub/Adapters/`), reine Mapper/Layout-Logik getestet in
`AtollHub` (`AppleEventMapper`/`AppleContactMapper`/`AtollEventMapper`/`AtollContactMapper`,
`MergedContact`, `CalendarWindow`/`CalendarLayout`).

**Phase 2** — **Heute-Cockpit** (`.heute`-Startmodul): aggregiert **Termine heute**
(live, Apple+Atoll über den Hub) und **offene Aufgaben** (verdrahtet über
`Hub.allTasks()`, leer bis ein TodoProvider in Phase 4 dazukommt). Sektionen
**Neue Nachrichten** und **Neue Leads** sind Empty-States, die Phase 3/4 befüllen.
Jede Sektion navigiert ins zugehörige Modul. Reine Aggregations-Logik getestet in
`AtollHub` (`CockpitDigest`).

**Phase 3a** — **Kombox lesen + Realtime** (`.kombox`-Modul): Kontaktliste
(Konversationen, neueste zuerst, client-seitig aus `contact_events` gruppiert) +
**Verlauf** je Kontakt (WhatsApp-Bubbles in/out, aufklappbare Mail-Karten,
System-Marker, Tages-Trenner) mit **Live-Updates** über Supabase-Realtime
(`contact_events`, invalidate→refetch). Reine Logik getestet in `AtollHub`
(`KomboxEvent`/`KomboxMapper`/`KomboxDigest`). Senden/Antworten/Löschen/Filter
folgen in Phase 3b, der Privat-WhatsApp-WebView-Tab in 3c.
