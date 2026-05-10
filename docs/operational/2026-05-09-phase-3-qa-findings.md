# Phase 3 QA Findings — 2026-05-09

**Setup:**
- iPhone 16 Pro Max + iPad
- iCloud-Account: weckherlin@icloud.com
- Beide Geräte auf HEAD `e4fa4e4` der `feat/phase-3-qa-and-profiletab`-Branch
- Beide Geräte zeigen denselben Logbuch-Stand bei Test-Beginn

---

## Spur A — Happy Path

| # | Schritt | Status | Notiz |
|---|---------|--------|-------|
| 2.1 | Setup leeres/echtes Logbuch | ✅ | 9 echte Dives, Test-Entitäten on-top |
| 2.2 | Schüler anlegen via StudentPicker → NewStudentSheet | ✅ | Max Mustermann via QuickLog → Course-Training-Block |
| 2.3 | Prior Mastery seeden via PriorMasterySeedSheet | ⏭️ skipped | Trigger nicht offensichtlich auffindbar; nicht-blocking für die übrigen Schritte |
| 2.4 | Pool-Session anlegen (Slot CW1, OWD) | ✅ | Pool angelegt, im Logbuch sichtbar |
| 2.5 | Skills im Pool cyclen | 🐛 blocked | siehe Bug #1 — CW-Catalog leer |
| 2.6 | OWD-Dive anlegen mit Course-Training=ON, Schüler wählen | ✅ | Test-Dive #8'767 |
| 2.7 | DiveDetail Schüler-Section sichtbar mit Skill-Grid | ✅ | 13 OW1-Skills + 9 Flexible Skills |
| 2.8 | Im DiveDetail Skills cyclen (append-only Records) | ✅ | Tap-Cycle, Long-Press, Swipe-Reset funktionieren |
| 2.9 | StudentProfileView Per-Slot-Fortschritt korrekt | ✅ | Per-Slot-Counter aktualisiert sich |
| 2.10 | Sync auf iPad (~30-60s warten) | ✅ | Schüler + Dive + Skills syncen, Latenz <60s |
| 2.11 | Buddy-Signature für den Dive | ✅ | Sign-Tab → Buddy-Signatur funktioniert (Architektur: kein separates Schüler-Signoff, Audit-Trail über SkillCompletion-Records reicht) |
| 2.12 | PDF-Export mit Schüler+Skill-Daten | ✅ | Profile-Tab → Export, Multi-Select-fähig (1, mehrere, alle TGs), PDF + CSV |

