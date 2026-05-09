# Contacts-Migration Runbook — ATOLL Adressverwaltung

**Status:** Phase A–I abgeschlossen. Phase J (Legacy-Cleanup) ausstehend.
**Datum:** 2026-05-09
**Autor:** Dominik Weckherlin (mit Claude)

---

## Kontext

Diese Migration konsolidiert die drei getrennten Adress-Tabellen (`instructors`, `people`, `organizations`) in ein einheitliches CRM-Modell: eine zentrale `contacts`-Tabelle mit rollenbasierten Sidecars (`contact_instructor`, `contact_student`, `contact_organization`), n:m-Beziehungen (`contact_relationships`) und einem vollständigen Audit-Log (`contact_audit_log`). Der neue Einstiegspunkt für Benutzer ist das Adressbuch unter `/contacts` mit universellen `ContactDetailPanel` und adaptiven Tabs.

Vollständige Architektur-Dokumentation:
- **Spec:** `docs/superpowers/specs/2026-05-09-adressverwaltung-design.md`
- **Plan:** `docs/superpowers/plans/2026-05-09-adressverwaltung.md`

---

## Pre-flight Checklist

Bevor irgendeine Migration in Produktion läuft:

- [ ] **PITR-Backup verifiziert** — in Supabase Dashboard unter *Project Settings → Database → Backups* sicherstellen, dass ein aktuelles Point-in-Time-Recovery-Backup existiert. Backup-Zeitstempel notieren.
- [ ] **Dedup-Audit Query ausführen** — potenzielle Duplikate identifizieren, bevor Backfill läuft:

```sql
-- Dedup-Audit: Personen mit identischer E-Mail (Legacy-Tabellen)
SELECT
  'people' AS source,
  p1.id       AS id_a,
  p2.id       AS id_b,
  p1.email    AS email,
  p1.first_name || ' ' || p1.last_name AS name_a,
  p2.first_name || ' ' || p2.last_name AS name_b
FROM people p1
JOIN people p2
  ON lower(p1.email) = lower(p2.email)
  AND p1.id < p2.id
  AND p1.email IS NOT NULL

UNION ALL

-- Instructor ↔ Person Crossover (gleiche E-Mail in beiden Tabellen)
SELECT
  'cross_instructor_person' AS source,
  i.id       AS id_a,
  p.id       AS id_b,
  i.email    AS email,
  i.first_name || ' ' || i.last_name AS name_a,
  p.first_name || ' ' || p.last_name AS name_b
FROM instructors i
JOIN people p
  ON lower(i.email) = lower(p.email)
  AND i.email IS NOT NULL

ORDER BY source, email;
```

- [ ] CSV der Duplikate exportieren (via Supabase Studio → *SQL Editor → Export*)
- [ ] Duplikate manuell prüfen und entscheiden, welche Paare gemerged werden sollen (nach Phase A–I, via `merge_contacts` RPC oder UI)

---

## Phase-by-Phase Rollout

### Phase A — Schema (Migration M1, additiv)

**Migration:** `supabase/migrations/0079_contacts_schema.sql`

Was sie tut:
- Erstellt Enums `contact_kind`, `relationship_kind`
- Erstellt Haupttabelle `contacts` mit GENERATED `display_name`, JSONB-Feldern (`emails`, `phones`, `addresses`), `roles TEXT[]`, `tags TEXT[]`, Timestamps
- Erstellt Sidecar-Tabellen `contact_instructor`, `contact_student`, `contact_organization`
- Erstellt `contact_relationships` (n:m), `contact_audit_log`
- Alle Indexes und FK-Constraints

**Supabase Studio:** keine manuelle Aktion — reine Schema-Migration.

**Smoke-Test:**
```sql
SELECT count(*) FROM contacts;                    -- erwartet: 0
SELECT count(*) FROM contact_audit_log;           -- erwartet: 0
SELECT column_name FROM information_schema.columns
  WHERE table_name = 'contacts' ORDER BY ordinal_position;
```

**Geschätzte Zeit:** 5–10 Sekunden (DDL-only)

---

### Phase B — Triggers (Migration M2)

**Migration:** `supabase/migrations/0080_contacts_triggers.sql`

Was sie tut:
- `set_updated_at`-Trigger auf alle Contact-Tabellen
- `audit_contact_changes()`-Funktion + Trigger: loggt INSERT/UPDATE/DELETE auf `contacts` und Sidecars → `contact_audit_log`
- `sync_role_from_sidecar()`-Trigger: hält `contacts.roles[]` synchron mit Sidecar-Existenz

