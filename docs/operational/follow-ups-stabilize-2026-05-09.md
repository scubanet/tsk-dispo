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

---

# Phase-3 QA Findings (deferred)

Aus dem Phase-3-QA-Pass am 2026-05-09. Eine Critical-Konvergenz-Bug, zwei
Important und sieben Minor — bewusst nicht in dieser Session gefixt, weil
real-life-Workflow-Wahrscheinlichkeit niedrig oder Aufwand hoch.

Vollständiger Test-Walkthrough + Repro-Steps siehe
`2026-05-09-phase-3-qa-findings.md`.

## #5 SkillCompletion-Sync konvergiert nicht (Critical)

**Problem.** Zwei Geräte mit konkurrenten Skill-Cycles auf demselben
Schüler+Skill zeigen unterschiedlichen Status nach CloudKit-Sync. Verifiziert
mit iPhone+iPad: iPhone zeigte OW1.1=Mastered, iPad OW1.1=Eingeführt für
identischen Dive.

**Vermutete Ursache.** `currentStatus` greift auf
`max(by: assessedOn)` zu. Bei Same-Second-`assessedOn`-Ties (z.B.
zeitgleicher Cycle in Flugzeugmodus auf zwei Geräten) ist die Sortierung
unstable, und beide Geräte können unterschiedliche Records als „neuesten"
interpretieren.

**Selbe Bug-Klasse wie #1** (Date-Tie-Tie-Breaker für Dive-Numbering),
nur im Skill-Domain.

**Lösung (Skizze).** Stabile Sekundär-Sortierung in `currentStatus`:

```swift
// In Student.currentStatus(for:)
let latest = (skillCompletions ?? [])
    .filter { $0.skillCode == skillCode }
    .sorted { lhs, rhs in
        if lhs.assessedOn != rhs.assessedOn { return lhs.assessedOn > rhs.assessedOn }
        // tie-breaker: persistentModelID-string for deterministic ordering across devices
        return String(describing: lhs.persistentModelID) > String(describing: rhs.persistentModelID)
    }
    .first
```

**Real-life-Wahrscheinlichkeit.** Niedrig — Solo-Course-Director nutzt
typischerweise nur ein Device gleichzeitig. Akzeptabel für Phase 4
TestFlight, sollte aber vor breiterem Release angepackt werden.

## #6 CW-Catalog (Pool-Skills) ist leer (Important)

**Problem.** PADI-Standards-JSON für Confined Water Sessions (CW1-CW5) ist
nur mit „CW1.1 — TBD"-Platzhalter gefüllt. Pool-zentrische Workflows sind
unbrauchbar. Flexible-Skills im Pool fallen auf OW-Flex-Skills zurück.

**Lösung.** Echte PADI-CW-Skills recherchieren und in `owd.json` /
`owd.de.json` einpflegen (oder eigene Sub-Catalogs für `cwskills.json`).
Pro CW-Slot ~12-15 Skills + Flex-Skills. Aufwand: 30-60 Min Recherche +
Eintragung. Schema-konform mit existing PADIStandards-Loader.

## #7 Sprache mid-flow inkonsistent (Important)

**Problem.** Sprachwechsel in iOS-Settings wird teils von der App
übernommen (L10n-Strings), teils nicht (PADI-Catalog-Strings, iOS-native
Tab-Bar). Nach App-Restart ist alles konsistent.

**Lösung.** PADIStandards.shared muss bei Sprachwechsel den Catalog
neu laden. Listener auf `NSLocale.currentLocaleDidChangeNotification`
oder eigene App-internal Notification. iOS-native Strings (Tab-Bar)
brauchen App-Restart — User-Hinweis-Dialog beim Sprachwechsel.

## Minor — Phase-3-Sammlung

| # | Beschreibung | Notes |
|---|--------------|-------|
| M1 | Sign-Tab nicht hinter Pro-Gate | Phase-4-Coverage-Audit greift das auf. |
| M2 | Tauchgangstyp + Kurs-Tauchgang nicht exklusiv | UX-Frage. Doku-Klärung statt Code-Fix möglich. |
| M3 | Per-Dive-PDF-Export aus DiveDetail fehlt | Bulk-Export aus Profile-Tab deckt Use-Case ab. |
| M4 | Prior-Mastery-Trigger nicht offensichtlich | UX-Polish, evtl. Button in StudentProfileView prominenter. |
| M5 | „1 students"-Plural-Bug | stringsdict / String-Catalog mit Plural-Variants. |
| M6 | StudentEdit nur via ProfileView | Long-Press oder Swipe-Edit im StudentPicker als ergonomische Verbesserung. |
| M7 | Schüler-Duplikate beim konkurrenten Anlegen | Dedupe-Logik analog DiverProfile (richness-scored). Niedrige Priorität. |
| M8 | ExportSheet nutzt ein abweichendes Theme | `Color.deepOcean` / `.coral` / `.seafoam` / `.cardBg` + erzwungenes `.preferredColorScheme(.dark)` statt `appAccent` / `glassCard` / `DSSpacing`. Konsequenz: Export-Modal sticht visuell stark vom Rest der App ab. Migration auf das aktuelle Design-System: ~30-60 Min. Phase-4-Polish. |
