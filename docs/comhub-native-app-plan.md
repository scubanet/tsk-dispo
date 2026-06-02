# ComHub (AtollKom-Hub) — Plan: native macOS- & iOS-App

_Stand: 2026-06-02 · Larry/myPKA_

## 1. Vision

**ComHub** ist ein **modularer, Outlook-artiger Hub**, der die heute getrennten Bausteine in **einer** nativen App zusammenführt — statt mehrerer Apps:

- **Kombox** — die Kommunikations-Zentrale: WhatsApp + E-Mail pro Kontakt, mit dem Verlauf und Composer, den wir gerade im Web gebaut haben.
- **Kalender** — AtollCal (bestehende SwiftUI-App) als Modul.
- **Adressbuch/Kontakte** — die CRM-Kontakte mit Detail (Stammdaten, Rollen, Saldo).
- _optional_ **Heute/Cockpit** — Tagesübersicht (offene Tasks, neue Nachrichten, Termine).

Layout wie Outlook: links eine **Modul-Sidebar**, dann eine **Listen-Spalte**, dann eine **Detail-Spalte**. **macOS zuerst**, iOS/iPadOS aus demselben Code.

## 2. Grundprinzip: gleiches Backend, neuer Client

**Kein neues Backend.** ComHub ist ein SwiftUI-Client über das bestehende Supabase-Projekt (`axnrilhdokkfujzjifhj`):

- Auth, `contacts`, `contact_events`, RLS und **Realtime** (gerade aktiviert) sind schon da.
- **Senden** → ruft die bestehende Edge Function `comms-outbound` (Resend für Mail, 360dialog für WhatsApp).
- **Empfangen** → läuft serverseitig (`comms-inbound`-Webhook schreibt `contact_events`); der Client bekommt neue Nachrichten **live via Realtime**.
- **Lesebestätigung** (WhatsApp blaue Haken) → schon serverseitig in `comms-inbound`.

→ Die gesamte Comms-Logik (Matching, Provider, Read-Semantik) bleibt im Backend. Der native Client ist eine **schöne Oberfläche + Realtime + Push** — keine Geschäftslogik wird dupliziert.

## 3. Tech-Stack

- **SwiftUI, Multiplatform** — ein Target für macOS + iOS/iPadOS. `NavigationSplitView` liefert das 3-Spalten-Layout und kollabiert auf iPhone automatisch zu Stack-Navigation.
- **supabase-swift** (offizielles SDK, spiegelt supabase-js): Auth, PostgREST-Queries, Realtime (Postgres Changes, RLS-konform), `functions.invoke` für `comms-outbound`. Unterstützt iOS/macOS, Installation via SPM.
- **AtollDesign** (euer bestehendes Swift-Package: BrandColors, Glass-Theme) — wiederverwenden für konsistenten Look mit AtollCard/AtollCal.
- **AtollCal** — als Package/Modul einbinden (Kalender-Spalte).
- **Lokaler Cache:** SwiftData (oder GRDB) für Offline-Lesen + schnellen Start; Supabase bleibt Source of Truth.
- **Keychain** für die Session.

## 4. Module (Outlook-Stil)

1. **Kombox** (Kern, Modul 1):
   - Kontaktliste mit letzter Nachricht + Ungelesen-Badge.
   - Verlauf: WhatsApp-Bubbles + aufklappbare Mail-Karten + System-Marker + Tages-Trenner — **derselbe Aufbau wie im Web** (Design steht).
   - Filter Alle/WhatsApp/Mail, Suche im Verlauf, Quick-Log (Notiz/Anruf/…).
   - Composer: Kanal-Switch WhatsApp/Mail, Templates, Senden via `comms-outbound`, Antworten, Löschen.
2. **Kalender:** AtollCal eingebettet.
3. **Kontakte/Adressbuch:** Liste + Detail (read/edit gegen `contacts`).
4. **Heute** (optional): aggregierte Tagesansicht.

Modulwechsel über die linke Sidebar — analog zur Web-Navigation.

## 5. Layout & Plattform

