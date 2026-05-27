# Phase G Foundation — Schema-Audit-Notes

**Date:** 2026-05-27
**Purpose:** Verify schema assumptions before writing Migrations 0110-0113.
**References:** [Spec §13](../specs/2026-05-27-contacts-crm-redesign.md), [Plan Task 0](2026-05-27-phase-g-foundation.md)

---

## 1. `course_participants` — canonical enrollment table?

**Yes — canonical.** Defined in
[`supabase/migrations/0027_students_and_participants.sql:40-49`](../../../supabase/migrations/0027_students_and_participants.sql).

**Current column layout (post Phase-F1 / Phase-J):**

| Column | Type | Notes |
|---|---|---|
| `id` | UUID PK | |
| `course_id` | UUID NOT NULL | FK → `courses(id)` ON DELETE CASCADE |
| `student_id` | UUID NOT NULL | **FK retargeted to `contacts(id)` in `0092_phase_j_etappe_3c_pre_drop_cleanup.sql:61-66`** — column name was *not* renamed to `contact_id`, it still reads `student_id` but stores a `contacts(id)` reference. |
| `status` | `participant_status` enum | values: `enrolled` / `certified` / `dropped` |
| `enrolled_at` | TIMESTAMPTZ NOT NULL DEFAULT now() | |
| `certificate_nr` | TEXT | |
| `notes` | TEXT | |
| `certified_by_instructor_id` | UUID | added 0058, refs `instructors(id)` ON DELETE SET NULL |
| `certified_on` | DATE | added 0058 |

UNIQUE: `(course_id, student_id)`. Indexes on `course_id`, `student_id`, `status`, `certified_by_instructor_id` (partial), `certified_on` (partial).

**For the View `v_contact_timeline` UNION (course_enrollment branch), use:**
- `cp.id` → `source_id` and `event_id`
- `cp.student_id` → `contact_id`
- `cp.enrolled_at` → `occurred_at`
- `cp.course_id` → carry into `payload` (join `courses` for type/title summary)
- `cp.status` → into `payload` or `status` (note: enum value `enrolled` vs `certified` vs `dropped` should map to event-level state)

> **Watch out:** no FK to `contacts(id)` on `student_id` exists *as a database constraint*. Per [`0086_retarget_fks_to_contacts.sql`](../../../supabase/migrations/0086_retarget_fks_to_contacts.sql) header comment, the FK was apparently *not* present originally and only re-added in 0092 (re-add with `ADD CONSTRAINT course_participants_student_id_fkey FOREIGN KEY (student_id) REFERENCES public.contacts(id) ON DELETE RESTRICT`). Header of 0086 contradicts this — assumes the constraint did not exist. Either way, by current head (0109), the constraint exists per 0092 and points at `contacts(id)`. Verify against production with `\d course_participants` before final SELECT.

## 2. Pipeline-Stage-History storage

**No dedicated history table exists.** Migration 0112 will need to add one (e.g. `pipeline_stage_changes`).

- Original trigger `sync_pipeline_stage_changed()` in
  [`0048_cd_role_and_people_extend.sql:114-127`](../../../supabase/migrations/0048_cd_role_and_people_extend.sql)
  only updated `students.stage_changed_on := now()` when `pipeline_stage` changed — it did **not** write to any history table.
- That function was **dropped** in
  [`0092_phase_j_etappe_3c_pre_drop_cleanup.sql:184`](../../../supabase/migrations/0092_phase_j_etappe_3c_pre_drop_cleanup.sql)
  via `DROP FUNCTION IF EXISTS public.sync_pipeline_stage_changed() CASCADE`.
- It was replaced by `tg_contact_student_stage_changed()` in
  [`0091_phase_j_etappe_3a_sidecars.sql:77-90`](../../../supabase/migrations/0091_phase_j_etappe_3a_sidecars.sql)
  on `contact_student`. **This new trigger also only updates `stage_changed_on` — still no history table.**

Currently, stage changes are recorded *only* in `contact_audit_log` (because `contact_student.pipeline_stage` is one of the audited columns — see Q5). That JSON diff can be re-projected as a "stage change" event in the view, but a dedicated table is cleaner for indexing and avoids parsing JSONB at read-time.

**Action for Migration 0112:** Add table

```sql
CREATE TABLE public.pipeline_stage_changes (
  id           BIGSERIAL PRIMARY KEY,
  contact_id   UUID NOT NULL REFERENCES public.contacts(id) ON DELETE CASCADE,
  from_stage   TEXT,
  to_stage     TEXT,
  changed_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  changed_by   UUID                      -- nullable, no FK (audit pattern, see Q5)
);
CREATE INDEX idx_pipeline_stage_changes_contact ON public.pipeline_stage_changes(contact_id, changed_at DESC);
```

