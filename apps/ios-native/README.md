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

- **1a — Foundation** (jetzt): Scaffolding, Auth-Flow, leere Tabs ← *aktuell*
- **1b — Today + Einsätze**: Heute-Screen mit nächsten Kursen, Einsätze-Liste
- **1c — Saldo + Profil**: Saldo-Screen mit Breakdowns, Profil read-only
- **1d — Push Notifications**: APNs-Setup, Webhook von Supabase
- **2 — TestFlight**: Internal Testing für TSK-Crew
- **3 — App Store**: Submission

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
