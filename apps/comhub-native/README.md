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
# macOS
xcodebuild -scheme ComHub -destination 'platform=macOS,arch=arm64' build
xcodebuild test -scheme ComHub -destination 'platform=macOS,arch=arm64'

# Kern-Logik (schnell, ohne Xcode)
cd ../../swift-packages/AtollHub && swift test
```

## Phase 0 (dieser Stand)

OTP-Login gegen Atoll-Supabase, leere 3-Spalten-Shell mit Modul-Leiste,
getesteter Provider-Kern (`AtollHub`). **Keine** echten Daten-Adapter — die
kommen in Phase 1+ (siehe `docs/superpowers/plans/`).
