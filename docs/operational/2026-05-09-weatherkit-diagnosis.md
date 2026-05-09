# WeatherKit Diagnose — 2026-05-09

**Test-Device:** iPhone 16 Pro Max (iOS aktuell)
**Test-Location:** Richterswil, 47.2745° / 8.7237°
**Test-Date:** 2026-05-09 12:20 CEST

## Beobachtetes OSLog

```
Failed to generate jwt token for: com.apple.weatherkit.authservice
  with error: Error Domain=WeatherDaemon.WDSJWTAuthenticatorServiceListener.Errors Code=2 "(null)"

Encountered an error when fetching weather data subset;
  location=<+47.27448741,+8.72369827> ...
  error=WeatherDaemon.WDSJWTAuthenticatorServiceListener.Errors 2

WeatherKit failed: domain=WeatherDaemon.WDSJWTAuthenticatorServiceListener.Errors
  code=2 desc=The operation couldn't be completed.
  (WeatherDaemon.WDSJWTAuthenticatorServiceListener.Errors error 2.) userInfo=[:]
```

UI-Anzeige im DiveFormView/QuickLog:
> Weather service unreachable: WeatherDaemon.WDSJWTAuthenticatorServiceListener.Errors 2 — The operation couldn't be completed.

## Diagnose

**Auth/Capability-Pfad** (aus Plan-Step 5.4 Tabelle): WeatherKit kann keinen JWT-Token generieren, weil die WeatherKit-Capability auf der App-ID `com.weckherlin.DiveLogPro` im Apple-Developer-Portal **nicht aktiviert** ist.

Die Entitlement-Datei (`DiveLog Pro/DiveLog_Pro.entitlements`) hat zwar `com.apple.developer.weatherkit = true`, aber das Entitlement allein reicht nicht — die App-ID-Konfiguration muss matching haben, sonst stellt das Apple-Backend keinen JWT aus.

## Nächste Aktion

→ **Plan-Task 6:** WeatherKit-Capability auf App-ID aktivieren, Provisioning-Profile neu generieren, Build wiederholen, Resolution unten ergänzen.

## Resolution

- **2026-05-09:** WeatherKit-Capability auf App-ID `com.weckherlin.DiveLogPro` im Apple-Developer-Portal aktiviert.
- Provisioning-Profile in Xcode neu gezogen.
- Build aufs iPhone 16 Pro Max, Wetter-Auto-Fill in der App getriggert → Wetter füllt sich erfolgreich, kein `WeatherKit failed`-Eintrag mehr im OSLog.

**Lessons Learned:**

- Die Entitlement-Datei (`DiveLog_Pro.entitlements`) und die App-ID-Konfiguration im Developer-Portal müssen *beide* WeatherKit aktiv haben. Nur eine Seite reicht nicht.
- Apple-Backend braucht typischerweise wenige Minuten bis zur Propagierung der Capability-Änderung; nach dem Save am Portal also nicht sofort einen JWT-Fehler als "Fix hat nicht funktioniert" interpretieren.
- Bei künftigen WeatherKit-Errors ist `Code=2` aus `WeatherDaemon.WDSJWTAuthenticatorServiceListener.Errors` der erste Indikator für ein App-ID/Entitlement-Mismatch, nicht für ein Code-Problem.

---

# Two-Device Validation — 2026-05-09

Validiert die Bug-Fixes aus Phase 2b (Numbering) und Phase 2c (Foto-Sync) auf
realer Hardware mit CloudKit-Sync zwischen zwei Geräten.

**Setup:** iPhone 16 Pro Max + iPad, beide am selben iCloud-Account, beide auf
HEAD `feat/instructor-skill-assessment`.

## Test 1 — Numbering-Konvergenz: ✓ pass

- Beide Geräte ins Flugzeugmodus → konkurrente Inserts (iPhone 14:00,
  iPad 12:00) → Flugzeugmodus aus → ~30-60 s warten.
- Beide Geräte zeigen die TGs in chronologischer Reihenfolge mit identischen
  fortlaufenden Nummern. Keine Duplikate, keine Lücken.
- Bestätigt: `CloudKitRenumberCoordinator` triggert nach Import-Events
  einen idempotenten Renumber-Pass, beide Devices konvergieren auf
  derselben Sequenz.

## Test 2 — Foto-Sync: ✓ pass

- Foto auf iPhone hinzugefügt → ~30-60 s später auf iPad sichtbar.
- Bestätigt: `DivePhoto.imageData` als Wahrheit, CloudKit syncht's als
  Asset, `load(filename:from:)`-Fallback funktioniert auch ohne Disk-Cache.

## Resultat

Bug 1 (Numbering nicht fortlaufend) und Bug 3 (Foto-Sync unzuverlässig) sind
auf zwei Geräten verifiziert gefixt. Bug 2 (Wetter) wurde bereits mit der
Capability-Aktivierung gelöst.