**Supabase Studio:** keine manuelle Aktion.

**Smoke-Test:**
```sql
INSERT INTO contacts (kind, first_name, last_name, primary_email, roles)
  VALUES ('person', 'Smoke', 'Test', 'smoke@test.local', '{}')
  RETURNING id;

-- Mit der zurückgegebenen UUID:
SELECT changed_at, operation FROM contact_audit_log
  WHERE contact_id = '<uuid>' ORDER BY changed_at DESC LIMIT 1;
-- erwartet: 1 Zeile, operation = 'INSERT'

DELETE FROM contacts WHERE primary_email = 'smoke@test.local';
```

**Geschätzte Zeit:** 5–10 Sekunden

---

### Phase C — RPCs (Migration M3)

**Migration:** `supabase/migrations/0081_contacts_rpcs.sql`

Was sie tut:
- `find_potential_duplicates(p_contact_id)` — sucht Duplikate per E-Mail, Telefon, Name+Geburtsdatum
- `merge_contacts(p_winner, p_loser)` — rebiindet alle FKs, archiviert den Loser, kombiniert Rollen
- `gdpr_anonymize_contact(p_contact_id)` — ersetzt PII durch Platzhalter, behält ID + Audit-History

**Bekanntes Problem:** `merge_contacts` referenziert `person_id` auf `course_participants`, `intake_checklists` und `communication_entries`. Die tatsächlichen Spalten in der DB heissen für einige Tabellen `student_id` (Legacy von Migration 0027/0069). Die RPC läuft ohne Fehler, weil `person_id` in `communication_entries`/`course_participants` durch Migration 0082 Backfill-Kompatibilität hergestellt wird — aber `intake_checklists` und `elearning_progress` haben weiterhin `student_id`. Patch vor der ersten Produktions-Merge-Operation (siehe *Known Issues* unten).

**Supabase Studio:** keine manuelle Aktion.

**Smoke-Test:**
```sql
SELECT proname FROM pg_proc
  WHERE proname IN ('find_potential_duplicates','merge_contacts','gdpr_anonymize_contact');
-- erwartet: 3 Zeilen
```

**Geschätzte Zeit:** 5–15 Sekunden

---

### Phase D — Backfill (Migration M4)

**Migration:** `supabase/migrations/0082_contacts_backfill.sql`

Was sie tut:
- Kopiert `instructors` → `contacts` (kind=person, roles inkl. app_role) + `contact_instructor`-Sidecars
- Kopiert `people` → `contacts` (kind=person, roles aus `is_student`/`is_candidate`) + `contact_student`-Sidecars
- Kopiert `organizations` → `contacts` (kind=organization) + `contact_organization`-Sidecars
- Kopiert `organization_members` → `contact_relationships` (works_at)
- Smoke-Count am Schluss der Migration

**Wichtig:** Die Migration deaktiviert role-sync-Trigger temporär und reaktiviert sie am Ende. In Produktion sicherstellen, dass kein Concurrent-Write läuft (Wartungsfenster empfohlen).

**Supabase Studio:**
```sql
-- Vor der Migration (Erwartungswerte erfassen):
SELECT count(*) FROM instructors;    -- z.B. 12
SELECT count(*) FROM people;         -- z.B. 340
SELECT count(*) FROM organizations;  -- z.B. 25

-- Nach der Migration prüfen:
SELECT source, count(*) FROM contacts GROUP BY source;
-- erwartet: legacy_migration = 377 (Summe obiger)
```

**Smoke-Test:**
```sql
SELECT count(*) FROM contacts WHERE source = 'legacy_migration';
SELECT count(*) FROM contact_instructor;
SELECT count(*) FROM contact_student;
SELECT count(*) FROM contact_organization;
```

**Geschätzte Zeit:** 30 Sekunden – 3 Minuten (abhängig von Datenmenge)

---

### Phase E — Sync-Trigger (Migration M5)

**Migration:** `supabase/migrations/0083_contacts_sync_triggers.sql`

Was sie tut:
- Erstellt bidirektionale Sync-Trigger: Änderungen an Legacy-Tabellen (`instructors`, `people`, `organizations`) werden auf `contacts`/Sidecars gespiegelt
- Erstellt `UNIQUE INDEX uniq_works_at` auf `contact_relationships` für `works_at`-Beziehungen
- Ermöglicht den alten Code weiterzulaufen, während das Frontend schrittweise umgestellt wird (Phase M2)

