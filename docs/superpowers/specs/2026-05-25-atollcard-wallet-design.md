# AtollCard Wallet-Pass-Signing

**Status:** Draft (User-Review pending)
**Date:** 2026-05-25
**Author:** Dominik Weckherlin (with Claude/Larry)
**Spec Owner:** Dominik
**Target Release:** Welle C (Sub-Projekt 4 von 9 im AtollCard-Roadmap-Umbrella)

---

## 1. Kontext & Problem

### Heutiger Zustand

Die iOS-App AtollCard hat einen Wallet-Service-Stub (`WalletPassService.swift`):
POSTed `{card_id: <uuid>}` an `/api/wallet/pass`, erwartet `application/vnd.apple.pkpass`-Binary zurück, übergibt an `PKAddPassesViewController`. Der Server-Endpoint existiert nicht — heute zeigt der Wallet-Button einen Info-Alert.

### Pain-Points

1. **Pass-Signing braucht Server-seitige Crypto** — Pass-Cert auf dem iPhone wäre ein Leak (jeder mit App-Binary könnte beliebige Pässe signieren).
2. **Kein offline-verfügbares Karten-Format** — heute braucht jeder Karten-Empfänger Internet, um `https://atoll-os.com/c/<slug>` zu öffnen.
3. **Kein Lock-Screen-Trigger** — Wallet kann Pässe via Zeit oder Geo-Fence aufpoppen lassen; ohne Pass keine solche Sichtbarkeit.

### Zielbild

Du tippst in AtollCard auf "In Wallet speichern", `PKAddPassesViewController` zeigt einen signierten Pass deiner Karte, du bestätigst → Pass landet im iPhone-Wallet. QR-Code auf dem Pass linkt zur Public-Card-Page (`https://atoll-os.com/c/<slug>`). Du kannst den `.pkpass`-File via iMessage / AirDrop an Empfänger weiterleiten.

---

## 2. Architektur-Entscheidung

**Pass-Signing in einer Supabase Edge Function.** Begründung:

- Cert lebt in Supabase Secrets (verschlüsselt, nie im Client-Binary)
- TypeScript/Deno-Function statt eigenständigem Web-Server — kein zusätzlicher Service zu deployen
- Authorization via JWT (Standard-Supabase-Mechanik) — kein eigenes Auth-System
- Crypto-Heavy-Lifting via etablierter Library (`node-forge` für PKCS#7), nicht handgeschriebenes ASN.1

**Owner-only Auth.** Nur der Karten-Owner kann seinen eigenen Pass laden — verhindert dass Fremde Pässe von beliebigen Slugs ziehen. Wenn der Owner einen Pass mit jemandem teilen will, schickt er das `.pkpass`-File via iMessage/AirDrop weiter (iOS handhabt das nativ).

**Manuelle Pass-Updates.** Apple bietet APNs-basierte Pass-Updates (Pass-spezifisches Topic, Server-side Push wenn Daten sich ändern). Out-of-scope für diesen MVP — Aufwand (separate APNs-Cert-Setup, Pass-Registration-Endpoints, Pass-Update-Endpoints) übersteigt den Nutzen. Wenn der User die Karte editiert, muss er den Pass im Wallet löschen und neu speichern.

---

## 3. Pass-Inhalt

### 3.1 Pass-Metadaten

```json
{
  "formatVersion": 1,
  "passTypeIdentifier": "pass.swiss.atoll.card.persona",
  "serialNumber": "<card_id>-v<updated_at_unix>",
  "teamIdentifier": "XK8V89P2QV",
  "organizationName": "ATOLL",
  "description": "AtollCard — <title>",
  "logoText": "AtollCard",
  "backgroundColor": "rgb(<from card.theme.gradient_start>)",
  "foregroundColor": "rgb(255, 255, 255)",
  "labelColor": "rgba(255, 255, 255, 0.7)"
}
```

`serialNumber` enthält `updated_at` damit eine editierte Karte einen neuen Pass produziert (selber Serial → Wallet ersetzt; anderer Serial → neuer Eintrag, alter bleibt).

### 3.2 Front-Layout (generic-Style)

| Slot | Inhalt |
|---|---|
| `headerFields[0]` | `key: "badge"`, `label: ""`, `value: card.badge` (z.B. "PADI CD") |
| `primaryFields[0]` | `key: "name"`, `label: ""`, `value: contact.display_name` |
| `secondaryFields[0]` | `key: "title"`, `label: "TITEL"`, `value: card.title` |
| `secondaryFields[1]` | `key: "padi"`, `label: "PADI #"`, `value: dive_profile.padi_member_number` |
| `auxiliaryFields` | leer |
| `barcodes[0]` | `format: PKBarcodeFormatQR`, `message: card.public_url`, `messageEncoding: iso-8859-1` |

### 3.3 Back-Layout

```json
"backFields": [
  { "key": "email",      "label": "EMAIL",        "value": "<contact.primary_email>" },
  { "key": "phone",      "label": "TELEFON",      "value": "<contact.primary_phone>" },
  { "key": "level",      "label": "LEVEL",        "value": "<dive_profile.instructor_level>" },
  { "key": "dives",      "label": "TAUCHGÄNGE",   "value": "<dive_profile.total_dives>" },
  { "key": "since",      "label": "SEIT",         "value": "<dive_profile.since_year>" },
  { "key": "specs",      "label": "SPECIALTIES",  "value": "<dive_profile.specialties joined by ', '>" },
  { "key": "langs",      "label": "SPRACHEN",     "value": "<dive_profile.teaching_languages joined by ', '>" },
  { "key": "card_url",   "label": "ATOLLCARD",    "value": "<card.public_url>" },
  { "key": "updated",    "label": "AKTUALISIERT", "value": "<card.updated_at formatted dd.MM.yyyy>" }
]
```

Fields werden weggelassen wenn der Wert leer/NULL ist.

### 3.4 Color-Derivation

Wenn `card.theme.preset` einer der Presets:
- `courseDirector` → background `rgb(34, 103, 16)` (PADI-grün-ähnlich)
- `seaExplorers` → background `rgb(0, 95, 138)` (Ocean-Blau)
- `privat` → background `rgb(80, 80, 80)` (Neutral)

Wenn `card.theme.preset == "custom"`:
- background = `card.theme.gradient_start_hex` (Edge Function konvertiert Hex → RGB)

Foreground immer `rgb(255, 255, 255)`. Label immer 70% white via rgba.

---

## 4. Edge Function `atollcard-wallet-pass`

### 4.1 Endpoint

- URL: `https://axnrilhdokkfujzjifhj.supabase.co/functions/v1/atollcard-wallet-pass`
- Method: POST
- Auth: JWT in `Authorization: Bearer <token>` Header (Standard-Supabase)
- Body: `{ "card_id": "<uuid>" }`
- Success Response: `200`, `Content-Type: application/vnd.apple.pkpass`, Binary
- Deployment: `supabase functions deploy atollcard-wallet-pass` (Standard — JWT-Verifikation wird gebraucht, also **kein** `--no-verify-jwt`)

### 4.2 Function-Flow

```
1. Parse + validate body (card_id ist UUID)
   → 400 "invalid_request" wenn missing/malformed

2. JWT validate via supabase.auth.getUser(token)
   → 401 "invalid_token" wenn JWT failed

3. SELECT card + JOIN contact:
     SELECT c.*, p.display_name, p.primary_email, p.phones
     FROM cards c
     JOIN contacts p ON p.id = c.person_id
     WHERE c.id = $1 AND c.is_active = true
     -- RLS verifiziert auth.uid() === Owner via existing card_leads_owner Policy-Pattern
   → 404 "card_not_found" wenn nichts (auch wenn nicht Owner)

4. Build pass.json (Sektion 3 oben), in-memory

5. Build manifest.json:
     { "pass.json": sha1(pass.json), "icon.png": sha1(...), ... }

6. Sign manifest.json:
     - Load .p12 cert from secret WALLET_PASS_CERT_BASE64 (decode + parse with forge)
     - Load WWDR.cer from secret WALLET_WWDR_CERT_BASE64
     - PKCS#7 detached signature mit forge.pkcs7.createSignedData()
     - Output as DER binary

7. Build zip with all files:
     - pass.json
     - manifest.json
     - signature (PKCS#7 DER)
     - icon.png, icon@2x.png, icon@3x.png
     - logo.png, logo@2x.png, logo@3x.png

8. Return:
     Status 200
     Content-Type: application/vnd.apple.pkpass
     Content-Disposition: attachment; filename="<slug>.pkpass"
     Body: zip bytes
```

### 4.3 Dependencies (NPM via Deno-Compat)

```typescript
import forge from 'npm:node-forge@1.3.1'
import { ZipWriter, Uint8ArrayWriter, Uint8ArrayReader } from 'jsr:@zip-js/zip-js@2.7'
import { createClient } from 'npm:@supabase/supabase-js@2'
```

**Cold-Start-Impact:** forge fügt ~150kb komprimierten Code dazu, Cold-Start steigt um geschätzt 200-300ms. Akzeptabel für einen Endpoint der vermutlich <10× pro Tag aufgerufen wird.

### 4.4 Static Assets

Pass-Bundle braucht 6 PNG-Files. Liegen in `supabase/functions/atollcard-wallet-pass/assets/`:

| Datei | Dimension |
|---|---|
| `icon.png` | 29 × 29 |
| `icon@2x.png` | 58 × 58 |
| `icon@3x.png` | 87 × 87 |
| `logo.png` | 160 × 50 (max) |
| `logo@2x.png` | 320 × 100 |
| `logo@3x.png` | 480 × 150 |

Bei Function-Start einmalig via `Deno.readFile()` geladen, in Module-Scope-Variable gecached. Pro Request nur in den ZipWriter geschrieben, kein neuer Disk-Read.

**Inhalt:** ATOLL-Glyph-Logo (gleiche Marke wie Web-Header), kein persona-spezifisches Branding — Personalisierung passiert über backgroundColor + headerField "Badge".

**Asset-Voraussetzung:** die 6 PNGs müssen vor dem ersten Deploy committed sein. Wenn nicht vorhanden, Spec markiert das als Pre-Implementation-Blocker.

### 4.5 Required Supabase Secrets

```
WALLET_PASS_CERT_BASE64     base64(.p12)
WALLET_PASS_CERT_PASSWORD   <p12-passwort>
WALLET_WWDR_CERT_BASE64     base64(AppleWWDRCAG4.cer)
WALLET_PASS_TYPE_ID         pass.swiss.atoll.card.persona
WALLET_TEAM_ID              XK8V89P2QV
```

Konfiguriert via:
```bash
supabase secrets set \
  WALLET_PASS_CERT_BASE64="$(base64 -i ~/Downloads/PassTypeId_Persona.p12)" \
  WALLET_PASS_CERT_PASSWORD="dein-passwort" \
  WALLET_WWDR_CERT_BASE64="$(base64 -i ~/Downloads/AppleWWDRCAG4.cer)" \
  WALLET_PASS_TYPE_ID="pass.swiss.atoll.card.persona" \
  WALLET_TEAM_ID="XK8V89P2QV"
```

### 4.6 Error-Handling

| Status | Code | Wann |
|---|---|---|
| 400 | `invalid_request` | Body ist kein JSON oder `card_id` fehlt/nicht UUID |
| 401 | `invalid_token` | JWT ungültig oder abgelaufen |
| 404 | `card_not_found` | Karte existiert nicht ODER User ist nicht Owner (gleicher Status — kein Leak) |
| 500 | `signing_failed` | PKCS#7-Signing wirft (z.B. Cert nicht parsbar, Passwort falsch) — stack logged |
| 500 | `zip_failed` | Zip-Erstellung wirft — selten |
| 500 | `unknown_error` | Catch-all — voller Stack in Logs |

Alle Errors als JSON: `{ "error": "<code>", "message": "<human-readable de>" }`.

---

## 5. iOS-Anpassungen

### 5.1 `WalletPassService.swift`

Zwei Änderungen:

**(a) JWT-Header mitschicken:**

Vor `URLSession.shared.data(for:)` in `passViewController(for:)`:

```swift
if let session = try? await SupabaseClient.shared.auth.session {
  request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
}
```

**(b) Endpoint-URL korrigieren:**

Heute baut der Stub `Config.publicCardBaseURL.deletingLastPathComponent().appendingPathComponent("api/wallet/pass")` → `https://atoll-os.com/api/wallet/pass`. Das ist nicht die Supabase-Function-URL.

Ersatz: neue `Config.walletPassEndpoint`:

```swift
// In Config.swift
static let walletPassEndpoint = URL(string:
  "https://axnrilhdokkfujzjifhj.supabase.co/functions/v1/atollcard-wallet-pass")!
```

In `WalletPassService.passViewController(for:)`:

```swift
var request = URLRequest(url: Config.walletPassEndpoint)
```

### 5.2 `PersonaDetailCard` Wallet-Button

Heute zeigt der Button vermutlich `WalletPassError.unavailable` oder einen Info-Alert. Stattdessen:

```swift
Task {
  do {
    let vc = try await walletService.passViewController(for: card)
    presentSheet(vc)   // existierende Sheet-Präsentationslogik
  } catch {
    toastCenter.show("Wallet-Pass: \(error.localizedDescription)", severity: .error)
  }
}
```

### 5.3 Mock-Mode

Wenn `Config.useMockData == true`, kann die Function nicht erreichbar sein (lokale Mock-DB hat keine Card-IDs die der Server kennt). Button zeigt Info-Alert "Wallet im Mock-Modus nicht verfügbar — bitte mit `useMockData = false` neu starten."

Implementierung in `passViewController(for:)`:

```swift
if Config.useMockData {
  throw WalletPassError.serverError(0)  // wird im Mock-Modus zu klarem Toast übersetzt
}
```

Oder ein eigenes `.mockMode` Error-Case mit klarerem Text.

### 5.4 Entitlements

**Keine neuen Entitlements nötig.** PassKit funktioniert ohne `com.apple.developer.passkit`. Das Entitlement wäre nur für `PKAddPaymentPassViewController` (Apple Pay) — nutzen wir nicht.

---

## 6. Apple-Developer-Setup (einmalig, vor erstem Deploy)

### 6.1 Pass Type ID registrieren

1. [https://developer.apple.com/account](https://developer.apple.com/account) → **Certificates, Identifiers & Profiles** → **Identifiers** (links) → Filter auf **Pass Type IDs** → **+**
2. **Description:** `AtollCard Persona Pass`
3. **Identifier:** `pass.swiss.atoll.card.persona`
4. Continue → Register

### 6.2 Pass Type ID Certificate erstellen

1. Auf der neu angelegten Pass-Type-ID den Button **Create Certificate** klicken
2. **CSR generieren via Keychain Access:**
   - Keychain Access → Certificate Assistant → Request a Certificate from a Certificate Authority
   - Email = deine, Common Name = `AtollCard Pass`, "Saved to disk" + "Let me specify key pair information"
   - Continue → 2048-bit RSA → Save
3. CSR-File im Apple Portal hochladen → Continue → Download `pass.cer`
4. `pass.cer` doppelklicken → wird in Keychain importiert
5. In Keychain Access: das Cert finden (im "Login"-Schlüsselbund), den Disclosure-Pfeil aufklappen → Private Key + Cert markieren → Rechtsklick → **Export 2 items** → Format `.p12` → Passwort vergeben (in 1Password speichern) → Datei z.B. `PassTypeId_Persona.p12` in `~/Downloads/` speichern

### 6.3 Apple WWDR Intermediate Cert

1. [https://www.apple.com/certificateauthority/](https://www.apple.com/certificateauthority/) → "Worldwide Developer Relations - G4" → `.cer` herunterladen
2. Speicher als `~/Downloads/AppleWWDRCAG4.cer`

### 6.4 Secrets in Supabase setzen

Siehe Sektion 4.5 oben.

---

## 7. File-Inventar

### Neu

```
supabase/functions/atollcard-wallet-pass/
├── index.ts                         Edge Function (~250 LOC mit forge + zip-js)
└── assets/
    ├── icon.png                     29×29
    ├── icon@2x.png                  58×58
    ├── icon@3x.png                  87×87
    ├── logo.png                     160×50
    ├── logo@2x.png                  320×100
    └── logo@3x.png                  480×150

docs/superpowers/runbooks/
└── 2026-05-25-atollcard-wallet-welle-c-rollout.md   Schritt-für-Schritt Setup
```

### Geändert

```
apps/atollcard-native/AtollCard/
├── Config.swift                     + walletPassEndpoint Konstante
├── Services/WalletPassService.swift + JWT-Header + neue Endpoint-URL + Mock-Mode-Guard
└── Views/Cards/PersonaDetailCard.swift  + Wallet-Button verdrahten

apps/atollcard-native/CHANGELOG.md   + 0.10.0 Entry (Welle C)
```

### Test-Coverage

- **Unit-Test der Function-Helpers** (`apps/web` oder dedicated `supabase/functions/atollcard-wallet-pass/__tests__/`):
  - `buildPassJson(card, contact)` returnt erwartete JSON-Shape
  - `colorForTheme(theme)` returnt korrekte RGB-Strings für die 3 Presets
  - `serialNumberFor(card)` ist deterministisch und enthält updated_at
- **Manueller curl-Test:** `supabase functions serve` lokal, JWT aus Browser-DevTools kopieren, `curl -X POST -H 'Authorization: Bearer ...' -d '{"card_id":"..."}' --output test.pkpass`, dann:
  - `unzip -l test.pkpass` zeigt 10 Files
  - `openssl smime -verify -in signature -content manifest.json -inform DER -noverify` → "Verification successful"
- **End-to-End auf echtem iPhone:** App → Karte → Wallet-Button → `PKAddPassesViewController` zeigt sich → Add → Pass im Wallet → QR scannt zur Public Page

---

## 8. Rollout-Plan

1. **Apple-Cert-Touch** (einmalig, ~30 Min): Pass Type ID, Certificate, .p12, WWDR.cer
2. **Assets erstellen oder organisieren** (Pre-Implementation-Blocker): 6 PNGs in der richtigen Dimension
3. **Function entwickeln** lokal: `supabase functions serve atollcard-wallet-pass` + curl-Test
4. **Secrets setzen** in Supabase
5. **Function deployen:** `supabase functions deploy atollcard-wallet-pass` (mit JWT-Verifikation, **ohne** `--no-verify-jwt`)
6. **iOS-Build** mit den Service- + Config- + Button-Änderungen
7. **End-to-End-Test** auf echtem iPhone
8. **CHANGELOG-Eintrag** + Branch-Push

---

## 9. Out-of-Scope

- Pass-Update via APNs (Frage 3 → A: manuell only). Implementation kommt in einem späteren Sub-Projekt wenn der Bedarf da ist.
- "Save to Wallet"-Button auf der Public Card Page (Frage 4 → A: owner-only). Würde einen anonymen Endpoint brauchen — separates Design.
- NFC-Pass-Trigger (z.B. Tap-to-Pay-ähnlich). Kein Use-Case ohne Storefront-NFC-Reader; für Visitenkarten unnötig.
- Apple Wallet App Strip (das aufklappbare Detail). Für Visitenkarten overkill.
- Custom Personalisierung pro Empfänger (z.B. "Pass für Maria" eingedruckt). Nicht jetzt.

---

## 10. Open Risiken & Annahmen

1. **`node-forge` in Deno:** funktioniert via `npm:`-Import seit Deno 1.30+, aber Pass-Signing-Pfad ist nicht extrem gut dokumentiert für die Library. Falls forge sich querstellt: Fallback auf `@yourpalmark/pkpass` oder manuelles ASN.1.
2. **PKCS#7-Format-Kompatibilität mit Apple:** Apple verlangt detached PKCS#7-Signatur. forge unterstützt das (`createSignedData` mit `detached: true`), getestet im Pass-Signing-Ökosystem.
3. **Pass-Cert Renewal:** läuft 1 Jahr. Renewal-Reminder muss im Captains-Log oder Calendar landen (separate Aktion, nicht in dieser Spec).
4. **Asset-PNGs noch nicht vorhanden:** Pre-Implementation-Voraussetzung. Wenn keine SVG/Sketch-Quelle existiert, brauchst du den Designer / Figma-Export.
5. **`Config.useMockData`-Path:** der Mock-Mode-Guard verhindert dass im Demo-Mode Function-Calls passieren — wichtig damit Demos nicht silent failen.

---

## 11. Akzeptanzkriterien

- [ ] Edge Function `atollcard-wallet-pass` läuft, gibt bei valider Auth + Owner-Karte einen `.pkpass`-File zurück
- [ ] `openssl smime -verify` validiert die Signatur erfolgreich
- [ ] iOS-Button "In Wallet speichern" öffnet `PKAddPassesViewController` mit dem Pass
- [ ] Pass im Wallet sichtbar mit korrekten Feldern (Name, Title, PADI-#, Badge, QR)
- [ ] QR auf dem Pass scannt zur Public-Card-Page
- [ ] Pass-Rückseite zeigt Email, Phone, Specialties, Languages, Total Dives, Card-URL, Updated-Datum
- [ ] Auth-Negative-Test: ohne JWT → 401, mit JWT eines fremden Users → 404 (nicht 403, damit kein Card-Existenz-Leak)
- [ ] Mock-Mode: Button zeigt Info-Toast statt Function-Call
- [ ] Pass-Edit-Test: nach Karten-Update produziert die Function einen neuen Pass (anderer serialNumber)

---

## 12. Referenzen

- [Apple Pass Format Documentation](https://developer.apple.com/library/archive/documentation/UserExperience/Reference/PassKit_Bundle/Chapters/Introduction.html)
- [Apple Pass-Signing-Anforderungen](https://developer.apple.com/library/archive/documentation/UserExperience/Conceptual/PassKit_PG/Updating.html)
- [node-forge PKCS#7](https://github.com/digitalbazaar/forge#pkcs7)
- [zip-js für Deno](https://gildas-lormeau.github.io/zip.js/)
- WalletPassService.swift im Repo (`apps/atollcard-native/AtollCard/Services/`)
- README "Phase 5: Wallet Pass Type ID" (`apps/atollcard-native/README.md`)
- AtollCard 0.4 CHANGELOG-Eintrag (`apps/atollcard-native/CHANGELOG.md`)
