# ATOLL iOS — Native SwiftUI App

Native iOS App für **ATOLL · The diving school OS**.

- **Target:** iOS 17+ (für Liquid Glass Materials, modernes SwiftUI)
- **Bundle Identifier:** `swiss.atoll.app`
- **Display Name:** ATOLL
- **Architektur:** SwiftUI · Swift Concurrency · Supabase Swift SDK
- **Auth:** Magic Link mit `atoll://auth/callback` URL-Scheme

## First-time Setup

```bash
# 1. xcodegen installieren (einmalig, falls noch nicht da)
brew install xcodegen

# 2. Xcode-Projekt aus project.yml generieren
cd apps/ios-native
xcodegen generate

# 3. In Xcode öffnen
open ATOLL.xcodeproj
```

`ATOLL.xcodeproj` ist gitignored — wird immer aus `project.yml` regeneriert. Das verhindert Merge-Konflikte in der riesigen pbxproj-Datei.

## Konfiguration

`ATOLL/Config.swift` enthält Supabase URL + Anon Key.

Werte sind **dieselben** wie in `apps/web/.env.production`:
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY` (öffentlicher Key, RLS sichert Daten)

Bitte vor dem ersten Run dort eintragen.

## Magic-Link Setup

Damit der Auth-Callback in der App landet (statt im Safari):

1. **In Supabase Dashboard** → Authentication → URL Configuration → Redirect URLs:
   Hinzufügen: `atoll://auth/callback`

2. **In Email-Template** → das Confirmation-Link-Default ist ok, Supabase respektiert die in der Auth-Call übergebene `redirectTo`.

Der iOS-Code im `SignInView` ruft `signInWithOTP` mit `emailRedirectTo: "atoll://auth/callback"` auf.

## Run

In Xcode → iPhone-Simulator wählen → ⌘R.

Erste Compilation lädt die Swift Package Dependencies (Supabase Swift SDK von GitHub) — kann beim ersten Mal 1-2 Minuten dauern.

## Phase-Plan

- ✅ **1a — Foundation**: Scaffolding, Auth-Flow, leere Tabs
- ✅ **1b — Today + Einsätze**: Heute-Screen mit nächsten Kursen, Einsätze-Liste
- ✅ **1c — Saldo + Profil**: Saldo-Screen mit Breakdowns, Profil mit Skills
- ⏳ **1d — Push Notifications + Calendar + Polish**: ← *aktuell*
- ☐ **2 — TestFlight**: Internal Testing für TSK-Crew
- ☐ **3 — App Store**: Submission

## Push-Notifications Setup

Dauert ~10 Min einmalig. iOS kann Push erst empfangen wenn das alles steht.

### A) Xcode — Capability hinzufügen

1. `apps/ios-native/ATOLL.xcodeproj` öffnen
2. **Project Navigator** → Target **ATOLL** → Tab **Signing & Capabilities**
3. **+ Capability** → **Push Notifications** doppelklicken
4. Nochmal **+ Capability** → **Background Modes** → Häkchen **Remote notifications**
5. Speichern

### B) Apple Developer Portal — Key erstellen

1. [developer.apple.com/account/resources/authkeys/list](https://developer.apple.com/account/resources/authkeys/list)
2. **+** → **Apple Push Notifications service (APNs)** → Häkchen
3. Name: `ATOLL APNs Key` → Continue → Register
4. **Download** (du kriegst nur EINE Chance — sicher ablegen!)
5. Notiere dir:
   - **Key ID** (10 Zeichen, z.B. `ABC123XYZ4`)
   - **Team ID** (oben rechts in Apple Developer, z.B. `ABCD123456`)

### C) Bundle ID Push aktivieren

1. [developer.apple.com/account/resources/identifiers/list](https://developer.apple.com/account/resources/identifiers/list)
2. `swiss.atoll.app` öffnen
3. Scroll zu **Capabilities** → Häkchen bei **Push Notifications**
4. **Save**

### D) Supabase Edge Function (kommt in Phase 1d-Backend)

Diese 3 Werte werden später als Supabase-Secrets gesetzt:

```bash
supabase secrets set APNS_AUTH_KEY="$(cat ~/Downloads/AuthKey_ABC123XYZ4.p8 | base64)"
supabase secrets set APNS_KEY_ID="ABC123XYZ4"
supabase secrets set APNS_TEAM_ID="ABCD123456"
supabase secrets set APNS_BUNDLE_ID="swiss.atoll.app"
```

Die Edge-Function `send-assignment-notification` wird per Database-Webhook auf Insert in `course_assignments` getriggert.

### E) Test

1. App auf einem **echten iPhone** bauen (Push funktioniert nicht im Simulator)
2. Beim ersten Start nach Login: Permission-Dialog erscheint
3. *Erlauben* — App registriert sich, Token landet in `device_tokens` Tabelle
4. In Supabase SQL Editor checken:
   ```sql
   SELECT * FROM device_tokens WHERE instructor_id = '<deine instructor_id>';
   ```
   Sollte deinen Token zeigen.

## Folder-Struktur

```
ATOLL/
├── ATOLLApp.swift         (@main entry)
├── Config.swift           (Supabase credentials)
├── Models/                (Codable structs für DB-Tabellen)
├── Services/              (Supabase Wrapper, AuthState)
├── Views/                 (SignIn, MainTab, Today, Einsätze, Saldo, Profil)
├── Components/            (GlassCard, Chip, Avatar — wiederverwendbare UI)
└── Resources/Assets.xcassets/  (Logo + Brand-Farben)
```
