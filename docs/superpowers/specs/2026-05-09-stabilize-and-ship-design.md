# DiveLog Pro — Stabilize & Ship

**Datum:** 2026-05-09
**Branch:** `feat/instructor-skill-assessment`
**Status:** Spec / awaiting user review

## Ziel

Drei klar diagnostizierte Daten-/Funktions-Bugs ausräumen, die uncommittete Paywall-/StoreKit-Arbeit sauber landen, das Instructor-Skill-Assessment-Feature einmal end-to-end durchstressen und die App so weit polieren, dass ein TestFlight-Build sinnvoll ist. Wir arbeiten verzahnt in vier Phasen, damit dieselben Files (`DiveFormView`, `JournalTab`, `DivePhotoComponents`) nicht mehrfach in unterschiedlichen Workstreams angefasst werden.

## Heutiger Stand (Kurzfassung)

Auf `feat/instructor-skill-assessment` liegen 40+ Commits Instructor-Layer-Arbeit (Students, Pool-Sessions, Skill-Grids, PADI-JSON-Standards, CloudKit-Sync) und die Atoll-Hub-Bridge ist via Merge mit `main` integriert. Uncommittet im Working-Tree liegen ~15 Files mit ~534 Inserts für eine StoreKit-2-Paywall: `StoreManager`, `PaywallView`, `InstructorPro.storekit`, plus Pro-Gates in `MainTabView` (Sign-Tab → `ProTeaser`) und `DiveFormView` (Course-Training-Block). Build kompiliert; Paywall ist konzeptionell unfertig.

## Drei Bugs auf dem Tisch

### Bug 1 — Tauchgangs-Nummerierung inkonsistent

**Symptom:** Nummern sind nicht fortlaufend; nachgetragene Tauchgänge brechen die chronologische Logik; auf zwei Geräten kann dieselbe Nummer entstehen.

**Ursachen im Code (`DiveFormView.swift:685`):**

```swift
let startingNumber = profiles.first?.startingDiveNumber ?? 8758
let num = (existingDives.first?.number ?? (startingNumber - 1)) + 1
```

mit `@Query(sort: \Dive.number, order: .reverse)`. Das ist „Maximum vorhandener Nummer + 1" — drei Failure-Modes:

- **CloudKit-Race:** parallele Inserts auf zwei Geräten → identische Nummern nach Sync.
- **Insertion-Order ≠ chronologisch:** Ein nachgetragener TG vom letzten Monat kriegt die höchste Nummer, obwohl er datumsmäßig dazwischen gehört.
- **Profile-Sync-Reihenfolge:** Wenn der erste TG vor dem Profile-Datensatz syncht, wird Default 8758 verwendet — danach stimmt der Offset nicht mehr.

**Entschiedene Regel:** Chronologisch nach `dive.date`. Bei jedem Insert/Edit/Delete wird das gesamte Logbuch (ohne `PoolSession` — die haben keine Nummer) sortiert nach `date` durchnummeriert ab `profile.startingDiveNumber`.

### Bug 2 — Wetter-Modul liefert keine Daten

**Symptom:** WeatherKit-Aufruf in `DiveFormView` schlägt fehl, kein Wetter wird gefüllt.

**Diagnose:** `DiveWeatherService` (Code) ist sauber. Entitlement `com.apple.developer.weatherkit` ist gesetzt. Letzter Commit (`diag(weather): expose underlying WeatherKit error in UI + OSLog`) hat bereits Detail-Logging eingebaut. Das ist mit hoher Wahrscheinlichkeit kein Code-Bug, sondern **Provisioning/Capability**. Wahrscheinliche Wurzel:

- WeatherKit ist nicht auf der App-ID im Apple-Developer-Portal aktiviert (Entitlement-File ≠ App-ID-Konfiguration).
- Test läuft auf Simulator (WeatherKit oft nur am echten Gerät verlässlich).
- Bundle-ID-Mismatch oder abgelaufenes Profil.

