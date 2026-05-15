# AtollCal — Native iOS+macOS Kalender

Native SwiftUI-App, baut auf den ATOLL-Foundation-Packages (`AtollCore`, `AtollDesign`) auf.
Bundle-ID: `swiss.atoll.cal`. URL-Scheme: `atollcal://`.

## Setup

```
cd apps/atollcal-native
xcodegen generate
open AtollCal.xcodeproj
```

`AtollCal.xcodeproj` ist gitignored — wird aus `project.yml` regeneriert.

## Konfiguration

`AtollCal/Config.swift` (nach Task 2) enthält Supabase-URL + Anon-Key.
