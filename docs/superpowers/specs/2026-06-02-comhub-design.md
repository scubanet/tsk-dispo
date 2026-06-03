# ComHub — Design-Spec

_Stand: 2026-06-02 · Larry/myPKA · Status: **Design freigegeben** (Brainstorming abgeschlossen, bereit für Implementierungsplan)_

> Diese Spec ersetzt den ersten Entwurf `docs/comhub-native-app-plan.md`. Sie ist das Ergebnis des `/superpowers:brainstorming`-Durchlaufs und das Eingangsdokument für `writing-plans`.

---

## 1. Vision & Nutzer

**ComHub** ist ein **anbieter-offener, Outlook-artiger Hub** als native Apple-App — **ein** integriertes Werkzeug für Kalender, E-Mail, WhatsApp, Aufgaben, Kontakte und Atoll-Events, statt mehrerer getrennter Apps.

**Wer es benutzt:** Nicht die Dispatch-User der Web-App, sondern **Dominik selbst** sowie **TL/DM** (Teamleiter / Dive Manager) — analog zur Positionierung von AtollCal. Es ist ein persönliches Produktivitäts-/Cockpit-Tool, kein Massen-Frontend.

**Leitbild:** „Mein Outlook" — der Kalender ist das Rückgrat, daneben direkter Zugang zu Atoll-Events, E-Mail und WhatsApp als integrierte Kanäle, plus die Tagesübersicht als Heimat.

**Offenheit als Kern-Designprinzip:** Die App wird so gebaut, dass sich **mehrere Anbieter** einklinken lassen — Apple Mail/Kalender/Erinnerungen/Kontakte, Google, Microsoft 365 — und **Atoll** als das große Plus (Events, Kombox-Comms, CardInbox, CRM-Kontakte). Der erste Ausbau liefert **Apple/iCloud + Atoll**; Google/Microsoft folgen über denselben Konten-Mechanismus.

---

## 2. Scope

### In Scope (macOS-MVP + naher Ausbau)
- **Heute-Cockpit** als Startseite (aggregiert Termine, neue Nachrichten, offene Tasks, neue Leads).
- **Kalender**: Apple/iCloud via EventKit (lesen **und** schreiben) **plus** Atoll-Events, in einer gemeinsamen Ansicht zusammengeführt.
- **Kombox** (volle Atoll-Comms): WhatsApp + E-Mail pro Kontakt, Verlauf, Composer, Senden/Antworten/Löschen, Realtime — wie die neue Web-Mailbox.
- **Privat-WhatsApp** als eigener **WhatsApp-Web-WebView-Tab** (offizieller QR), nicht in die Atoll-Kombox gemischt.
- **Kombiniertes Adressbuch**: Atoll-Kontakte + Apple-Kontakte, gematcht/dedupliziert, mit Quell-Tags.
- **Tasks**: Apple Erinnerungen + Atoll-Tasks (`contact_events` Typ `task`), gemeinsam.
- **CardInbox**: Lese-/Bearbeitungsfläche für `card_leads` (AtollCard-Leads), neue Karten erscheinen im Cockpit.
- **Push** bei eingehender Atoll-Nachricht / neuem Lead (APNs).
- **Plattform:** macOS zuerst; iOS/iPadOS aus demselben SwiftUI-Code (späterer Feinschliff).

### Out of Scope / Non-Goals (bewusst nicht im MVP)
- **Kein neues Backend / keine neue Datenbank.** Atoll-Daten bleiben in bestehendem Supabase; Apple-Daten via native Frameworks; Cloud-Tokens im Keychain; nur ein lokaler Geräte-Cache.
- **Kein reverse-engineered WhatsApp** (Baileys o. ä.) — ToS-Verstoß / Sperr-Risiko. Privat-WA ausschließlich über offizielles WhatsApp Web.
- **Google/Microsoft-Adapter** sind vorgesehen, aber **nicht** Teil des ersten Slice.
- Keine Dispatch-/Disponenten-Funktionen (das ist die Web-App).
- Keine serverseitige Comms-Logik-Duplikation — Matching/Provider/Read-Semantik bleiben im Backend.

---

## 3. Architektur

### 3.1 Ansatz (gewählt: Ansatz 1)
Eine **neue SwiftUI-Multiplatform-App „ComHub"**, die bestehende Swift-Packages wiederverwendet:
- **`AtollDesign`** — Marken-/Glass-Theme (BrandColors, Komponenten), für konsistenten Look mit AtollCard/AtollCal.
- **`AtollCal`** — Kalender als eingebettetes Modul/Package.
- Die **Datenschicht** wird als kleines, sauberes Modul gebaut, das später zu einem gemeinsamen **„AtollKit"** wachsen kann.