**Vorgehen:** Erst Diagnose am Device statt zu raten. Build aufs iPhone, OSLog filter `subsystem == com.weckherlin.DiveLogPro && category == weather`, Domain/Code im Error-Log lesen. Danach ist die Wurzel in einer Minute klar (häufig 401-Auth → App-ID-Capability nachziehen).

### Bug 3 — Foto-Synchronisierung unzuverlässig

**Symptome:** Fotos kommen nicht oder erst sehr verzögert auf das andere Gerät; teilweise nur lokal sichtbar.

**Architektur-Ursachen:**

- **Doppelte Quelle der Wahrheit:** `PhotoStore.save(image:toDive:context:)` schreibt sowohl als JPEG-Datei in `Documents/dive_photos/` als auch als `imageData: Data` ins `DivePhoto`-SwiftData-Record. Das Record syncht via CloudKit, die Disk-Datei nicht — beide können auseinanderlaufen.
- **Zwei Photo-Pfade nebeneinander:** Das Legacy-Feld `dive.photoFilenames: [String]` und die neue Relationship `dive.photos: [DivePhoto]?` existieren parallel. Eine Migration (`migrateLocalPhotosToCloudKit`) ist mittendrin — abhängig davon, *wann* ein Tauchgang erstellt wurde, syncht das Foto oder eben nicht.
- **`@Relationship var dive: Dive?`** in `DivePhoto` ohne expliziten Inverse — unter CloudKit fragiler als die anderen Models (Student, SkillCompletion haben Inverses).
- **Kein Sync-Status im UI** — User weiß nicht, ob ein Bild „angekommen" ist.

**Entschiedene Architektur:** CloudKit-Asset + Disk-Cache.
- `DivePhoto.imageData` bleibt die **einzige Wahrheit** (CloudKit syncht große `Data`-Properties automatisch als Asset, nicht inline).
- Disk-Verzeichnis `Documents/dive_photos/` wird zu reinem Read-Through-Cache.
- `dive.photoFilenames: [String]` wird deprecated und in einer einmaligen Migration in `DivePhoto`-Records überführt.
- `@Relationship` bekommt expliziten Inverse auf `Dive.photos`.

## Architektur-Übersicht

Die vier Phasen verändern Module so:

```
Phase 1 — Werkbank        Phase 2 — Bugs            Phase 3 — Polish        Phase 4 — Ship
────────────────────      ───────────────────       ────────────────────    ────────────────
StoreManager (commit)     DiveWeatherService        ProfileTab Split        Pro-Gating-Audit
PaywallView (commit)      DiveFormView.numbering    Skill-Assessment QA     Onboarding-Touch
MainTabView gates         Dive.swift +numberLogic   Edge-case Fixes         AppStoreConnect
DiveFormView gates        PhotoStore (rewrite)      ProfileTab Refactor     Screenshots/Build
.storekit committed       DivePhoto +inverse                                TestFlight
                          ModelContextExtensions
                          Migration Script
```

## Phase 1 — Stabilisierung der Werkbank

**Ziel:** Den uncommitteten WIP-Diff (15 Files, ~534 Inserts) in 3-4 logischen Commits einrahmen, ohne Verhaltensänderung. Das Repo ist danach sauber, Bug-Fixes in Phase 2 erzeugen klare Diffs.

**Commit-Plan (logisch zerlegt, jeder Commit baut sauber, keine *zusätzlichen* Verhaltensänderungen über den bestehenden WIP-Stand hinaus):**

1. `feat(store): StoreManager + .storekit configuration` — `StoreManager.swift`, `Resources/InstructorPro.storekit`, Project-File-Eintrag, `Info.plist`, `DiveLogProApp.swift` (Init).
2. `feat(paywall): PaywallView UI` — `Views/Screens/PaywallView.swift`, OnboardingView-Touch.
3. `feat(pro-gate): Sign tab + course training behind Pro` — `MainTabView` (ProTeaser), `DiveFormView` (Course-Block).
4. `chore(misc): touched files for paywall integration` — restliche kleine Edits in `Profile/Journal/DiveDetail/DivePhotoComponents/Dive.swift`, dokumentiert was die Änderungen sind.

