# Runbook: AtollCard Localization DE/EN/FR (Welle E)

**Spec:** `docs/superpowers/specs/2026-05-26-atollcard-localization-design.md`
**Plan:** `docs/superpowers/plans/2026-05-26-atollcard-localization.md`

## Pre-Implementation

- [ ] Branch `feat/atollcard-localization` ausgecheckt
- [ ] Voherige Wellen A-D auf main

## Code-Deploy

- [ ] `xcodegen generate` im `apps/atollcard-native/`
- [ ] Xcode öffnen, Catalog auswählen → EN/FR Sprachen hinzufügen, Auto-Translate, Polish-Pass
- [ ] iOS Cmd+B sollte clean durchgehen
- [ ] Web: `npm run build` im `apps/web/` — sollte clean

## Manueller iOS-Test

- [ ] App auf iPhone, System-Locale auf English stellen (iOS Einstellungen → Allgemein → Sprache & Region → English)
- [ ] AtollCard öffnen — alle UI-Strings EN
- [ ] Auf French wechseln — alle UI-Strings FR
- [ ] Zurück auf Deutsch
- [ ] Widget am Lock-Screen prüfen — "Tippen → QR" / "Tap → QR" / "Taper → QR" je nach Locale

## Manueller iOS Settings-Override-Test

- [ ] System-Locale Deutsch
- [ ] App → Settings → Sprache → English
- [ ] App neu starten — alle Strings EN obwohl System DE

## Manueller Web-Test

- [ ] `npm run dev`
- [ ] `http://localhost:5173/c/dominik-cd` — sollte mit Browser-Locale rendern
- [ ] `?lang=en` — EN
- [ ] `?lang=fr` — FR
- [ ] LanguageSwitcher oben rechts → durchklicken
- [ ] Lead-Form ausfüllen + senden — alle Labels EN, Success-Message EN
- [ ] vCard "Save as contact" funktioniert in EN

## Rollback

Wenn etwas bricht:
- iOS: Bundle-Override für `AppleLanguages` entfernen via `UserDefaults.standard.removeObject(forKey: "AppleLanguages")`. App neu starten, fällt zurück auf System
- Web: `?lang=`-Param ignorieren in der URL → Browser-Default greift