### 3.2 Schichten
```
UI (SwiftUI, NavigationSplitView 3-spaltig, AtollDesign-Theme)
        │
Hub-Kern (Aggregation über Konten; vereinheitlichte Modelle; Matching/Dedup)
        │
Capability-Protokolle:  MailProvider · CalendarProvider · TodoProvider · ContactsProvider
        │                + Atoll-spezifisch: CommsProvider · EventsProvider · CardInboxProvider
Adapter:  AppleAdapter · AtollAdapter · (später) GoogleAdapter · MicrosoftAdapter
        │
Quellen:  EventKit · Reminders · Contacts.framework · IMAP  │  supabase-swift (PostgREST/Realtime/Functions)
        │
Lokaler Cache: SwiftData (pro Gerät) · Keychain (Sessions/Tokens)
```

### 3.3 Konten-Modell
Ein **`Account`** trägt einen Typ (`apple` | `google` | `microsoft` | `atoll`) und erfüllt eine oder mehrere Capability-Protokolle. Der Hub-Kern fragt **alle** Konten ab, die eine Capability können, und führt die Ergebnisse in vereinheitlichten Modellen zusammen. Neue Anbieter = neuer Adapter, der die Protokolle erfüllt — der Rest der App bleibt unverändert.

### 3.4 Capability-Matrix (erster Ausbau)

| Capability        | AppleAdapter                    | AtollAdapter                                  | Google/MS (später) |
|-------------------|---------------------------------|-----------------------------------------------|--------------------|
| **Calendar**      | EventKit (lesen + schreiben)    | Atoll-Events (lesen; schreiben nach Bedarf)   | geplant            |
| **Mail**          | IMAP (vorbereitet, nach MVP)    | `comms-outbound` (Resend) / `contact_events`  | geplant            |
| **Todo**          | Reminders                       | `contact_events` Typ `task`                   | geplant            |
| **Contacts**      | Contacts.framework              | `contacts` (CRM)                              | geplant            |
| **Comms (Kombox)**| —                               | `contact_events` (WhatsApp+Mail) + Realtime   | —                  |
| **CardInbox**     | —                               | `card_leads` (+ Realtime)                     | —                  |

> Apple-WhatsApp gibt es nicht als Capability — **privates WhatsApp** läuft separat als WebView-Tab (siehe §7). **Atoll-WhatsApp** (Geschäftsnummer, 360dialog) ist Teil der Kombox-Comms.

### 3.5 Stack
- **SwiftUI Multiplatform**, ein Target für macOS + iOS/iPadOS. `NavigationSplitView` liefert das 3-Spalten-Layout und kollabiert auf iPhone zu Stack-Navigation.
- **supabase-swift** (offizielles SDK): Auth, PostgREST, **Realtime** (Postgres Changes, RLS-konform), `functions.invoke` für `comms-outbound`.
- **EventKit** (Kalender), **EventKit/Reminders** (Tasks), **Contacts.framework** (Adressbuch) — native Apple-Frameworks mit System-Berechtigungen.
- **SwiftData** als lokaler Cache (Offline-Lesen, schneller Start); Quellen bleiben Source of Truth.
- **Keychain** für Atoll-Session und (später) Google/MS-Tokens.
- **APNs** für Push.

---

## 4. Module & Layout

**Outlook-Stil, 3-spaltig** (`NavigationSplitView`): links **Modul-Leiste** (Icon-Rail), Mitte **Liste**, rechts **Detail**. macOS mit Menüleiste/Shortcuts; iPad 2–3 Spalten; iPhone Stack.

1. **Heute (Cockpit)** — Startseite. Aggregiert: **Termine heute**, **neue Nachrichten** (Atoll-Kombox), **offene Tasks**, **neue Leads** (CardInbox). Jede Zeile verlinkt ins jeweilige Modul. Quell-Badges (Atoll / Apple).
2. **Kalender** — Apple/iCloud (EventKit, lesen+schreiben) + Atoll-Events, **gemergt**; Tag/Woche/Monat (AtollCal-Reuse).
3. **Kombox** — Kontaktliste (letzte Nachricht, Ungelesen-Badge) · Verlauf (WhatsApp-Bubbles, aufklappbare Mail-Karten, System-Marker, Tages-Trenner) · Composer (Kanal-Switch WhatsApp/Mail, Templates, Betreff, Senden via `comms-outbound`, Antworten, Löschen) · Filter Alle/WhatsApp/Mail, Suche, Quick-Log/Quick-Task — **gleicher Aufbau wie die neue Web-Mailbox**.
4. **Kontakte/Adressbuch** — kombiniert (Atoll + Apple), Liste + Detail.
5. **Tasks** — Apple Erinnerungen + Atoll-Tasks, gemeinsam.
6. **CardInbox** — `card_leads` (AtollCard-Komponenten-Reuse), „Lead → Kontakt".
7. **Privat-WhatsApp** — eigener Tab mit WhatsApp Web im WebView (siehe §7).