Plus a replacement trigger on `contact_student` that writes a row whenever `pipeline_stage IS DISTINCT FROM` — keep the existing `stage_changed_on := now()` semantics. Backfill from `contact_audit_log` is optional but recommended (filter `table_name = 'contact_student'` and `changed_fields ? 'pipeline_stage'`).

## 3. `contact_balance` vs `instructor_balance`

**`v_instructor_balance` exists; `v_contact_balance` does NOT.**

- `v_instructor_balance` defined in
  [`0014_view_instructor_balance.sql`](../../../supabase/migrations/0014_view_instructor_balance.sql)
  and replaced by
  [`0039_balance_only_completed.sql:15-45`](../../../supabase/migrations/0039_balance_only_completed.sql).
  Columns: `instructor_id, name, padi_level, balance_chf, last_movement_date, movement_count`.
- Joins on legacy `instructors` table (not dropped — see header note in
  [`0093_phase_j_etappe_3c_drop_legacy_tables.sql:11-13`](../../../supabase/migrations/0093_phase_j_etappe_3c_drop_legacy_tables.sql):
  *"instructors bleibt vorerst — Edge-Functions … lesen noch davon"*).
- `account_movements.instructor_id` is `UUID NOT NULL REFERENCES instructors(id)` per
  [`0012_table_account_movements.sql:3`](../../../supabase/migrations/0012_table_account_movements.sql).
  This FK has **not** been retargeted to `contacts`. Per the 0086 header comment, only `certifications.issued_by_person_id` and `people.organization_id` got retargeted; everything else was relying on referential integrity by UUID match alone.

**Action for Migration 0113:** Create `v_contact_balance` as a sibling. Since `instructors.id == contacts.id` (UUIDs are shared across legacy + contacts per Phase F1 design), the new view can join `account_movements` directly via `contact_id`:

```sql
CREATE OR REPLACE VIEW public.v_contact_balance AS
SELECT
  c.id          AS contact_id,
  c.display_name,
  ci.padi_level,
  COALESCE(SUM(
    CASE
      WHEN am.ref_assignment_id IS NULL THEN am.amount_chf
      WHEN cr.status = 'completed' THEN am.amount_chf
      ELSE 0
    END
  ), 0)::NUMERIC(10,2) AS balance_chf,
  MAX(...) AS last_movement_date,
  COUNT(...) AS movement_count
FROM public.contacts c
JOIN public.contact_instructor ci ON ci.contact_id = c.id
LEFT JOIN public.account_movements am ON am.instructor_id = c.id   -- UUIDs match
LEFT JOIN public.course_assignments ca ON ca.id = am.ref_assignment_id
LEFT JOIN public.courses cr ON cr.id = ca.course_id
GROUP BY c.id, c.display_name, ci.padi_level;
```

> **Decision needed:** Keep `v_instructor_balance` as legacy view (Edge Functions still read it), OR rewrite it to `SELECT * FROM v_contact_balance` for single source of truth. Suggest: keep both, mark `v_instructor_balance` as deprecated via COMMENT.

## 4. Intake-Checklist structure

**Single-row-per-student with boolean/scalar columns. NO sub-table.** Defined in
[`0050_cd_elearning_and_intake.sql:31-62`](../../../supabase/migrations/0050_cd_elearning_and_intake.sql),
extended in
[`0068_intake_idc_prerequisites.sql:11-21`](../../../supabase/migrations/0068_intake_idc_prerequisites.sql).

Each "checkpoint" is a column in `public.intake_checklists`:

**From 0050:**
`medical_received`, `medical_signed`, `medical_doctor_required`, `medical_doctor_signed`, `medical_notes`,
`logbook_seen`, `logbook_dives_count`,
`id_seen`, `id_kind`,
`insurance_proof`, `insurance_provider`, `insurance_valid_to`,
`liability_signed`, `safe_diving_signed`,
`notes`, `updated_at`, `created_at`

**From 0068 (IDC-specific extensions):**
`min_age_confirmed`, `instructor_status`, `certified_diver_since`, `medical_signed_on`,
`efr_completed_on`, `efr_kind`, `non_padi_certs_seen`, `non_padi_certs_notes`,
`checked_by_id` (FK → `instructors(id)` SET NULL), `checked_on`

**FK target:** `intake_checklists.student_id` was retargeted to `contacts(id)` in
[`0092:75-80`](../../../supabase/migrations/0092_phase_j_etappe_3c_pre_drop_cleanup.sql).
Also has `course_participant_id UUID REFERENCES course_participants(id)` from
[`0069:42`](../../../supabase/migrations/0069_rename_students_to_people.sql) — preferred linkage post-0069.

