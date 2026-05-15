# ATOLL App Suite Foundation

**Status:** Implementiert (2026-05-15)
**Date:** 2026-05-14
**Author:** Dominik Weckherlin (with Claude)
**Spec Owner:** Dominik
**Target Release:** Foundation v0.1 (Voraussetzung für AtollCal v1)

---

## 1. Kontext & Vision

### Heutiger Zustand

ATOLL ist heute eine Punktlösung mit zwei Clients:

- `apps/web/` — React-Web-App für Dispatcher/Owner (Cockpit, Kursplanung, Kontakte)
- `apps/ios-native/ATOLL/` — SwiftUI-iOS-App für Instructors (Today, Profile, Students, Skill-Check)

Beide teilen sich Supabase (Postgres + Auth + Storage) als Backend.

### Vision

ATOLL wird die **Plattform-Basis** für eine wachsende Familie von Apps, die alle auf demselben Backend aufsetzen und für Tauchprofis spezifische Workflows abbilden:

- **ATOLL Web** — Dispatcher-Cockpit (existiert)
- **ATOLL iOS** — Instructor-Workflow (existiert)
- **AtollCal** — Fantastical-Style Kalender mit ATOLL-Daten als einer Quelle (geplant, eigener Spec)
- **AtollLog** — persönliches Tauchlogbuch mit ATOLL-Kurs-Verknüpfung (geplant)
- weitere Tools nach Bedarf

### Pain-Points beim Bauen ohne Foundation

Wenn AtollCal und AtollLog jeweils eigene Auth, eigene Models, eigene Supabase-Wrapper, eigenes Brand-Design implementieren, dann:

1. **Drei mal Magic-Link-Auth schreiben** — Wartung explodiert, Bugs vervielfachen sich
2. **Drei `Course`-Definitionen** — driftet auseinander, Refactorings werden zur Migration
3. **Drei Brand-Identitäten** — User merkt: das ist nicht „aus einem Guss"
4. **Login pro App** — User muss sich in jeder Atoll-App separat einloggen, obwohl es derselbe Account ist
5. **Doppelarbeit pro Bug-Fix** im Gemeinsamen

### Was diese Foundation löst

Vor dem Bau von AtollCal extrahieren wir die wiederverwendbaren Bestandteile aus der bestehenden ATOLL-iOS-App in zwei Swift Packages, validieren dass die existierende App nach der Migration weiterhin identisch funktioniert, und legen damit die Basis für AtollCal + AtollLog.

## 2. Scope dieser Etappe

**In Scope:**

- Repo-Umstrukturierung: `apps/ios-native/` → `apps/atoll-ios/`, neuer Ordner `swift-packages/`
- Swift Package `AtollCore` — Auth, Supabase-Client, geteilte Models, Locale-Handling
- Swift Package `AtollDesign` — Brand-Tokens (Farben), wiederverwendbare SwiftUI-Components
- Migration der bestehenden ATOLL-iOS-App auf die neuen Packages — Views referenzieren importierte Types
- Build + Smoke-Test der ATOLL-iOS-App nach Migration (TestFlight oder Simulator)

**Out of Scope (eigene Specs):**

- AtollCal-App selbst (eigener Spec)
- AtollLog-App (Future)
- `AtollRealtime`-Package — erst wenn die erste App Postgres-Realtime-Channels braucht
- App Group + Keychain Sharing für Single-Sign-On über Apps hinweg — erst wenn 2+ Apps gleichzeitig installiert sind
- Universal Links zwischen Apps (`https://atoll-os.com/course/<id>` öffnet die richtige App)
- Cross-Platform-Schritt: macOS-Targets — erst mit AtollCal
- Branding-Refresh: neues Logo, Marketing-Identität
- Publishing der Packages auf Swift Package Index — bleibt private Local-Package

## 3. Repo-Struktur nach Migration

```
Dispo/
├── apps/
│   ├── web/                    (ATOLL Web — React, unverändert)
│   ├── atoll-ios/              (umbenannt von ios-native — Dispatcher/Instructor-App)
│   └── (atollcal-native/)      (kommt mit Spec B)
├── swift-packages/
│   ├── AtollCore/              (Auth, Supabase-Client, Models, Locale)
│   │   ├── Package.swift
│   │   ├── Sources/AtollCore/
│   │   │   ├── Auth/
│   │   │   ├── Supabase/
│   │   │   ├── Models/
│   │   │   └── Locale/
│   │   └── Tests/AtollCoreTests/
│   └── AtollDesign/            (Brand-Tokens + Common-Components)
│       ├── Package.swift
│       ├── Sources/AtollDesign/
│       │   ├── Theme/
│       │   └── Components/
│       └── Tests/AtollDesignTests/
├── supabase/                   (Backend, unverändert)
└── docs/
```