**Definition of Done:**
- `git status` sauber, alle Tests grün.
- App startet, Sign-Tab zeigt Teaser für nicht-Pro, Paywall öffnet sich, In-App-Purchase im Sandbox kauft erfolgreich.

## Phase 2 — Bugs

Reihenfolge: Wetter (Diagnose → vermutlich Capability-Setting), Numbering (klare Regel + Tests), Foto-Sync (Architektur + Migration). Jeder Bug bekommt Tests, damit's nicht zurückkommt.

### Phase 2a — Wetter

**Schritte:**

1. Build aufs echte iPhone (nicht Simulator), Wetter im DiveFormView triggern.
2. OSLog-Eintrag aus dem `diag(weather)`-Commit auslesen — Domain/Code/userInfo.
3. Abhängig vom Result einer dieser Pfade:
   - **Capability fehlt:** WeatherKit auf der App-ID im Apple-Developer-Portal aktivieren, Provisioning-Profile neu generieren, Build erneut.
   - **Bundle-ID-Mismatch:** Project-File angleichen.
   - **Echter Code-Bug:** dann erst tieferer Fix.
4. Erfolgreichen Pfad mit einem `WeatherKitSmokeTest` absichern (manuell ausgeführt, dokumentiert was geprüft wird — automatisierte WeatherKit-Tests sind unzuverlässig).

**Definition of Done:** Wetter füllt sich beim DiveFormView-Auto-Fill am echten Gerät; OSLog zeigt keinen Error.

### Phase 2b — Numbering (chronologisch)

**Neue Regel:**

```
nummer(dive) = startingDiveNumber + index_in(sortedByDateAscending(allDives))
```

**Architektur:**

- Neue Funktion `ModelContext.renumberDives(from profile: DiverProfile)` — sortiert alle `Dive` nach `date` ascending, weist `dive.number = profile.startingDiveNumber + index` zu, persistiert.
- Hooks: nach jedem Insert (DiveFormView, QuickLogView), nach Date-Edit (DiveFormView edit-mode), nach Delete (LogbookTab swipe-delete + Undo-Restore).
- `ProfileEditView.applyShift` wird ersetzt durch denselben Renumber-Aufruf.
- Bei massiven Logbüchern ist O(n) pro Operation OK — wir reden Hunderte, nicht Millionen TGs.

**CloudKit-Konfliktbehandlung:** Renumber läuft idempotent. Wenn nach Sync der Datensatz von einem anderen Gerät reinkommt, hängt sich ein Listener an `NSPersistentCloudKitContainer.eventChangedNotification` und triggert einen debounced Renumber-Pass (1s Window), und alle Devices konvergieren auf dieselbe Reihenfolge ohne Loop.

**Performance-Anmerkung:** Renumber ist O(n) pro Insert/Edit/Delete. Bei einem typischen Logbuch (Hunderte TGs, nicht Millionen) ist das auf moderner Hardware unmessbar. Bei einer hypothetischen Bulk-Operation (Import von externem Logbook) wird der Renumber einmal am Ende der Bulk-Operation ausgelöst, nicht pro Datensatz.

**Tests:**
- `NumberingTests.empty_logbook_starts_at_profile_offset()`
- `NumberingTests.appended_dive_in_past_renumbers_correctly()`
- `NumberingTests.deleted_dive_renumbers_remaining()`
- `NumberingTests.changing_starting_number_renumbers_all()`
- `NumberingTests.parallel_inserts_converge_after_save()` (zweiter Context simuliert Sync)

**Definition of Done:** Logbook zeigt fortlaufende Nummern in Datum-Reihenfolge, auch nach Nachträgen und Löschen. Sample-Daten in `SampleData.swift` werden auf die neue Logik angepasst.

### Phase 2c — Foto-Sync (CloudKit-Asset + Disk-Cache)

**Refactor von `PhotoStore`:**