- **macOS:** `NavigationSplitView` 3-spaltig (Modul-Sidebar | Liste | Detail), Menüleiste, Tastatur-Shortcuts, ggf. mehrere Fenster.
- **iOS/iPadOS:** dasselbe `NavigationSplitView` — iPad 2–3 Spalten, iPhone Stack.
- Ein Codebase; plattform-spezifische Feinheiten via `#if os(macOS)`.

## 6. Daten- & Realtime-Schicht

- Kontakt öffnen → `contact_events` laden (PostgREST) + Realtime-Channel `contact_events:<id>` abonnieren → eingehende Nachrichten erscheinen sofort (wie der Web-Live-Refresh).
- Senden → `supabase.functions.invoke("comms-outbound", …)`; optimistisch einfügen, Bestätigung via Realtime.
- RLS gilt auch im Realtime (nur erlaubte Zeilen werden zugestellt).

## 7. Push-Benachrichtigungen — der native Mehrwert

Das stärkste Argument für nativ gegenüber Web: **echte Push** bei eingehender WhatsApp/Mail.

- Umsetzung: kleiner Zusatz nach dem Insert in `comms-inbound` (oder DB-Trigger) → Push über **APNs** an die Geräte (Device-Token in neuer Tabelle `device_tokens`).
- Notification → Deep-Link direkt in den Kontakt/Verlauf.
- **Reuse:** ihr habt APNs-Erfahrung aus AtollCard (die „APNs-Welle") + die `send-notification`-Function.

## 8. Auth

- Supabase-Auth wie im Web (Magic-Link). Nativ zwei Optionen:
  - **OTP-Code** eingeben (einfachste native Variante), oder
  - **Magic-Link via Universal Link** zurück in die App (Apple-App-Site-Association nötig).
- Empfehlung: mit OTP starten, Universal Link später. Session im Keychain.

## 9. Phasen / Meilensteine

| Phase | Inhalt | Aufwand |
|---|---|---|
| **0 — Gerüst** | Multiplatform-SwiftUI-Projekt, supabase-swift, Auth (OTP), AtollDesign + AtollCal eingebunden, leere 3-Spalten-Shell | ~1 Woche |
| **1 — Kombox lesen** | Kontaktliste, Verlauf (Bubbles/Mail-Karten/Marker/Trenner), Realtime-Live-Refresh — read-only | ~1–2 Wochen |
| **2 — Kombox senden** | Composer (WhatsApp/Mail), Senden via `comms-outbound`, Templates, Antworten, Löschen | ~1 Woche |
| **3 — Module** | Kalender (AtollCal) + Kontakte/Adressbuch integriert, Modul-Sidebar | ~1–2 Wochen |
| **4 — Push** | APNs-Tokens + Push bei inbound + Deep-Link | ~1 Woche |
| **5 — Politur** | Offline-Cache, Shortcuts, Menüleiste, iOS-Feinschliff, Tests | laufend |

→ **MVP** (macOS · Kombox lesen + senden + Realtime) realistisch in **~4–5 Wochen**; voller Hub + iOS + Push **~8–10 Wochen**.

## 10. Risiken / offene Fragen

- **Magic-Link nativ:** Universal Links einrichten _oder_ auf OTP-Code umstellen — früh entscheiden.
- **AtollCal-Reuse-Tiefe:** als Package einbinden vs. Screens kopieren — hängt davon ab, wie modular AtollCal heute aufgebaut ist.
- **Multiplatform-Aufwand:** macOS-zuerst, iOS „fällt fast ab" — aber Notifications + Layout brauchen je etwas Plattform-Spezifisches.
- **Realtime aktivieren:** für neue Tabellen ist Realtime per Default aus; `contact_events` haben wir bereits in die Publication aufgenommen — passt.

## 11. Empfehlung

- **macOS zuerst** (dein Hauptgerät), iOS direkt aus demselben Target mitnehmen.
- **Kombox = Modul 1** — höchster Nutzen, Design steht aus dem Web.
- **Backend nicht anfassen** — nur ein dünner Push-Zusatz in `comms-inbound`.
- Start mit **Phase 0 + 1 als Durchstich** (Auth → Kontakt → Live-Verlauf), dann iterieren.

---

_Quellen: Supabase Swift SDK & Realtime-Doku — supabase.com/docs/reference/swift, supabase.com/docs/guides/realtime/postgres-changes_
