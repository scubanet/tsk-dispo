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
| 2.1 | Sign-In + leeres Logbuch | | |
| 2.2 | Schüler anlegen via StudentPicker → NewStudentSheet | | |
| 2.3 | Prior Mastery seeden via PriorMasterySeedSheet | | |
| 2.4 | Pool-Session anlegen (Slot CW1, OWD) | | |
| 2.5 | Skills im Pool cyclen (notStarted → introduced → practiced → mastered) | | |
| 2.6 | OWD-Dive anlegen mit Course-Training=ON, Schüler wählen | | |
| 2.7 | DiveDetail Schüler-Section sichtbar mit Skill-Grid | | |
| 2.8 | Im DiveDetail Skills cyclen (append-only Records) | | |
| 2.9 | StudentProfileView Per-Slot-Fortschritt korrekt | | |
| 2.10 | Sync auf iPad (~30-60s warten) | | |
| 2.11 | Buddy-Signature für den Dive | | |
| 2.12 | PDF-Export mit Schüler+Skill-Daten | | |

---

## Spur B — Edge Cases

| # | Schritt | Status | Notiz |
|---|---------|--------|-------|
| 3.1 | DiveFormView mit leerer Schüler-Liste | | |
| 3.2 | Schüler ohne Pool-Session direkt im OWD-Dive | | |
| 3.3 | notStarted-Badge-Rendering klar erkennbar | | |
| 3.4 | Multi-Sprache-Wechsel (DE↔EN) mid-flow | | |
| 3.5 | 10 Schüler in einer Pool-Session — Performance + UX | | |
| 3.6 | Dive löschen mit angehängten SkillCompletion-Records | | |
| 3.7 | Schüler löschen via StudentEditSheet destructive delete | | |

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
| | | | | |

**Severity-Definition:**
- **Critical** — App-Crash, Datenverlust, falsche Skill-Status-Anzeige, CloudKit-Duplikate/Verlust, PDF-Export schlägt fehl. Muss vor Phase 4 gefixt sein.
- **Important** — UX-Friction die einen realen Use-Case spürbar verschlechtert (unklare Empty-States, Loading-Indikatoren fehlen, Lokalisierungs-Lücken in zentralen Views).
- **Minor** — Polish, kosmetische Inkonsistenzen, unwahrscheinliche Edge-Cases.

**Stop-Bedingung:** Wenn die Triage >5 Critical+Important Bugs zeigt, Plan stoppen und Status mit User abstimmen.

---

## Minor-Findings (Follow-up)

(Werden nach Triage in `docs/operational/follow-ups-stabilize-2026-05-09.md` als Sektion „Phase-3 Minor-Findings" übernommen.)
