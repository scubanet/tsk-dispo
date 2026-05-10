# FIT Direct Import (Phase B) — Manual Smoke Test

**Datum:** 2026-05-11
**Branch:** `feat/divecomputer-import`
**Device:** iPhone 16 Pro Max
**iOS:** _<Version>_
**FIT SDK:** garmin/fit-swift-sdk @ 21.202.0

Phase B baut FIT-Direkt-Import auf das Phase-A-UDDF-Gerüst (Plan A) auf.
Die 7 Test-Fixtures (MK3i-Aufnahmen in `DiveLog ProTests/Fixtures/fit/`)
sind alle automatisiert verifiziert (24 Tests grün); dieser Doc deckt
die UX-Pfade ab, die nur am Device geprüft werden können.

## Pfad A — In-App File-Picker

Profile-Tab → Datenverwaltung → "Tauchgänge importieren" → `.fit`-File aus Files

- [ ] Sheet öffnet sich
- [ ] Loading-State zeigt "FIT-Datei wird gelesen…" (nicht "UDDF")
- [ ] Generator-Zeile zeigt "Garmin Descent Mk3i" o.ä.
- [ ] 1 Dive in der Liste, korrekte Tiefe/Dauer/Datum
- [ ] Import → Dive im Logbook mit fortlaufender Nummer

## Pfad B — Share-Sheet via Files

Files-App → `.fit`-File long-press → Share → Atoll Log

- [ ] Sheet öffnet über dem aktuellen Tab
- [ ] Generator + Daten wie in Pfad A
- [ ] Import funktioniert

## Pfad C — AirDrop von Garmin Connect (optional)

Garmin Connect Mobile → Dive exportieren als FIT → AirDrop → iPhone → Atoll Log

- [ ] Sheet öffnet
- [ ] Daten korrekt

## Tank-Druck-Verifikation (AirIntegration)

Nach Import: DiveDetail → Cylinder/Pressure-Bereich

- [ ] `tankStartBar` zeigt echten Anfangsdruck (nicht 200 Default)
- [ ] `tankEndBar` zeigt echten Enddruck (nicht 50 Default)
- [ ] Werte sind plausibel (start > end, beide 0–300 bar)

Bekannt: nicht alle Dives haben TankSummary in der FIT (Apnea, manche
Single-Tank-Setups schreiben sie nicht). Wenn 200/50 angezeigt wird,
einmal überprüfen ob die FIT-File überhaupt TankSummary enthält
(via Diagnostic-Test, falls nötig).

## Cross-Format-Duplicate-Detection

Nach erfolgreichem FIT-Import: dasselbe Dive nochmal als UDDF importieren
(aus Subsurface oder direkt aus `DiveLog ProTests/Fixtures/uddf/test.uddf`).

- [ ] Sheet zeigt den Dive als "Duplikat von #N"
- [ ] Default-Strategy "Überspringen" greift
- [ ] "Beide behalten" produziert zwei sauber durchnummerierte Einträge

Toleranzen für Duplicate-Detection: datetime ±5 min AND maxDepth ±0.5 m
(siehe `UDDFImportCoordinator.findConflict`).

## Tauchplatz

- [ ] Site-Name leer nach Import (erwartet — siehe `feat(fit): dive-site
      extraction`-Commit, MK3i schreibt kein GPS in FIT)
- [ ] User editiert manuell wie in Garmin Dive App auch

## Bekannte Limitierungen / Follow-ups

- **Datum-Offset zwischen UDDF und FIT:** Subsurface strippt timezone
  beim UDDF-Export (Phillipinen-Dives +8h, Pool +2h). Unser FIT-Import
  ist korrekt (UTC); falls User UDDF + FIT mischt, können dieselben
  physical Dives als Duplikate erkannt werden ODER als zwei separate
  (je nach dem ob die Date-Toleranz hält). Beobachtbar bei dual-import.
- **GPS:** kommt nicht aus FIT. Eigenes Feature wäre: Site-Suggestions
  aus DiverProfile-DiveSites (Garmin-Dive-App-Style).
- **Tank-Update-Profile:** 689 TankUpdateMesg pro Dive werden nicht
  gespeichert. Phase-4-Idee: Tank-Pressure-over-Time-Chart in DiveDetail.
