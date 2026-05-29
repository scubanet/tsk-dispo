# Design-Spec: Comms-Integration (E-Mail + WhatsApp + LinkedIn) via Unipile

- **Datum:** 2026-05-29
- **Status:** Freigegeben (Design) — bereit für Implementierungsplan
- **Scope:** `apps/web` (AtollCal) + Supabase (Postgres, Edge Functions)
- **Verwandt:** `docs/superpowers/specs/2026-05-27-contacts-crm-redesign.md`,
  `PKA/Deliverables/2026-05-28-unipile-whatsapp/` (Briefing + Stufe-1-Konzept)

## 1. Ziel

Aus den manuellen Log-Composern der Contact-Timeline (`WhatsAppLogComposer`,
`EmailLogComposer`, `CallComposer`) wird echte, zweiseitige Kommunikation: E-Mail,
WhatsApp und LinkedIn werden **gesendet und automatisch empfangen** und erscheinen am
richtigen Kontakt. LinkedIn dient zusätzlich der **Anreicherung** von Adressdaten.

Alle drei Kanäle werden **gleichzeitig** integriert (kein Phasing nach Kanal).

## 2. Entscheidungen (gewählt)

| Frage | Entscheidung |
|---|---|
| Provider-Strategie | **Ansatz C** — Unipile als einziger Layer, je legalste Methode darunter |
| E-Mail | Über Unipile (Gmail/Outlook/IMAP), nicht Direkt-OAuth |
| WhatsApp | Über Unipile **Cloud API** (via BSP), nicht QR/Web-Bridge |
| LinkedIn | Über Unipile — Comms **und** Anreicherung (Account-Risiko akzeptiert) |
| Richtung | Zwei-Wege (senden + empfangen) ab Start |
| UI-Ort | Timeline pro Kontakt **+** zentraler Unified-Inbox-Screen |
| WhatsApp-Nummer | Dedizierte Business-Nummer (Dominik besorgt) — **nie** die private |

### Begründung Schlüsselpunkte

- **E-Mail über Unipile:** Direkt-Anbindung erforderte Googles OAuth-Verifizierung für
  sensible Scopes (jährliches CASA-Security-Assessment) + separate MS-App-Registrierung.
  Unipile hat das (Hosted-Auth, CASA Tier 2), Token-Refresh automatisch, Backend sieht
  nur `account_id`. Fixpreis bis 10 Accounts → kein Kostenargument fürs Direkt-Anbinden.
- **WhatsApp Cloud API statt QR:** QR/Web-Bridge liegt in der ToS-Grauzone mit realem
  Sperr-Risiko (siehe Briefing). Cloud API via BSP ist offiziell und ban-sicher.
- **Nummer-Constraint:** Eine Cloud-API-Nummer kann nicht gleichzeitig im normalen
  WhatsApp laufen → zwingend dedizierte Nummer.

## 3. Architektur & Datenfluss

```
E-Mail (Gmail/Outlook/IMAP) ┐
LinkedIn (Comms+Enrichment) ┼──► Unipile (Hosted-Auth · Webhooks · Send-API)
WhatsApp (Cloud API via BSP)┘            │
                                         ▼
                    Edge Function: inbound   Edge Function: outbound
                    (normalisieren+matchen)  (senden)
                                         │
                                         ▼
                    Supabase Postgres: contact_events · contacts(Anreicherung)
                                         │
                                         ▼
                    AtollCal UI: Timeline + Unified Inbox
```

- Unipile ist das **einzige**, was externe Konten berührt. Backend hält nie Roh-OAuth-
  Tokens, nur `unipile_account_id` + server-seitigen API-Key.
- Empfangen läuft abwärts, Senden aufwärts (alle Verbindungen zweiseitig).
- Anreicherung ist ein eigener Pfad: schreibt in `contacts`, nicht in die Event-Timeline.

## 4. Datenmodell

### 4.1 Event-Typen (wiederverwenden + 1 neu)
- Bestehend genutzt: `whatsapp_log`, `email_external`.
- Neu in `UserEventType`: `linkedin_message`.
- Unterscheidung auto/manuell über `payload`, **nicht** über neue Typen.

`payload`-Erweiterung (alle Messaging-Events):
```ts
{
  source: 'auto' | 'manual'
  direction: 'inbound' | 'outbound'
  provider_message_id: string      // = source_id
  thread_id?: string
  attachment_count?: number
  unipile_account_id: string
}
```
Gesendete Nachrichten = dasselbe Event mit `direction: 'outbound'`.

### 4.2 Kontakt-Matching (inbound → Kontakt)
- WhatsApp: gegen `contacts.phones[].e164` (normalisiert via `libphonenumber-js`).
- E-Mail: gegen `contacts.emails[].email`.
- LinkedIn: gegen neues stabiles Feld `contacts.linkedin_member_id`.

### 4.3 Idempotenz
- Unique-Index `contact_events(source_table, source_id)`, `source_id = provider_message_id`.

### 4.4 Neue Tabellen (Migration 0116+)
- `messaging_accounts`: `id, channel, unipile_account_id, provider, label,
  owner_user_id, status, connected_at, last_event_at`. **Keine Tokens.**
- `messaging_unmatched`: normalisierter Payload, Kanal, Absender-Handle, `received_at`,
  `resolved_contact_id` (nullable). Nie verwerfen.