**Implication for Migration 0112 (View `v_contact_timeline` intake branch):**

There is no granular "checkpoint X was completed on date Y" data — only one `updated_at` timestamp on the whole checklist. To surface "intake item completed" as timeline events, the View has two realistic options:

- **Coarse:** Emit one event per checklist row at `updated_at` with `summary = "Intake aktualisiert"` and `payload` containing the full set of boolean flags. Cheap; loses granularity.
- **Fine via audit_log:** UNION against `contact_audit_log WHERE table_name = 'intake_checklists' AND operation = 'UPDATE'`, expand each changed field into one event row via `jsonb_each(changed_fields)`. Yields per-checkpoint events but only works for events *after* triggers are wired to intake_checklists (currently they are NOT — see Q5).

> Recommend the coarse approach for the View in Migration 0112; revisit if PM wants per-checkpoint granularity (would require extending `audit_contact_changes` to cover `intake_checklists`, or adding a dedicated `intake_checklist_events` table).

## 5. `audit_log` schema

**Actual table name:** `public.contact_audit_log` (not `audit_log`). Defined in
[`0079_contacts_schema.sql:175-187`](../../../supabase/migrations/0079_contacts_schema.sql).
Trigger function `audit_contact_changes()` in
[`0080_contacts_triggers.sql:24-79`](../../../supabase/migrations/0080_contacts_triggers.sql).

**Columns:**

| Column | Type | Notes |
|---|---|---|
| `id` | BIGSERIAL PK | |
| `contact_id` | UUID NOT NULL | **No FK** (deliberate — must outlive DELETE) |
| `changed_by` | UUID | nullable, from `auth.uid()` |
| `changed_at` | TIMESTAMPTZ NOT NULL DEFAULT now() | |
| `table_name` | TEXT NOT NULL | one of `'contacts'`, `'contact_instructor'`, `'contact_student'`, `'contact_organization'` |
| `operation` | TEXT NOT NULL | `'INSERT'` / `'UPDATE'` / `'DELETE'` (CHECK constraint) |
| `changed_fields` | JSONB | shape on UPDATE: `{ "field_name": { "old": <val>, "new": <val> }, ... }`. NULL on INSERT/DELETE. |
| `old_row` | JSONB | full OLD snapshot on UPDATE/DELETE, NULL on INSERT |
| `new_row` | JSONB | full NEW snapshot on INSERT/UPDATE, NULL on DELETE |

Index: `idx_audit_contact ON (contact_id, changed_at DESC)`.

**Filter strategy for `v_contact_timeline` UNION branches:**

- **`role_change` events** (someone added/removed from a sidecar) → filter on `operation IN ('INSERT','DELETE') AND table_name IN ('contact_instructor','contact_student','contact_organization')`. The role can be inferred from `table_name`.
- **`audit_edit` (PII / general data edit) events** → `operation = 'UPDATE' AND table_name = 'contacts'`. The field list is `jsonb_object_keys(changed_fields)`.
- **`pipeline_stage_change` events** (if backfilling before Migration 0112 adds a dedicated table) → `operation = 'UPDATE' AND table_name = 'contact_student' AND changed_fields ? 'pipeline_stage'`. From/to extractable via `changed_fields->'pipeline_stage'->>'old'` and `->>'new'`.

> Note: the audit-trigger pattern uses `changed_fields` (plural), not `field` / `column_name`. The spec text in §13 question 5 mentioning "field/column_name/changed_field" was speculative — the real column is `changed_fields::JSONB`.

## 6. `is_contact_owner()` existence

**Does not exist.** Only referenced in spec/plan as a function to be created. Confirmed by:
- `Grep "is_contact_owner"` in `supabase/migrations/` → no matches.
- `Grep "is_contact_owner"` repo-wide → matches only in `docs/superpowers/specs/` and `docs/superpowers/plans/`.

**Adjacent helpers that DO exist** (in [`0045_owner_role_and_cockpit.sql`](../../../supabase/migrations/0045_owner_role_and_cockpit.sql) and [`0048_cd_role_and_people_extend.sql`](../../../supabase/migrations/0048_cd_role_and_people_extend.sql)):
- `is_owner()` — true if current user has system role `owner` on legacy `instructors` table
- `is_owner_or_dispatcher()` — same, broader
- `is_dispatcher()`, `is_cd()`

These are role gates, **not** the per-contact owner check the spec defines.