**Supabase Studio:** keine manuelle Aktion.

**Smoke-Test:**
```sql
-- Einen Instructor in der Legacy-Tabelle aktualisieren:
UPDATE instructors SET first_name = 'SyncTest' WHERE id = (SELECT id FROM instructors LIMIT 1)
  RETURNING id;
-- Dann in contacts prüfen:
SELECT first_name FROM contacts WHERE id = '<uuid>';
-- erwartet: 'SyncTest'
-- Rückgängig machen!
UPDATE instructors SET first_name = '<ursprünglicher Name>' WHERE id = '<uuid>';
```

**Geschätzte Zeit:** 5–10 Sekunden

---

### Phase F — RLS (Migration M6)

**Migration:** `supabase/migrations/0084_contacts_rls.sql`

Was sie tut:
- Aktiviert Row Level Security auf allen Contact-Tabellen
- Permissive Policies: `authenticated` darf alles lesen/schreiben (App-seitige Zugriffskontrolle)
- Kein anonymer Zugriff auf Contact-Daten

**Supabase Studio:** keine manuelle Aktion.

**Smoke-Test:**
```sql
-- Als anon-Rolle testen (Supabase Studio nutzt service_role, daher in der App testen):
-- Alternativ:
SELECT relname, relrowsecurity FROM pg_class
  WHERE relname IN ('contacts','contact_instructor','contact_student',
                    'contact_organization','contact_relationships','contact_audit_log');
-- Alle sollten relrowsecurity = true zeigen.
```

**Geschätzte Zeit:** 5–10 Sekunden

---

### Phasen G–I — Frontend (kein DB-Rollout)

Diese Phasen betreffen ausschliesslich TypeScript/React-Code:

| Phase | Was |
|-------|-----|
| **G** — Foundation Components | `InlineTextField`, `InlineField`, `ContactHeader`, `EmailList`, `PhoneList`, `AddressList`, `PhoneNormalizer` (libphonenumber-js) |
| **H** — ContactDetailPanel + Tabs | 12 adaptive Tabs, `OverviewTab` mit Inline-Edit, `AuditHistoryTab`, `OrgMembersTab`, etc. |
| **I** — AddressbookScreen + Sheets | `AddressbookScreen` (Master-Detail), `CreateContactSheet`, `RoleManagerSheet`, `MergeContactsSheet`, `AddRelationshipSheet`, `ContactMoreMenu` |

Kein DB-Eingriff nötig. Deploy via normalem CI/CD-Pipeline.

**Smoke-Test:** App unter `/contacts` aufrufen, Kontakt aus der Liste auswählen, alle Tabs durchklicken.

---

## Rollback-Strategie

### Phasen A–F (Schema + Daten)

Die Migration ist **additiv** — keine existierenden Tabellen wurden geändert oder gelöscht (Legacy-Tabellen existieren weiterhin). Rollback-Optionen:

1. **Einfacher Rollback (DDL):**
   ```sql
   -- Sync-Trigger zuerst entfernen (0083)
   DROP TRIGGER IF EXISTS trg_sync_instructor_to_contacts ON instructors;
   DROP TRIGGER IF EXISTS trg_sync_person_to_contacts ON people;
   DROP TRIGGER IF EXISTS trg_sync_org_to_contacts ON organizations;
   DROP INDEX IF EXISTS uniq_works_at;

   -- Dann neue Tabellen droppen
   DROP TABLE IF EXISTS contact_audit_log CASCADE;
   DROP TABLE IF EXISTS contact_relationships CASCADE;
   DROP TABLE IF EXISTS contact_organization CASCADE;
   DROP TABLE IF EXISTS contact_student CASCADE;
   DROP TABLE IF EXISTS contact_instructor CASCADE;
   DROP TABLE IF EXISTS contacts CASCADE;

   -- Enums
   DROP TYPE IF EXISTS contact_kind;
   DROP TYPE IF EXISTS relationship_kind;

   -- RPCs
   DROP FUNCTION IF EXISTS find_potential_duplicates(UUID);
   DROP FUNCTION IF EXISTS merge_contacts(UUID, UUID);
   DROP FUNCTION IF EXISTS gdpr_anonymize_contact(UUID);
   ```

2. **PITR-Restore:** Falls der DDL-Rollback nicht ausreicht oder Daten korrumpiert wurden, Wiederherstellung via Supabase Dashboard → *Database → Backups → Point in Time Restore*. Zeitstempel vom Pre-flight-Check verwenden.

