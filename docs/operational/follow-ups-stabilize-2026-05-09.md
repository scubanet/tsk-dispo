# Stabilize-and-Ship — Follow-up Issues

Aus dem Final-Code-Review zur `feat/instructor-skill-assessment`-Branch
(2026-05-09) übrig gebliebene, bewusst deferred Punkte. Eigene Tickets/Specs,
kein Blocker für TestFlight.

---

## #1 Tie-Breaker für `Dive.date`-Kollisionen

**Problem.** `ModelContext.renumberDives(from:)` sortiert per
`SortDescriptor(\Dive.date, .forward)`. Bei zwei Tauchgängen mit *identischer
Sekunde* (selten bei manueller Eingabe, möglich bei Bulk-Imports oder
zukünftigem Tauchcomputer-Import) ist die Sortierreihenfolge instabil.
Damit ist die im Doc-Comment versprochene **CloudKit-Konvergenz-Garantie**
(zwei Geräte konvergieren auf identische Nummern) theoretisch verletzbar:
Device A könnte fetch-Reihenfolge `[A, B]` sehen, Device B `[B, A]`, und
beide würden nach Renumber unterschiedliche Nummern vergeben.

**Lösung (Skizze):** Eine stabile Sekundär-Sortierung auf Dive einführen.
Vorschlag:

```swift
// In Dive.swift
var stableSortKey: String = UUID().uuidString  // einmal beim Insert gesetzt
```

Dann in `renumberDives`:

```swift
let descriptor = FetchDescriptor<Dive>(
    sortBy: [
        SortDescriptor(\Dive.date, order: .forward),
        SortDescriptor(\Dive.stableSortKey, order: .forward)
    ]
)
```

**Aufwand:** ~30 Min Code + Tests, plus eine SwiftData/CloudKit-Schema-
Migration (neue Property muss bei alten Records einen Default haben).

**Priorität:** niedrig — bisher nicht beobachtet bei normalen Workloads.

**Wird gefährlich, wenn:** Tauchcomputer-Import-Feature kommt (Phase 5+).

---

## #2 StoreManager.deinit cancelt updatesTask nicht

**Problem.** `StoreManager` ist als `static let shared` Singleton — der
deinit-Pfad läuft im Produktiv-Code nie. Aber falls jemand in einem Test
einen frischen `StoreManager()` über Reflection erzeugt, läuft die
`for await ... in Transaction.updates`-Schleife unbegrenzt weiter und leakt.

**Fix:**

```swift
deinit {
    updatesTask?.cancel()
}
```

(Aktuell ist deinit nonisolated und leer.)

**Priorität:** sehr niedrig, eher Hygiene als Bug. Kann mit Phase-4-
StoreKit-Polish gebündelt werden.

---

## #3 .storekit Konfiguration enthält Placeholder-IDs

`InstructorPro.storekit` hat:
```
"_developerTeamID" : "XXXXXXXXXX"
"_applicationInternalID" : "1234567890"
```

Echte Werte vor App-Store-Connect-Submission setzen. Phase-4-Aufgabe.

---

## #4 CloudKitRenumberCoordinator: `event.succeeded` Check

`handleEvent` filtert auf `.import` + `endDate != nil`, aber nicht auf
`event.succeeded`. Ein fehlgeschlagener Import löst aktuell trotzdem einen
(no-op) Renumber-Pass aus. Korrekt aber unsauber.

**Fix:** zusätzlich `event.succeeded` prüfen (oder `event.error == nil`).

**Priorität:** kosmetisch.