**Linking table for the new helper:** `public.contact_instructor` (PK = `contact_id`, contains `auth_user_id UUID UNIQUE REFERENCES auth.users(id) ON DELETE SET NULL`). Defined
[`0079:92-108`](../../../supabase/migrations/0079_contacts_schema.sql).

So the spec-intended definition for Migration 0111 is correct as-written:

```sql
CREATE OR REPLACE FUNCTION public.is_contact_owner(p_contact_id UUID)
RETURNS BOOLEAN
LANGUAGE SQL STABLE SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.contact_instructor
    WHERE contact_id = p_contact_id
      AND auth_user_id = auth.uid()
  );
$$;
```

> **Semantic note:** This helper says "the current authenticated user *is* this contact" (self-ownership for instructors with auth seats). It does **not** model "user X owns/manages contact Y". If the latter is needed in future phases, the natural column is the existing `contacts.owner_id` (see [`0079:43`](../../../supabase/migrations/0079_contacts_schema.sql)), which is a `UUID REFERENCES contacts(id)` — would need a second helper.

---

## Action items for Migrations 0110-0113

- **Migration 0112 must additionally create `public.pipeline_stage_changes`** (table + trigger on `contact_student`) — does not currently exist. Backfill from `contact_audit_log` recommended.
- **Migration 0113** (or wherever the new view lives) should create `v_contact_balance` as a sibling to `v_instructor_balance`. Keep both; mark legacy as deprecated.
- **`course_participants.student_id` keeps its name** — write the view JOIN as `JOIN course_participants cp ON cp.student_id = c.id` (NOT `cp.contact_id`).
- **`contact_audit_log` is the audit table name** — not `audit_log`. Field-name column is `changed_fields::JSONB` keyed by column name.
- **Intake events in the View should be one-event-per-checklist-row** (using `intake_checklists.updated_at` and `student_id`); per-checkpoint granularity would require extending audit triggers to cover `intake_checklists`.
- **`is_contact_owner()` is brand new** — Migration 0111 must include the full `CREATE OR REPLACE FUNCTION` (no existing helper to consolidate).
- **Watch:** `course_participants.student_id` FK to `contacts(id)` was added in 0092 but the header of 0086 contradicts this. Re-verify against production schema before finalising the SELECT in Migration 0112 (a missing FK doesn't break the view but may surprise tests).

---

## Actor-UUID Orphan-Probe (Pre-Phase-2, 2026-05-27)

Drei Probes auf Production gelaufen, alle **0 orphans**:

| Probe | Source-FK | Orphan-Count |
|---|---|---|
| `account_movements.created_by → contacts(id)` | nicht retargeted, UUID-Identität via Phase F1 | **0** |
| `padi_skill_records.instructor_id → contacts(id)` | analog | **0** |
| `certifications.issued_by_person_id → contacts(id)` | in 0086 retargeted | **0** |

**Implication:** Actor-UUIDs sind komplett konsistent über alle Source-Tabellen die `v_contact_timeline.actor_contact_id` befüllen. `EventCard` kann den `actor_contact_id` UUID direkt mit `contacts`-Lookup auflösen — **kein „Unbekannt"-Orphan-Fallback** im UI nötig. Phase F1 hat die UUID-Identität echt durchgezogen.

---

## Phase 3 Sidecar + Storage-Audit (Pre-Phase-3, 2026-05-27)

Vor PropertiesSidebar-Implementation gegen Production geprüft:

| Probe | Tabelle/View | Status |
|---|---|---|
| 1 | `v_contact_balance` | ✓ existiert, liefert Saldo-Zahlen für aktive Instructors korrekt |
| 2 | `contact_instructor` Spalten | ✓ existiert (Phase F1) — Schema wird in Task 1 Hook genutzt |
| 2 | `contact_student` Spalten | ✓ existiert (Phase F1) |
| 2 | `contact_organization` Spalten | ✓ existiert (Phase F1) |
| 3 | Org-Membership-Pattern | ✓ via `contact_relationships` mit `kind='works_at'` |
| 4 | `contact_tags` | ✗ **existiert NICHT** — Migration in Phase 3 anlegen |

**`contact_relationships.kind`** hat aktuell 3 Werte: `works_at` (Employment/Org-Membership), `parent_of`, `partner_of`. Phase 3 OrgRelationsSection nutzt `works_at`. Familien (`parent_of`, `partner_of`) sind out-of-scope Phase 3, könnten in eine zukünftige RelationshipsSection landen.

**Tag-Storage:** keine `tag`-Spalte irgendwo + keine `contact_tags`-Tabelle. Phase 3 bringt eine neue Migration `0117_contact_tags.sql` mit (siehe Plan Task 9-pre).