### 4.5 Anreicherung — getrennt & auditierbar
- LinkedIn-Daten **nicht** roh in Kontaktfelder, sondern Begleitstruktur mit Herkunft
  (`source`, `fetched_at`, Feldwerte) + `linkedin_member_id` am Kontakt fürs Matching.
- **Regel: Enrichment überschreibt nie vom Nutzer eingetippte Felder** — füllt nur
  Leerstellen oder erscheint als „Vorschlag". DSGVO-Herkunftsnachweis inklusive.

## 5. Sicherheit & DSGVO (Vex-Gate, vor Go-live zwingend)

- **Secrets:** Unipile-API-Key in Supabase Vault/Secrets, nie im Client. Edge Functions
  mit Service-Rolle. OAuth-Tokens bei Unipile; wir speichern nur `account_id`.
- **Webhook-Härtung:** Kein Insert ohne verifizierte HMAC-Signatur. Idempotenz gegen Replays.
- **RLS:** Schreiben in `contact_events`, `messaging_accounts`, `messaging_unmatched`
  nur über Service-Rolle. Lesen owner-/rollen-gescoped. Jeder sieht nur eigene Konten.
- **DSGVO-Pflichtteile:**
  - Auftragsverarbeitungsvertrag mit Unipile (Voraussetzung Produktivbetrieb).
  - Löschpfad: Kontakt löschen → kaskadiert Messaging-Events + Anreicherung; zusätzlich
    Einzel-Konto-Purge.
  - Auskunft/Export: Kommunikation + Enrichment im Datenexport.
  - Verarbeitungsverzeichnis-Eintrag (drei Kanäle + Unipile als Verarbeiter).
- **LinkedIn-Leitplanken:** nur Kontakte mit bestehender Beziehung anreichern (keine
  kalten Fremdprofile), Herkunft+Zeitstempel mitschreiben, Widerspruch/Löschung ehren.
  Operativ gegen Sperren: Anreicherung rate-limiten, menschliches Tempo, dediziertes
  LinkedIn-Konto.
- **Unbekannte Absender:** Quarantäne, **kein** Auto-Anlegen von Kontakten.

## 6. Komponenten

### 6.1 Edge Functions (vier, getrennt)
- `comms-inbound` — Webhook: Signatur → normalisieren → matchen → `contact_events` oder
  Quarantäne. Idempotent.
- `comms-outbound` — Senden: `{contact_id, channel, account_id, body}` → Unipile-Send-API
  → bei Erfolg outbound-Event schreiben.
- `comms-enrich` — LinkedIn-Anreicherung: pro Kontakt/Batch, rate-limitiert, schreibt
  Enrichment-Begleitstruktur + `linkedin_member_id`.
- `comms-connect` — erzeugt Unipile-Hosted-Auth-Link, verarbeitet Connection-Callback →
  `messaging_accounts` upserten.

### 6.2 Frontend
- Verbindungs-UI in Settings (Konten verbinden + Status-Liste).
- Log-Composer → echtes Senden, wenn Kanal verbunden; sonst Fallback manuelles Log.
- Unified-Inbox-Screen (kanalübergreifend, gefiltert nach Kontakt/Kurs).
- Enrichment als „Vorschlag" am Kontakt mit Annehmen/Ablehnen.
- Quarantäne-Ansicht mit „Zuordnen".
- Optional: Supabase-Realtime-Subscription für Live-Updates der offenen Timeline.

## 7. Fehlerfälle

- Ungültige Signatur → 401, kein Insert.
- Duplikat → 200 No-op (Idempotenz).
- Kein Kontakt-Treffer → Quarantäne, kein Fehler.
- Konto getrennt (Nutzer-Revoke) → `status='disconnected'`, „Neu verbinden", Sync stoppt.
- Provider/Unipile down beim Senden → Fehler an Nutzer, Entwurf bleibt, Backoff bei transient.
- Rate-Limits (Gmail ~500/Tag, LinkedIn-Tempo) → Drosselung/Queue, Backoff bei 429.
- Anhänge: in dieser Stufe Metadaten + „📎 N Anhänge" loggen; Datei-Download als Folge-Schritt.

## 8. Teststrategie

- **Unit:** Normalizer pro Kanal, Kontakt-Matcher (e164/E-Mail/linkedin_member_id),
  Idempotenz, Enrichment-Merge (Nie-Überschreiben-Regel).
- **Integration:** Edge Functions gegen gemockte Unipile-Payloads + Signaturprüfung
  (gültig/ungültig).
- **E2E (Playwright):** Konto verbinden (gemockt), Senden → Event erscheint, inbound →
  Timeline, Quarantäne → Zuordnen, Enrichment annehmen/ablehnen.
- **Security:** unsignierter Webhook abgelehnt; RLS (Fremd-Konten nicht lesbar).
- Bestehende 422 Tests bleiben grün.

## 9. Offene Punkte / Voraussetzungen

- Dedizierte WhatsApp-Business-Nummer (Dominik besorgt) + BSP-Auswahl (z.B. 360dialog).
- Unipile-Account + API-Key + AVV.
- Unipile-Webhook-Payload-Shapes real verifizieren vor dem Bau der Normalizer
  (pro Kanal einmal live abgreifen).

## 10. Nicht im Scope (YAGNI)

- Datei-/Medien-Download (nur Metadaten in dieser Stufe).
- WhatsApp Template-Management-UI (proaktive Nachrichten) — späterer Schritt.
- Kalender-/Meeting-Sync, Anruf-Integration.
