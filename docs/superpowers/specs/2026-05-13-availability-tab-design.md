# AvailabilityTab — Dispatcher-Sicht auf TL/DM-Verfügbarkeit

**Status:** Draft (User-Review pending)
**Date:** 2026-05-13
**Author:** Dominik Weckherlin (with Claude)
**Spec Owner:** Dominik
**Target Release:** v1.1 (vor Soft-Live)

---

## 1. Kontext & Problem

### Heutiger Zustand

- TL/DM können Verfügbarkeit (`urlaub` / `abwesend` / `verfügbar`) im
  `MyProfileScreen` selber eintragen — Add + Delete funktionieren über die
  `availability`-Tabelle (Migration `0008`). Kinds-Enum aus Migration `0001`.
- Im Dispatcher-Kontakt-Detail existiert ein `AvailabilityTab.tsx`, der aber
  nur ein `tab-stub`-Placeholder ist (siehe Tab-Registrierung in
  `ContactDetailPanel.tsx`, Tab nur sichtbar für Kontakte mit Rolle
  `instructor`).
- Der Dispatcher hat damit aktuell **keinen Einblick**, wer wann verfügbar
  oder abwesend ist — außer er fragt jede Person einzeln.

### Pain-Point

1. WhatsApp-Meldungen wie „Bin nächste Woche weg" landen nirgends im System,
   wenn der Instructor sie nicht selber einträgt.
2. Beim Kurs-Planen muss der Dispatcher trotz vorhandener Daten erraten, ob
   eine Person frei ist. Die Information ist da, aber unsichtbar im
   Dispatcher-Workflow.
3. Das Demo-Skript verspricht Verfügbarkeits-Eintragung als Höhepunkt der
   TL/DM-Sicht (Pitch §6). Ohne Dispatcher-Gegenstück bleibt der Mehrwert
   einseitig — TL/DM trägt ein, aber niemand schaut hin.

### Was diese Etappe NICHT löst

- Keine Konflikt-Erkennung beim Kurs-Zuweisen (= Etappe 3, eigener Spec)
- Keine globale Wer-ist-wann-da-Matrix (= Etappe 4, post-Pitch)
- Kein Edit (Delete + Re-Insert ist Konsistenz-Linie)
- Keine wiederkehrenden Einträge

## 2. Scope dieser Etappe (1 + 2 zusammen)

**Etappe 1 — Dispatcher-View:** `AvailabilityTab` zeigt alle Einträge einer
Instructor-Person, gruppiert nach Status.

**Etappe 2 — Stellvertretend eintragen:** Plus-Button im Tab öffnet die
bestehende Add-Sheet mit der Instructor-ID des aktuellen Kontakts. Dispatcher
kann auch löschen (Vollrechte, kein Audit-Trail).

## 3. Komponenten-Architektur

### Shared-Komponenten ausziehen

`MyProfileScreen.tsx` enthält heute `AvailabilityRowView` und
`AvailabilityAddSheet` als interne Funktionen. Diese werden in ein gemeinsames
Modul gehoben:

```
apps/web/src/components/availability/
  ├─ AvailabilityRow.tsx        (ehem. AvailabilityRowView)
  └─ AvailabilityAddSheet.tsx
```

Beide nehmen `instructorId: string` als Prop. `MyProfileScreen` und
`AvailabilityTab` importieren aus dem gemeinsamen Modul — kein Duplikat, kein
Divergenz-Risiko.

### Daten-Layer

`fetchMyAvailability(instructorId)` in `lib/queries.ts` wird umbenannt zu
`fetchAvailability(instructorId)`. Funktional unverändert. Aufrufer im
`MyProfileScreen` werden mit-migriert. Insert/Delete bleiben Inline-Supabase-
Calls in den Shared-Komponenten.

### AvailabilityTab — Aufbau

```
┌─ Header ──────────────────────────────────────────────────────┐
│  Verfügbarkeit                              [ + Eintrag ]     │
├─ Aktuell (n) ─────────────────────────────────────────────────┤
│  [Badge: Urlaub]  10.–17.05.2026                         [×]  │
│    Notiz: Familienurlaub Spanien                              │
├─ Zukünftig (n) ───────────────────────────────────────────────┤
│  [Badge: Abwesend]  03.–05.06.2026                       [×]  │
├─ Vergangen (n) ▸ ─────────────────────────────────────────────┤
│  (eingeklappt)                                                │
└───────────────────────────────────────────────────────────────┘
```

Wenn alle drei Sektionen leer: zentrierter Empty-State mit Hinweis und
Plus-Button.

## 4. Gruppierungs-Logik

Im Frontend, kein DB-seitiges Re-Query nötig:

- **Aktuell:** `from_date <= today AND today <= to_date`. Sortierung
  `from_date ASC`.
- **Zukünftig:** `from_date > today`. Sortierung `from_date ASC`.
- **Vergangen:** `to_date < today`. Sortierung `from_date DESC`. Default
  eingeklappt, Toggle „Vergangene anzeigen (n)" oben rechts in der Section-
  Header-Zeile.

`today` als lokales Datum (browser-Zeitzone) — keine UTC-Anomalien für
Demo-Szenarien in CH.