---

## 5. Daten & Fluss

### 5.1 Vereinheitlichte Modelle
Der Hub-Kern definiert quellneutrale Modelle (`UnifiedEvent`, `UnifiedMessage`, `UnifiedTask`, `UnifiedContact`, `Lead`) mit `source`-Tag und der jeweiligen Original-ID. Adapter mappen ihre Rohdaten auf diese Modelle.

### 5.2 Kontakt-Matching / Dedup (kombiniertes Adressbuch)
Atoll- und Apple-Kontakte werden über **normalisierte E-Mail/Telefonnummer** gematcht (E.164-Normalisierung für Telefon, lowercase/trim für Mail). Treffer werden zu einem `UnifiedContact` verlinkt (mit beiden Quell-IDs); Dubletten werden zusammengeführt, Quellen bleiben als Tags sichtbar. Kein Schreiben über Quellgrenzen im MVP (Atoll-Kontakt bleibt in Supabase, Apple-Kontakt in Contacts.framework).

### 5.3 Realtime & Sync
- **Atoll:** Supabase **Realtime** (Postgres Changes, RLS-aware) auf `contact_events` (Kombox-Live wie im Web) und `card_leads` (neue Leads). Senden via `supabase.functions.invoke("comms-outbound", …)`, optimistisch einfügen, Bestätigung via Realtime.
- **Apple:** EventKit-/Contacts-Change-Notifications → SwiftData-Cache aktualisieren.
- **Cache:** SwiftData hält den letzten Stand pro Gerät für Offline-Lesen und schnellen Start.

### 5.4 Backend
**Kein neues Backend, keine neue DB.** Bestehendes Supabase-Projekt `axnrilhdokkfujzjifhj`: Auth, `contacts`, `contact_events`, `card_leads`, RLS, Realtime (bereits für `contact_events` + `card_leads` in der Publication). Senden über bestehende Edge Function `comms-outbound`; Empfang serverseitig über `comms-inbound`. Einzige Backend-Ergänzung: ein kleiner Push-Zusatz (siehe §8).

---

## 6. Auth & Konten

- **Atoll (Supabase):** Auth wie im Web, nativ über **OTP-Code** (einfachste native Variante); Session im **Keychain**. (Universal-Link-Magic-Link optional später.)
- **Apple:** System-Berechtigungsdialoge für Kalender, Erinnerungen, Kontakte (EventKit/Reminders/Contacts).
- **Privat-WhatsApp:** offizieller **QR-Login** im WebView (WhatsApp Web).
- **Google/Microsoft:** OAuth später, Tokens im Keychain — über denselben `Account`-Mechanismus.

Berechtigung ist pro Konto/Capability; das Konten-Modell hält fest, welches Konto welche Capability liefert.

---

## 7. WhatsApp-Strategie

Zwei klar getrennte Wege — bewusst hybrid:

- **Atoll-WhatsApp (Geschäftsnummer):** offiziell über **360dialog** angebunden, läuft serverseitig über `comms-outbound`/`comms-inbound` und ist **voll in die Kombox integriert** (gemischter Verlauf mit Mail pro Kontakt, im Cockpit aggregiert).
- **Privates WhatsApp:** über **WhatsApp Web in einem WebView-Tab** (offizieller QR-Login). Das ist genau der Ansatz der „inoffiziellen" App-Store-Apps (WebView-Wrapper um WhatsApp Web) — sicher, keine eigene Infrastruktur, kein ToS-Verstoß. **Aber:** eigener gerenderter Bereich, **nicht** in die Atoll-Kombox gemischt.
- **Bewusst verworfen:** reverse-engineered Clients (Baileys o. ä.) — ToS-Verstoß, Sperr-Risiko, Session-Service nötig.

---

## 8. Push & Benachrichtigungen

Der stärkste native Mehrwert: echte Push bei eingehender Atoll-WhatsApp/Mail und bei neuen Leads.
- **Umsetzung:** kleiner Zusatz nach dem Insert in `comms-inbound` (bzw. DB-Trigger) → Push über **APNs**; Device-Token in neuer Tabelle `device_tokens`.
- **Reuse:** APNs-Erfahrung aus AtollCard + bestehende `send-notification`-Function.
- **Deep-Link:** Notification öffnet direkt den Kontakt/Verlauf bzw. den Lead.