- `PhotoStore.save(image:toDive:context:)` schreibt **nur noch** ins `DivePhoto.imageData` und cached parallel auf Disk. Disk ist optional, kein Datenverlust wenn weg.
- `PhotoStore.load(filename:from:)` liest Disk zuerst, fällt auf `imageData` zurück, schreibt fehlende Bilder in den Disk-Cache zurück.
- Neue Funktion `PhotoStore.evictDiskCache(olderThan:)` für künftige Aufräum-Schritte.

**Model-Änderungen:**

- `DivePhoto.@Relationship var dive: Dive?` → `@Relationship(inverse: \Dive.photos) var dive: Dive?`.
- `Dive.photoFilenames: [String]` bleibt im Schema (CloudKit-Migration verlangt das), wird aber als `@available(*, deprecated)` markiert und nicht mehr gelesen, nur noch geschrieben für Rückwärtskompatibilität (entfernt in einer späteren Schema-Version).

**Migration:**

Beim ersten App-Start nach Update:
- Pro Tauchgang `migrateLocalPhotosToCloudKit(dive:context:)` erweitern: für jedes `filename` in `dive.photoFilenames`, das noch keinen `DivePhoto`-Record hat, lade Disk-Datei und erzeuge Record.
- Idempotent — erkennt bereits migrierte Bilder am `filename`-Match.

**UI:**

- `DivePhotoComponents`-Galerie zeigt Sync-Status pro Bild: `cloud.fill` wenn synced, `cloud.upload` wenn pending, `exclamationmark.cloud` wenn Fehler. Status wird aus `record.persistentModelID`-Status abgeleitet (SwiftData hat einen Sync-State über NSPersistentCloudKitContainer-Notifications).

**Tests:**
- `PhotoStoreTests.save_creates_record_and_disk_cache()`
- `PhotoStoreTests.load_falls_back_to_record_when_disk_missing()`
- `PhotoStoreTests.migration_creates_records_for_legacy_filenames()`
- `PhotoStoreTests.migration_is_idempotent()`

**Definition of Done:** Foto auf Gerät A → erscheint binnen Sync-Latenz auf Gerät B. Disk-Cache leeren → Bild rendert weiterhin (lädt aus Record). Legacy-Tauchgang mit nur `photoFilenames` → wird automatisch migriert.

## Phase 3 — Skill-Assessment QA + ProfileTab-Refactor

**Ziel:** Die 40-Commits-Arbeit am Instructor-Layer einmal real durchstressen. Zwei Spuren:

**3a — Manueller QA-Pass.** Mit echten Daten (oder Sample) durchgehen:

- Neuen Schüler anlegen → seeden via `PriorMasterySeedSheet` → in einer Pool-Session Skills cyclen → in Dive 1 OWD anwenden → `StudentProfileView` prüft Per-Slot-Fortschritt korrekt → CloudKit-Sync auf zweitem Gerät kommt sauber an → PDF-Export aus `Sign`-Tab funktioniert mit den Skills.
- Edge-Cases sammeln: leere Schüler-Liste in DiveFormView, Schüler ohne Pool-Session, Skill ohne Status, Multi-Sprache (DE↔EN switchen während Assessment offen ist).

Gefundene Bugs werden als Sub-Issues in dieser Phase abgearbeitet. Aufwand ist *unbekannt* — könnte 2 Stunden sein, könnte ein Tag sein.

**3b — `ProfileTab.swift` zerlegen.** Aktuell ~870 LoC, nach Brainstorming-Skill-Prinzip „smaller, well-bounded units":

- Extract: `ProfileHeaderView`, `ProfileStatsRow`, `ProfileQuickActionsList`, `ProfileLogbookSection`, `ProfileSettingsSection`, `ProfileSignOutButton`.
- Top-Level `ProfileTab` wird zur Komposition (~150 LoC).
- Verhaltensneutraler Refactor; bestehende Tests müssen weiter grün laufen.

