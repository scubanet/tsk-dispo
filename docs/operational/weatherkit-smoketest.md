# WeatherKit Smoke-Test

Manueller Test, ausführen vor jedem TestFlight-Build und nach jedem Wechsel der Apple-Developer-Account-Konfiguration.

## Voraussetzungen

- Echtes iPhone (Simulator wird für WeatherKit nicht zuverlässig unterstützt)
- iCloud-Account am Device angemeldet
- App-ID `com.weckherlin.DiveLogPro` hat WeatherKit-Capability aktiv im Apple-Developer-Portal (siehe `2026-05-09-weatherkit-diagnosis.md` Resolution)
- Aktives, frisches Provisioning-Profile in Xcode

## Durchführung

1. App auf das Test-Device bauen + starten (Cmd+R in Xcode mit Device als Target).
2. Console.app auf dem Mac öffnen, das angeschlossene iPhone in der linken Sidebar wählen.
3. Console-Filter setzen: `subsystem:com.weckherlin.DiveLogPro category:weather`.
4. In der App: Logbook → FAB-Menu → „Tauchgang anlegen" oder „Schnelleingabe".
5. Tauchplatz: aktueller Standort via GPS-Button (Standort-Permission akzeptieren falls noch nicht erteilt).
6. Datum: heute, Uhrzeit: jetzt.
7. Wetter-Auto-Fill antippen.

## Erwartetes Verhalten

- Wetter-Feld zeigt eine der internen Conditions: `sunny | partly_cloudy | cloudy | rainy | windy | foggy`.
- Lufttemperatur ist gefüllt mit einem plausiblen Wert für aktuellen Standort/Zeitpunkt.
- Im OSLog erscheint **kein** `WeatherKit failed`-Eintrag.

## Bei Fehlschlag

OSLog auslesen, Domain/Code in der Tabelle nachschlagen:

| Domain | Code | Wahrscheinliche Ursache | Fix |
|--------|------|-------------------------|-----|
| `WeatherDaemon.WDSJWTAuthenticatorServiceListener.Errors` | 2 | App-ID hat WeatherKit-Capability nicht | Im Developer-Portal aktivieren, Provisioning refreshen |
| `WKBackendErrorDomain` | 401 | Token/Provisioning-Probleme | Provisioning komplett neu generieren |
| `NSURLErrorDomain` | -1009 / -1003 | Netzwerk (kein Internet, DNS) | Realer Konnektivitäts-Fehler, nicht App-Bug |
| `WeatherDaemon.…Errors` | 4 | Region/Datum nicht unterstützt | Code-Fix in `DiveWeatherService.fetch` (Range-Validierung) |

Bei unbekanntem Fehler: zuerst Capability + Provisioning prüfen (häufigste Ursache), dann tieferer Code-Fix.
