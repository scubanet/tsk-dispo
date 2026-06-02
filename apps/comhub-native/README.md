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

**Phase 3b** — **Kombox schreiben + 3-Pane** (CoHub-Look): Kanal-Rail
(Alle/WhatsApp/Mail) · Konversationsliste mit Suche · Reader mit **Composer**
(Senden via Edge Function `comms-outbound`) und **Löschen** (`contact_events`).
Filter-Logik getestet in `AtollHub` (`KomboxFilter`). Senden braucht eine
`messaging_accounts`-Zeile des Users. Privat-WhatsApp-WebView folgt in 3c.

**Phase 3c** — **Privat-WhatsApp** als eigener Tab: WhatsApp Web (offizieller
QR-Login) in einem `WKWebView` mit Desktop-User-Agent und persistentem Datastore
(Login bleibt erhalten). Bewusst **getrennt** von der Atoll-Kombox. Damit ist die
Kombox-Phase 3 abgeschlossen (lesen + senden + Privat-WhatsApp).

**Design D1** — CoHub-Mockup-Look: ComHub-lokale Design-Schicht (`ComHub/Design/`:
`CoColor`/`CoTheme`/`CoCard`/`CoAvatar`/`CoChip`), Systemblau-Akzent (light/dark),
restylte **Sidebar** (modul-farbige Icons, Count-Badges, User-Footer) und ein neu
gebautes **Heute** (Begrüssung + „Heutiger Tagesablauf"-Karte + Vorschau-Widgets).
Reine Helfer getestet in `AtollHub` (`Initials`/`AvatarPalette`/`Greeting`).
Referenz: `docs/superpowers/specs/2026-06-02-comhub-design-system.md`. Restyle
Kalender/Kombox/Kontakte folgt in D2; Aufgaben/CardInbox in Phase 4 direkt im Look.

**Design D2a** — **Kontakte** im CoHub-Look: 2-Pane (links A-Z-Liste mit Suche,
Avatar, Quell-Chips, E-Mail; rechts Detail mit grossem Avatar, Mail/Anruf-Aktionen,
Detail-Zeilen). A-Z-Gruppierung getestet in `AtollHub` (`ContactSections`).
Kombox-Restyle folgt in Phase 3b.

**Design D2b** — **Kalender** als echtes Zeitgitter (CoHub-Look): Tag/Woche mit
Stunden-Gutter, Gitterlinien, überlappenden Event-Blöcken (Spalten-Packing),
Ganztags-Lane, roter Now-Linie und Heute-markiertem Tages-Header; Monat als
7-Spalten-Raster mit Farb-Dots. Reine Layout-Logik getestet in `AtollHub`
(`EventColumns`, `DayWindow`). Erstellen/Drag (Schreiben) folgt in Phase 5.

**Design D3** — **Einstellungen** (`.einstellungen`-Modul) im CoHub-Look: Konto-Kopf,
**Abmelden** (`auth.signOut`), Apple-Berechtigungs-Status (Kalender/Erinnerungen/
Kontakte) mit „Erneut anfragen" + Systemeinstellungen-Deeplink, Atoll-Konto, Hinweis
„Erscheinungsbild folgt System", Versions-Fusszeile. Push-Schalter folgt in Phase 5,
Google/Microsoft-Konten in Phase 6.