**Definition of Done:** Skill-Assessment-Pfad einmal vollständig durchgespielt + Bug-Liste abgearbeitet; `ProfileTab` < 200 LoC, Sub-Komponenten getestet wo sinnvoll.

## Phase 4 — Paywall fertig + Release-Ready

**4a — Pro-Gating-Coverage-Audit.** Aktuell sind nur Sign-Tab und Course-Training in DiveFormView gegated. Zu entscheiden (im Plan-Schritt, nicht hier im Spec): wo verläuft die Free/Pro-Trennlinie wirklich?

Vorschlag (zur Diskussion im Implementation-Plan):
- **Free:** Logbook, Journal, Stats, Profile, Foto-Sync, Wetter-Auto-Fill — also „mein eigenes Logbuch führen".
- **Pro:** Sign-Tab (Buddy-Signaturen, Remote-Signature), Course-Training-Toggle, Schüler-Verwaltung, Pool-Sessions, Skill-Assessment, Student-PDF-Export.

**4b — Onboarding-Touchpoint.** Nicht-Pro-User soll im Onboarding einen Hauch von dem sehen, was Pro kann (Screenshot-Carousel, „Du bist Instructor? Zeig's deinen Schülern"). Direktverlink in Paywall.

**4c — App Store Connect.**
- IAP-Produkt `com.weckherlin.DiveLogPro.instructorPro` anlegen, Beschreibung DE/EN, Pricing.
- Review-Notes mit Test-Account vorbereiten.
- App-Store-Eintrag: Beschreibung, Keywords, Screenshots in DE+EN für iPhone (6.7"+6.1"), Screenshots für Pro-Features mit „Pro"-Badge.
- Privacy-Manifest + Tracking-Disclosure (CloudKit, WeatherKit, StoreKit).

**4d — TestFlight.**
- Build-Number-Hochzählen, Archive, Upload.
- Internal-Tester einladen.
- StoreKit-Sandbox-Account dokumentieren.

**Definition of Done:** TestFlight-Build live, mindestens ein externer Tester kann durchspielen (Skill-Assessment + Paywall-Flow + Foto-Sync zwischen zwei Geräten), keine bekannten Bugs aus den drei Bug-Klassen.

## Risiken und offene Punkte

- **CloudKit-Schema-Migration:** Phase 2c berührt das Schema (neuer Inverse). SwiftData migriert sanft, aber wir testen mit echten Daten am Gerät, nicht nur im Simulator.
- **WeatherKit-Capability:** Falls die Aktivierung im Developer-Portal länger braucht (Apple-Side-Latenz), bleibt Phase 2a länger offen — kein Blocker für den Rest.
- **Pro-Gating-Linie:** In Phase 4a ist die finale Free/Pro-Trennung noch nicht entschieden. Der Implementation-Plan greift den Vorschlag oben auf und stellt eine konkrete Frage.
- **Photo-Migration auf bestehendem Logbuch:** Falls jemand bereits 1000+ Fotos hat, läuft die Migration beim ersten Start. Wir müssen sie idempotent + im Background ausführen, mit Progress-UI.

## Was nicht in diesem Spec ist

Bewusst nicht enthalten, kommt in eigene Specs falls relevant:

- Apple-Watch-Companion.
- iPad-Optimierung über reine SwiftUI-Adaption hinaus.
- Tauchcomputer-Import (Suunto, Shearwater).
- Mehr-Sprachen-Support jenseits DE/EN.

## Skalierung

Wenn sich beim Implementation-Plan herausstellt, dass eine Phase (insbesondere Phase 2c oder Phase 4) zu groß für einen Plan-Durchgang wird, wird sie in einen eigenen Spec ausgelagert und der Master-Plan referenziert sie. Phasen 1–2 sind klar genug für einen Plan; Phasen 3–4 können bei Bedarf gesplittet werden.

## Nächster Schritt

Nach User-Review dieses Specs: Übergang in die `superpowers:writing-plans`-Skill für einen Implementation-Plan, der die vier Phasen in Tasks zerlegt.
