# DiveLog Pro — DiveComputer-Import (UDDF + FIT)

**Datum:** 2026-05-10
**Branch:** wird `feat/divecomputer-import` (eigener Branch von `main`)
**Status:** Spec / awaiting user review
**Vorgänger:** Phase 1+2+3 abgeschlossen und auf `origin/main` (commits bis `b3efe09`)

## Ziel

Tauchgänge aus externen Dive-Computern (primär Garmin Descent MK3i, aber auch alle UDDF-fähigen Quellen) in das DiveLog-Pro-Logbuch importieren. Statt manueller Felder-Eingabe nach jedem Tauchgang nimmt der User eine Datei vom Computer, teilt sie mit der App, bestätigt einen Preview, und der Tauchgang ist mit Datum, Tiefe, Zeit, Wassertemperatur, Gas-Mix, GPS und Tiefenprofil im Logbuch.

Zwei Eingabe-Formate werden unterstützt — sequenziell implementiert, parallel ausgerollt:

- **UDDF** (Universal Dive Data Format, XML) — Foundation `XMLParser` reicht aus, kein externer Library-Bedarf. Funktioniert für Garmin (via Subsurface als Bridge), Suunto (via DM5), Shearwater (via Cloud), Mares und andere.
- **FIT** (Garmin's Binär-Format, direkt vom MK3i) — eliminiert den Subsurface-Zwischenschritt. Erfordert Erweiterung der `FitDataProtocol`-Library um Dive-spezifische Messages.

## Heutiger Stand

`main` ist auf `b3efe09` (nach Phase 3 + Export-Sheet-Theme-Migration). Das `Dive`-Model in `DiveLog Pro/Models/Dive.swift` hat ~40 Felder und kann von einem Importer voll bedient werden. Es gibt einen funktionierenden Importer-Workflow für **keinen** externen Format — alle Tauchgänge werden bisher manuell über `DiveFormView` oder `QuickLogView` eingegeben.

ExportSheet (`DiveLog Pro/Views/Screens/ExportSheet.swift`) bietet PDF + CSV Export. Symmetrische Import-Funktionalität fehlt.

## Architektur-Übersicht

Vier saubere Schichten, sequenziell ausgerollt in zwei Plans:

```
                Phase A (Plan A)        Phase B (Plan B)
                ─────────────────       ─────────────────

  .uddf file                              .fit file
  (XML, Subsurface)                       (binary, MK3i)
        │                                      │
        │                                      ▼
        │                              ┌──────────────────┐
        │                              │ Layer 1: FIT     │
        │                              │ Parser (FitData  │
        │                              │ Protocol + Dive  │
        │                              │ Messages)        │
        │                              └──────────────────┘
        │                                      │ FitMessage objects
        │                                      ▼
        │                              ┌──────────────────┐
        │                              │ FIT → UDDF       │
        │                              │ internal mapper  │
        │                              └──────────────────┘
        │                                      │
        ▼                                      │
  ┌──────────────────────────────────────────┴┐
  │ Layer 2: UDDF Parser                       │
  │ (Foundation XMLParser → Swift structs)    │
  └────────────────────────────────────────────┘
        │ [UDDFDive] (one or more)
        ▼
  ┌────────────────────────────────────────────┐
  │ Layer 3: UDDF → Dive Mapper                │
  │ (defaults, unit conversion, GPS-resolve)  │
  └────────────────────────────────────────────┘
        │ [Dive] (unsaved drafts)
        ▼
  ┌────────────────────────────────────────────┐
  │ Layer 4: Import UI                          │
  │ - File-picker / share-extension entry      │
  │ - Preview-Sheet (per-dive selectable)      │
  │ - Conflict-Detection (datetime ± 5min      │
  │   AND maxDepth ± 0.5m)                    │
  │ - Confirm → insert + renumberDives        │
  └────────────────────────────────────────────┘
        │
        ▼
  SwiftData store
```

**Warum diese Schichtung:**

- Jede Schicht ist isoliert testbar.
- Wenn das Dive-Model sich ändert, ist nur Layer 3 betroffen.
- Layer 2 normalisiert UDDF-Quirks (Kelvin, m³, Sekunden-vs-Minuten) ein einziges Mal — Layer 3 sieht saubere SI-Daten in unseren App-Einheiten.
- Layer 1 (FIT) produziert dieselbe interne UDDF-Struktur wie Layer 2 — d.h. Layer 3+4 funktionieren identisch für FIT und UDDF, ohne wissen zu müssen woher die Daten kommen.

## Phase A — UDDF Import (Plan A)

**Ziel:** End-to-End funktionsfähig vom .uddf-File bis zum Dive im Logbuch.

**Test-Fixture:** das vom User gelieferte `test.uddf` (1.1 MB, 7 Tauchgänge aus Subsurface 3, UDDF 3.2.0). Wird zu `DiveLog ProTests/Fixtures/uddf/test.uddf` im Repo eingecheckt.

### Layer 2 — UDDF Parser

**File:** `DiveLog Pro/Utils/UDDFParser.swift`

**Interne Datenstruktur:**

```swift
struct UDDFFile {
    let generator: String                  // "Subsurface Divelog v3"
    let gasDefinitions: [String: UDDFGas]  // by mix-id ("mix(21/0)")
    let diveSites: [String: UDDFSite]      // by site-id
    let dives: [UDDFDive]
}

struct UDDFGas {
    let id: String
    let name: String                       // "air", "ean32", ...
    let o2: Double                         // fraction 0.21
    let he: Double                         // fraction 0.00
}

struct UDDFSite {
    let id: String
    let name: String
    let latitude: Double?
    let longitude: Double?
}

struct UDDFDive {
    let datetime: Date                     // ISO-8601 parsed
    let siteRef: String?                   // resolves to UDDFSite via UDDFFile
    let leadKg: Double?                    // weight
    let gasRef: String?                    // resolves to UDDFGas
    let tankVolumeLiters: Double?
    let maxDepth: Double                   // meters (from <greatestdepth>)
    let avgDepth: Double                   // meters
    let durationSec: Int                   // seconds (from <diveduration>)
    let notes: String?
    let samples: [UDDFSample]              // depth profile
}

struct UDDFSample {
    let depth: Double                      // meters
    let time: Int                          // seconds since dive start
    let temperatureC: Double?              // converted from Kelvin
    let gasSwitchRef: String?
}
```

**Parser-Strategie:** `Foundation.XMLParser` ist Event-driven (SAX-style). Wir bauen einen `XMLParserDelegate`-Sub-Klasse, die einen State-Machine-Approach nutzt:

- Top-Level Elemente (`<gasdefinitions>`, `<divesite>`, `<profiledata>`) wechseln Modi
- Pro `<dive>`-Element bauen wir ein `UDDFDive`-struct inkrementell auf
- Sample-Sammlung ist die größte Performance-Concern (in unserem Test-File 9499 Samples) — wir alloce einen einzigen `[UDDFSample]`-Array pro Dive und appenden

### Layer 3 — UDDF → Dive Mapper

**File:** `DiveLog Pro/Utils/UDDFDiveMapper.swift`

**Hauptfunktion:**

```swift
static func makeDive(from uddf: UDDFDive, in file: UDDFFile) -> Dive
```

**Mapping-Tabelle:**

| UDDF | Dive-Feld | Konversion |
|---|---|---|
| `datetime` | `date` | direkt |
| `siteRef → UDDFSite.name` | `siteName` | direkt |
| `siteRef → UDDFSite.latitude` | `latitude` | direkt |
| `siteRef → UDDFSite.longitude` | `longitude` | direkt |
| `maxDepth` | `maxDepth` | direkt (Meter) |
| `avgDepth` | `avgDepth` | direkt |
| `durationSec` | `totalTime` | `÷ 60`, gerundet auf Minuten |
| `durationSec` | `bottomTime` | gleiche Quelle — UDDF unterscheidet nicht |
| `leadKg` | `weightKg` | direkt |
| `gasRef → UDDFGas` | `gas` | Mapping: o2=0.21,he=0 → "air"; o2=0.32 → "eanx32"; o2=0.36 → "eanx36"; o2=0.40 → "eanx40"; he>0 → "trimix"; else "air" |
| `tankVolumeLiters` | `cylinderSizeLiters` | direkt (UDDF: m³ → l × 1000 in Layer 2) |
| `notes` | `notes` | direkt |
| Min(`samples[].temperatureC`) | `waterTempBottom` | wenn ≥1 temp sample da; Fallback: 27 |
| Max(`samples[].temperatureC`) | `waterTempSurface` | wenn ≥1 temp sample da; Fallback: 28 |
| `samples[].depth` | `depthProfile` | Array der depth-Werte; down-sample auf max 200 Punkte für UI-Performance (gleichmäßig sampled) |

**Default-Werte für nicht-UDDF-Felder:** Werden vom `Dive`-Init mit den existierenden Defaults belegt (z.B. `tankStartBar: 200`, `tankEndBar: 50`, `weather: "sunny"`, `suit: "shorty"`). User kann sie nach Import im DiveFormView nachpflegen.

**Edge-Cases:**
- Fehlendes `siteRef` → `siteName: ""`, lat/lon = 0
- Fehlendes `gasRef` → `gas: "air"` (sicherer Default)
- Keine Samples → `depthProfile: []` (DiveDetail zeigt dann keinen Chart)
- Keine Temperatur-Samples → Defaults 28/27 °C
- `durationSec == 0` → `totalTime: 0`, `bottomTime: 0` (sollte aber im Preview als Warning angezeigt werden)

### Layer 4 — Import UI

**Files:**
- `DiveLog Pro/Views/Screens/UDDFImportSheet.swift`
- `DiveLog Pro/Utils/UDDFImportCoordinator.swift` — bündelt Parser+Mapper+Conflict-Detection

**Entry-Points:**

1. **Files-App / iCloud Drive / AirDrop Share-Sheet** — User wählt unsere App. iOS gibt ein File-URL via `UIApplicationDelegate.application(_:open:options:)` oder SwiftUI `.onOpenURL`. Wir registrieren `.uddf` als unterstütztes File-Type via `Info.plist` `CFBundleDocumentTypes`.

2. **In-App Button** — Profile-Tab → DataManagementCard → neuer Eintrag „Tauchgänge importieren" → öffnet `UIDocumentPicker` für `.uddf`-Files.

**UI-Flow:**

```
Entry-Point
    │
    ▼
UDDFImportCoordinator.parse(url:) async
  ├─ XMLParser läuft → [UDDFDive]
  ├─ Dive-Drafts erzeugen (UDDFDiveMapper)
  └─ Conflict-Check gegen existing Dives
    │
    ▼
UDDFImportSheet (modal):
  - Quelle: Generator-Name aus UDDF
  - Header: "7 Tauchgänge gefunden, 2 Duplikate, 5 neu"
  - Liste mit Checkboxen, pro Dive:
      ✓/☐ Datum · Tiefe · Dauer · Tauchplatz · Gas
      [NEU] oder [DUPLIKAT mit #N]
  - Konflikt-Strategie-Picker:
      ◉ Duplikate überspringen
      ○ Duplikate überschreiben
      ○ Beide behalten (Renumber via renumberDives)
  - Buttons: [Abbrechen] [Importieren (5 ausgewählt)]
    │
    ▼
On confirm:
  - Insert selected dives into ModelContext
  - Apply conflict strategy
  - Call ctx.renumberDives(from: profile)
  - try? ctx.save()
  - Show success Toast: "5 Tauchgänge importiert (#8'767 bis #8'771)"
```

**Conflict-Detection-Algorithmus:**

```
for newDive in importedDives:
    for existingDive in dives:
        if abs(newDive.date.timeInterval(to: existingDive.date)) ≤ 300  // 5 min
           AND abs(newDive.maxDepth - existingDive.maxDepth) ≤ 0.5:
            mark newDive as DUPLICATE of existingDive.number
            break
```

Pro Duplikat speichern wir die `existingDive.number` für die Anzeige im UI („Duplikat von #8'757").

## Phase B — FIT Direct Import (Plan B)

**Ziel:** Eliminiere den Subsurface-Zwischenschritt. User shared .fit-File direkt, App parst es zu denselben internen UDDF-Strukturen, Rest des Pipelines bleibt identisch.

**Test-Fixtures:** die 7 vom User gelieferten FIT-Files (`8753 IDC 126.fit`, `8754 IDC 126.fit`, etc.) werden zu `DiveLog ProTests/Fixtures/fit/` eingecheckt. Goldenes Soll: die UDDF-Werte aus Phase A's `test.uddf` (die durch Subsurface aus genau diesen FIT-Files erzeugt wurden).

### Layer 1 — FIT Parser-Erweiterung

**Library-Strategie:** `FitDataProtocol` (MIT, MIT-License, gepflegt) als vendored SPM-Dependency. Forkbar wenn Upstream nicht mergt, aber unsere Erweiterungen sind additiv und stören existierende Funktionalität nicht.

**Neue Message-Klassen** (folgen `SessionMessage.swift`-Pattern aus der Library):

| Klasse | Global # | Wichtige Felder für unseren Use-Case |
|---|---|---|
| `DiveSummaryMessage` | 268 | timestamp, reference_mesg, reference_index, avg_depth, max_depth, surface_interval, start_cns, end_cns, start_n2, end_n2, o2_toxicity, dive_number, bottom_time |
| `DiveSettingsMessage` | 258 | name, model, gf_low, gf_high, water_type, water_density, po2_warn, po2_critical, safety_stop_enabled, bottom_depth, bottom_time |
| `DiveGasMessage` | 259 | message_index, helium_content, oxygen_content, status (enabled/disabled) |
| `DiveAlarmMessage` | 262 | message_index, depth, time, enabled, alarm_type, sound |
| `TankSummaryMessage` | 323 | timestamp, sensor, start_pressure, end_pressure, volume_used |
| `TankUpdateMessage` | 319 | timestamp, sensor, pressure |

**Bonus:** der existierende `RecordMessage` enthält bereits Felder wie `depth`, `next_stop_depth`, `next_stop_time`, `time_to_surface`, `n2_load` — die nutzen wir wie sie sind.

**Field-Definitionen:** Aus Garmin's `Profile.xlsx` (FIT SDK, öffentlich verfügbar). Wir transkribieren nur die Felder die wir für unser Dive-Model brauchen — kein vollständiger Profile-Support.

### FIT → UDDF Internal Mapper

**File:** `DiveLog Pro/Utils/FITToUDDFMapper.swift`

Nimmt eine Liste `FitMessage`-Objekte aus dem Parser und produziert eine `UDDFFile`-Struktur:

```swift
static func makeUDDFFile(from messages: [FitMessage]) -> UDDFFile
```

Mapping:
- `FileIdMessage` + `DeviceInfoMessage` → `UDDFFile.generator` (z.B. "Garmin Descent MK3i")
- `DiveGasMessage`(s) → `UDDFFile.gasDefinitions`
- Wenn GPS-Daten in `SessionMessage.startPosition*` → `UDDFFile.diveSites` mit lat/lon
- `SessionMessage` + `DiveSummaryMessage` → `UDDFDive`-Header
- `RecordMessage`(s) → `UDDFDive.samples`
- `TankSummaryMessage` → `UDDFDive.tankVolumeLiters` + (NEU für FIT-Quelle:) `tankStartBar` / `tankEndBar` via `start_pressure` / `end_pressure`

**Erweiterung der UDDF-Internal-Struktur:** Wir fügen `tankStartBar: Int?` und `tankEndBar: Int?` zu `UDDFDive` hinzu, weil FIT diese liefert, UDDF (aus Subsurface) nicht. Phase A's Mapper ignoriert diese Felder; Phase B's Mapper befüllt sie. Layer 3 nutzt sie, wenn vorhanden, sonst Defaults.

### Phase-B Import-UI-Anpassung

Minimal. Das `UDDFImportSheet` wird zu `DiveComputerImportSheet` umbenannt und nimmt beide Datei-Typen entgegen. Coordinator dispatcht intern:

```swift
func parse(url: URL) async throws -> [Dive] {
    let ext = url.pathExtension.lowercased()
    switch ext {
    case "uddf": return try parseUDDF(url)
    case "fit":  return try parseFIT(url)   // → UDDF intern → Dive
    default:     throw ImportError.unsupportedFormat
    }
}
```

`Info.plist` `CFBundleDocumentTypes` wird um `.fit` erweitert.

## Datenfluss & Einheiten

| Quelle | Ausgangs-Einheit | Layer-2-Norm | Dive-Feld |
|---|---|---|---|
| UDDF `<depth>` | Meter | Meter | `maxDepth`, `avgDepth`, profile |
| UDDF `<diveduration>` | Sekunden | Sekunden in `UDDFDive`, Layer-3 ÷60 | `totalTime` (Minuten) |
| UDDF `<temperature>` | **Kelvin** | Celsius (− 273.15) | `waterTempSurface/Bottom` |
| UDDF `<tankvolume>` | **m³** | Liter (× 1000) | `cylinderSizeLiters` |
| UDDF `<leadquantity>` | kg | kg | `weightKg` |
| UDDF `<latitude>`/`<longitude>` | Dezimal-Grad | Dezimal-Grad | `latitude`, `longitude` |
| FIT `RecordMessage.depth` | Meter (scaled int) | Meter (Library macht's) | profile |
| FIT `DiveSummaryMessage.maxDepth` | Meter | Meter | `maxDepth` |
| FIT `RecordMessage.temperature` | **Celsius** | Celsius | `waterTempBottom/Surface` |
| FIT `TankSummaryMessage.startPressure` | Pascal (scaled) | bar (× 1e-5) | `tankStartBar` |
| FIT `SessionMessage.startPositionLat` | **Semicircles** | Dezimal-Grad (× 180/2³¹) | `latitude` |

Layer 2 ist die einzige Stelle, die Einheiten-Konversion macht — Layer 3+4 sehen alles in App-Einheiten.

## Performance-Überlegungen

**Sample-Down-Sampling:** Test-File hat 9499 Samples über 7 Dives — durchschnittlich 1356 pro Dive. Bei 1-Hz Logging und 22-Min-Dauer realistisch. Speichern als `depthProfile`-Array in SwiftData:

- 1356 Doubles × 8 Bytes = 10.8 KB pro Dive
- × 100 Dives = 1.08 MB Profile-Daten in der Datenbank
- CloudKit-syncbar, aber nicht trivial

Mitigation in Layer 3: **uniform down-sample auf max 200 Punkte** für UI-Rendering. Original-Auflösung bleibt im FIT/UDDF-File, falls jemand das später full-fidelity haben will (separates Feature, out of scope).

**Async-Parsing:** XMLParser ist synchron, blockiert Main-Thread bei 1.1MB-Files (~100-300ms). Layer 4 ruft Parser in `Task.detached(priority: .userInitiated)` auf, UI zeigt Spinner während Parsing.

## Test-Strategie

### Phase A
- **Unit:** `UDDFParserTests.swift` mit dem `test.uddf` als Fixture. Tests verifizieren: Anzahl Dives, Datum/Tiefe/Dauer pro Dive, Gas-Definition, Site-Resolution, Sample-Count, Temperatur-Konversion (303.15K → 30.0°C), Volume-Konversion (0.012 m³ → 12 l).
- **Unit:** `UDDFDiveMapperTests.swift` — pro UDDFDive ein erwarteter Dive-Output, Field-by-Field-Vergleich.
- **Unit:** `ImportConflictDetectionTests.swift` — Toleranz-Logik verifizieren (datetime ±5min, maxDepth ±0.5m).
- **Manueller Smoke-Test:** Test-UDDF in der App importieren, Preview-Sheet sichten, importieren, im Logbook prüfen.

### Phase B
- **Unit:** `FITToUDDFMapperTests.swift` — pro FIT-Fixture-File die produzierte UDDFFile-Struktur gegen die Phase-A-UDDF-Werte vergleichen. Goldener-Soll-Test: für `8757 Mamutic Island.fit` muss die produzierte UDDF dieselben Werte wie der `2026-01-11T10:03:17`-Dive aus `test.uddf` ergeben.
- **Unit:** Dive-spezifische Message-Parser-Tests gegen Garmin's Profile-Specs.
- **Manueller Smoke-Test:** FIT-File teilen, Import durchlaufen, Vergleich mit der UDDF-Variante desselben Dives.

### Fixtures-Ordner
```
DiveLog ProTests/Fixtures/
├── uddf/
│   └── test.uddf  (1.1 MB, 7 Dives aus Subsurface)
└── fit/
    ├── 8753 IDC 126.fit
    ├── 8754 IDC 126.fit
    ├── 8756 Mamutic Island.fit
    ├── 8757 Mamutic Island.fit
    ├── 8758 OWD Dry Tg1.fit
    ├── 8762 Singlegas-Tauchgang.fit
    └── 8763 OWD Dry Tg2.fit
```

## Risiken und offene Punkte

- **FitDataProtocol-Fork-Wartung.** Wir vendoren die Library mit unseren Dive-Message-Erweiterungen. Falls Upstream Major-Updates pushed, müssen wir nachziehen. Mitigation: Erweiterungen sind additiv und in separaten Files, Diff-Konflikte minimal.
- **MK3i-Spezifika.** Garmin könnte proprietäre Felder im FIT verwenden, die nicht in der öffentlichen Profile-Spec stehen. Mitigation: wir parsen nur Felder die definiert sind, Unbekanntes wird ignoriert.
- **Conflict-Detection-Toleranz.** `±5min / ±0.5m` ist ein Educated-Guess. Bei realer Nutzung könnten False-Positives (Repetition-Dives gleicher Tiefe innerhalb von 30 Min) oder False-Negatives (Manuelle Eingabe mit gerundetem Datum) auftreten. Wir notieren das im Follow-up-File und bei Bedarf bauen wir es nach.
- **Down-Sample-Verlust.** 1356 → 200 Samples ist ~7× Reduktion. Bei stufenförmigen Decompression-Stops könnten lokale Maxima verloren gehen. Mitigation: Wir nutzen Largest-Triangle-Three-Buckets oder Min/Max-Aware-Sampling statt linearem Uniform-Sample. (Algorithmus-Detail im Plan.)
- **Sample-Speicher in SwiftData.** ~10 KB pro Dive × 1000 Dives = 10 MB. CloudKit's Property-Limit ist 1 MB pro Field, aber Array<Double> wird automatisch zu CKAsset bei >1MB — also kein hartes Limit, aber Sync-Latenz wächst. Mitigation: down-sampling hält uns weit unter dem Limit.
- **Pro-Gating-Entscheidung.** Vertagt zu Phase 4 (Pro-Gating-Coverage-Audit). Feature ist initial für alle User sichtbar.

## Was nicht in diesem Spec ist

- **Direkter BLE-Sync vom MK3i** — Garmin's BT ist proprietär, kein offener Standard. Vermutlich Reverse-Engineering, out of scope.
- **Connect-IQ-App auf dem MK3i** — Garmin's Connect-IQ-SDK ist eigene Welt, eigenes Projekt.
- **UDDF-Export** — kommt vermutlich in Phase 4 zusammen mit dem ExportSheet-Ausbau.
- **Multi-Device-Sync der Import-Fixtures** — Test-Fixtures werden ins Repo eingecheckt, nicht über CloudKit synct.
- **Full-Fidelity-Profile-Erhaltung** — wir down-samplen auf 200 Punkte. Wer Maximum will, behält FIT-File extern.
- **Other-Dive-Computer-Quirks** — wir testen mit Garmin MK3i und Subsurface-UDDF. Suunto/Shearwater/Mares könnten Quirks haben — adressieren wir wenn der Bedarf kommt.

## Nächste Schritte

Nach User-Review dieses Specs: Übergang in `superpowers:writing-plans` zweimal hintereinander:

1. **Plan A — UDDF Import** schreiben und ausführen. ~5 Tage. Resultat: User kann via Subsurface FIT → UDDF → unsere App importieren.
2. **Plan B — FIT Direct Import** schreiben und ausführen. ~7 Tage, baut auf Plan A. Resultat: User kann FIT direkt teilen, Subsurface entfällt.

Beide Plans landen auf demselben Feature-Branch `feat/divecomputer-import`. Wenn Plan A merged ist und Plan B sich verzögert, ist das OK — UDDF-Import läuft bereits.