---

## 9. Reuse (bestehende Bausteine)

- **AtollDesign** — Theme/Komponenten (Glass-Look, BrandColors).
- **AtollCal** — Kalender-Modul (als Package).
- **AtollCard** — Komponenten für die CardInbox (`card_leads`).
- **Web-Mailbox-Design** — Aufbau der Kombox (TimelineFeed: Bubbles/Mail-Karten/Marker/Trenner, Composer) als Vorlage für die native Umsetzung.
- **Backend** — Supabase, `comms-outbound`/`comms-inbound`, Realtime-Publication, `send-notification`.

---

## 10. Testing

- **Adapter-Protokolle:** Unit-Tests gegen `MailProvider`/`CalendarProvider`/`TodoProvider`/`ContactsProvider` mit Fake-Adaptern.
- **Aggregation & Matching:** Tests für die Hub-Kern-Zusammenführung und das Kontakt-Matching/Dedup (E-Mail/Telefon-Normalisierung, Verlinkung, Dubletten).
- **Cache-Sync:** Tests für SwiftData-Aktualisierung aus Realtime/Change-Notifications.

---

## 11. Phasen / Slices (macOS zuerst; Apple + Atoll)

| Phase | Inhalt | Aufwand |
|---|---|---|
| **0 — Gerüst & Konten** | Multiplatform-SwiftUI-Projekt; `AtollDesign` + `AtollCal` als Packages; supabase-swift; **Provider-/Account-Kern** (Protokolle + Capability-Matrix); Atoll-Auth (OTP) + Apple-Permissions; leere 3-Spalten-Shell + Modul-Leiste | ~1 Wo |
| **1 — Kalender + Kontakte (lesen)** | AppleAdapter (EventKit, Contacts) + AtollAdapter (Events, `contacts`) → gemergter **Kalender** (Tag/Woche/Monat) + **kombiniertes Adressbuch** (Dedup/Matching) | ~1–2 Wo |
| **2 — Heute-Cockpit** | aggregierte Heimat (Termine + Nachrichten + Tasks + neue Leads), verlinkt in die Module | ~1 Wo |
| **3 — Kombox (Atoll-Comms voll)** | Web-Mailbox nativ (Liste · Verlauf · Composer), Senden via `comms-outbound`, Realtime, Antworten/Löschen + **Privat-WhatsApp-WebView-Tab** | ~1–2 Wo |
| **4 — Tasks + CardInbox** | Apple Reminders + Atoll-Tasks gemergt; **CardInbox** (`card_leads`, „Lead → Kontakt") | ~1 Wo |
| **5 — Schreiben + Push** | EventKit/Reminders zurückschreiben; APNs-Push für Atoll-inbound + neue Leads | ~1 Wo |
| **6 — iOS + Google/Microsoft** | iOS-Feinschliff aus demselben Code; Google-/MS-Adapter über den Konten-Slot | später |

→ Brauchbarer **macOS-Stand** (Kalender + Kontakte + Cockpit + Kombox) nach **Phase 3 (~5–6 Wochen)**; voll mit Tasks/CardInbox/Push ~7–8 Wochen; iOS + Google/MS danach.

---

## 12. Risiken / offene Fragen

- **AtollCal-Reuse-Tiefe:** als Package einbinden vs. Screens adaptieren — hängt von der heutigen Modularität von AtollCal ab. Früh prüfen.
- **IMAP-Aufwand (Apple Mail):** echtes IMAP ist mehr Arbeit als EventKit/Contacts; ggf. erst Atoll-Mail in der Kombox, Apple-Mail-Capability später im selben Slot.
- **Kontakt-Matching-Qualität:** Telefon-/Mail-Normalisierung muss robust sein, sonst Dubletten oder Fehlverknüpfungen.
- **WebView-WhatsApp:** offizielles WhatsApp Web im WebView ist erlaubt und stabil, aber bewusst **getrennt** — keine Aggregation ins Cockpit.
- **Multiplatform-Feinheiten:** macOS zuerst, iOS „fällt fast ab", aber Push + Layout brauchen je etwas Plattform-Spezifisches (`#if os(...)`).
- **Push-Zusatz im Backend:** kleiner Eingriff in `comms-inbound`/Trigger + `device_tokens`-Tabelle — sauber halten, damit die Web-Pfade unberührt bleiben.

---

_Quellen: bestehender Entwurf `docs/comhub-native-app-plan.md`; Supabase Swift SDK & Realtime-Doku (supabase.com/docs/reference/swift, .../guides/realtime/postgres-changes); Apple EventKit/Reminders/Contacts; WhatsApp Web._