### Phase G–I (Frontend)

Einfacher Git-Revert des Deployments. Legacy-Screens funktionieren weiterhin, da die Compat-Views / Legacy-Tabellen unverändert sind.

### Phase J (noch nicht ausgeführt)

Phase J (`0085_fk_rename.sql`, `0086_drop_legacy_views.sql`) löscht Legacy-Tabellen und benennt FKs um. Diese Phase ist **nicht umkehrbar** ohne PITR. Erst ausführen, wenn:
- 90 Tage stabiler Betrieb mit neuen Tabellen
- Kein Code mehr auf Legacy-Tabellen zeigt
- PITR-Backup unmittelbar vor Phase J bestätigt

---

## 90-Tage Legacy-Tables Disposal (Phase J)

Sobald Phase J freigegeben wird (Zieldatum: **2026-08-09**):

```sql
-- 0085: FK-Spalten umbenennen (Beispiel für course_participants)
ALTER TABLE course_participants RENAME COLUMN person_id TO contact_id;
ALTER TABLE intake_checklists   RENAME COLUMN student_id TO contact_id;
ALTER TABLE elearning_progress  RENAME COLUMN student_id TO contact_id;
-- ... weitere Tabellen gemäss 0085_fk_rename.sql

-- 0086: Sync-Trigger + Legacy-Views droppen, Legacy-Tabellen archivieren
DROP TABLE IF EXISTS instructors_legacy;
DROP TABLE IF EXISTS people_legacy;
DROP TABLE IF EXISTS organizations_legacy;
```

> **Hinweis:** Die Tabellen `instructors`, `people`, `organizations` bleiben noch als Live-Backup (mit Sync-Triggern aktiv), bis Phase J ausgeführt wird. Sie werden in Phase J zu `*_legacy`-Tabellen umbenannt und erst nach 90 Tagen stabilem Betrieb gedroppt.

---

## Known Issues / Open Items

1. **Phase J postponed** — Legacy-Tabellen (`instructors`, `people`, `organizations`) existieren weiterhin als Live-Backup. Sync-Trigger (Migration 0083) halten `contacts` aktuell. Dies ist gewollt bis zum Zieldatum 2026-08-09.

2. **`merge_contacts` RPC: falsche FK-Spaltennamen** — Die RPC referenziert `person_id` auf:
   - `intake_checklists` → tatsächlich `student_id`
   - `elearning_progress` → tatsächlich `student_id`
   - `performance_records` → Spaltenname noch nicht verifiziert
   - `student_certifications` → Spaltenname noch nicht verifiziert

   Patch-Vorlage für `0081_contacts_rpcs.sql`:
   ```sql
   -- Ersetze in merge_contacts():
   UPDATE intake_checklists   SET student_id = p_winner WHERE student_id = p_loser;
   UPDATE elearning_progress  SET student_id = p_winner WHERE student_id = p_loser;
   ```
   Vor der ersten Produktions-Merge-Operation diese Änderung als neue Migration `0085_contacts_rpcs_patch.sql` deployen.

3. **Peter Muster Duplikat** — Ein bekannter Datensatz existiert als Instructor UND als Student (zwei separate UUIDs mit identischer E-Mail). Muss via `merge_contacts` bereinigt werden, nachdem die RPC gepatcht ist.

4. **libphonenumber-js** — Einzige neue Produktions-Abhängigkeit, die in dieser Migration hinzugefügt wurde (`^1.13.0`). Bundle-Impact: ~145 KB (minified). Falls Bundle-Size ein Problem wird, kann auf die kleinere `libphonenumber-js/max` oder `mobile`-Variante umgestellt werden.

5. **Docker / lokale Tests nicht verfügbar** — Playwright-E2E-Tests (Phase K) wurden geschrieben, aber nicht ausgeführt. Alle Tests sind mit `test.skip` markiert bis ein `SUPABASE_TEST_TOKEN` in der CI-Umgebung verfügbar ist. Zum Ausführen: `cd apps/web && SUPABASE_TEST_TOKEN=<token> npx playwright test`.

6. **Implementierungsdauer** — Phasen A–K wurden in einer einzigen Arbeitssession ohne laufende Docker-Infrastruktur und ohne Playwright-Ausführung umgesetzt. Manuelle QA auf einem Staging-System mit befüllter DB wird empfohlen, bevor die Migration in Produktion geht.
