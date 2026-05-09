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