**Bonus-Findings (positiv):**
- Tauchgangs-Renumbering läuft live (#8'767 nach #8'766) — Phase 2b ist in Production aktiv.
- Foto-Sync funktioniert (Phase 2c-Vorarbeit + record-first-save).
- Bulk-Actions „Alle auf mastered" / „Offene auf introduced" im Skill-Grid sind ergonomisch.
- CloudKit-Sync ist zuverlässig im Sub-Minuten-Bereich.

---

## Spur B — Edge Cases

| # | Schritt | Status | Notiz |
|---|---------|--------|-------|
| 3.1 | DiveFormView mit leerer Schüler-Liste | 🐛 | Speichern geht ohne Schüler durch — siehe Bug #6 |
| 3.2 | Schüler ohne Pool-Session direkt im OWD-Dive | ✅ | implizit getestet via Spur A — funktioniert |
| 3.3 | notStarted-Badge-Rendering klar erkennbar | ✅ | implizit getestet via Skill-Cycle — Badge ist klar |
| 3.4 | Multi-Sprache-Wechsel (DE↔EN) mid-flow | 🐛 | mid-flow inkonsistent, App-Restart liefert sauberen Stand — siehe Bug #7 |
| 3.5 | 10 Schüler in einer Pool-Session — Performance + UX | ⏭️ skipped | Setup-Aufwand vs. Risiko zu hoch; nachholbar bei späterem Stress-Test |
| 3.6 | Dive löschen mit angehängten SkillCompletion-Records | ✅ | Cascade-Verhalten akzeptabel |
| 3.7 | Schüler löschen via StudentEditSheet destructive delete | ✅ | funktioniert über StudentProfileView → Edit. UX-Friction siehe Bug #8 |

---

## Spur C — Sync-Stress

| # | Schritt | Status | Notiz |
|---|---------|--------|-------|
| 4.1 | Konkurrente Skill-Cycles auf iPhone + iPad (Flugzeugmodus → Online) | | |
| 4.2 | Konkurrentes Schüler-Anlegen mit gleichem Namen auf beiden Geräten | | |

---

## Triage-Liste

| # | Severity | Beschreibung | Repro | Fix-Status |
|---|----------|--------------|-------|------------|
| 1 | Important | **CW-Catalog ist leer.** Pool-Skills (CW1-CW5) sind nicht im PADI-Catalog gepflegt — Pool-Detail zeigt nur „CW1.1 — TBD" als Platzhalter. Zusätzlich fällt der Flexible-Skills-Bereich auf Open-Water-Flex-Skills zurück, weil keine CW-spezifischen Flex-Skills definiert sind. Der gesamte IDC/Pool-Workflow ist damit unbrauchbar. | Logbook → FAB → Pool-Session anlegen → CW1, OWD, Schüler → speichern → Pool öffnen → nur ein TBD-Skill sichtbar | offen |
| 2 | Minor | **Sign-Tab nicht hinter Pro-Gate.** ProTeaser sollte erscheinen für nicht-Pro-User; stattdessen wird der Sign-Tab-Inhalt direkt gerendert. Phase-4-Coverage-Audit greift das auf. | Sandbox-Build mit isPro=false → Sign-Tab → Tauchgangsliste statt ProTeaser sichtbar | offen / verschoben in Phase 4 |
| 3 | Minor | **Tauchgangstyp + Kurs-Tauchgang nicht exklusiv.** „Fun Dive" + „Kurs-Tauchgang"-Toggle gleichzeitig möglich. Semantisch evtl. OK (Spass-Tauchgang ist gleichzeitig Trainings-Tauchgang), UI klärt das nicht. | QuickLogView → Tauchgangstyp Fun Dive → Kurs-Tauchgang Toggle ON → beides ist gleichzeitig aktiv | offen |
| 4 | Minor | **Per-Dive-PDF-Export aus DiveDetail fehlt.** „..."-Menu im DiveDetail hat nur „TG löschen". Bulk-Export aus Profile-Tab → Datenverwaltung deckt den Use-Case ab (Multi-Select 1/mehrere/alle), aber direkter Export aus dem Tauchgang wäre ergonomisch. | DiveDetail öffnen → ... Menu → nur „TG löschen" | offen, polish |
| 5 | Minor | **Prior-Mastery-Trigger ist nicht offensichtlich.** PriorMasterySeedSheet existiert im Code, aber im UI-Walkthrough nicht über StudentPicker oder StudentProfileView direkt erkennbar. | Schüler anlegen → kein Button „Prior Mastery seeden" auffindbar | offen, UX-Polish oder Doku |
| 6 | Important | **Course-Training=ON + leere Schüler-Liste speichert ohne Validation.** Tauchgang wird mit Course-Training-Markierung gespeichert auch ohne Schüler — sinnlos für den IDC-Use-Case, kein Crash aber Datenmüll. Fix: Validation oder automatischer Toggle-Reset wenn keine Schüler. | DiveFormView → Course-Training ON → Slot wählen → keine Schüler → Speichern geht durch | offen |
| 7 | Important | **Sprachwechsel mid-flow ist inkonsistent.** L10n-Strings wechseln sofort (Profile, Progress, Not started, etc.), aber Tab-Bar und PADI-Catalog-Strings (Slot-Namen, Skill-Namen) bleiben in alter Sprache stehen. Nach App-Restart ist alles konsistent. Fix: PADI-Catalog-Reload bei Language-Change-Notification + Restart-Hinweis für iOS-native Strings. | App in DE → iOS-Settings → Language EN → zurück zur App → halb-EN halb-DE | offen |
| 8 | Minor | **Plural-Handling fehlt** — „1 students" statt „1 student". Mehrere Stellen vermutlich betroffen. Fix: stringsdict-Templates oder String-Catalog mit Plural-Variants. | DiveDetail mit 1 Schüler → "1 students" sichtbar | offen |
| 9 | Minor | **StudentEditSheet-Trigger nur via Edit-Button in StudentProfileView.** Im StudentPicker direkt fehlt Long-Press oder Swipe-Edit. User muss erst zur ProfileView navigieren um zu editieren/löschen. UX-Friction. | StudentPicker → Long-Press auf Schüler-Bubble → kein Trigger | offen |

**Severity-Definition:**
- **Critical** — App-Crash, Datenverlust, falsche Skill-Status-Anzeige, CloudKit-Duplikate/Verlust, PDF-Export schlägt fehl. Muss vor Phase 4 gefixt sein.
- **Important** — UX-Friction die einen realen Use-Case spürbar verschlechtert (unklare Empty-States, Loading-Indikatoren fehlen, Lokalisierungs-Lücken in zentralen Views).
- **Minor** — Polish, kosmetische Inkonsistenzen, unwahrscheinliche Edge-Cases.

**Stop-Bedingung:** Wenn die Triage >5 Critical+Important Bugs zeigt, Plan stoppen und Status mit User abstimmen.

---

## Minor-Findings (Follow-up)

(Werden nach Triage in `docs/operational/follow-ups-stabilize-2026-05-09.md` als Sektion „Phase-3 Minor-Findings" übernommen.)