Die Swift Packages werden lokal über `Package.swift` mit `Path:`-Dependency referenziert — kein Git-URL nötig.

## 4. `AtollCore`-Package — Inhalt

### Was rein kommt (extrahiert aus `apps/atoll-ios/ATOLL/`)

**Auth/**
- `AuthState.swift` (heute `Services/AuthState.swift`) — Magic-Link-Flow, Session-Verwaltung, Status-Enum (loading/signedOut/signedIn)
- `AuthCallbackHandler.swift` — extrahierter URL-Scheme-Callback (heute inline in `ATOLLApp.swift`), parametrisiert über App-spezifischen Scheme

**Supabase/**
- `SupabaseClientShared.swift` (heute `Services/SupabaseClient+Shared.swift`) — App-weiter Singleton, Initialisierung aus Config
- `SupabaseConfig.swift` — Protocol für `supabaseURL` + `supabaseAnonKey`, jede App liefert ihre eigene Config-Implementation

**Models/**
- `Course.swift`, `Assignment.swift`, `CourseParticipant.swift`, `Student.swift`, `Instructor.swift`, `Skill.swift`, `SkillDefinition.swift`, `SkillRecord.swift`, `IntakeChecklist.swift`, `CurrentUser.swift`, `AppDate.swift` — alle bestehenden Models aus `apps/atoll-ios/ATOLL/Models/`

**Locale/**
- `LocaleStore.swift` (heute `Services/LocaleStore.swift`) — Sprach-Handling, Locale-Override per User-Preferred-Language

### Was NICHT rein kommt

- `PushManager.swift` — App-spezifisch (Bundle-IDs unterschiedlich, Server-Tokens pro App)
- Domain-spezifische Stores wie `IntakeStore`, `SkillCheckStore`, `ParticipantsStore`, `AssignmentsStore`, `StudentsStore` — bleiben in der ATOLL-iOS-App, weil sie ATOLL-spezifischen Workflow abbilden
- `AppDelegate.swift` — App-Lifecycle ist immer App-spezifisch
- Views — bleiben App-spezifisch

### Versionierung

Lokales Swift Package, kein Tagging zu Beginn. Wenn AtollLog dazu kommt und Foundation-Breaking-Changes nötig werden, schauen wir uns Tagging an. Solange wir Monorepo + Local-Path-Dependency nutzen, ist Coordinated-Update automatisch.

## 5. `AtollDesign`-Package — Inhalt

### Was rein kommt

**Theme/**
- `BrandColors.swift` (heute `Theme/BrandColors.swift`) — Farb-Tokens (Brand-Blau, Sekundär, Backgrounds, Text-Hierarchien)
- `Typography.swift` — Type-Scale + Font-Definitionen (NEU — heute über System-Fonts inline)
- `Spacing.swift` — Standardisierte Spacing-Tokens (NEU)

**Components/**
- `AtollLogo.swift`, `AvatarView.swift`, `BrandHeader.swift`, `RoleBadge.swift`, `SkillChip.swift`, `StatusChip.swift` — wiederverwendbare SwiftUI-Components aus `apps/atoll-ios/ATOLL/Components/`

### Was NICHT rein kommt

- `StudentAvatar.swift` — Variante von AvatarView, kann in AtollCore-Models bleiben oder in der iOS-App, je nach Reusability bei AtollCal-Review

## 6. Migrations-Strategie für die existierende ATOLL-iOS-App

Die Umstellung passiert **nicht über einen Big-Bang-Commit**. Schrittweise mit Validierung dazwischen:

1. **Repo-Rename** `apps/ios-native` → `apps/atoll-ios`. Build muss noch identisch funktionieren (Xcode-Projekt-Pfade aktualisieren).
2. **Packages anlegen** als leere Skelette mit `Package.swift`. Noch keine Files, noch keine Dependency.
3. **AtollCore** — Models + Supabase-Wrapper rüberkopieren. App auf neue Imports umstellen, alte Files löschen.
4. **AtollCore** — Auth + Locale rüberkopieren. App umstellen.
5. **AtollDesign** — Theme + Components rüberkopieren. App umstellen.
6. **Final-Build + Smoke-Test** der ATOLL-iOS-App: Login, Today-Screen, Skill-Check öffnen, Logout. Wenn alles wie vor der Migration funktioniert: Foundation ist live.

Jeder Schritt = ein Commit. Kann notfalls einzeln rückgängig gemacht werden.

## 7. Sicherheit + Qualität

- **Tests:** Unit-Tests für die extrahierten Pure-Logic-Teile (z.B. AppDate-Parsing). Auth-Flow ist schwer zu unit-testen ohne Supabase-Mock — Smoke-Test über die App reicht in Phase 1.
- **Type-Safety:** Alle Models bleiben strikt typisiert, kein `[String: Any]` reingeschmuggelt.
- **Backward-Compatibility:** Keine. Die bestehende ATOLL-iOS-App ist die einzige Konsumentin und wird mit-migriert.
- **Code-Style:** Folge dem Pattern der existierenden Files. Keine Re-Formatierung außerhalb der nötigen Edits.

## 8. Akzeptanzkriterien

- [x] `apps/ios-native/` ist nach `apps/atoll-ios/` umbenannt, Xcode-Projekt baut weiterhin
- [x] `swift-packages/AtollCore/` existiert als Swift Package mit `Package.swift`
- [x] `swift-packages/AtollDesign/` existiert als Swift Package mit `Package.swift`
- [x] Alle Models aus `apps/atoll-ios/ATOLL/Models/` sind nach `AtollCore/Sources/AtollCore/Models/` umgezogen, ATOLL-iOS-App importiert sie aus dem Package
- [x] `SupabaseClient+Shared`, `AuthState`, `LocaleStore` sind in `AtollCore` umgezogen, ATOLL-iOS-App importiert sie
- [x] `BrandColors` + alle wiederverwendbaren Components sind in `AtollDesign` umgezogen, ATOLL-iOS-App importiert sie
- [x] ATOLL-iOS-App buildet ohne Fehler nach kompletter Migration
- [x] Manueller Smoke-Test: Login, Today-Screen, Skill-Check, Logout funktionieren identisch zu vor der Migration
- [x] Existierende `Localizable.xcstrings` und `Assets.xcassets` bleiben in der App (nicht in AtollDesign, weil App-spezifisch)
- [x] Kein neuer Bug eingeschleppt — Vergleich zur Production-Version per Hand-Test der Hauptflows

## 9. Risiken + Verifizieren vor Implementierung

1. **Xcode-Projekt-Surgery ist fragil** — Pfad-Änderungen bei Asset-Catalogs, Info.plist-Verweise, Code-Signing-Settings können zu obskuren Build-Fehlern führen. Strategie: jede Änderung als separater Commit, der einzeln gebuildet werden kann.
2. **Swift-Package vs Xcode-Project-Module** — bei lokalem Package-Path-Linking ist die Reihenfolge wichtig: erst Package mit `Package.swift` anlegen, dann in Xcode-Projekt als Local Package hinzufügen, dann Imports in der App ändern.
3. **`@Observable`-Macro-Verfügbarkeit** — Foundation-Code wird ggf. von beiden Apps mit unterschiedlichen Swift-Versionen genutzt. AtollCore sollte minimal `swift-tools-version: 5.9` setzen (für `@Observable`).
4. **Existierender `Services/`-Code referenziert sich gegenseitig** — z.B. `AssignmentsStore` nutzt `AuthState`. Beim Verschieben von Auth muss `AssignmentsStore` über `import AtollCore` weiter zugreifen können — Public/Internal-Access-Levels prüfen.
5. **iOS-Bundle-ID + Entitlements bleiben** — beim Repo-Rename darf sich die Bundle-ID `com.atoll-os.atoll` (oder wie auch immer aktuell) nicht ändern, sonst wäre das eine andere App im App-Store.
6. **Existierende Brand-Identity-Skill** — der User hat einen `brand-identity`-Skill installiert (siehe `.claude/skills/brand-identity/`). AtollDesign-Package sollte sich an dessen Tokens orientieren, wo das überschneidend ist.

## 10. Was nach dieser Foundation-Etappe kommt

Sobald Spec A implementiert + verifiziert ist:

- **Spec B — AtollCal v1** wird gegen die Foundation gebaut. Erstes Validierungs-Projekt der Plattform-Architektur.
- Lessons-Learned aus AtollCal-Bau fließen als Foundation-v0.2-Anpassungen zurück.
- Wenn AtollLog dazu kommt: weiter Pattern wiederholen, ggf. neue Packages (`AtollLogModels` o.ä.) hinzufügen.