## 5. UI-Details

- **Kind-Badge** farbcodiert: `urlaub` gelb, `abwesend` rot, `verfügbar`
  grün. Wenn passende Tokens (`--badge-warn`, `--badge-danger`, `--badge-ok`)
  schon existieren — verwenden. Sonst neutral mit Text-Label und in einer
  Folge-Etappe nachschärfen.
- **Zeitraum-Format:** `DD.MM. – DD.MM.YYYY`. Wenn `from_date === to_date`:
  nur ein Datum. Wenn Jahr-Übergang: `DD.MM.YYYY – DD.MM.YYYY`.
- **Notiz:** inline unterhalb des Datums in Caption-Größe. Wenn leer: keine
  zweite Zeile.
- **Delete-Icon:** rechts in der Zeile, mit `confirm`-Dialog wie heute im
  MyProfileScreen.
- **Kein Edit:** Konsistenz-Linie mit MyProfileScreen. Falsch eingetragene
  Zeile = löschen + neu anlegen.

## 6. i18n

Neue Keys unter `contacts.availability.*` in `de.json` und `en.json`:

| Key                | de                              | en                          |
|--------------------|---------------------------------|-----------------------------|
| `section_current`  | Aktuell                         | Current                     |
| `section_future`   | Zukünftig                       | Upcoming                    |
| `section_past`     | Vergangen                       | Past                        |
| `show_past`        | Vergangene anzeigen ({{n}})     | Show past ({{n}})           |
| `hide_past`        | Vergangene ausblenden           | Hide past                   |
| `empty_state`      | Keine Verfügbarkeit eingetragen | No availability entered yet |
| `add_button`       | + Eintrag                       | + Entry                     |

Die Sheet- und Row-i18n-Keys bleiben unter `my_profile.*` — die Komponenten
werden geteilt, der Key-Namespace bleibt zur Diff-Minimierung in der
bisherigen Form. Bei späterer Aufräum-Runde umgeziehen.

## 7. Sichtbarkeit & Rechte

- Tab ist bereits in `ContactDetailPanel.tsx` (Zeile 80) nur für Kontakte mit
  Rolle `instructor` registriert — keine Änderung nötig.
- Vollrechte für Dispatcher: kann alle Einträge der Person löschen und neue
  anlegen. Keine `created_by`-Spalte, kein Audit-Trail in dieser Etappe.
  Vertrauensbasiertes Modell: Dispatcher korrigiert WhatsApp-gemeldete oder
  falsch eingetragene Zeilen statt Instructor neu zu kontaktieren.

## 8. Risiken & Prüfpunkte vor Implementierung

1. **`contactId === instructors.id`-Annahme:** Phase J 2c hat die FK-Targets
   retargeted, das sollte gelten. Vor Start eine Test-Query gegen Production:
   `SELECT i.id, c.id FROM instructors i JOIN contacts c ON c.id = i.id
   LIMIT 5` — bestätigt 1:1-Beziehung. (Memory-Feedback: Schema-Annahmen
   immer gegen Production verifizieren.)
2. **RLS-Policies:** Migration `0017_rls_policies.sql` prüfen, ob Dispatcher
   Schreibrechte auf `availability` hat. Falls nicht: kleine Folge-Migration
   für Insert+Delete-Policy für Rolle `dispatcher`.
3. **Sync-Trigger-Drift (10.05.-Gotcha):** Vor Etappen-Start mit der Memory-
   Notiz abgleichen, ob seit 10.05. neue Drifts zwischen Legacy und
   Sidecars entstanden sind. Für AvailabilityTab nicht direkt relevant
   (`availability` referenziert `instructors`, nicht `contacts`), aber zur
   Sicherheit.

## 9. Akzeptanzkriterien

- [ ] AvailabilityTab im Kontakt-Detail einer Instructor-Person zeigt alle
      Einträge, gruppiert in drei Sektionen.
- [ ] Dispatcher kann via Plus-Button einen neuen Eintrag anlegen — Sheet
      öffnet, Speichern legt in `availability` an, Liste refresht.
- [ ] Dispatcher kann jeden Eintrag löschen, unabhängig davon wer ihn angelegt
      hat. Confirm-Dialog vor Delete.
- [ ] MyProfileScreen funktioniert nach Komponenten-Auszug identisch wie
      vorher (keine Regression — vor Cutover manuell durchklicken).
- [ ] Vergangene Einträge sind default eingeklappt, mit Toggle umschaltbar.
- [ ] Leerer Tab zeigt sinnvollen Empty-State mit direkter Eintrag-Möglichkeit.
- [ ] i18n: alle Strings haben `de` und `en` Keys, kein Hardcoded-Text.

## 10. Out of Scope (für später)

- Konflikt-Erkennung beim Kurs-Zuweisen → Etappe 3, eigener Spec
- Globale Wer-ist-wann-da-Matrix → Etappe 4, post-Pitch
- Edit-Funktion auf bestehende Einträge
- Wiederkehrende Verfügbarkeit („Jeden Donnerstag ab 18:00")
- `created_by`-Audit-Spalte
- Email-/Notification-Trigger bei stellvertretender Eintragung
