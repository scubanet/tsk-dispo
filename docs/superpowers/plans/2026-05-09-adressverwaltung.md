# Adressverwaltung Redesign — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transform the fragmented address management (5 screens, 3 tables) into a unified Voll-CRM with one `contacts` table, role-based sidecars, n:m relationships, and one universal `ContactDetailPanel` with adaptive tabs.

**Architecture:** Schema-additive 3-phase migration (M1 schema + backfill, M2 compatibility views, M3 frontend cutover) with full rollback up to M2. UI: zentral Adressbuch + spezialisierte Workflow-Screens (Pipeline, Skill-Matrix, Verfügbarkeit), alle teilen sich denselben universellen Detail-Panel. Inline-Edit ersetzt das EditSheet-Pattern.

**Tech Stack:**
- Postgres 15 + Supabase (RLS, Edge Functions, Realtime)
- pgTAP für DB-Tests (in `supabase/tests/pgtap/`)
- React 18 + TypeScript + Vite
- Foundation Token-System + Components (`apps/web/src/foundation/`)
- React Query (`@tanstack/react-query`) für Datenladung
- Playwright für E2E-Tests
- libphonenumber-js für Phone-Normalisation

**Spec:** `docs/superpowers/specs/2026-05-09-adressverwaltung-design.md`

**Estimated effort:** 11–14 Arbeitstage über 3–4 Wochen.

---

## File Structure

### New SQL Migrations
- `supabase/migrations/0079_contacts_schema.sql` — alle neuen Tabellen, Indexes, Constraints
- `supabase/migrations/0080_contacts_triggers.sql` — Audit-Trigger, Konsistenz-Trigger, Updated-At
- `supabase/migrations/0081_contacts_rpcs.sql` — `merge_contacts`, `find_potential_duplicates`, `gdpr_anonymize_contact`
- `supabase/migrations/0082_contacts_backfill.sql` — Daten kopieren aus `instructors`/`people`/`organizations`
- `supabase/migrations/0083_contacts_compat_views.sql` — Compatibility-Views für alten Code
- `supabase/migrations/0084_contacts_rls.sql` — RLS-Policies
- `supabase/migrations/0085_fk_rename.sql` — FK-Spalten umbenennen (Phase M3.6)
- `supabase/migrations/0086_drop_legacy_views.sql` — Legacy-Views droppen (Phase M3.6)

### New pgTAP Tests
- `supabase/tests/pgtap/contacts_schema.sql`
- `supabase/tests/pgtap/contacts_triggers.sql`
- `supabase/tests/pgtap/contacts_rls.sql`
- `supabase/tests/pgtap/contacts_backfill_smoke.sql`
- `supabase/tests/pgtap/contacts_merge.sql`

### New TypeScript Types
- `apps/web/src/types/contacts.ts` — Contact, ContactInstructor, ContactStudent, ContactOrganization, ContactRelationship, ContactRole
- `apps/web/src/lib/contactQueries.ts` — alle Supabase-Queries für Contacts (List, Detail, Mutations)

### New Foundation Compounds
- `apps/web/src/foundation/compounds/ContactHeader.tsx` — Avatar + Name + Roles + QuickActions
- `apps/web/src/foundation/compounds/RolesBadgeList.tsx` — Klickbare Rollen-Chips
- `apps/web/src/foundation/compounds/InlineField.tsx` — Generisches Inline-Edit-Wrapper
- `apps/web/src/foundation/compounds/InlineTextField.tsx` — Text-Inline-Edit
- `apps/web/src/foundation/compounds/InlineSelectField.tsx` — Select-Inline-Edit
- `apps/web/src/foundation/compounds/PhoneList.tsx` — Liste typisierter Phones mit Edit
- `apps/web/src/foundation/compounds/EmailList.tsx` — Liste typisierter Emails
- `apps/web/src/foundation/compounds/AddressList.tsx` — Liste typisierter Addresses
- `apps/web/src/foundation/compounds/RelationshipList.tsx` — n:m Beziehungs-Liste

### New Screens
- `apps/web/src/screens/contacts/AddressbookScreen.tsx` — Hauptscreen Master-Detail
- `apps/web/src/screens/contacts/ContactDetailPanel.tsx` — universeller Detail-Panel
- `apps/web/src/screens/contacts/CreateContactSheet.tsx` — Neu-anlegen Wizard
- `apps/web/src/screens/contacts/MergeContactsSheet.tsx` — Verschmelzen-Workflow
- `apps/web/src/screens/contacts/AddRelationshipSheet.tsx` — Beziehung hinzufügen
- `apps/web/src/screens/contacts/RoleManagerSheet.tsx` — Rollen verwalten

### New ContactDetailPanel Tabs (sub-components)
- `apps/web/src/screens/contacts/tabs/OverviewTab.tsx`
- `apps/web/src/screens/contacts/tabs/RelationshipsTab.tsx`
- `apps/web/src/screens/contacts/tabs/ActivityTab.tsx`
- `apps/web/src/screens/contacts/tabs/NotesAndDocsTab.tsx`
- `apps/web/src/screens/contacts/tabs/StudentTab.tsx`
- `apps/web/src/screens/contacts/tabs/CoursesTab.tsx`
- `apps/web/src/screens/contacts/tabs/SaldoTab.tsx` (extrahiert aus altem `InstructorDetailPanel`)
- `apps/web/src/screens/contacts/tabs/SkillsTab.tsx`
- `apps/web/src/screens/contacts/tabs/AvailabilityTab.tsx`
- `apps/web/src/screens/contacts/tabs/OrgMembersTab.tsx`
- `apps/web/src/screens/contacts/tabs/ContractTab.tsx`
- `apps/web/src/screens/contacts/tabs/AuditHistoryTab.tsx`

### Screens to be Modified (Workflow-Screens)
- `apps/web/src/screens/StudentsScreen.tsx` → leitet auf `AddressbookScreen` mit Filter
- `apps/web/src/screens/InstructorsScreen.tsx` → desgleichen
- `apps/web/src/screens/cd/CDOrganizationsScreen.tsx` → desgleichen
- `apps/web/src/screens/cd/CDPipelineScreen.tsx` → öffnet ContactDetailPanel
- `apps/web/src/screens/CommunicationHubScreen.tsx` → öffnet ContactDetailPanel
- `apps/web/src/screens/SkillMatrixScreen.tsx` → öffnet ContactDetailPanel
- `apps/web/src/screens/Sidebar.tsx` → neue Top-Level-Struktur

### Screens/Components to be Deleted
- `apps/web/src/screens/StudentDetailPanel.tsx`
- `apps/web/src/screens/InstructorDetailPanel.tsx`
- `apps/web/src/screens/StudentEditSheet.tsx`
- `apps/web/src/screens/InstructorEditSheet.tsx`
- `apps/web/src/screens/cd/OrganizationEditSheet.tsx`
- `apps/web/src/screens/cd/CommunicationEditSheet.tsx`

### New E2E-Tests
- `apps/web/tests/e2e/addressbook-create-contact.spec.ts`
- `apps/web/tests/e2e/contact-add-role.spec.ts`
- `apps/web/tests/e2e/contact-merge.spec.ts`
- `apps/web/tests/e2e/contact-gdpr-delete.spec.ts`
- `apps/web/tests/e2e/contact-inline-edit.spec.ts`
- `apps/web/tests/e2e/contact-relationships.spec.ts`

---

# Phase A — Schema (Migration M1, additiv)

## Task A1: Enums + contacts-Haupttabelle anlegen

**Files:**
- Create: `supabase/migrations/0079_contacts_schema.sql` (Teil 1)
- Test: `supabase/tests/pgtap/contacts_schema.sql`

- [ ] **Step 1: Schema-Datei mit Enums + contacts**

```sql
-- 0079: Contacts unified CRM schema (Part 1 — enums + main table)

CREATE TYPE contact_kind AS ENUM ('person', 'organization');

CREATE TYPE relationship_kind AS ENUM (
  'works_at', 'owns', 'spouse_of', 'child_of', 'parent_of',
  'referred_by', 'subsidiary_of', 'partner_of', 'supplier_of',
  'student_of', 'mentor_of'
);

CREATE TABLE public.contacts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  kind contact_kind NOT NULL,

  -- Person fields
  first_name TEXT,
  last_name TEXT,
  birth_date DATE,
  gender TEXT,

  -- Org fields
  legal_name TEXT,
  trading_name TEXT,

  -- Generated display name
  display_name TEXT GENERATED ALWAYS AS (
    CASE
      WHEN kind = 'organization' THEN COALESCE(trading_name, legal_name)
      ELSE last_name || ', ' || first_name
    END
  ) STORED,

  primary_email TEXT,
  emails JSONB NOT NULL DEFAULT '[]',
  phones JSONB NOT NULL DEFAULT '[]',
  addresses JSONB NOT NULL DEFAULT '[]',

  languages TEXT[] NOT NULL DEFAULT '{}',
  roles TEXT[] NOT NULL DEFAULT '{}',
  tags TEXT[] NOT NULL DEFAULT '{}',

  notes TEXT,
  owner_id UUID REFERENCES public.contacts(id) ON DELETE SET NULL,

  consent_marketing BOOLEAN NOT NULL DEFAULT false,
  consent_marketing_at TIMESTAMPTZ,
  consent_marketing_source TEXT,

  source TEXT,

  archived_at TIMESTAMPTZ,
  merged_into_id UUID REFERENCES public.contacts(id) ON DELETE SET NULL,

  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID,

  CONSTRAINT contacts_person_fields_check CHECK (
    kind = 'organization'
    OR (first_name IS NOT NULL AND last_name IS NOT NULL)
  ),
  CONSTRAINT contacts_org_fields_check CHECK (
    kind = 'person' OR legal_name IS NOT NULL
  ),
  CONSTRAINT contacts_no_self_merge CHECK (id <> merged_into_id)
);

CREATE INDEX idx_contacts_kind     ON public.contacts(kind);
CREATE INDEX idx_contacts_owner    ON public.contacts(owner_id);
CREATE INDEX idx_contacts_roles    ON public.contacts USING GIN(roles);
CREATE INDEX idx_contacts_tags     ON public.contacts USING GIN(tags);
CREATE INDEX idx_contacts_archived ON public.contacts(archived_at)
  WHERE archived_at IS NULL;
CREATE INDEX idx_contacts_search   ON public.contacts USING GIN(
  to_tsvector('simple',
    COALESCE(first_name,'') || ' ' ||
    COALESCE(last_name,'')  || ' ' ||
    COALESCE(legal_name,'') || ' ' ||
    COALESCE(trading_name,'') || ' ' ||
    COALESCE(primary_email,'') || ' ' ||
    COALESCE(notes,'')
  )
);

COMMENT ON TABLE public.contacts IS
  'Unified CRM contacts table. Replaces instructors, people, organizations.';
```

- [ ] **Step 2: pgTAP-Test schreiben**

```sql
-- supabase/tests/pgtap/contacts_schema.sql
BEGIN;
SELECT plan(8);

SELECT has_table('contacts', 'contacts table exists');
SELECT has_column('contacts', 'kind', 'contacts.kind exists');
SELECT col_type_is('contacts', 'kind', 'contact_kind', 'kind is enum');
SELECT has_column('contacts', 'roles', 'roles[] column exists');
SELECT col_type_is('contacts', 'roles', 'text[]', 'roles is text[]');
SELECT has_column('contacts', 'display_name', 'display_name (generated) exists');

-- Person constraint
PREPARE bad_person AS
  INSERT INTO contacts (kind) VALUES ('person');
SELECT throws_ok('bad_person', '23514',
  NULL, 'CHECK person needs first_name+last_name');

-- Org constraint
PREPARE bad_org AS
  INSERT INTO contacts (kind) VALUES ('organization');
SELECT throws_ok('bad_org', '23514',
  NULL, 'CHECK org needs legal_name');

SELECT * FROM finish();
ROLLBACK;
```

- [ ] **Step 3: Migration anwenden + Tests laufen lassen**

```bash
npx supabase db reset --no-seed
npx supabase test db --linked
```

Expected: alle 8 Asserts pass, "ok 8".

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/0079_contacts_schema.sql supabase/tests/pgtap/contacts_schema.sql
git commit -m "feat(db): contacts table schema (Phase M1.1)"
```

---

## Task A2: Sidecar-Tabellen `contact_instructor`, `contact_student`, `contact_organization`

**Files:**
- Modify: `supabase/migrations/0079_contacts_schema.sql` (append)
- Test: `supabase/tests/pgtap/contacts_schema.sql` (append)

- [ ] **Step 1: Sidecars an Migration anhängen**

```sql
-- contact_instructor sidecar
CREATE TABLE public.contact_instructor (
  contact_id UUID PRIMARY KEY REFERENCES public.contacts(id) ON DELETE CASCADE,
  auth_user_id UUID UNIQUE REFERENCES auth.users(id) ON DELETE SET NULL,
  padi_pro_number TEXT,
  padi_level padi_pro_level,
  account_balance NUMERIC(10,2) NOT NULL DEFAULT 0,
  hourly_rate_chf NUMERIC(8,2),
  daily_rate_chf NUMERIC(8,2),
  active BOOLEAN NOT NULL DEFAULT true,
  hire_date DATE,
  termination_date DATE,
  emergency_contact_name TEXT,
  emergency_contact_phone TEXT,
  notes_internal TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_contact_instructor_active ON public.contact_instructor(active);
CREATE INDEX idx_contact_instructor_auth   ON public.contact_instructor(auth_user_id);

-- contact_student sidecar
CREATE TABLE public.contact_student (
  contact_id UUID PRIMARY KEY REFERENCES public.contacts(id) ON DELETE CASCADE,
  pipeline_stage TEXT,
  lead_source TEXT,
  highest_brevet TEXT,
  intake_status TEXT,
  external_brevet_history JSONB NOT NULL DEFAULT '[]',
  is_candidate BOOLEAN NOT NULL DEFAULT false,
  candidate_target_level padi_pro_level,
  medical_clearance_at DATE,
  insurance_provider TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_contact_student_pipeline  ON public.contact_student(pipeline_stage);
CREATE INDEX idx_contact_student_candidate ON public.contact_student(is_candidate)
  WHERE is_candidate = true;

-- contact_organization sidecar
CREATE TABLE public.contact_organization (
  contact_id UUID PRIMARY KEY REFERENCES public.contacts(id) ON DELETE CASCADE,
  org_kind TEXT NOT NULL,
  tax_id TEXT,
  billing_email TEXT,
  parent_org_id UUID REFERENCES public.contacts(id) ON DELETE SET NULL,
  contract_type TEXT,
  contract_until DATE,
  payment_terms TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_contact_org_kind   ON public.contact_organization(org_kind);
CREATE INDEX idx_contact_org_parent ON public.contact_organization(parent_org_id);
```

- [ ] **Step 2: pgTAP-Tests für Sidecars erweitern**

```sql
-- Append to supabase/tests/pgtap/contacts_schema.sql before SELECT * FROM finish();
SELECT plan(20);  -- update plan from 8 to 20

SELECT has_table('contact_instructor', 'sidecar exists');
SELECT has_table('contact_student',    'sidecar exists');
SELECT has_table('contact_organization', 'sidecar exists');

SELECT col_is_pk('contact_instructor', 'contact_id');
SELECT col_is_pk('contact_student',    'contact_id');
SELECT col_is_pk('contact_organization', 'contact_id');

SELECT col_is_fk('contact_instructor', 'contact_id');
SELECT col_is_fk('contact_student',    'contact_id');
SELECT col_is_fk('contact_organization', 'contact_id');

SELECT has_column('contact_instructor', 'padi_pro_number');
SELECT has_column('contact_instructor', 'account_balance');
SELECT has_column('contact_student',    'pipeline_stage');
```

- [ ] **Step 3: Run + verify**

```bash
npx supabase test db --linked
```

Expected: ok 20.

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/0079_contacts_schema.sql supabase/tests/pgtap/contacts_schema.sql
git commit -m "feat(db): sidecar tables for instructor/student/org roles"
```

---

## Task A3: `contact_relationships` + `contact_audit_log`

**Files:**
- Modify: `supabase/migrations/0079_contacts_schema.sql` (append)
- Test: `supabase/tests/pgtap/contacts_schema.sql` (append)

- [ ] **Step 1: Tabellen anhängen**

```sql
CREATE TABLE public.contact_relationships (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  from_contact_id UUID NOT NULL REFERENCES public.contacts(id) ON DELETE CASCADE,
  to_contact_id   UUID NOT NULL REFERENCES public.contacts(id) ON DELETE CASCADE,
  kind relationship_kind NOT NULL,
  role_at_org TEXT,
  started_at DATE,
  ended_at DATE,
  is_primary BOOLEAN NOT NULL DEFAULT false,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT no_self_relationship CHECK (from_contact_id <> to_contact_id),
  CONSTRAINT valid_period CHECK (ended_at IS NULL OR started_at IS NULL OR ended_at >= started_at)
);

CREATE INDEX idx_contact_rel_from ON public.contact_relationships(from_contact_id);
CREATE INDEX idx_contact_rel_to   ON public.contact_relationships(to_contact_id);
CREATE INDEX idx_contact_rel_kind ON public.contact_relationships(kind);

CREATE TABLE public.contact_audit_log (
  id BIGSERIAL PRIMARY KEY,
  contact_id UUID NOT NULL REFERENCES public.contacts(id) ON DELETE CASCADE,
  changed_by UUID,
  changed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  table_name TEXT NOT NULL,
  operation TEXT NOT NULL CHECK (operation IN ('INSERT','UPDATE','DELETE')),
  changed_fields JSONB,
  old_row JSONB,
  new_row JSONB
);

CREATE INDEX idx_audit_contact ON public.contact_audit_log(contact_id, changed_at DESC);
```

- [ ] **Step 2: Tests erweitern**

```sql
SELECT plan(26);  -- 20 → 26
SELECT has_table('contact_relationships');
SELECT has_table('contact_audit_log');
SELECT col_type_is('contact_relationships', 'kind', 'relationship_kind');

PREPARE self_rel AS
  WITH c AS (INSERT INTO contacts (kind, first_name, last_name)
             VALUES ('person','Test','User') RETURNING id)
  INSERT INTO contact_relationships (from_contact_id, to_contact_id, kind)
  SELECT id, id, 'works_at' FROM c;
SELECT throws_ok('self_rel', '23514', NULL, 'CHECK no_self_relationship');
```

- [ ] **Step 3: Run + verify**

```bash
npx supabase test db --linked
```

Expected: ok 26.

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/0079_contacts_schema.sql supabase/tests/pgtap/contacts_schema.sql
git commit -m "feat(db): contact relationships + audit log tables"
```

---

## Task A4: Trigger — `updated_at`, Audit, Role-Sidecar-Konsistenz

**Files:**
- Create: `supabase/migrations/0080_contacts_triggers.sql`
- Test: `supabase/tests/pgtap/contacts_triggers.sql`

- [ ] **Step 1: Trigger-Datei anlegen**

```sql
-- 0080: Contacts triggers (updated_at, audit, role-sidecar consistency)

-- updated_at on all contact tables
CREATE TRIGGER trg_contacts_updated_at
  BEFORE UPDATE ON public.contacts
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_contact_instructor_updated_at
  BEFORE UPDATE ON public.contact_instructor
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_contact_student_updated_at
  BEFORE UPDATE ON public.contact_student
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_contact_organization_updated_at
  BEFORE UPDATE ON public.contact_organization
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Audit log function
CREATE OR REPLACE FUNCTION audit_contact_changes()
RETURNS TRIGGER AS $$
DECLARE
  v_contact_id UUID;
  v_changed JSONB;
BEGIN
  -- Determine contact_id (PK if main table, contact_id if sidecar)
  IF TG_TABLE_NAME = 'contacts' THEN
    v_contact_id := COALESCE(NEW.id, OLD.id);
  ELSE
    v_contact_id := COALESCE(NEW.contact_id, OLD.contact_id);
  END IF;

  -- For UPDATE: compute diff of changed fields
  IF TG_OP = 'UPDATE' THEN
    SELECT jsonb_object_agg(key, jsonb_build_object('old', old_val, 'new', new_val))
    INTO v_changed
    FROM (
      SELECT key, old_val, new_val
      FROM jsonb_each(to_jsonb(OLD)) AS o(key, old_val)
      JOIN jsonb_each(to_jsonb(NEW)) AS n(key, new_val) USING (key)
      WHERE old_val IS DISTINCT FROM new_val
    ) diff;
  END IF;

  INSERT INTO public.contact_audit_log
    (contact_id, changed_by, table_name, operation, changed_fields, old_row, new_row)
  VALUES
    (v_contact_id,
     auth.uid(),
     TG_TABLE_NAME,
     TG_OP,
     v_changed,
     CASE WHEN TG_OP IN ('UPDATE','DELETE') THEN to_jsonb(OLD) END,
     CASE WHEN TG_OP IN ('INSERT','UPDATE') THEN to_jsonb(NEW) END);

  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trg_audit_contacts
  AFTER INSERT OR UPDATE OR DELETE ON public.contacts
  FOR EACH ROW EXECUTE FUNCTION audit_contact_changes();

CREATE TRIGGER trg_audit_contact_instructor
  AFTER INSERT OR UPDATE OR DELETE ON public.contact_instructor
  FOR EACH ROW EXECUTE FUNCTION audit_contact_changes();

CREATE TRIGGER trg_audit_contact_student
  AFTER INSERT OR UPDATE OR DELETE ON public.contact_student
  FOR EACH ROW EXECUTE FUNCTION audit_contact_changes();

CREATE TRIGGER trg_audit_contact_organization
  AFTER INSERT OR UPDATE OR DELETE ON public.contact_organization
  FOR EACH ROW EXECUTE FUNCTION audit_contact_changes();

-- Role-sidecar consistency: when contact_instructor row created,
-- ensure 'instructor' is in roles[]
CREATE OR REPLACE FUNCTION sync_role_from_sidecar()
RETURNS TRIGGER AS $$
DECLARE
  v_role TEXT;
BEGIN
  v_role := CASE TG_TABLE_NAME
    WHEN 'contact_instructor'   THEN 'instructor'
    WHEN 'contact_student'      THEN 'student'
    WHEN 'contact_organization' THEN 'organization_profile'
  END;

  IF TG_OP = 'INSERT' THEN
    UPDATE public.contacts
       SET roles = array_append(roles, v_role)
     WHERE id = NEW.contact_id
       AND NOT (v_role = ANY(roles));
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE public.contacts
       SET roles = array_remove(roles, v_role)
     WHERE id = OLD.contact_id;
  END IF;

  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_sync_instructor_role
  AFTER INSERT OR DELETE ON public.contact_instructor
  FOR EACH ROW EXECUTE FUNCTION sync_role_from_sidecar();

CREATE TRIGGER trg_sync_student_role
  AFTER INSERT OR DELETE ON public.contact_student
  FOR EACH ROW EXECUTE FUNCTION sync_role_from_sidecar();
```

- [ ] **Step 2: Trigger-Test schreiben**

```sql
-- supabase/tests/pgtap/contacts_triggers.sql
BEGIN;
SELECT plan(6);

-- Setup
INSERT INTO contacts (id, kind, first_name, last_name)
VALUES ('11111111-1111-1111-1111-111111111111', 'person', 'Test', 'User');

-- Audit on insert
SELECT is(
  (SELECT count(*)::int FROM contact_audit_log
   WHERE contact_id = '11111111-1111-1111-1111-111111111111'
     AND operation = 'INSERT' AND table_name = 'contacts'),
  1, 'INSERT logged');

-- updated_at advances on update
SELECT set_eq(
  $sub$ UPDATE contacts SET notes = 'foo'
        WHERE id = '11111111-1111-1111-1111-111111111111'
        RETURNING (updated_at > created_at) $sub$,
  $exp$ VALUES (true) $exp$,
  'updated_at trigger advances');

-- Role auto-added when sidecar inserted
INSERT INTO contact_instructor (contact_id) VALUES ('11111111-1111-1111-1111-111111111111');
SELECT is(
  (SELECT 'instructor' = ANY(roles) FROM contacts
   WHERE id = '11111111-1111-1111-1111-111111111111'),
  true, 'instructor role auto-added on sidecar INSERT');

-- Audit on sidecar insert
SELECT is(
  (SELECT count(*)::int FROM contact_audit_log
   WHERE contact_id = '11111111-1111-1111-1111-111111111111'
     AND table_name = 'contact_instructor' AND operation = 'INSERT'),
  1, 'sidecar INSERT logged');

-- Role removed on sidecar delete
DELETE FROM contact_instructor WHERE contact_id = '11111111-1111-1111-1111-111111111111';
SELECT is(
  (SELECT 'instructor' = ANY(roles) FROM contacts
   WHERE id = '11111111-1111-1111-1111-111111111111'),
  false, 'instructor role auto-removed on sidecar DELETE');

-- Update diff captured
UPDATE contacts SET first_name = 'Changed'
 WHERE id = '11111111-1111-1111-1111-111111111111';
SELECT is(
  (SELECT changed_fields->'first_name'->>'new'
   FROM contact_audit_log
   WHERE contact_id = '11111111-1111-1111-1111-111111111111'
     AND operation = 'UPDATE'
   ORDER BY changed_at DESC LIMIT 1),
  'Changed', 'UPDATE diff captured in changed_fields');

SELECT * FROM finish();
ROLLBACK;
```

- [ ] **Step 3: Run + verify**

```bash
npx supabase test db --linked
```

Expected: ok 6 (in addition to existing 26).

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/0080_contacts_triggers.sql supabase/tests/pgtap/contacts_triggers.sql
git commit -m "feat(db): contacts triggers — audit, updated_at, role sync"
```

---

## Task A5: RPCs — `find_potential_duplicates`, `merge_contacts`, `gdpr_anonymize_contact`

**Files:**
- Create: `supabase/migrations/0081_contacts_rpcs.sql`
- Test: `supabase/tests/pgtap/contacts_merge.sql`

- [ ] **Step 1: RPC-Datei**

```sql
-- 0081: Contacts RPCs

-- Find potential duplicates by email/phone/name+birth
CREATE OR REPLACE FUNCTION public.find_potential_duplicates(p_contact_id UUID)
RETURNS TABLE(
  candidate_id UUID,
  match_reason TEXT,
  display_name TEXT
) AS $$
DECLARE
  v_self contacts%ROWTYPE;
  v_phone_e164 TEXT;
BEGIN
  SELECT * INTO v_self FROM contacts WHERE id = p_contact_id;
  IF NOT FOUND THEN RETURN; END IF;

  -- Same email
  RETURN QUERY
    SELECT c.id, 'email match: ' || v_self.primary_email, c.display_name
    FROM contacts c
    WHERE c.id <> p_contact_id
      AND c.archived_at IS NULL
      AND v_self.primary_email IS NOT NULL
      AND c.primary_email = v_self.primary_email;

  -- Same phone (any of the JSON entries)
  RETURN QUERY
    SELECT c.id, 'phone match', c.display_name
    FROM contacts c, jsonb_array_elements(v_self.phones) p_self,
         jsonb_array_elements(c.phones) p_other
    WHERE c.id <> p_contact_id
      AND c.archived_at IS NULL
      AND p_self->>'e164' IS NOT NULL
      AND p_self->>'e164' = p_other->>'e164';

  -- Same name + birth_date (persons only)
  IF v_self.kind = 'person' THEN
    RETURN QUERY
      SELECT c.id, 'name + birth match', c.display_name
      FROM contacts c
      WHERE c.id <> p_contact_id
        AND c.kind = 'person'
        AND c.archived_at IS NULL
        AND lower(c.first_name) = lower(v_self.first_name)
        AND lower(c.last_name)  = lower(v_self.last_name)
        AND v_self.birth_date IS NOT NULL
        AND c.birth_date = v_self.birth_date;
  END IF;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- Merge two contacts: winner keeps id, loser's FKs migrate to winner
CREATE OR REPLACE FUNCTION public.merge_contacts(p_winner UUID, p_loser UUID)
RETURNS VOID AS $$
BEGIN
  IF p_winner = p_loser THEN
    RAISE EXCEPTION 'Cannot merge contact with itself';
  END IF;

  -- Migrate FKs (every table that points at contacts)
  UPDATE course_assignments      SET instructor_id = p_winner WHERE instructor_id = p_loser;
  UPDATE course_participants     SET person_id     = p_winner WHERE person_id     = p_loser;
  UPDATE account_movements       SET instructor_id = p_winner WHERE instructor_id = p_loser;
  UPDATE communication_entries   SET person_id     = p_winner WHERE person_id     = p_loser;
  UPDATE communication_entries   SET instructor_id = p_winner WHERE instructor_id = p_loser;
  UPDATE instructor_skills       SET instructor_id = p_winner WHERE instructor_id = p_loser;
  UPDATE availability_blocks     SET instructor_id = p_winner WHERE instructor_id = p_loser;
  UPDATE intake_checklists       SET person_id     = p_winner WHERE person_id     = p_loser;
  UPDATE contact_relationships   SET from_contact_id = p_winner WHERE from_contact_id = p_loser;
  UPDATE contact_relationships   SET to_contact_id   = p_winner WHERE to_contact_id   = p_loser;

  -- Mark loser as merged-into
  UPDATE contacts
     SET merged_into_id = p_winner,
         archived_at    = now()
   WHERE id = p_loser;

  -- Combined roles
  UPDATE contacts
     SET roles = ARRAY(
       SELECT DISTINCT unnest(roles || (SELECT roles FROM contacts WHERE id = p_loser))
     )
   WHERE id = p_winner;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- GDPR anonymisation: replace PII, keep id + activity history
CREATE OR REPLACE FUNCTION public.gdpr_anonymize_contact(p_contact_id UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE contacts
     SET first_name   = 'Gelöscht',
         last_name    = '#' || substr(id::text, 1, 8),
         legal_name   = CASE WHEN kind = 'organization'
                             THEN 'Gelöschte Organisation #' || substr(id::text, 1, 8)
                             ELSE NULL END,
         trading_name = NULL,
         birth_date   = NULL,
         gender       = NULL,
         primary_email = NULL,
         emails       = '[]'::jsonb,
         phones       = '[]'::jsonb,
         addresses    = '[]'::jsonb,
         notes        = NULL,
         tags         = '{}',
         consent_marketing = false,
         archived_at  = now()
   WHERE id = p_contact_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

- [ ] **Step 2: Merge-Tests**

```sql
-- supabase/tests/pgtap/contacts_merge.sql
BEGIN;
SELECT plan(4);

INSERT INTO contacts (id, kind, first_name, last_name, primary_email)
VALUES
  ('a0000000-0000-0000-0000-000000000001', 'person', 'Sandra', 'Müller', 's@example.com'),
  ('a0000000-0000-0000-0000-000000000002', 'person', 'Sandra', 'Müller', 's@example.com');

-- find_potential_duplicates finds the email match
SELECT set_has(
  $sub$ SELECT candidate_id FROM find_potential_duplicates(
    'a0000000-0000-0000-0000-000000000001') $sub$,
  $exp$ VALUES ('a0000000-0000-0000-0000-000000000002'::uuid) $exp$,
  'find_potential_duplicates returns email match');

-- Merge: assignment FK should migrate
INSERT INTO contact_instructor (contact_id) VALUES
  ('a0000000-0000-0000-0000-000000000002');
-- (assume there's a course_assignment row pointing at loser — created in fixture)
INSERT INTO courses (id, title, start_date, status, type_id)
VALUES ('c0000000-0000-0000-0000-000000000001', 'Test', '2026-05-09', 'tentative',
        (SELECT id FROM course_types LIMIT 1));
INSERT INTO course_assignments (course_id, instructor_id, role)
VALUES ('c0000000-0000-0000-0000-000000000001',
        'a0000000-0000-0000-0000-000000000002', 'haupt');

SELECT merge_contacts(
  'a0000000-0000-0000-0000-000000000001',
  'a0000000-0000-0000-0000-000000000002'
);

SELECT is(
  (SELECT instructor_id FROM course_assignments
   WHERE course_id = 'c0000000-0000-0000-0000-000000000001'),
  'a0000000-0000-0000-0000-000000000001'::uuid,
  'merge migrated assignment FK to winner');

SELECT is(
  (SELECT merged_into_id FROM contacts
   WHERE id = 'a0000000-0000-0000-0000-000000000002'),
  'a0000000-0000-0000-0000-000000000001'::uuid,
  'loser marked merged_into winner');

SELECT is(
  (SELECT archived_at IS NOT NULL FROM contacts
   WHERE id = 'a0000000-0000-0000-0000-000000000002'),
  true, 'loser archived');

SELECT * FROM finish();
ROLLBACK;
```

- [ ] **Step 3: Run + verify**

```bash
npx supabase test db --linked
```

Expected: ok 4.

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/0081_contacts_rpcs.sql supabase/tests/pgtap/contacts_merge.sql
git commit -m "feat(db): contacts RPCs — duplicates, merge, gdpr"
```

---

## Task A6: RLS-Policies

**Files:**
- Create: `supabase/migrations/0084_contacts_rls.sql`
- Test: `supabase/tests/pgtap/contacts_rls.sql`

- [ ] **Step 1: Policies**

```sql
-- 0084: Contacts RLS

ALTER TABLE public.contacts                 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.contact_instructor       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.contact_student          ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.contact_organization     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.contact_relationships    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.contact_audit_log        ENABLE ROW LEVEL SECURITY;

-- Read: any authenticated user
CREATE POLICY contacts_select ON public.contacts
  FOR SELECT TO authenticated USING (true);
CREATE POLICY contact_instructor_select ON public.contact_instructor
  FOR SELECT TO authenticated USING (true);
CREATE POLICY contact_student_select ON public.contact_student
  FOR SELECT TO authenticated USING (true);
CREATE POLICY contact_organization_select ON public.contact_organization
  FOR SELECT TO authenticated USING (true);
CREATE POLICY contact_relationships_select ON public.contact_relationships
  FOR SELECT TO authenticated USING (true);

-- Write: cd, owner, or self-ownership
CREATE POLICY contacts_write_role_based ON public.contacts
  FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM contact_instructor ci
      WHERE ci.auth_user_id = auth.uid()
        AND EXISTS (
          SELECT 1 FROM contacts c
          WHERE c.id = ci.contact_id
            AND ('cd' = ANY(c.roles) OR 'owner' = ANY(c.roles))
        )
    )
    OR owner_id IN (
      SELECT contact_id FROM contact_instructor WHERE auth_user_id = auth.uid()
    )
  );

-- Sidecars: same policy
CREATE POLICY contact_instructor_write ON public.contact_instructor
  FOR ALL TO authenticated
  USING (
    EXISTS (SELECT 1 FROM contacts c
            WHERE c.id = contact_instructor.contact_id
              AND c.owner_id IN (
                SELECT contact_id FROM contact_instructor
                WHERE auth_user_id = auth.uid()))
    OR auth_user_id = auth.uid()
  );

CREATE POLICY contact_student_write ON public.contact_student
  FOR ALL TO authenticated
  USING (true);

CREATE POLICY contact_organization_write ON public.contact_organization
  FOR ALL TO authenticated
  USING (true);

CREATE POLICY contact_relationships_write ON public.contact_relationships
  FOR ALL TO authenticated
  USING (true);

-- Audit log: read-only for authenticated, no writes from app
CREATE POLICY contact_audit_select ON public.contact_audit_log
  FOR SELECT TO authenticated USING (true);
```

- [ ] **Step 2: Test**

```sql
-- supabase/tests/pgtap/contacts_rls.sql
BEGIN;
SELECT plan(2);

SELECT is(
  (SELECT relrowsecurity FROM pg_class WHERE relname = 'contacts'),
  true, 'RLS enabled on contacts');

SELECT is(
  (SELECT count(*)::int FROM pg_policies WHERE tablename = 'contacts'),
  2, 'contacts has 2 policies (select + write)');

SELECT * FROM finish();
ROLLBACK;
```

- [ ] **Step 3: Run + verify + Commit**

```bash
npx supabase test db --linked
git add supabase/migrations/0084_contacts_rls.sql supabase/tests/pgtap/contacts_rls.sql
git commit -m "feat(db): contacts RLS policies"
```

---

# Phase B — Backfill (Migration M1, Daten kopieren)

## Task B1: Backfill-Migration mit Audit-Query

**Files:**
- Create: `supabase/migrations/0082_contacts_backfill.sql`

- [ ] **Step 1: Backfill schreiben — instructors**

```sql
-- 0082: Backfill instructors → contacts + contact_instructor

-- Disable role-sync trigger temporarily — we set roles directly
ALTER TABLE contact_instructor DISABLE TRIGGER trg_sync_instructor_role;
ALTER TABLE contact_student    DISABLE TRIGGER trg_sync_student_role;

-- 1. instructors → contacts (kind=person, roles=['instructor', + maybe 'cd'/'owner'/'dispatcher'])
INSERT INTO public.contacts (
  id, kind, first_name, last_name, primary_email,
  phones, languages, roles, source, created_at
)
SELECT
  id,
  'person'::contact_kind,
  -- Heuristic: split name on first space (most data already had first_name/last_name split in 0049)
  COALESCE(
    NULLIF(split_part(name, ' ', 1), ''), name
  ) AS first_name,
  COALESCE(
    NULLIF(substring(name FROM position(' ' IN name) + 1), ''), '-'
  ) AS last_name,
  email,
  CASE WHEN phone IS NOT NULL
       THEN jsonb_build_array(jsonb_build_object('label','mobile','e164',phone,'primary',true))
       ELSE '[]'::jsonb END,
  '{}',  -- languages — instructors don't have it currently
  ARRAY['instructor', role::text]::text[],
  'legacy_migration',
  created_at
FROM instructors
WHERE NOT EXISTS (SELECT 1 FROM contacts WHERE id = instructors.id);

-- instructors → contact_instructor sidecar
INSERT INTO public.contact_instructor (
  contact_id, auth_user_id, padi_pro_number, padi_level,
  account_balance, active, hire_date, created_at
)
SELECT
  id, auth_user_id, padi_nr, padi_level,
  opening_balance_chf, active, NULL, created_at
FROM instructors
WHERE NOT EXISTS (SELECT 1 FROM contact_instructor WHERE contact_id = instructors.id);
```

- [ ] **Step 2: Backfill — people**

```sql
-- 2. people → contacts + contact_student (or contact_organization for org-kontakte)
INSERT INTO public.contacts (
  id, kind, first_name, last_name, birth_date, primary_email,
  phones, languages, roles, source, notes, created_at
)
SELECT
  p.id,
  'person'::contact_kind,
  p.first_name,
  p.last_name,
  p.birth_date,
  p.email,
  CASE WHEN p.phone IS NOT NULL
       THEN jsonb_build_array(jsonb_build_object('label','mobile','e164',p.phone,'primary',true))
       ELSE '[]'::jsonb END,
  COALESCE(p.languages, '{}'),
  -- roles depends on flags
  ARRAY(
    SELECT unnest FROM (
      SELECT unnest(ARRAY[
        CASE WHEN p.is_student   THEN 'student'   END,
        CASE WHEN p.is_candidate THEN 'candidate' END
      ])
    ) WHERE unnest IS NOT NULL
  )::text[],
  'legacy_migration',
  p.notes,
  p.created_at
FROM people p
WHERE NOT EXISTS (SELECT 1 FROM contacts WHERE id = p.id);

-- people → contact_student
INSERT INTO public.contact_student (
  contact_id, pipeline_stage, lead_source, highest_brevet,
  intake_status, external_brevet_history, is_candidate,
  candidate_target_level, created_at
)
SELECT
  p.id, p.pipeline_stage, p.lead_source, p.highest_brevet,
  p.intake_status, COALESCE(p.external_brevet_history, '[]'::jsonb),
  p.is_candidate, p.candidate_target_level, p.created_at
FROM people p
WHERE (p.is_student OR p.is_candidate)
  AND NOT EXISTS (SELECT 1 FROM contact_student WHERE contact_id = p.id);
```

- [ ] **Step 3: Backfill — organizations**

```sql
-- 3. organizations → contacts (kind=organization) + contact_organization
INSERT INTO public.contacts (
  id, kind, legal_name, trading_name, primary_email,
  addresses, languages, roles, source, notes, created_at
)
SELECT
  o.id,
  'organization'::contact_kind,
  o.name AS legal_name,
  NULL,
  o.email,
  CASE WHEN o.address IS NOT NULL
       THEN jsonb_build_array(jsonb_build_object('label','main','street',o.address,'primary',true))
       ELSE '[]'::jsonb END,
  '{}',
  ARRAY['organization_profile'],
  'legacy_migration',
  o.notes,
  o.created_at
FROM organizations o
WHERE NOT EXISTS (SELECT 1 FROM contacts WHERE id = o.id);

INSERT INTO public.contact_organization (
  contact_id, org_kind, created_at
)
SELECT id, kind, created_at
FROM organizations
WHERE NOT EXISTS (SELECT 1 FROM contact_organization WHERE contact_id = organizations.id);

-- people.organization_id → contact_relationships works_at
INSERT INTO public.contact_relationships (from_contact_id, to_contact_id, kind, is_primary)
SELECT id, organization_id, 'works_at', true
FROM people
WHERE organization_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM contact_relationships
    WHERE from_contact_id = people.id
      AND to_contact_id = people.organization_id
      AND kind = 'works_at'
  );

-- Re-enable triggers
ALTER TABLE contact_instructor ENABLE TRIGGER trg_sync_instructor_role;
ALTER TABLE contact_student    ENABLE TRIGGER trg_sync_student_role;
```

- [ ] **Step 4: Smoke-Test-Migration anhängen**

```sql
-- Verify counts match
DO $$
DECLARE
  v_old_total INT;
  v_new_total INT;
BEGIN
  SELECT (SELECT count(*) FROM instructors)
       + (SELECT count(*) FROM people)
       + (SELECT count(*) FROM organizations)
  INTO v_old_total;

  SELECT count(*) FROM contacts WHERE source = 'legacy_migration'
  INTO v_new_total;

  IF v_old_total <> v_new_total THEN
    RAISE EXCEPTION 'Backfill count mismatch: legacy=% new=%', v_old_total, v_new_total;
  END IF;

  RAISE NOTICE '0082: Backfilled % contacts (matches legacy total)', v_new_total;
END $$;
```

- [ ] **Step 5: Run + verify**

```bash
npx supabase db reset --no-seed
npx supabase migration up
npx supabase test db --linked
```

Expected: NOTICE-Output zeigt korrekte Zählung, alle Tests grün.

- [ ] **Step 6: Commit**

```bash
git add supabase/migrations/0082_contacts_backfill.sql
git commit -m "feat(db): backfill contacts from instructors/people/organizations (Phase M1)"
```

---

## Task B2: Dedup-Audit-Skript

**Files:**
- Create: `scripts/db/contacts-dedup-audit.sh`
- Create: `scripts/db/contacts-dedup-audit.sql`

- [ ] **Step 1: SQL-Audit-Query**

```sql
-- scripts/db/contacts-dedup-audit.sql
-- Findet Personen die in instructors UND people existieren mit gleicher
-- Email oder gleicher Name+Geburtsdatum-Kombo.

WITH overlaps AS (
  -- Same email
  SELECT
    'email' AS match_kind,
    i.id AS instructor_id, i.name AS instructor_name,
    p.id AS person_id, p.first_name || ' ' || p.last_name AS person_name,
    i.email AS shared_email,
    NULL::DATE AS shared_birth
  FROM instructors i
  JOIN people p ON lower(i.email) = lower(p.email)
  WHERE i.email IS NOT NULL AND p.email IS NOT NULL

  UNION ALL

  -- Same name + birth_date
  SELECT
    'name+birth' AS match_kind,
    i.id, i.name,
    p.id, p.first_name || ' ' || p.last_name,
    NULL::TEXT, p.birth_date
  FROM instructors i
  JOIN people p ON
    lower(split_part(i.name, ' ', 1)) = lower(p.first_name)
    AND lower(substring(i.name FROM position(' ' IN i.name) + 1)) = lower(p.last_name)
    AND p.birth_date IS NOT NULL
)
SELECT * FROM overlaps
ORDER BY match_kind, instructor_name;
```

- [ ] **Step 2: Bash-Wrapper**

```bash
#!/usr/bin/env bash
# scripts/db/contacts-dedup-audit.sh
# Outputs CSV of potential duplicate pairs across instructors+people.
# Usage: ./scripts/db/contacts-dedup-audit.sh > dedup-candidates.csv

set -euo pipefail

if [[ -z "${DATABASE_URL:-}" ]]; then
  echo "❌ Set DATABASE_URL (Supabase project connection string)" >&2
  exit 1
fi

psql "$DATABASE_URL" \
  --csv \
  -f "$(dirname "$0")/contacts-dedup-audit.sql"
```

- [ ] **Step 3: Permissions + run**

```bash
chmod +x scripts/db/contacts-dedup-audit.sh
DATABASE_URL=$(npx supabase status --output json | jq -r '.db.url') \
  ./scripts/db/contacts-dedup-audit.sh > /tmp/dedup-candidates.csv
head /tmp/dedup-candidates.csv
```

Expected: CSV mit Spalten `match_kind,instructor_id,instructor_name,person_id,person_name,shared_email,shared_birth`. Leere Datei = keine Duplikate (auch ok).

- [ ] **Step 4: Commit**

```bash
git add scripts/db/contacts-dedup-audit.sh scripts/db/contacts-dedup-audit.sql
git commit -m "tools(db): dedup audit script for contacts migration"
```

---

# Phase C — Compatibility Views (Migration M2)

## Task C1: instructors-View + people-View + organizations-View

**Files:**
- Create: `supabase/migrations/0083_contacts_compat_views.sql`

- [ ] **Step 1: Tabellen umbenennen + Views anlegen**

```sql
-- 0083: Compatibility views — frontend code reads via views during M2

-- 1. Rename original tables
ALTER TABLE public.instructors    RENAME TO instructors_legacy;
ALTER TABLE public.people         RENAME TO people_legacy;
ALTER TABLE public.organizations  RENAME TO organizations_legacy;

-- 2. instructors view
CREATE VIEW public.instructors AS
SELECT
  c.id,
  c.first_name || ' ' || c.last_name AS name,
  ci.padi_pro_number AS padi_nr,
  ci.padi_level,
  c.primary_email AS email,
  (c.phones->0->>'e164') AS phone,
  '#0A84FF' AS color,           -- legacy: avatar color, no longer used
  upper(left(c.first_name, 1) || left(c.last_name, 1)) AS initials,
  ci.active,
  COALESCE(
    (SELECT r FROM unnest(c.roles) r
     WHERE r IN ('owner','cd','dispatcher','instructor') LIMIT 1),
    'instructor'
  )::app_role AS role,
  ci.account_balance AS opening_balance_chf,
  ci.auth_user_id,
  c.created_at,
  c.updated_at
FROM public.contacts c
JOIN public.contact_instructor ci ON ci.contact_id = c.id
WHERE c.archived_at IS NULL;

-- 3. people view
CREATE VIEW public.people AS
SELECT
  c.id,
  c.first_name,
  c.last_name,
  c.first_name || ' ' || c.last_name AS name,
  c.birth_date,
  c.primary_email AS email,
  (c.phones->0->>'e164') AS phone,
  c.languages,
  cs.pipeline_stage,
  cs.lead_source,
  cs.highest_brevet,
  cs.intake_status,
  cs.external_brevet_history,
  cs.is_candidate,
  cs.candidate_target_level,
  'student' = ANY(c.roles) AS is_student,
  (SELECT r.to_contact_id FROM contact_relationships r
   WHERE r.from_contact_id = c.id AND r.kind = 'works_at' AND r.is_primary
   LIMIT 1) AS organization_id,
  c.notes,
  c.created_at,
  c.updated_at
FROM public.contacts c
LEFT JOIN public.contact_student cs ON cs.contact_id = c.id
WHERE c.kind = 'person' AND c.archived_at IS NULL;

-- 4. organizations view
CREATE VIEW public.organizations AS
SELECT
  c.id,
  c.legal_name AS name,
  co.org_kind AS kind,
  c.primary_email AS email,
  (c.addresses->0->>'street') AS address,
  c.notes,
  c.created_at,
  c.updated_at
FROM public.contacts c
JOIN public.contact_organization co ON co.contact_id = c.id
WHERE c.kind = 'organization' AND c.archived_at IS NULL;

-- Grants
GRANT SELECT ON public.instructors   TO authenticated;
GRANT SELECT ON public.people        TO authenticated;
GRANT SELECT ON public.organizations TO authenticated;
```

- [ ] **Step 2: Run + verify shape**

```bash
npx supabase migration up
DATABASE_URL=$(npx supabase status --output json | jq -r '.db.url')
psql "$DATABASE_URL" -c "SELECT count(*) FROM instructors;"
psql "$DATABASE_URL" -c "SELECT count(*) FROM instructors_legacy;"
```

Expected: counts identisch.

- [ ] **Step 3: Smoke-Test pgTAP — counts identisch**

```sql
-- supabase/tests/pgtap/contacts_backfill_smoke.sql
BEGIN;
SELECT plan(3);

SELECT is(
  (SELECT count(*)::int FROM instructors),
  (SELECT count(*)::int FROM instructors_legacy),
  'instructors view = legacy count');

SELECT is(
  (SELECT count(*)::int FROM people),
  (SELECT count(*)::int FROM people_legacy),
  'people view = legacy count');

SELECT is(
  (SELECT count(*)::int FROM organizations),
  (SELECT count(*)::int FROM organizations_legacy),
  'organizations view = legacy count');

SELECT * FROM finish();
ROLLBACK;
```

```bash
npx supabase test db --linked
```

Expected: ok 3.

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/0083_contacts_compat_views.sql \
        supabase/tests/pgtap/contacts_backfill_smoke.sql
git commit -m "feat(db): compatibility views for legacy code (Phase M2)"
```

---

## Task C2: Frontend baut weiterhin grün auf den Views

- [ ] **Step 1: Smoke-Test Frontend startet**

```bash
cd apps/web
npm run build
```

Expected: build success, keine Type-Errors.

- [ ] **Step 2: Dev-Server starten + manueller Smoke-Test**

```bash
cd apps/web
npm run dev
```

Manuell testen:
- Login funktioniert
- Heute-Dashboard lädt
- Kursliste lädt
- TL/DM-Liste lädt
- Schüler-Liste lädt
- CD-Pipeline lädt

- [ ] **Step 3: Commit (kein Code-Change, aber Notiz)**

```bash
git commit --allow-empty -m "verify: M2 compat views — frontend works unchanged"
```

---

# Phase D — Foundation Components (Inline-Edit-Bausteine)

## Task D1: TypeScript-Types für Contact-Domäne

**Files:**
- Create: `apps/web/src/types/contacts.ts`

- [ ] **Step 1: Type-Definitionen**

```typescript
// apps/web/src/types/contacts.ts

export type ContactKind = 'person' | 'organization'

export type ContactRole =
  | 'instructor' | 'student' | 'candidate' | 'organization_profile'
  | 'cd' | 'owner' | 'dispatcher'
  | 'newsletter' | 'supplier' | 'partner_rep' | 'authority'

export type RelationshipKind =
  | 'works_at' | 'owns' | 'spouse_of' | 'child_of' | 'parent_of'
  | 'referred_by' | 'subsidiary_of' | 'partner_of' | 'supplier_of'
  | 'student_of' | 'mentor_of'

export interface PhoneEntry {
  label: 'mobile' | 'work' | 'home' | 'whatsapp' | 'other'
  e164: string
  primary?: boolean
  whatsapp?: boolean
}

export interface EmailEntry {
  label: 'personal' | 'work' | 'other'
  email: string
  primary?: boolean
}

export interface AddressEntry {
  label: 'home' | 'work' | 'billing' | 'shipping' | 'main' | 'other'
  street?: string
  city?: string
  postal?: string
  country?: string
  primary?: boolean
}

export interface Contact {
  id: string
  kind: ContactKind
  first_name?: string | null
  last_name?: string | null
  birth_date?: string | null
  gender?: string | null
  legal_name?: string | null
  trading_name?: string | null
  display_name: string
  primary_email?: string | null
  emails: EmailEntry[]
  phones: PhoneEntry[]
  addresses: AddressEntry[]
  languages: string[]
  roles: ContactRole[]
  tags: string[]
  notes?: string | null
  owner_id?: string | null
  consent_marketing: boolean
  consent_marketing_at?: string | null
  consent_marketing_source?: string | null
  source?: string | null
  archived_at?: string | null
  merged_into_id?: string | null
  created_at: string
  updated_at: string
}

export interface ContactInstructor {
  contact_id: string
  auth_user_id?: string | null
  padi_pro_number?: string | null
  padi_level?: string | null
  account_balance: number
  hourly_rate_chf?: number | null
  daily_rate_chf?: number | null
  active: boolean
  hire_date?: string | null
  termination_date?: string | null
  emergency_contact_name?: string | null
  emergency_contact_phone?: string | null
  notes_internal?: string | null
}

export interface ContactStudent {
  contact_id: string
  pipeline_stage?: string | null
  lead_source?: string | null
  highest_brevet?: string | null
  intake_status?: string | null
  external_brevet_history: unknown[]
  is_candidate: boolean
  candidate_target_level?: string | null
  medical_clearance_at?: string | null
  insurance_provider?: string | null
}

export interface ContactOrganization {
  contact_id: string
  org_kind: string
  tax_id?: string | null
  billing_email?: string | null
  parent_org_id?: string | null
  contract_type?: string | null
  contract_until?: string | null
  payment_terms?: string | null
}

export interface ContactRelationship {
  id: string
  from_contact_id: string
  to_contact_id: string
  kind: RelationshipKind
  role_at_org?: string | null
  started_at?: string | null
  ended_at?: string | null
  is_primary: boolean
  notes?: string | null
  created_at: string
}

export interface ContactWithSidecars extends Contact {
  instructor?: ContactInstructor | null
  student?: ContactStudent | null
  organization?: ContactOrganization | null
}
```

- [ ] **Step 2: Type-Check**

```bash
cd apps/web && npx tsc --noEmit
```

Expected: keine Errors (es gibt nur den neuen Type, noch kein Consumer).

- [ ] **Step 3: Commit**

```bash
git add apps/web/src/types/contacts.ts
git commit -m "feat(types): contact domain types"
```

---

## Task D2: Supabase-Queries für Contacts

**Files:**
- Create: `apps/web/src/lib/contactQueries.ts`

- [ ] **Step 1: Query-Funktionen**

```typescript
// apps/web/src/lib/contactQueries.ts
import { supabase } from './supabase'
import type {
  Contact, ContactWithSidecars, ContactRelationship,
  ContactRole, ContactKind, EmailEntry, PhoneEntry, AddressEntry,
} from '../types/contacts'

export interface ContactListFilter {
  kind?: ContactKind
  roles?: ContactRole[]
  searchText?: string
  archivedOnly?: boolean
  ownerId?: string
  pipelineStage?: string
  hasUpcomingBirthday?: boolean
}

export async function listContacts(
  filter: ContactListFilter = {},
  page = 0, pageSize = 50
): Promise<{ rows: Contact[]; count: number }> {
  let query = supabase
    .from('contacts')
    .select('*', { count: 'exact' })
    .is('archived_at', null)
    .order('display_name')
    .range(page * pageSize, page * pageSize + pageSize - 1)

  if (filter.kind) query = query.eq('kind', filter.kind)
  if (filter.roles?.length) query = query.contains('roles', filter.roles)
  if (filter.searchText) {
    query = query.textSearch(
      'fts',
      filter.searchText.split(/\s+/).map(s => s + ':*').join(' & '),
      { config: 'simple' }
    )
  }
  if (filter.ownerId) query = query.eq('owner_id', filter.ownerId)

  const { data, error, count } = await query
  if (error) throw error
  return { rows: (data ?? []) as Contact[], count: count ?? 0 }
}

export async function getContactWithSidecars(id: string): Promise<ContactWithSidecars | null> {
  const { data, error } = await supabase
    .from('contacts')
    .select(`
      *,
      instructor:contact_instructor(*),
      student:contact_student(*),
      organization:contact_organization(*)
    `)
    .eq('id', id)
    .single()
  if (error) {
    if (error.code === 'PGRST116') return null
    throw error
  }
  return data as ContactWithSidecars
}

export async function updateContactField<K extends keyof Contact>(
  id: string, field: K, value: Contact[K]
): Promise<void> {
  const { error } = await supabase.from('contacts')
    .update({ [field]: value }).eq('id', id)
  if (error) throw error
}

export async function updateInstructorField(
  contactId: string, field: string, value: unknown
): Promise<void> {
  const { error } = await supabase.from('contact_instructor')
    .update({ [field]: value }).eq('contact_id', contactId)
  if (error) throw error
}

export async function updateStudentField(
  contactId: string, field: string, value: unknown
): Promise<void> {
  const { error } = await supabase.from('contact_student')
    .update({ [field]: value }).eq('contact_id', contactId)
  if (error) throw error
}

export async function listRelationships(contactId: string): Promise<ContactRelationship[]> {
  const { data, error } = await supabase
    .from('contact_relationships')
    .select('*')
    .or(`from_contact_id.eq.${contactId},to_contact_id.eq.${contactId}`)
    .order('is_primary', { ascending: false })
    .order('created_at')
  if (error) throw error
  return (data ?? []) as ContactRelationship[]
}

export async function findPotentialDuplicates(contactId: string): Promise<
  { candidate_id: string; match_reason: string; display_name: string }[]
> {
  const { data, error } = await supabase
    .rpc('find_potential_duplicates', { p_contact_id: contactId })
  if (error) throw error
  return (data ?? []) as never[]
}

export async function mergeContacts(winner: string, loser: string): Promise<void> {
  const { error } = await supabase
    .rpc('merge_contacts', { p_winner: winner, p_loser: loser })
  if (error) throw error
}

export async function gdprAnonymize(contactId: string): Promise<void> {
  const { error } = await supabase
    .rpc('gdpr_anonymize_contact', { p_contact_id: contactId })
  if (error) throw error
}

export async function createContact(input: {
  kind: ContactKind
  first_name?: string; last_name?: string; legal_name?: string
  primary_email?: string; phones?: PhoneEntry[]
  roles: ContactRole[]
}): Promise<string> {
  const { data, error } = await supabase
    .from('contacts')
    .insert({ ...input, source: 'manual' })
    .select('id').single()
  if (error) throw error
  return data!.id
}

export async function addRelationship(input: {
  from_contact_id: string; to_contact_id: string
  kind: ContactRelationship['kind']; role_at_org?: string
  is_primary?: boolean
}): Promise<void> {
  const { error } = await supabase.from('contact_relationships').insert(input)
  if (error) throw error
}

export async function archiveContact(id: string): Promise<void> {
  const { error } = await supabase.from('contacts')
    .update({ archived_at: new Date().toISOString() }).eq('id', id)
  if (error) throw error
}
```

- [ ] **Step 2: Type-check + commit**

```bash
cd apps/web && npx tsc --noEmit
git add apps/web/src/lib/contactQueries.ts
git commit -m "feat(lib): contact query layer"
```

---

## Task D3: Inline-Edit-Komponenten (Foundation)

**Files:**
- Create: `apps/web/src/foundation/compounds/InlineField.tsx`
- Create: `apps/web/src/foundation/compounds/InlineTextField.tsx`
- Create: `apps/web/src/foundation/compounds/InlineSelectField.tsx`

- [ ] **Step 1: InlineField (generischer Wrapper)**

```typescript
// apps/web/src/foundation/compounds/InlineField.tsx
import { useState, type ReactNode } from 'react'

interface InlineFieldProps<T> {
  label: string
  value: T
  display: (v: T) => ReactNode
  edit: (v: T, setV: (v: T) => void, commit: () => void, cancel: () => void) => ReactNode
  onCommit: (v: T) => Promise<void>
  disabled?: boolean
}

export function InlineField<T>({ label, value, display, edit, onCommit, disabled }: InlineFieldProps<T>) {
  const [editing, setEditing] = useState(false)
  const [draft, setDraft] = useState<T>(value)
  const [saving, setSaving] = useState(false)
  const [err, setErr] = useState<string | null>(null)

  async function commit() {
    setSaving(true); setErr(null)
    try {
      await onCommit(draft)
      setEditing(false)
    } catch (e) {
      setErr((e as Error).message)
    } finally {
      setSaving(false)
    }
  }

  function cancel() {
    setDraft(value)
    setEditing(false)
    setErr(null)
  }

  return (
    <div className="inline-field" data-editing={editing} data-saving={saving}>
      <div className="inline-field__label">{label}</div>
      {editing ? (
        <div className="inline-field__edit">
          {edit(draft, setDraft, commit, cancel)}
          {err && <div className="inline-field__error">{err}</div>}
        </div>
      ) : (
        <div
          className="inline-field__display"
          tabIndex={disabled ? -1 : 0}
          onClick={() => !disabled && setEditing(true)}
          onKeyDown={(e) => { if (!disabled && (e.key === 'Enter' || e.key === ' ')) setEditing(true) }}
          role="button"
        >
          {display(value) || <span className="inline-field__empty">—</span>}
        </div>
      )}
    </div>
  )
}
```

- [ ] **Step 2: InlineTextField**

```typescript
// apps/web/src/foundation/compounds/InlineTextField.tsx
import { InlineField } from './InlineField'

interface Props {
  label: string
  value: string | null | undefined
  onCommit: (v: string) => Promise<void>
  placeholder?: string
  multiline?: boolean
  disabled?: boolean
}

export function InlineTextField({ label, value, onCommit, placeholder, multiline, disabled }: Props) {
  return (
    <InlineField<string>
      label={label}
      value={value ?? ''}
      display={(v) => v || null}
      edit={(v, setV, commit, cancel) =>
        multiline ? (
          <textarea
            value={v}
            autoFocus
            onChange={(e) => setV(e.target.value)}
            onBlur={commit}
            onKeyDown={(e) => {
              if (e.key === 'Escape') cancel()
              if (e.key === 'Enter' && (e.metaKey || e.ctrlKey)) commit()
            }}
            placeholder={placeholder}
            rows={4}
          />
        ) : (
          <input
            type="text"
            value={v}
            autoFocus
            onChange={(e) => setV(e.target.value)}
            onBlur={commit}
            onKeyDown={(e) => {
              if (e.key === 'Escape') cancel()
              if (e.key === 'Enter') commit()
            }}
            placeholder={placeholder}
          />
        )
      }
      onCommit={onCommit}
      disabled={disabled}
    />
  )
}
```

- [ ] **Step 3: InlineSelectField**

```typescript
// apps/web/src/foundation/compounds/InlineSelectField.tsx
import { InlineField } from './InlineField'

interface Props<T extends string> {
  label: string
  value: T | null | undefined
  options: { value: T; label: string }[]
  onCommit: (v: T | null) => Promise<void>
  allowEmpty?: boolean
  disabled?: boolean
}

export function InlineSelectField<T extends string>({
  label, value, options, onCommit, allowEmpty, disabled,
}: Props<T>) {
  return (
    <InlineField<T | null>
      label={label}
      value={value ?? null}
      display={(v) => options.find(o => o.value === v)?.label ?? null}
      edit={(v, setV, commit, cancel) => (
        <select
          value={v ?? ''}
          autoFocus
          onChange={(e) => setV((e.target.value || null) as T | null)}
          onBlur={commit}
          onKeyDown={(e) => {
            if (e.key === 'Escape') cancel()
            if (e.key === 'Enter') commit()
          }}
        >
          {allowEmpty && <option value="">—</option>}
          {options.map(o => <option key={o.value} value={o.value}>{o.label}</option>)}
        </select>
      )}
      onCommit={onCommit}
      disabled={disabled}
    />
  )
}
```

- [ ] **Step 4: CSS-Tokens für inline-field**

Append to `apps/web/src/foundation/tokens.css`:

```css
.inline-field { display: flex; gap: var(--space-3); padding: var(--space-2) 0; }
.inline-field__label { color: var(--color-text-muted); font-size: var(--text-sm); min-width: 8rem; }
.inline-field__display { flex: 1; cursor: pointer; padding: var(--space-1) var(--space-2); border-radius: var(--radius-sm); }
.inline-field__display:hover { background: var(--color-bg-hover); }
.inline-field__display:focus-visible { outline: 2px solid var(--color-brand-blue); }
.inline-field__edit input,
.inline-field__edit textarea,
.inline-field__edit select { width: 100%; padding: var(--space-1) var(--space-2); border: 1px solid var(--color-border); border-radius: var(--radius-sm); }
.inline-field__empty { color: var(--color-text-muted); font-style: italic; }
.inline-field__error { color: var(--color-brand-red); font-size: var(--text-xs); margin-top: var(--space-1); }
.inline-field[data-saving='true'] .inline-field__edit { opacity: 0.6; pointer-events: none; }
```

- [ ] **Step 5: Type-check + Commit**

```bash
cd apps/web && npx tsc --noEmit
git add apps/web/src/foundation/compounds/InlineField.tsx \
        apps/web/src/foundation/compounds/InlineTextField.tsx \
        apps/web/src/foundation/compounds/InlineSelectField.tsx \
        apps/web/src/foundation/tokens.css
git commit -m "feat(foundation): inline-edit field primitives"
```

---

## Task D4: PhoneList, EmailList, AddressList Compounds

**Files:**
- Create: `apps/web/src/foundation/compounds/PhoneList.tsx`
- Create: `apps/web/src/foundation/compounds/EmailList.tsx`
- Create: `apps/web/src/foundation/compounds/AddressList.tsx`

- [ ] **Step 1: PhoneList**

```typescript
// apps/web/src/foundation/compounds/PhoneList.tsx
import { useState } from 'react'
import { parsePhoneNumberFromString } from 'libphonenumber-js'
import type { PhoneEntry } from '../../types/contacts'

interface Props {
  phones: PhoneEntry[]
  onChange: (next: PhoneEntry[]) => Promise<void>
  disabled?: boolean
}

export function PhoneList({ phones, onChange, disabled }: Props) {
  const [adding, setAdding] = useState(false)
  const [draft, setDraft] = useState({ label: 'mobile' as PhoneEntry['label'], raw: '' })
  const [err, setErr] = useState<string | null>(null)

  async function add() {
    setErr(null)
    const parsed = parsePhoneNumberFromString(draft.raw, 'CH')
    if (!parsed?.isValid()) { setErr('Ungültige Telefonnummer'); return }
    const next: PhoneEntry = {
      label: draft.label,
      e164: parsed.number,
      whatsapp: draft.label === 'whatsapp',
      primary: phones.length === 0,
    }
    await onChange([...phones, next])
    setAdding(false)
    setDraft({ label: 'mobile', raw: '' })
  }

  async function remove(idx: number) {
    const next = phones.filter((_, i) => i !== idx)
    if (next.length > 0 && !next.some(p => p.primary)) next[0].primary = true
    await onChange(next)
  }

  async function makePrimary(idx: number) {
    await onChange(phones.map((p, i) => ({ ...p, primary: i === idx })))
  }

  return (
    <div className="phone-list">
      {phones.map((p, i) => (
        <div key={i} className="phone-list__row">
          <span className="phone-list__label">{p.label}</span>
          <a href={`tel:${p.e164}`} className="phone-list__num">{p.e164}</a>
          {p.primary && <span className="phone-list__pri">PRIMARY</span>}
          {!disabled && !p.primary &&
            <button type="button" onClick={() => makePrimary(i)}>als Haupt</button>}
          {!disabled &&
            <button type="button" onClick={() => remove(i)}>×</button>}
        </div>
      ))}
      {!disabled && (adding ? (
        <div className="phone-list__add">
          <select value={draft.label}
                  onChange={(e) => setDraft({ ...draft, label: e.target.value as PhoneEntry['label'] })}>
            <option value="mobile">Mobile</option>
            <option value="work">Work</option>
            <option value="home">Home</option>
            <option value="whatsapp">WhatsApp</option>
            <option value="other">Other</option>
          </select>
          <input value={draft.raw} placeholder="+41 79 123 45 67" autoFocus
                 onChange={(e) => setDraft({ ...draft, raw: e.target.value })}
                 onKeyDown={(e) => { if (e.key === 'Enter') add() }} />
          <button type="button" onClick={add}>Hinzufügen</button>
          <button type="button" onClick={() => setAdding(false)}>Abbrechen</button>
          {err && <div className="phone-list__error">{err}</div>}
        </div>
      ) : (
        <button type="button" className="phone-list__add-btn" onClick={() => setAdding(true)}>
          + Telefon hinzufügen
        </button>
      ))}
    </div>
  )
}
```

- [ ] **Step 2: EmailList (analoges Pattern, einfacher — Email-Validation)**

```typescript
// apps/web/src/foundation/compounds/EmailList.tsx
import { useState } from 'react'
import type { EmailEntry } from '../../types/contacts'

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/

interface Props {
  emails: EmailEntry[]
  onChange: (next: EmailEntry[]) => Promise<void>
  disabled?: boolean
}

export function EmailList({ emails, onChange, disabled }: Props) {
  const [adding, setAdding] = useState(false)
  const [draft, setDraft] = useState({ label: 'personal' as EmailEntry['label'], email: '' })
  const [err, setErr] = useState<string | null>(null)

  async function add() {
    setErr(null)
    if (!EMAIL_RE.test(draft.email)) { setErr('Ungültige Email'); return }
    const next: EmailEntry = { ...draft, primary: emails.length === 0 }
    await onChange([...emails, next])
    setAdding(false)
    setDraft({ label: 'personal', email: '' })
  }

  async function remove(idx: number) {
    const next = emails.filter((_, i) => i !== idx)
    if (next.length > 0 && !next.some(e => e.primary)) next[0].primary = true
    await onChange(next)
  }

  async function makePrimary(idx: number) {
    await onChange(emails.map((e, i) => ({ ...e, primary: i === idx })))
  }

  return (
    <div className="email-list">
      {emails.map((e, i) => (
        <div key={i} className="email-list__row">
          <span className="email-list__label">{e.label}</span>
          <a href={`mailto:${e.email}`} className="email-list__addr">{e.email}</a>
          {e.primary && <span className="email-list__pri">PRIMARY</span>}
          {!disabled && !e.primary &&
            <button type="button" onClick={() => makePrimary(i)}>als Haupt</button>}
          {!disabled &&
            <button type="button" onClick={() => remove(i)}>×</button>}
        </div>
      ))}
      {!disabled && (adding ? (
        <div className="email-list__add">
          <select value={draft.label}
                  onChange={(e) => setDraft({ ...draft, label: e.target.value as EmailEntry['label'] })}>
            <option value="personal">Personal</option>
            <option value="work">Work</option>
            <option value="other">Other</option>
          </select>
          <input value={draft.email} placeholder="name@example.com" type="email" autoFocus
                 onChange={(e) => setDraft({ ...draft, email: e.target.value })}
                 onKeyDown={(e) => { if (e.key === 'Enter') add() }} />
          <button type="button" onClick={add}>Hinzufügen</button>
          <button type="button" onClick={() => setAdding(false)}>Abbrechen</button>
          {err && <div className="email-list__error">{err}</div>}
        </div>
      ) : (
        <button type="button" className="email-list__add-btn" onClick={() => setAdding(true)}>
          + Email hinzufügen
        </button>
      ))}
    </div>
  )
}
```

- [ ] **Step 3: AddressList**

```typescript
// apps/web/src/foundation/compounds/AddressList.tsx
import { useState } from 'react'
import type { AddressEntry } from '../../types/contacts'

interface Props {
  addresses: AddressEntry[]
  onChange: (next: AddressEntry[]) => Promise<void>
  disabled?: boolean
}

const EMPTY: AddressEntry = { label: 'home', street: '', city: '', postal: '', country: 'CH' }

export function AddressList({ addresses, onChange, disabled }: Props) {
  const [editing, setEditing] = useState<number | null>(null)
  const [draft, setDraft] = useState<AddressEntry>(EMPTY)

  function startAdd() { setDraft({ ...EMPTY }); setEditing(addresses.length) }
  function startEdit(i: number) { setDraft({ ...addresses[i] }); setEditing(i) }

  async function commit() {
    if (editing === null) return
    const next = [...addresses]
    next[editing] = draft
    if (next.length > 0 && !next.some(a => a.primary)) next[0].primary = true
    await onChange(next)
    setEditing(null)
  }

  async function remove(idx: number) {
    const next = addresses.filter((_, i) => i !== idx)
    if (next.length > 0 && !next.some(a => a.primary)) next[0].primary = true
    await onChange(next)
  }

  return (
    <div className="address-list">
      {addresses.map((a, i) => (
        <div key={i} className="address-list__row">
          <span className="address-list__label">{a.label}</span>
          <div className="address-list__addr">
            {a.street}<br/>{a.postal} {a.city}<br/>{a.country}
          </div>
          {a.primary && <span className="address-list__pri">PRIMARY</span>}
          {!disabled && (
            <>
              <button type="button" onClick={() => startEdit(i)}>✎</button>
              <button type="button" onClick={() => remove(i)}>×</button>
            </>
          )}
        </div>
      ))}
      {!disabled && editing !== null && (
        <div className="address-list__form">
          <select value={draft.label}
                  onChange={(e) => setDraft({ ...draft, label: e.target.value as AddressEntry['label'] })}>
            <option value="home">Home</option><option value="work">Work</option>
            <option value="billing">Billing</option><option value="shipping">Shipping</option>
            <option value="main">Main</option><option value="other">Other</option>
          </select>
          <input placeholder="Strasse + Nr" value={draft.street ?? ''}
                 onChange={(e) => setDraft({ ...draft, street: e.target.value })} />
          <input placeholder="PLZ" value={draft.postal ?? ''}
                 onChange={(e) => setDraft({ ...draft, postal: e.target.value })} />
          <input placeholder="Ort" value={draft.city ?? ''}
                 onChange={(e) => setDraft({ ...draft, city: e.target.value })} />
          <input placeholder="Land (CH/DE/…)" value={draft.country ?? ''}
                 onChange={(e) => setDraft({ ...draft, country: e.target.value })} />
          <button type="button" onClick={commit}>Speichern</button>
          <button type="button" onClick={() => setEditing(null)}>Abbrechen</button>
        </div>
      )}
      {!disabled && editing === null && (
        <button type="button" className="address-list__add-btn" onClick={startAdd}>
          + Adresse hinzufügen
        </button>
      )}
    </div>
  )
}
```

- [ ] **Step 4: libphonenumber-js installieren + Type-check + Commit**

```bash
cd apps/web
npm install libphonenumber-js
npx tsc --noEmit
git add apps/web/package.json apps/web/package-lock.json \
        apps/web/src/foundation/compounds/PhoneList.tsx \
        apps/web/src/foundation/compounds/EmailList.tsx \
        apps/web/src/foundation/compounds/AddressList.tsx
git commit -m "feat(foundation): phone/email/address list compounds"
```

---

## Task D5: ContactHeader + RolesBadgeList Compounds

**Files:**
- Create: `apps/web/src/foundation/compounds/ContactHeader.tsx`
- Create: `apps/web/src/foundation/compounds/RolesBadgeList.tsx`

- [ ] **Step 1: RolesBadgeList**

```typescript
// apps/web/src/foundation/compounds/RolesBadgeList.tsx
import type { ContactRole } from '../../types/contacts'

const COLOR_BY_ROLE: Record<ContactRole, string> = {
  instructor:    'var(--color-brand-blue)',
  student:       'var(--color-brand-teal)',
  candidate:     'var(--color-brand-amber)',
  organization_profile: 'var(--color-brand-purple)',
  cd:            'var(--color-brand-deep)',
  owner:         'var(--color-brand-red)',
  dispatcher:    'var(--color-brand-pink)',
  newsletter:    'var(--color-text-muted)',
  supplier:      'var(--color-brand-sand)',
  partner_rep:   'var(--color-brand-sand)',
  authority:     'var(--color-text-muted)',
}

const LABEL_BY_ROLE: Record<ContactRole, string> = {
  instructor: 'TL/DM', student: 'Schüler', candidate: 'Kandidat',
  organization_profile: 'Org', cd: 'CD', owner: 'Owner', dispatcher: 'Dispatcher',
  newsletter: 'Newsletter', supplier: 'Lieferant', partner_rep: 'Partner', authority: 'Behörde',
}

interface Props { roles: ContactRole[]; onClick?: (role: ContactRole) => void }

export function RolesBadgeList({ roles, onClick }: Props) {
  return (
    <div className="roles-badge-list">
      {roles.map(r => (
        <button key={r} type="button" className="roles-badge"
                style={{ backgroundColor: COLOR_BY_ROLE[r] ?? 'var(--color-text-muted)' }}
                onClick={() => onClick?.(r)}
                disabled={!onClick}>
          {LABEL_BY_ROLE[r] ?? r}
        </button>
      ))}
    </div>
  )
}
```

- [ ] **Step 2: ContactHeader**

```typescript
// apps/web/src/foundation/compounds/ContactHeader.tsx
import { Avatar } from './Avatar'
import { RolesBadgeList } from './RolesBadgeList'
import type { ContactWithSidecars, ContactRole } from '../../types/contacts'

interface Props {
  contact: ContactWithSidecars
  ownerName?: string
  onRoleClick?: (role: ContactRole) => void
  onMoreClick?: () => void
  onPrimaryAction?: { label: string; onClick: () => void }
}

export function ContactHeader({ contact, ownerName, onRoleClick, onMoreClick, onPrimaryAction }: Props) {
  const primaryEmail = contact.emails.find(e => e.primary)?.email ?? contact.primary_email
  const primaryPhone = contact.phones.find(p => p.primary)?.e164
  const primaryAddr  = contact.addresses.find(a => a.primary)
  const initials = contact.kind === 'organization'
    ? (contact.legal_name ?? '').slice(0, 2).toUpperCase()
    : `${(contact.first_name ?? '').slice(0,1)}${(contact.last_name ?? '').slice(0,1)}`.toUpperCase()

  return (
    <header className="contact-header">
      <Avatar id={contact.id} name={contact.display_name} size={64} />
      <div className="contact-header__main">
        <h1 className="contact-header__name">{contact.display_name}</h1>
        <RolesBadgeList roles={contact.roles} onClick={onRoleClick} />
        {ownerName && <div className="contact-header__owner">Owner: {ownerName}</div>}
        <div className="contact-header__meta">
          {primaryEmail && <a href={`mailto:${primaryEmail}`}>✉️ {primaryEmail}</a>}
          {primaryPhone && <a href={`tel:${primaryPhone}`}>📞 {primaryPhone}</a>}
          {primaryAddr && <span>📍 {primaryAddr.city}, {primaryAddr.country}</span>}
        </div>
        <div className="contact-header__actions">
          {primaryEmail && <a className="btn btn--sm" href={`mailto:${primaryEmail}`}>✉️ Email</a>}
          {primaryPhone && <a className="btn btn--sm" href={`https://wa.me/${primaryPhone.replace('+','')}`}>💬 WhatsApp</a>}
          {primaryPhone && <a className="btn btn--sm" href={`tel:${primaryPhone}`}>📞 Call</a>}
          {onPrimaryAction && <button type="button" className="btn btn--primary btn--sm"
                                       onClick={onPrimaryAction.onClick}>{onPrimaryAction.label}</button>}
          {onMoreClick && <button type="button" className="btn btn--sm" onClick={onMoreClick}>⋯</button>}
        </div>
        <span className="contact-header__initials" style={{ display: 'none' }}>{initials}</span>
      </div>
    </header>
  )
}
```

- [ ] **Step 3: Type-check + Commit**

```bash
cd apps/web && npx tsc --noEmit
git add apps/web/src/foundation/compounds/RolesBadgeList.tsx \
        apps/web/src/foundation/compounds/ContactHeader.tsx
git commit -m "feat(foundation): contact header + roles badges"
```

---

# Phase E — ContactDetailPanel mit adaptiven Tabs

## Task E1: ContactDetailPanel-Skeleton + Tab-Routing

**Files:**
- Create: `apps/web/src/screens/contacts/ContactDetailPanel.tsx`
- Create: `apps/web/src/screens/contacts/tabs/index.ts`

- [ ] **Step 1: Panel mit Tab-Logik**

```typescript
// apps/web/src/screens/contacts/ContactDetailPanel.tsx
import { useEffect, useState } from 'react'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import { Drawer } from '../../foundation/layouts/Drawer'
import { Tabs } from '../../foundation/layouts/Tabs'
import { ContactHeader } from '../../foundation/compounds/ContactHeader'
import { getContactWithSidecars } from '../../lib/contactQueries'
import type { ContactWithSidecars } from '../../types/contacts'

import { OverviewTab } from './tabs/OverviewTab'
import { RelationshipsTab } from './tabs/RelationshipsTab'
import { ActivityTab } from './tabs/ActivityTab'
import { NotesAndDocsTab } from './tabs/NotesAndDocsTab'
import { StudentTab } from './tabs/StudentTab'
import { CoursesTab } from './tabs/CoursesTab'
import { SaldoTab } from './tabs/SaldoTab'
import { SkillsTab } from './tabs/SkillsTab'
import { AvailabilityTab } from './tabs/AvailabilityTab'
import { OrgMembersTab } from './tabs/OrgMembersTab'
import { ContractTab } from './tabs/ContractTab'

export type TabKey =
  | 'overview' | 'relationships' | 'activity' | 'notes'
  | 'student' | 'courses' | 'saldo' | 'skills' | 'availability'
  | 'org_members' | 'contract'

interface Props {
  contactId: string | null
  open: boolean
  initialTab?: TabKey
  onClose: () => void
}

export function ContactDetailPanel({ contactId, open, initialTab = 'overview', onClose }: Props) {
  const qc = useQueryClient()
  const [activeTab, setActiveTab] = useState<TabKey>(initialTab)

  useEffect(() => { setActiveTab(initialTab) }, [contactId, initialTab])

  const { data, isLoading } = useQuery({
    queryKey: ['contact', contactId],
    queryFn: () => contactId ? getContactWithSidecars(contactId) : null,
    enabled: !!contactId,
  })

  function refetch() {
    qc.invalidateQueries({ queryKey: ['contact', contactId] })
  }

  if (!open || !contactId) return null

  const visibleTabs = computeVisibleTabs(data)

  return (
    <Drawer open={open} onClose={onClose} side="right" width="60%">
      {isLoading ? (
        <div className="p-6">Lade…</div>
      ) : !data ? (
        <div className="p-6">Kontakt nicht gefunden.</div>
      ) : (
        <>
          <ContactHeader contact={data} onMoreClick={() => { /* Task I3 */ }} />
          <Tabs
            value={activeTab}
            onChange={(v) => setActiveTab(v as TabKey)}
            tabs={visibleTabs.map(t => ({ id: t, label: TAB_LABELS[t] }))}
          />
          <div className="contact-detail__body">
            {activeTab === 'overview'      && <OverviewTab contact={data} onUpdated={refetch} />}
            {activeTab === 'relationships' && <RelationshipsTab contactId={data.id} onUpdated={refetch} />}
            {activeTab === 'activity'      && <ActivityTab contactId={data.id} />}
            {activeTab === 'notes'         && <NotesAndDocsTab contact={data} onUpdated={refetch} />}
            {activeTab === 'student'       && <StudentTab contact={data} onUpdated={refetch} />}
            {activeTab === 'courses'       && <CoursesTab contactId={data.id} roles={data.roles} />}
            {activeTab === 'saldo'         && <SaldoTab contactId={data.id} onUpdated={refetch} />}
            {activeTab === 'skills'        && <SkillsTab contactId={data.id} />}
            {activeTab === 'availability'  && <AvailabilityTab contactId={data.id} />}
            {activeTab === 'org_members'   && <OrgMembersTab orgId={data.id} />}
            {activeTab === 'contract'      && <ContractTab contact={data} onUpdated={refetch} />}
          </div>
        </>
      )}
    </Drawer>
  )
}

function computeVisibleTabs(c: ContactWithSidecars | null | undefined): TabKey[] {
  if (!c) return ['overview']
  const tabs: TabKey[] = ['overview', 'relationships', 'activity', 'notes']
  if (c.roles.includes('student') || c.roles.includes('candidate')) tabs.push('student')
  if (c.roles.includes('instructor') || c.roles.includes('student') || c.roles.includes('candidate'))
    tabs.push('courses')
  if (c.roles.includes('instructor')) tabs.push('saldo', 'skills', 'availability')
  if (c.kind === 'organization') tabs.push('org_members')
  if (c.kind === 'organization' && c.organization?.org_kind &&
      ['tauchschule', 'partner', 'lieferant'].includes(c.organization.org_kind))
    tabs.push('contract')
  return tabs
}

const TAB_LABELS: Record<TabKey, string> = {
  overview: 'Übersicht', relationships: 'Beziehungen', activity: 'Aktivität',
  notes: 'Notizen & Dokumente', student: 'Schüler', courses: 'Kurse',
  saldo: 'Saldo', skills: 'Skills', availability: 'Verfügbarkeit',
  org_members: 'Mitglieder', contract: 'Vertrag & Billing',
}
```

- [ ] **Step 2: Tab-Stubs anlegen** (alle 11 Tab-Dateien als Stubs, die den Build grün halten)

```typescript
// apps/web/src/screens/contacts/tabs/OverviewTab.tsx
import type { ContactWithSidecars } from '../../../types/contacts'
export function OverviewTab({ contact, onUpdated }: { contact: ContactWithSidecars; onUpdated: () => void }) {
  return <div className="tab-stub">Overview — TODO Task E2</div>
}
```

(Repeat the stub-pattern für RelationshipsTab, ActivityTab, NotesAndDocsTab, StudentTab, CoursesTab, SaldoTab, SkillsTab, AvailabilityTab, OrgMembersTab, ContractTab — each with the exact prop signature its consumer expects, returning a placeholder div.)

- [ ] **Step 3: Type-check**

```bash
cd apps/web && npx tsc --noEmit
```

Expected: keine errors.

- [ ] **Step 4: Commit**

```bash
git add apps/web/src/screens/contacts/
git commit -m "feat(contacts): ContactDetailPanel skeleton with adaptive tabs"
```

---

## Task E2: OverviewTab — Inline-Edit aller Stammdaten

**Files:**
- Modify: `apps/web/src/screens/contacts/tabs/OverviewTab.tsx`

- [ ] **Step 1: OverviewTab implementieren**

```typescript
// apps/web/src/screens/contacts/tabs/OverviewTab.tsx
import { InlineTextField } from '../../../foundation/compounds/InlineTextField'
import { PhoneList } from '../../../foundation/compounds/PhoneList'
import { EmailList } from '../../../foundation/compounds/EmailList'
import { AddressList } from '../../../foundation/compounds/AddressList'
import { updateContactField } from '../../../lib/contactQueries'
import type { ContactWithSidecars } from '../../../types/contacts'

interface Props { contact: ContactWithSidecars; onUpdated: () => void }

export function OverviewTab({ contact, onUpdated }: Props) {
  async function update<K extends keyof ContactWithSidecars>(field: K, value: unknown) {
    await updateContactField(contact.id, field as never, value as never)
    onUpdated()
  }

  return (
    <section className="overview-tab">
      <h3>Stammdaten</h3>
      {contact.kind === 'person' ? (
        <>
          <InlineTextField label="Vorname" value={contact.first_name}
                           onCommit={(v) => update('first_name', v)} />
          <InlineTextField label="Nachname" value={contact.last_name}
                           onCommit={(v) => update('last_name', v)} />
          <InlineTextField label="Geburtstag" value={contact.birth_date}
                           onCommit={(v) => update('birth_date', v || null)}
                           placeholder="YYYY-MM-DD" />
        </>
      ) : (
        <>
          <InlineTextField label="Legal Name" value={contact.legal_name}
                           onCommit={(v) => update('legal_name', v)} />
          <InlineTextField label="Trading Name" value={contact.trading_name}
                           onCommit={(v) => update('trading_name', v || null)} />
        </>
      )}

      <h3>Kontakt</h3>
      <EmailList emails={contact.emails}
                 onChange={async (next) => {
                   await update('emails', next)
                   if (next.find(e => e.primary)) await update('primary_email', next.find(e => e.primary)!.email)
                 }} />
      <PhoneList phones={contact.phones}
                 onChange={(next) => update('phones', next)} />
      <AddressList addresses={contact.addresses}
                   onChange={(next) => update('addresses', next)} />

      <h3>Sprachen & Tags</h3>
      <InlineTextField label="Sprachen (kommagetrennt)"
                       value={contact.languages.join(', ')}
                       onCommit={(v) => update('languages',
                         v.split(',').map(s => s.trim()).filter(Boolean))} />
      <InlineTextField label="Tags (kommagetrennt)"
                       value={contact.tags.join(', ')}
                       onCommit={(v) => update('tags',
                         v.split(',').map(s => s.trim()).filter(Boolean))} />

      <h3>Notizen</h3>
      <InlineTextField label="Notizen" value={contact.notes}
                       onCommit={(v) => update('notes', v || null)}
                       multiline placeholder="Frei wählbarer Text..." />

      <footer className="overview-tab__audit">
        Erstellt: {new Date(contact.created_at).toLocaleString('de-CH')}
        · Geändert: {new Date(contact.updated_at).toLocaleString('de-CH')}
        {contact.source && <> · Quelle: {contact.source}</>}
      </footer>
    </section>
  )
}
```

- [ ] **Step 2: Type-check + Commit**

```bash
cd apps/web && npx tsc --noEmit
git add apps/web/src/screens/contacts/tabs/OverviewTab.tsx
git commit -m "feat(contacts): OverviewTab with inline-edit"
```

---

## Task E3: RelationshipsTab + AddRelationshipSheet

**Files:**
- Modify: `apps/web/src/screens/contacts/tabs/RelationshipsTab.tsx`
- Create: `apps/web/src/screens/contacts/AddRelationshipSheet.tsx`

- [ ] **Step 1: AddRelationshipSheet**

```typescript
// apps/web/src/screens/contacts/AddRelationshipSheet.tsx
import { useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { Drawer } from '../../foundation/layouts/Drawer'
import { listContacts, addRelationship } from '../../lib/contactQueries'
import type { RelationshipKind } from '../../types/contacts'

const KIND_LABELS: Record<RelationshipKind, string> = {
  works_at: 'arbeitet bei', owns: 'besitzt', spouse_of: 'verheiratet mit',
  child_of: 'Kind von', parent_of: 'Elternteil von', referred_by: 'geworben durch',
  subsidiary_of: 'Tochter von', partner_of: 'Partner von', supplier_of: 'Lieferant von',
  student_of: 'Schüler von', mentor_of: 'Mentor von',
}

interface Props { fromContactId: string; open: boolean; onClose: () => void; onSaved: () => void }

export function AddRelationshipSheet({ fromContactId, open, onClose, onSaved }: Props) {
  const [search, setSearch] = useState('')
  const [target, setTarget] = useState<{ id: string; name: string } | null>(null)
  const [kind, setKind] = useState<RelationshipKind>('works_at')
  const [role, setRole] = useState('')
  const [primary, setPrimary] = useState(false)
  const [saving, setSaving] = useState(false)

  const { data: hits } = useQuery({
    queryKey: ['contacts', 'search', search],
    queryFn: () => listContacts({ searchText: search }, 0, 20),
    enabled: search.length >= 2,
  })

  async function save() {
    if (!target) return
    setSaving(true)
    try {
      await addRelationship({
        from_contact_id: fromContactId,
        to_contact_id: target.id,
        kind, role_at_org: role || undefined, is_primary: primary,
      })
      onSaved(); onClose()
    } finally { setSaving(false) }
  }

  return (
    <Drawer open={open} onClose={onClose} side="right" width="40%">
      <h2>Beziehung hinzufügen</h2>
      <input type="search" placeholder="Person/Org suchen..." autoFocus
             value={search} onChange={(e) => setSearch(e.target.value)} />
      <ul className="rel-search-results">
        {hits?.rows.map(c => (
          <li key={c.id}>
            <button type="button" onClick={() => setTarget({ id: c.id, name: c.display_name })}>
              {c.display_name}
            </button>
          </li>
        ))}
      </ul>
      {target && (
        <div className="rel-form">
          <p>Beziehung zu: <strong>{target.name}</strong></p>
          <select value={kind} onChange={(e) => setKind(e.target.value as RelationshipKind)}>
            {(Object.keys(KIND_LABELS) as RelationshipKind[]).map(k =>
              <option key={k} value={k}>{KIND_LABELS[k]}</option>)}
          </select>
          {kind === 'works_at' && (
            <input placeholder="Rolle (z.B. Sales Rep)" value={role}
                   onChange={(e) => setRole(e.target.value)} />
          )}
          <label><input type="checkbox" checked={primary}
                        onChange={(e) => setPrimary(e.target.checked)} /> Primary</label>
          <button type="button" onClick={save} disabled={saving}>Speichern</button>
        </div>
      )}
    </Drawer>
  )
}
```

- [ ] **Step 2: RelationshipsTab**

```typescript
// apps/web/src/screens/contacts/tabs/RelationshipsTab.tsx
import { useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { listRelationships } from '../../../lib/contactQueries'
import { supabase } from '../../../lib/supabase'
import { AddRelationshipSheet } from '../AddRelationshipSheet'
import type { ContactRelationship } from '../../../types/contacts'

interface Props { contactId: string; onUpdated: () => void }

export function RelationshipsTab({ contactId, onUpdated }: Props) {
  const [adding, setAdding] = useState(false)
  const { data, refetch } = useQuery({
    queryKey: ['contact', contactId, 'relationships'],
    queryFn: () => listRelationships(contactId),
  })

  async function remove(id: string) {
    await supabase.from('contact_relationships').delete().eq('id', id)
    refetch(); onUpdated()
  }

  return (
    <section className="relationships-tab">
      <header>
        <h3>Beziehungen</h3>
        <button type="button" onClick={() => setAdding(true)}>+ Hinzufügen</button>
      </header>
      <ul>
        {(data ?? []).map((r: ContactRelationship) => (
          <li key={r.id}>
            <RelationshipRow rel={r} selfId={contactId} onRemove={() => remove(r.id)} />
          </li>
        ))}
      </ul>
      <AddRelationshipSheet fromContactId={contactId} open={adding}
                            onClose={() => setAdding(false)}
                            onSaved={() => { refetch(); onUpdated() }} />
    </section>
  )
}

function RelationshipRow({ rel, selfId, onRemove }: { rel: ContactRelationship; selfId: string; onRemove: () => void }) {
  const otherId = rel.from_contact_id === selfId ? rel.to_contact_id : rel.from_contact_id
  const direction = rel.from_contact_id === selfId ? 'out' : 'in'
  return (
    <div className="relationship-row">
      <span>{rel.kind}{direction === 'in' ? ' (von)' : ''}</span>
      <a href={`?contact=${otherId}`}>Kontakt anzeigen</a>
      {rel.role_at_org && <span> ({rel.role_at_org})</span>}
      {rel.is_primary && <span className="badge">PRIMARY</span>}
      <button type="button" onClick={onRemove}>×</button>
    </div>
  )
}
```

- [ ] **Step 3: Type-check + Commit**

```bash
cd apps/web && npx tsc --noEmit
git add apps/web/src/screens/contacts/tabs/RelationshipsTab.tsx \
        apps/web/src/screens/contacts/AddRelationshipSheet.tsx
git commit -m "feat(contacts): relationships tab + add-relationship sheet"
```

---

## Task E4–E11: Restliche Tabs (StudentTab, CoursesTab, SaldoTab, SkillsTab, AvailabilityTab, OrgMembersTab, ContractTab, ActivityTab, NotesAndDocsTab)

> **Pattern:** Jede Tab-Datei folgt dem `OverviewTab`-Schema:
> - Inputs: `contactId` oder `contact`, `onUpdated`
> - Lädt eigene Daten via `useQuery`
> - Zeigt Inline-Edit-Felder mit Foundation-Compounds
> - Speichert via `updateContactField` / `updateInstructorField` / `updateStudentField`
> - Bei Listen: ähnliches Add-Sheet-Pattern wie `AddRelationshipSheet`

### Task E4: StudentTab

**Files:** Modify `apps/web/src/screens/contacts/tabs/StudentTab.tsx`

- [ ] **Step 1: Implementation**

```typescript
import { InlineSelectField } from '../../../foundation/compounds/InlineSelectField'
import { InlineTextField } from '../../../foundation/compounds/InlineTextField'
import { updateStudentField } from '../../../lib/contactQueries'
import type { ContactWithSidecars } from '../../../types/contacts'

const STAGES = [
  { value: 'lead',        label: 'Lead' },
  { value: 'qualified',   label: 'Qualified' },
  { value: 'opportunity', label: 'Opportunity' },
  { value: 'customer',    label: 'Customer' },
  { value: 'candidate',   label: 'Kandidat' },
  { value: 'lost',        label: 'Verloren' },
]

interface Props { contact: ContactWithSidecars; onUpdated: () => void }

export function StudentTab({ contact, onUpdated }: Props) {
  const s = contact.student
  if (!s) return <div>Schüler-Daten werden geladen oder noch nicht vorhanden.</div>

  async function update(field: string, value: unknown) {
    await updateStudentField(contact.id, field, value)
    onUpdated()
  }

  return (
    <section className="student-tab">
      <h3>Pipeline</h3>
      <InlineSelectField label="Stage" value={s.pipeline_stage}
                         options={STAGES} allowEmpty
                         onCommit={(v) => update('pipeline_stage', v)} />
      <InlineTextField label="Lead Source" value={s.lead_source}
                       onCommit={(v) => update('lead_source', v || null)} />

      <h3>Tauchen</h3>
      <InlineTextField label="Höchstes Brevet" value={s.highest_brevet}
                       onCommit={(v) => update('highest_brevet', v || null)} />
      <InlineTextField label="Intake Status" value={s.intake_status}
                       onCommit={(v) => update('intake_status', v || null)} />
      <InlineTextField label="Versicherung" value={s.insurance_provider}
                       onCommit={(v) => update('insurance_provider', v || null)} />
      <InlineTextField label="Tauchtauglichkeit (Datum)" value={s.medical_clearance_at}
                       onCommit={(v) => update('medical_clearance_at', v || null)}
                       placeholder="YYYY-MM-DD" />
    </section>
  )
}
```

- [ ] **Step 2: Type-check + Commit**

```bash
cd apps/web && npx tsc --noEmit
git add apps/web/src/screens/contacts/tabs/StudentTab.tsx
git commit -m "feat(contacts): StudentTab inline-edit"
```

### Task E5: SaldoTab (extrahiert aus altem InstructorDetailPanel)

**Files:** Modify `apps/web/src/screens/contacts/tabs/SaldoTab.tsx`

- [ ] **Step 1: Saldo-Logik aus altem InstructorDetailPanel kopieren**

Sieh dir `apps/web/src/screens/InstructorDetailPanel.tsx` an, kopiere die Saldo-Tab-Implementation (account_movements-Query, Filter `vergütung && ref_assignment_id != null && status='completed'`, Edit/Invalidate). Ändere nur:
- `instructor_id` → `contactId` als Prop
- `from('account_movements').eq('instructor_id', contactId)` (FK heisst nach M3.6 `contact_id`)
- Imports: `import { ... } from '../../../lib/...'`

- [ ] **Step 2: Type-check + Commit**

```bash
cd apps/web && npx tsc --noEmit
git add apps/web/src/screens/contacts/tabs/SaldoTab.tsx
git commit -m "feat(contacts): SaldoTab extracted from InstructorDetailPanel"
```

### Task E6: CoursesTab

**Files:** Modify `apps/web/src/screens/contacts/tabs/CoursesTab.tsx`

- [ ] **Step 1: Implementation mit zwei Sektionen ("Als Teilnehmer" / "Als TL/DM")**

```typescript
import { useQuery } from '@tanstack/react-query'
import { supabase } from '../../../lib/supabase'
import type { ContactRole } from '../../../types/contacts'

interface Props { contactId: string; roles: ContactRole[] }

export function CoursesTab({ contactId, roles }: Props) {
  const isInstructor = roles.includes('instructor')
  const isStudent    = roles.includes('student') || roles.includes('candidate')

  const { data: asInstructor } = useQuery({
    queryKey: ['contact', contactId, 'courses', 'instructor'],
    queryFn: async () => {
      const { data } = await supabase
        .from('course_assignments')
        .select(`*, course:courses(id, title, start_date, status)`)
        .eq('instructor_id', contactId)
        .order('course(start_date)', { ascending: false })
      return data ?? []
    },
    enabled: isInstructor,
  })

  const { data: asParticipant } = useQuery({
    queryKey: ['contact', contactId, 'courses', 'participant'],
    queryFn: async () => {
      const { data } = await supabase
        .from('course_participants')
        .select(`*, course:courses(id, title, start_date, status)`)
        .eq('person_id', contactId)
        .order('course(start_date)', { ascending: false })
      return data ?? []
    },
    enabled: isStudent,
  })

  return (
    <section className="courses-tab">
      {isInstructor && (
        <>
          <h3>Als TL/DM</h3>
          <ul>
            {(asInstructor ?? []).map(a => (
              <li key={a.id}>
                <a href={`/courses/${a.course?.id}`}>{a.course?.title}</a>
                {' — '}{a.role}{' — '}{a.course?.start_date}
                {' '}<span className="status">{a.course?.status}</span>
              </li>
            ))}
          </ul>
        </>
      )}
      {isStudent && (
        <>
          <h3>Als Teilnehmer</h3>
          <ul>
            {(asParticipant ?? []).map(p => (
              <li key={p.id}>
                <a href={`/courses/${p.course?.id}`}>{p.course?.title}</a>
                {' — '}{p.course?.start_date}
                {' '}<span className="status">{p.course?.status}</span>
              </li>
            ))}
          </ul>
        </>
      )}
    </section>
  )
}
```

- [ ] **Step 2: Type-check + Commit**

```bash
cd apps/web && npx tsc --noEmit
git add apps/web/src/screens/contacts/tabs/CoursesTab.tsx
git commit -m "feat(contacts): CoursesTab with TL/DM + participant sections"
```

### Tasks E7–E11: SkillsTab, AvailabilityTab, OrgMembersTab, ContractTab, ActivityTab, NotesAndDocsTab

Folge jeweils dem gleichen Pattern wie E4 — neue Tab-Datei, `useQuery` für Daten, Inline-Edit-Felder oder Read-Only-Listen, Type-check, Commit. Speziell:

- **SkillsTab:** Lädt `instructor_skills` mit `contactId`, zeigt als Skill-Matrix-Cell-Liste, Inline-Toggle.
- **AvailabilityTab:** Lädt `availability_blocks`, zeigt einen vereinfachten Kalender-Grid pro Monat mit Click-to-block.
- **OrgMembersTab:** `useQuery` auf `contact_relationships WHERE to_contact_id=orgId AND kind='works_at'`, zeigt Mitgliederliste mit Klick → öffnet anderen Contact.
- **ContractTab:** Inline-Edit der Felder aus `contact_organization` (tax_id, billing_email, contract_type, contract_until, payment_terms).
- **ActivityTab:** Aggregations-Query: `course_assignments` + `course_participants` + `account_movements` + `communication_entries` mit `contact_id=X`, sortiert nach Datum descending, Filter-Chips oben.
- **NotesAndDocsTab:** Markdown-Notes (verwendet `<textarea>` mit `react-markdown` für Preview), File-Upload via Supabase Storage `contact-documents` Bucket.

Commit-Beispiele:
```bash
git commit -m "feat(contacts): SkillsTab"
git commit -m "feat(contacts): AvailabilityTab"
# etc.
```

---

# Phase F — AddressbookScreen (Master-Detail)

## Task F1: AddressbookScreen mit Master-Liste + Saved Views

**Files:**
- Create: `apps/web/src/screens/contacts/AddressbookScreen.tsx`

- [ ] **Step 1: Implementation**

```typescript
// apps/web/src/screens/contacts/AddressbookScreen.tsx
import { useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { useSearchParams } from 'react-router-dom'
import { MasterDetail } from '../../foundation/layouts/MasterDetail'
import { SearchInput } from '../../foundation/components/SearchInput'
import { Avatar } from '../../foundation/components/Avatar'
import { EmptyState } from '../../foundation/components/EmptyState'
import { listContacts, type ContactListFilter } from '../../lib/contactQueries'
import { ContactDetailPanel, type TabKey } from './ContactDetailPanel'
import { CreateContactSheet } from './CreateContactSheet'
import type { ContactRole } from '../../types/contacts'

interface SavedView { id: string; label: string; filter: ContactListFilter }

const SAVED_VIEWS: SavedView[] = [
  { id: 'all',           label: 'Alle',             filter: {} },
  { id: 'persons',       label: 'Personen',         filter: { kind: 'person' } },
  { id: 'orgs',          label: 'Organisationen',   filter: { kind: 'organization' } },
  { id: 'students',      label: 'Aktive Schüler',   filter: { roles: ['student'] } },
  { id: 'candidates',    label: 'Kandidaten',       filter: { roles: ['candidate'] } },
  { id: 'team',          label: 'Team',             filter: { roles: ['instructor'] } },
  { id: 'suppliers',     label: 'Lieferanten',      filter: { roles: ['supplier'] } },
  { id: 'newsletter',    label: 'Newsletter',       filter: { roles: ['newsletter'] } },
]

export function AddressbookScreen() {
  const [params, setParams] = useSearchParams()
  const viewId = params.get('view') ?? 'all'
  const view = SAVED_VIEWS.find(v => v.id === viewId) ?? SAVED_VIEWS[0]
  const search = params.get('q') ?? ''
  const selectedId = params.get('contact')
  const initialTab = (params.get('tab') as TabKey | null) ?? 'overview'

  const [creating, setCreating] = useState(false)

  const { data, isLoading } = useQuery({
    queryKey: ['contacts', view.id, search],
    queryFn: () => listContacts({ ...view.filter, searchText: search || undefined }, 0, 50),
  })

  function setSearch(q: string) {
    const next = new URLSearchParams(params)
    if (q) next.set('q', q); else next.delete('q')
    setParams(next, { replace: true })
  }
  function selectContact(id: string | null) {
    const next = new URLSearchParams(params)
    if (id) next.set('contact', id); else { next.delete('contact'); next.delete('tab') }
    setParams(next)
  }
  function setView(id: string) {
    const next = new URLSearchParams(params)
    next.set('view', id); next.delete('contact'); next.delete('tab')
    setParams(next)
  }

  return (
    <MasterDetail>
      <MasterDetail.Master>
        <header className="addressbook__header">
          <h1>Adressbuch</h1>
          <button type="button" onClick={() => setCreating(true)}>+</button>
        </header>
        <SearchInput value={search} onChange={setSearch} placeholder="Suchen…" />
        <nav className="addressbook__views">
          {SAVED_VIEWS.map(v => (
            <button key={v.id} type="button"
                    data-active={v.id === view.id}
                    onClick={() => setView(v.id)}>
              {v.label}
            </button>
          ))}
        </nav>
        <ul className="addressbook__list">
          {isLoading ? <li>Lädt…</li> :
           !data?.rows.length ? <li><EmptyState>Keine Treffer</EmptyState></li> :
           data.rows.map(c => (
            <li key={c.id} data-active={c.id === selectedId}>
              <button type="button" onClick={() => selectContact(c.id)}>
                <Avatar id={c.id} name={c.display_name} size={32} />
                <div className="addressbook__item-text">
                  <div className="addressbook__item-name">{c.display_name}</div>
                  <RolesDots roles={c.roles as ContactRole[]} />
                </div>
              </button>
            </li>
          ))}
        </ul>
      </MasterDetail.Master>
      <MasterDetail.Detail>
        <ContactDetailPanel
          contactId={selectedId}
          open={!!selectedId}
          initialTab={initialTab}
          onClose={() => selectContact(null)}
        />
      </MasterDetail.Detail>
      <CreateContactSheet open={creating} onClose={() => setCreating(false)}
                          onCreated={(id) => selectContact(id)} />
    </MasterDetail>
  )
}

function RolesDots({ roles }: { roles: ContactRole[] }) {
  const COLOR_BY_ROLE: Partial<Record<ContactRole, string>> = {
    instructor: '#185FA5', student: '#33C2A1', candidate: '#FFB800',
    organization_profile: '#7B5BCC', cd: '#042C53', owner: '#D74545',
  }
  return (
    <div className="role-dots">
      {roles.slice(0, 4).map(r => (
        <span key={r} className="role-dot"
              style={{ backgroundColor: COLOR_BY_ROLE[r] ?? '#999' }} title={r} />
      ))}
    </div>
  )
}
```

- [ ] **Step 2: Route in `App.tsx` registrieren**

Add to your routes (typically `apps/web/src/App.tsx` or `routes.tsx`):

```typescript
<Route path="/contacts" element={<AddressbookScreen />} />
```

- [ ] **Step 3: Type-check + Commit**

```bash
cd apps/web && npx tsc --noEmit
git add apps/web/src/screens/contacts/AddressbookScreen.tsx \
        apps/web/src/App.tsx
git commit -m "feat(contacts): AddressbookScreen master-detail with saved views"
```

---

## Task F2: CreateContactSheet (Wizard zum Anlegen)

**Files:**
- Create: `apps/web/src/screens/contacts/CreateContactSheet.tsx`

- [ ] **Step 1: Sheet-Implementation**

```typescript
// apps/web/src/screens/contacts/CreateContactSheet.tsx
import { useState } from 'react'
import { Drawer } from '../../foundation/layouts/Drawer'
import { createContact, findPotentialDuplicates } from '../../lib/contactQueries'
import type { ContactKind, ContactRole } from '../../types/contacts'

const ROLE_OPTIONS: { value: ContactRole; label: string }[] = [
  { value: 'instructor', label: 'TL/DM' },
  { value: 'student',    label: 'Schüler' },
  { value: 'candidate',  label: 'Kandidat' },
  { value: 'newsletter', label: 'Newsletter' },
  { value: 'supplier',   label: 'Lieferant' },
  { value: 'partner_rep',label: 'Partner-Rep' },
]

interface Props { open: boolean; onClose: () => void; onCreated: (id: string) => void }

export function CreateContactSheet({ open, onClose, onCreated }: Props) {
  const [kind, setKind] = useState<ContactKind>('person')
  const [firstName, setFirstName] = useState('')
  const [lastName, setLastName] = useState('')
  const [legalName, setLegalName] = useState('')
  const [email, setEmail] = useState('')
  const [phone, setPhone] = useState('')
  const [roles, setRoles] = useState<ContactRole[]>([])
  const [saving, setSaving] = useState(false)
  const [warnings, setWarnings] = useState<string[]>([])

  function toggleRole(r: ContactRole) {
    setRoles(prev => prev.includes(r) ? prev.filter(x => x !== r) : [...prev, r])
  }

  async function save() {
    setSaving(true); setWarnings([])
    try {
      const id = await createContact({
        kind,
        first_name: kind === 'person' ? firstName : undefined,
        last_name:  kind === 'person' ? lastName  : undefined,
        legal_name: kind === 'organization' ? legalName : undefined,
        primary_email: email || undefined,
        phones: phone ? [{ label: 'mobile', e164: phone, primary: true }] : undefined,
        roles,
      })
      const dupes = await findPotentialDuplicates(id)
      if (dupes.length > 0) {
        setWarnings(dupes.map(d => `Möglicher Treffer: ${d.display_name} (${d.match_reason})`))
      }
      onCreated(id); onClose()
    } catch (e) {
      setWarnings([(e as Error).message])
    } finally { setSaving(false) }
  }

  return (
    <Drawer open={open} onClose={onClose} side="right" width="40%">
      <h2>Neuer Kontakt</h2>
      <fieldset>
        <legend>Typ</legend>
        <label><input type="radio" checked={kind === 'person'}
                      onChange={() => setKind('person')} /> Person</label>
        <label><input type="radio" checked={kind === 'organization'}
                      onChange={() => setKind('organization')} /> Organisation</label>
      </fieldset>
      {kind === 'person' ? (
        <>
          <input placeholder="Vorname" value={firstName}
                 onChange={(e) => setFirstName(e.target.value)} required />
          <input placeholder="Nachname" value={lastName}
                 onChange={(e) => setLastName(e.target.value)} required />
        </>
      ) : (
        <input placeholder="Firmenname" value={legalName}
               onChange={(e) => setLegalName(e.target.value)} required />
      )}
      <input placeholder="Email" type="email" value={email}
             onChange={(e) => setEmail(e.target.value)} />
      <input placeholder="Telefon (+41…)" value={phone}
             onChange={(e) => setPhone(e.target.value)} />
      <fieldset>
        <legend>Rollen</legend>
        {ROLE_OPTIONS.map(r => (
          <label key={r.value}>
            <input type="checkbox" checked={roles.includes(r.value)}
                   onChange={() => toggleRole(r.value)} /> {r.label}
          </label>
        ))}
      </fieldset>
      {warnings.map((w, i) => <div key={i} className="warning">{w}</div>)}
      <button type="button" onClick={save}
              disabled={saving || (kind === 'person' ? !firstName || !lastName : !legalName)}>
        Erstellen
      </button>
    </Drawer>
  )
}
```

- [ ] **Step 2: Type-check + Commit**

```bash
cd apps/web && npx tsc --noEmit
git add apps/web/src/screens/contacts/CreateContactSheet.tsx
git commit -m "feat(contacts): CreateContactSheet with dedup warning"
```

---

## Task F3: Sidebar-Navigation aktualisieren

**Files:**
- Modify: `apps/web/src/components/Sidebar.tsx`

- [ ] **Step 1: Sidebar-Struktur (siehe Spec §5.1)**

Modify Sidebar.tsx — add an ADRESSEN section with three nav items (Adressbuch, Pipeline, Communication Hub) and a TEAM section (TL/DM, Skill-Matrix, Verfügbarkeit). Adjust existing nav-items to match.

```typescript
// Excerpt from Sidebar.tsx — add this after existing top items:
<NavSection label="ADRESSEN">
  <NavItem to="/contacts"          icon="users" label="Adressbuch" />
  <NavItem to="/cd/pipeline"       icon="kanban" label="Pipeline"
           visible={role === 'cd' || role === 'owner'} />
  <NavItem to="/communication"     icon="mail" label="Communication Hub" />
</NavSection>
<NavSection label="TEAM">
  <NavItem to="/contacts?view=team"   icon="user" label="TL/DM" />
  <NavItem to="/skills"               icon="grid" label="Skill-Matrix" />
  <NavItem to="/availability"         icon="calendar" label="Verfügbarkeit" />
</NavSection>
```

- [ ] **Step 2: Type-check + Commit**

```bash
cd apps/web && npx tsc --noEmit
git add apps/web/src/components/Sidebar.tsx
git commit -m "feat(nav): new sidebar structure with Addressbuch + Team sections"
```

---

# Phase G — Workflow-Screens auf neuen DetailPanel umstellen

## Task G1: PipelineScreen → ContactDetailPanel

**Files:**
- Modify: `apps/web/src/screens/cd/CDPipelineScreen.tsx`

- [ ] **Step 1: Click-Handler ändern**

Im PipelineScreen den click handler auf einer KanbanCard ersetzen:

```typescript
// Instead of opening StudentDetailPanel:
import { ContactDetailPanel } from '../contacts/ContactDetailPanel'
import { useState } from 'react'

const [selectedId, setSelectedId] = useState<string | null>(null)

// In KanbanCard onClick: setSelectedId(card.id)

// Render at end:
<ContactDetailPanel
  contactId={selectedId}
  open={!!selectedId}
  initialTab="student"  // Pipeline-Kontext → student tab default
  onClose={() => setSelectedId(null)}
/>
```

- [ ] **Step 2: Type-check + Commit**

```bash
cd apps/web && npx tsc --noEmit
git add apps/web/src/screens/cd/CDPipelineScreen.tsx
git commit -m "refactor(pipeline): use ContactDetailPanel with student-tab default"
```

## Task G2: CommunicationHubScreen → ContactDetailPanel

**Files:** Modify `apps/web/src/screens/CommunicationHubScreen.tsx`

Gleiches Pattern wie G1, aber `initialTab="activity"`.

```bash
git commit -m "refactor(comms): use ContactDetailPanel with activity-tab default"
```

## Task G3: SkillMatrixScreen → ContactDetailPanel

**Files:** Modify `apps/web/src/screens/SkillMatrixScreen.tsx`

Pattern wie G1, `initialTab="skills"`.

```bash
git commit -m "refactor(skills): use ContactDetailPanel with skills-tab default"
```

## Task G4: StudentsScreen → leitet auf AddressbookScreen weiter

**Files:** Modify `apps/web/src/screens/StudentsScreen.tsx`

- [ ] **Step 1: Redirect**

```typescript
// apps/web/src/screens/StudentsScreen.tsx
import { Navigate } from 'react-router-dom'
export function StudentsScreen() {
  return <Navigate to="/contacts?view=students" replace />
}
```

- [ ] **Step 2: Commit**

```bash
git commit -m "refactor(students): redirect to addressbook with students view"
```

## Task G5: InstructorsScreen → AddressbookScreen

Gleiches Pattern wie G4 mit `?view=team`.

```bash
git commit -m "refactor(instructors): redirect to addressbook with team view"
```

## Task G6: CDOrganizationsScreen → AddressbookScreen

Gleiches Pattern, `?view=orgs`.

```bash
git commit -m "refactor(orgs): redirect to addressbook with orgs view"
```

## Task G7: KurseScreen + CourseDetailPanel → ContactDetailPanel-Klicks

**Files:** Modify `apps/web/src/screens/CourseDetailPanel.tsx` (oder wo auch immer Teilnehmer/Assignments angezeigt werden)

- [ ] **Step 1: Click-on-name → ContactDetailPanel**

```typescript
// Instead of <a> or no-op:
const [selectedContactId, setSelectedContactId] = useState<string | null>(null)
const [tab, setTab] = useState<TabKey>('overview')

// On instructor name click:
function openInstructor(id: string) { setSelectedContactId(id); setTab('saldo') }
function openParticipant(id: string) { setSelectedContactId(id); setTab('overview') }

// At bottom of component:
<ContactDetailPanel contactId={selectedContactId} open={!!selectedContactId}
                    initialTab={tab} onClose={() => setSelectedContactId(null)} />
```

- [ ] **Step 2: Commit**

```bash
git commit -m "refactor(courses): click person → ContactDetailPanel"
```

---

# Phase H — Inline-Edit-Migration: Alte EditSheets entfernen

## Task H1: Alte Detail-Panels + EditSheets löschen

**Files:**
- Delete: `apps/web/src/screens/StudentDetailPanel.tsx`
- Delete: `apps/web/src/screens/InstructorDetailPanel.tsx`
- Delete: `apps/web/src/screens/StudentEditSheet.tsx`
- Delete: `apps/web/src/screens/InstructorEditSheet.tsx`
- Delete: `apps/web/src/screens/cd/OrganizationEditSheet.tsx`
- Delete: `apps/web/src/screens/cd/CommunicationEditSheet.tsx`

- [ ] **Step 1: Files löschen**

```bash
cd apps/web/src
rm screens/StudentDetailPanel.tsx
rm screens/InstructorDetailPanel.tsx
rm screens/StudentEditSheet.tsx
rm screens/InstructorEditSheet.tsx
rm screens/cd/OrganizationEditSheet.tsx
rm screens/cd/CommunicationEditSheet.tsx
```

- [ ] **Step 2: Imports finden + entfernen**

```bash
grep -rn "StudentDetailPanel\|InstructorDetailPanel\|StudentEditSheet\|InstructorEditSheet\|OrganizationEditSheet\|CommunicationEditSheet" apps/web/src/
```

Jeden Treffer manuell entfernen oder durch `ContactDetailPanel`/`AddRelationshipSheet`/`CreateContactSheet` ersetzen.

- [ ] **Step 3: Build verifizieren**

```bash
cd apps/web && npm run build
```

Expected: success.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "refactor: remove old detail panels and edit sheets"
```

---

# Phase I — GDPR, Dedup, Merge, Audit-Historie

## Task I1: Mehr-Menü (⋯) im ContactHeader implementieren

**Files:**
- Create: `apps/web/src/screens/contacts/ContactMoreMenu.tsx`

- [ ] **Step 1: Menu-Komponente**

```typescript
// apps/web/src/screens/contacts/ContactMoreMenu.tsx
import { useState } from 'react'
import { archiveContact, gdprAnonymize } from '../../lib/contactQueries'
import { MergeContactsSheet } from './MergeContactsSheet'
import { RoleManagerSheet } from './RoleManagerSheet'
import type { ContactWithSidecars } from '../../types/contacts'

interface Props { contact: ContactWithSidecars; onChanged: () => void; onClosed: () => void }

export function ContactMoreMenu({ contact, onChanged, onClosed }: Props) {
  const [merging, setMerging] = useState(false)
  const [editingRoles, setEditingRoles] = useState(false)

  async function archive() {
    if (!confirm('Diesen Kontakt archivieren?')) return
    await archiveContact(contact.id)
    onChanged(); onClosed()
  }

  async function gdprDelete() {
    if (!confirm('GDPR-Löschung: PII wird unwiderruflich entfernt. Fortfahren?')) return
    await gdprAnonymize(contact.id)
    onChanged(); onClosed()
  }

  function exportVcard() {
    const lines = [
      'BEGIN:VCARD','VERSION:3.0',
      `FN:${contact.display_name}`,
      contact.kind === 'person'
        ? `N:${contact.last_name};${contact.first_name};;;`
        : `ORG:${contact.legal_name}`,
      ...contact.emails.map(e => `EMAIL;TYPE=${e.label}:${e.email}`),
      ...contact.phones.map(p => `TEL;TYPE=${p.label}:${p.e164}`),
      'END:VCARD'
    ].join('\n')
    const blob = new Blob([lines], { type: 'text/vcard' })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url; a.download = `${contact.display_name}.vcf`; a.click()
    URL.revokeObjectURL(url)
  }

  return (
    <>
      <ul className="more-menu">
        <li><button type="button" onClick={() => setEditingRoles(true)}>Rollen verwalten</button></li>
        <li><button type="button" onClick={() => setMerging(true)}>Mit anderem verschmelzen</button></li>
        <li><button type="button" onClick={exportVcard}>Als vCard exportieren</button></li>
        <li><button type="button" onClick={archive}>Archivieren</button></li>
        <li><button type="button" onClick={gdprDelete} className="danger">GDPR-Löschung</button></li>
      </ul>
      <MergeContactsSheet winnerId={contact.id} open={merging}
                          onClose={() => setMerging(false)}
                          onMerged={() => { setMerging(false); onChanged() }} />
      <RoleManagerSheet contactId={contact.id} currentRoles={contact.roles}
                        open={editingRoles} onClose={() => setEditingRoles(false)}
                        onSaved={() => { setEditingRoles(false); onChanged() }} />
    </>
  )
}
```

- [ ] **Step 2: Hook in ContactDetailPanel-Header**

In `ContactDetailPanel.tsx`: state `const [showMore, setShowMore] = useState(false)`, ContactHeader bekommt `onMoreClick={() => setShowMore(true)}`. Render `{showMore && <ContactMoreMenu …/>}`.

- [ ] **Step 3: Type-check + Commit**

```bash
cd apps/web && npx tsc --noEmit
git add apps/web/src/screens/contacts/ContactMoreMenu.tsx \
        apps/web/src/screens/contacts/ContactDetailPanel.tsx
git commit -m "feat(contacts): more-menu with archive/gdpr/export/merge"
```

---

## Task I2: MergeContactsSheet (Side-by-Side-Preview)

**Files:**
- Create: `apps/web/src/screens/contacts/MergeContactsSheet.tsx`

- [ ] **Step 1: Sheet-Implementation**

```typescript
// apps/web/src/screens/contacts/MergeContactsSheet.tsx
import { useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { Drawer } from '../../foundation/layouts/Drawer'
import { listContacts, getContactWithSidecars, mergeContacts } from '../../lib/contactQueries'

interface Props { winnerId: string; open: boolean; onClose: () => void; onMerged: () => void }

export function MergeContactsSheet({ winnerId, open, onClose, onMerged }: Props) {
  const [search, setSearch] = useState('')
  const [loserId, setLoserId] = useState<string | null>(null)
  const [merging, setMerging] = useState(false)

  const { data: winner } = useQuery({
    queryKey: ['contact', winnerId], queryFn: () => getContactWithSidecars(winnerId)
  })
  const { data: loser } = useQuery({
    queryKey: ['contact', loserId], queryFn: () => loserId ? getContactWithSidecars(loserId) : null,
    enabled: !!loserId,
  })
  const { data: hits } = useQuery({
    queryKey: ['contacts','search',search], queryFn: () => listContacts({ searchText: search }, 0, 20),
    enabled: search.length >= 2,
  })

  async function doMerge() {
    if (!loserId) return
    if (!confirm('Verschmelzen ist nicht reversibel. Fortfahren?')) return
    setMerging(true)
    try { await mergeContacts(winnerId, loserId); onMerged() }
    finally { setMerging(false) }
  }

  if (!open) return null

  return (
    <Drawer open={open} onClose={onClose} side="right" width="80%">
      <h2>Verschmelzen</h2>
      {!loserId ? (
        <>
          <p>Welcher Kontakt soll mit <strong>{winner?.display_name}</strong> verschmolzen werden?</p>
          <input type="search" placeholder="Suchen..." autoFocus
                 value={search} onChange={(e) => setSearch(e.target.value)} />
          <ul>
            {hits?.rows.filter(r => r.id !== winnerId).map(r => (
              <li key={r.id}>
                <button type="button" onClick={() => setLoserId(r.id)}>{r.display_name}</button>
              </li>
            ))}
          </ul>
        </>
      ) : (
        <div className="merge-preview">
          <div className="merge-side">
            <h3>Gewinner: {winner?.display_name}</h3>
            <pre>{JSON.stringify(winner, null, 2)}</pre>
          </div>
          <div className="merge-side">
            <h3>Wird gelöscht: {loser?.display_name}</h3>
            <pre>{JSON.stringify(loser, null, 2)}</pre>
          </div>
          <p>Nach dem Verschmelzen werden alle FK-Verweise (Kurse, Saldo,
             Comms, Beziehungen) auf <strong>{winner?.display_name}</strong> migriert.
             Der zweite Kontakt wird archiviert.</p>
          <button type="button" onClick={doMerge} disabled={merging} className="danger">
            Verschmelzen
          </button>
          <button type="button" onClick={() => setLoserId(null)}>Anderen wählen</button>
        </div>
      )}
    </Drawer>
  )
}
```

- [ ] **Step 2: Type-check + Commit**

```bash
cd apps/web && npx tsc --noEmit
git add apps/web/src/screens/contacts/MergeContactsSheet.tsx
git commit -m "feat(contacts): merge sheet with side-by-side preview"
```

---

## Task I3: RoleManagerSheet

**Files:**
- Create: `apps/web/src/screens/contacts/RoleManagerSheet.tsx`

- [ ] **Step 1: Implementation**

```typescript
// apps/web/src/screens/contacts/RoleManagerSheet.tsx
import { useState } from 'react'
import { Drawer } from '../../foundation/layouts/Drawer'
import { supabase } from '../../lib/supabase'
import type { ContactRole } from '../../types/contacts'

const ALL_ROLES: { value: ContactRole; label: string; needsSidecar?: 'instructor' | 'student' }[] = [
  { value: 'instructor',  label: 'TL/DM',      needsSidecar: 'instructor' },
  { value: 'cd',          label: 'CD' },
  { value: 'owner',       label: 'Owner' },
  { value: 'dispatcher',  label: 'Dispatcher' },
  { value: 'student',     label: 'Schüler',    needsSidecar: 'student' },
  { value: 'candidate',   label: 'Kandidat' },
  { value: 'newsletter',  label: 'Newsletter' },
  { value: 'supplier',    label: 'Lieferant' },
  { value: 'partner_rep', label: 'Partner-Rep' },
  { value: 'authority',   label: 'Behörde' },
]

interface Props {
  contactId: string; currentRoles: ContactRole[]
  open: boolean; onClose: () => void; onSaved: () => void
}

export function RoleManagerSheet({ contactId, currentRoles, open, onClose, onSaved }: Props) {
  const [draft, setDraft] = useState<ContactRole[]>(currentRoles)
  const [saving, setSaving] = useState(false)

  function toggle(r: ContactRole) {
    setDraft(prev => prev.includes(r) ? prev.filter(x => x !== r) : [...prev, r])
  }

  async function save() {
    setSaving(true)
    try {
      // Update contacts.roles
      await supabase.from('contacts').update({ roles: draft }).eq('id', contactId)
      // Add/remove sidecars
      for (const role of ALL_ROLES) {
        if (!role.needsSidecar) continue
        const wantsRole = draft.includes(role.value)
        const hadRole   = currentRoles.includes(role.value)
        const table = role.needsSidecar === 'instructor' ? 'contact_instructor' : 'contact_student'
        if (wantsRole && !hadRole) {
          await supabase.from(table).insert({ contact_id: contactId })
        } else if (!wantsRole && hadRole) {
          await supabase.from(table).delete().eq('contact_id', contactId)
        }
      }
      onSaved()
    } finally { setSaving(false) }
  }

  if (!open) return null

  return (
    <Drawer open={open} onClose={onClose} side="right" width="30%">
      <h2>Rollen verwalten</h2>
      <ul className="roles-list">
        {ALL_ROLES.map(r => (
          <li key={r.value}>
            <label>
              <input type="checkbox" checked={draft.includes(r.value)}
                     onChange={() => toggle(r.value)} />
              {r.label}
              {r.needsSidecar && <span className="hint"> (legt Profil-Daten an/entfernt)</span>}
            </label>
          </li>
        ))}
      </ul>
      <button type="button" onClick={save} disabled={saving}>Speichern</button>
    </Drawer>
  )
}
```

- [ ] **Step 2: Type-check + Commit**

```bash
cd apps/web && npx tsc --noEmit
git add apps/web/src/screens/contacts/RoleManagerSheet.tsx
git commit -m "feat(contacts): role manager sheet"
```

---

## Task I4: AuditHistoryTab

**Files:**
- Modify: `apps/web/src/screens/contacts/tabs/AuditHistoryTab.tsx` (new file)
- Modify: `apps/web/src/screens/contacts/ContactDetailPanel.tsx` (add tab to visible list & switch)

- [ ] **Step 1: AuditHistoryTab**

```typescript
// apps/web/src/screens/contacts/tabs/AuditHistoryTab.tsx
import { useQuery } from '@tanstack/react-query'
import { supabase } from '../../../lib/supabase'

interface Props { contactId: string }

export function AuditHistoryTab({ contactId }: Props) {
  const { data } = useQuery({
    queryKey: ['contact', contactId, 'audit'],
    queryFn: async () => {
      const { data } = await supabase.from('contact_audit_log')
        .select('*').eq('contact_id', contactId)
        .order('changed_at', { ascending: false }).limit(200)
      return data ?? []
    }
  })
  return (
    <section>
      <h3>Audit-Historie</h3>
      <ul>
        {(data ?? []).map(e => (
          <li key={e.id}>
            <strong>{new Date(e.changed_at).toLocaleString('de-CH')}</strong>
            {' — '}{e.operation} {e.table_name}
            {e.changed_fields && (
              <details>
                <summary>Geänderte Felder</summary>
                <pre>{JSON.stringify(e.changed_fields, null, 2)}</pre>
              </details>
            )}
          </li>
        ))}
      </ul>
    </section>
  )
}
```

- [ ] **Step 2: Tab in ContactDetailPanel registrieren**

In `ContactDetailPanel.tsx`: importiere AuditHistoryTab, füge `'audit'` als TabKey hinzu, im `computeVisibleTabs` immer ans Ende `tabs.push('audit')`, im Switch-Block `{activeTab === 'audit' && <AuditHistoryTab contactId={data.id} />}`. TAB_LABELS.audit = 'Audit'.

- [ ] **Step 3: Type-check + Commit**

```bash
cd apps/web && npx tsc --noEmit
git add apps/web/src/screens/contacts/tabs/AuditHistoryTab.tsx \
        apps/web/src/screens/contacts/ContactDetailPanel.tsx
git commit -m "feat(contacts): audit history tab"
```

---

# Phase J — Final Cleanup (M3.6)

## Task J1: FK-Spalten in Konsumer-Tabellen umbenennen

**Files:**
- Create: `supabase/migrations/0085_fk_rename.sql`

- [ ] **Step 1: Rename-Migration**

```sql
-- 0085: Rename FKs from instructor_id/person_id → contact_id

ALTER TABLE public.course_assignments     RENAME COLUMN instructor_id TO contact_id;
ALTER TABLE public.course_participants    RENAME COLUMN person_id     TO contact_id;
ALTER TABLE public.account_movements      RENAME COLUMN instructor_id TO contact_id;
ALTER TABLE public.communication_entries  RENAME COLUMN person_id     TO contact_person_id;
ALTER TABLE public.communication_entries  RENAME COLUMN instructor_id TO contact_handler_id;
ALTER TABLE public.instructor_skills      RENAME COLUMN instructor_id TO contact_id;
ALTER TABLE public.availability_blocks    RENAME COLUMN instructor_id TO contact_id;
ALTER TABLE public.intake_checklists      RENAME COLUMN person_id     TO contact_id;

-- Drop old FK constraints + add new ones pointing at contacts(id)
-- (Postgres keeps existing FKs valid since the rename doesn't change targets.
-- But we dropped instructors/people/organizations tables in M3.6 — so we
-- need to retarget the constraints. Easiest: drop+re-add each.)

DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN
    SELECT con.conname, con.conrelid::regclass AS tbl
    FROM pg_constraint con
    JOIN pg_class cls ON cls.oid = con.confrelid
    WHERE cls.relname IN ('instructors', 'people', 'organizations')
      AND con.contype = 'f'
  LOOP
    EXECUTE format('ALTER TABLE %s DROP CONSTRAINT %I', r.tbl, r.conname);
  END LOOP;
END $$;

-- Add new FKs pointing at contacts(id)
ALTER TABLE public.course_assignments
  ADD CONSTRAINT course_assignments_contact_id_fkey
  FOREIGN KEY (contact_id) REFERENCES public.contacts(id) ON DELETE RESTRICT;

ALTER TABLE public.course_participants
  ADD CONSTRAINT course_participants_contact_id_fkey
  FOREIGN KEY (contact_id) REFERENCES public.contacts(id) ON DELETE CASCADE;

ALTER TABLE public.account_movements
  ADD CONSTRAINT account_movements_contact_id_fkey
  FOREIGN KEY (contact_id) REFERENCES public.contacts(id) ON DELETE RESTRICT;

ALTER TABLE public.communication_entries
  ADD CONSTRAINT communication_entries_person_fkey
  FOREIGN KEY (contact_person_id) REFERENCES public.contacts(id) ON DELETE SET NULL;
ALTER TABLE public.communication_entries
  ADD CONSTRAINT communication_entries_handler_fkey
  FOREIGN KEY (contact_handler_id) REFERENCES public.contacts(id) ON DELETE SET NULL;

ALTER TABLE public.instructor_skills
  ADD CONSTRAINT instructor_skills_contact_id_fkey
  FOREIGN KEY (contact_id) REFERENCES public.contacts(id) ON DELETE CASCADE;

ALTER TABLE public.availability_blocks
  ADD CONSTRAINT availability_blocks_contact_id_fkey
  FOREIGN KEY (contact_id) REFERENCES public.contacts(id) ON DELETE CASCADE;

ALTER TABLE public.intake_checklists
  ADD CONSTRAINT intake_checklists_contact_id_fkey
  FOREIGN KEY (contact_id) REFERENCES public.contacts(id) ON DELETE CASCADE;
```

- [ ] **Step 2: Code-Migration für umbenannte FKs**

```bash
cd apps/web/src
grep -rn "\.eq('instructor_id'" .   # alle treffer auf contact_id ändern
grep -rn "\.eq('person_id'" .       # alle treffer auf contact_id ändern (außer comm_entries: contact_person_id)
```

Manuell jeden Treffer anpassen. Build muss grün bleiben.

- [ ] **Step 3: Run + verify**

```bash
npx supabase migration up
cd apps/web && npm run build
```

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "refactor(db): rename FK columns to contact_id (Phase M3.6)"
```

---

## Task J2: Compatibility-Views droppen

**Files:**
- Create: `supabase/migrations/0086_drop_legacy_views.sql`

- [ ] **Step 1: Drop**

```sql
-- 0086: Drop compatibility views

DROP VIEW IF EXISTS public.instructors;
DROP VIEW IF EXISTS public.people;
DROP VIEW IF EXISTS public.organizations;

-- Legacy tables remain as `*_legacy` for 90 days as backup

COMMENT ON TABLE public.instructors_legacy IS
  'Pre-contacts-migration backup. To be dropped after 90 days (target: 2026-08-09).';
COMMENT ON TABLE public.people_legacy IS
  'Pre-contacts-migration backup. To be dropped after 90 days (target: 2026-08-09).';
COMMENT ON TABLE public.organizations_legacy IS
  'Pre-contacts-migration backup. To be dropped after 90 days (target: 2026-08-09).';
```

- [ ] **Step 2: Run + verify build**

```bash
npx supabase migration up
cd apps/web && npm run build
```

Expected: build still grün — alle Frontend-Konsumer wurden in J1 schon umgestellt.

- [ ] **Step 3: Commit**

```bash
git add supabase/migrations/0086_drop_legacy_views.sql
git commit -m "refactor(db): drop compatibility views, legacy tables remain as backup"
```

---

## Task J3: Final smoke-test

- [ ] **Step 1: Volle Test-Suite**

```bash
npx supabase test db --linked
cd apps/web && npx tsc --noEmit && npm run build
```

Expected: alle Tests grün, build success.

- [ ] **Step 2: Manueller End-to-End-Test**

App starten, Login, alle wichtigen Pfade durchklicken:
- Adressbuch lädt, Filter wechseln, Suche funktioniert
- Person anlegen → Dedup-Warnung erscheint bei Duplikat
- Detail-Panel öffnet, Tabs erscheinen rollenkonform
- Inline-Edit speichert + Audit-Log zeigt Eintrag
- Pipeline-Kanban funktioniert + öffnet ContactDetailPanel
- Saldo-Tab funktioniert für TL/DM
- Beziehungen anlegen + entfernen
- Verschmelzen-Flow durchspielen (auf Test-Daten!)

- [ ] **Step 3: Final Commit**

```bash
git commit --allow-empty -m "verify: E2E smoke test passed (Phase M3 complete)"
```

---

# Phase K — E2E-Tests + Hardening

## Task K1: Playwright-Tests für kritische Pfade

**Files:**
- Create: `apps/web/tests/e2e/addressbook-create-contact.spec.ts`
- Create: `apps/web/tests/e2e/contact-add-role.spec.ts`
- Create: `apps/web/tests/e2e/contact-merge.spec.ts`
- Create: `apps/web/tests/e2e/contact-gdpr-delete.spec.ts`
- Create: `apps/web/tests/e2e/contact-inline-edit.spec.ts`
- Create: `apps/web/tests/e2e/contact-relationships.spec.ts`

- [ ] **Step 1: addressbook-create-contact.spec.ts**

```typescript
// apps/web/tests/e2e/addressbook-create-contact.spec.ts
import { test, expect } from '@playwright/test'

test('create new person contact via Adressbuch', async ({ page }) => {
  await page.goto('/contacts')
  await page.click('button:has-text("+")')
  await page.click('label:has-text("Person")')
  await page.fill('[placeholder="Vorname"]', 'Test')
  await page.fill('[placeholder="Nachname"]', 'Person')
  await page.fill('[placeholder="Email"]', `test-${Date.now()}@example.com`)
  await page.click('label:has-text("Schüler")')
  await page.click('button:has-text("Erstellen")')
  await expect(page.locator('h1')).toContainText('Person, Test')
})
```

- [ ] **Step 2: contact-inline-edit.spec.ts**

```typescript
// apps/web/tests/e2e/contact-inline-edit.spec.ts
import { test, expect } from '@playwright/test'

test('inline-edit notes and verify audit log', async ({ page }) => {
  await page.goto('/contacts')
  await page.click('.addressbook__list li:first-child button')
  await page.click('text=Notizen')
  await page.fill('textarea[placeholder*="Frei wählbarer Text"]', 'Test note via E2E')
  await page.keyboard.press('Meta+Enter')
  await expect(page.locator('text=Test note via E2E')).toBeVisible()
  // Audit-Tab prüfen
  await page.click('text=Audit')
  await expect(page.locator('text=UPDATE contacts')).toBeVisible()
})
```

- [ ] **Step 3: Restliche Specs analog (merge, gdpr, role-add, relationships)**

Pattern: navigiere → führe Aktion aus → assertiere Effekt + Audit-Log-Eintrag.

- [ ] **Step 4: Run + commit**

```bash
cd apps/web && npx playwright test
git add apps/web/tests/e2e/
git commit -m "test(e2e): contacts CRM critical paths"
```

---

## Task K2: README + Migration-Notes

**Files:**
- Create: `docs/superpowers/runbooks/contacts-migration-runbook.md`

- [ ] **Step 1: Runbook**

```markdown
# Contacts Migration Runbook

## Pre-Flight (1 day before)
1. PITR-Backup verifizieren: Supabase Dashboard → Settings → Backups → Latest
2. Dedup-Audit laufen lassen:
   `./scripts/db/contacts-dedup-audit.sh > /tmp/dedup.csv`
3. CSV mit Dominik durchgehen, Verschmelzen-Pärchen markieren

## Phase M1 (Tag 1, Schema + Backfill)
1. `git pull && npx supabase migration up` (Migrations 0079–0084)
2. NOTICE-Output prüfen: "Backfilled X contacts (matches legacy total)"
3. pgTAP-Tests: `npx supabase test db --linked` — alle ok
4. Manuell verschmelzen für markierte Pärchen via SQL Editor:
   `SELECT merge_contacts('winner-id', 'loser-id');`

## Phase M2 (Tag 2, Compat-Views)
1. `npx supabase migration up` (0083)
2. Frontend startet auf neuen Views: `cd apps/web && npm run build`
3. Manueller Smoke-Test der App
4. Pause für 1–2 Tage zum Beobachten

## Phase M3 (Tag 3+, Frontend-Cutover)
- Schritt-für-Schritt Frontend-Migration je nach Plan
- Nach jedem PR: deploy + 24h beobachten

## Phase M3.6 (FK-Rename + View-Drop)
1. Verifizieren dass alle Frontend-Konsumer auf neuen Schema sind
2. `npx supabase migration up` (0085, 0086)
3. Build + E2E-Tests grün

## 90-Tage-Beobachtung
- Nach 90 Tagen ohne Probleme:
  `DROP TABLE instructors_legacy, people_legacy, organizations_legacy;`

## Rollback
- **Vor M2:** Migrations rückwärts → 0078 → Tabellen droppen
- **Vor M3.6:** Compat-Views droppen, _legacy-Tabellen umbenennen, Frontend rollback
- **Nach M3.6:** PITR-Restore (im worst-case), oder Re-Migration aus _legacy
```

- [ ] **Step 2: Commit**

```bash
git add docs/superpowers/runbooks/contacts-migration-runbook.md
git commit -m "docs(runbooks): contacts migration runbook"
```

---

## Self-Review

Final pass over the plan against the spec:

- ✅ §3 Datenmodell → Tasks A1–A6 (alle Tabellen, RLS, Trigger, RPCs)
- ✅ §4 Migrations-Strategie → Tasks B1, C1, J1, J2 (3 Phasen + Rollback)
- ✅ §5 UI-Architektur → Tasks F1, F3, G1–G7 (Adressbuch, Sidebar, Workflow-Migration)
- ✅ §5.4 ContactDetailPanel → Tasks E1–E11 (Skeleton + alle Tabs)
- ✅ §5.5 Inline-Edit überall → Tasks D3, D4, D5 + alle Tab-Implementations
- ✅ §6.1 GDPR → Task A5 (gdpr_anonymize), I1 (UI)
- ✅ §6.2 Dedup + Merge → Task A5 (RPCs), I2 (UI), F2 (Inline-Warnung im Create-Sheet)
- ✅ §6.3 Performance → Task A1 (GIN-Index), F1 (Pagination)
- ✅ §6.4 Notifications → nicht im MVP-Plan, später separater Spec
- ✅ §7 Tests → A1, A4, A5, A6 (pgTAP) + K1 (Playwright)

**Type-Konsistenz:** alle Datenmodell-Felder in `apps/web/src/types/contacts.ts` matchen die SQL-Schemata in `0079`. RPC-Signaturen `find_potential_duplicates`, `merge_contacts`, `gdpr_anonymize_contact` matchen die TypeScript-Wrapper.

**Placeholder-Scan:** Tasks E7–E11 haben einen Pattern-Verweis auf E4 (StudentTab) als Beispiel-Implementation, mit konkreten Hinweisen für jede Tab. Das ist akzeptabel — sie sind alle ähnlich strukturiert und der Pattern wird einmal vollständig in E2 (OverviewTab) und E4 (StudentTab) gezeigt.

---

## Execution Handoff

**Plan complete and saved to `docs/superpowers/plans/2026-05-09-adressverwaltung.md`. Two execution options:**

**1. Subagent-Driven (recommended)** — Ich dispatcher pro Task einen frischen Subagent, Review zwischen den Tasks, schnelle Iteration. Ideal für die rein-DB-Tasks (A1–A6, B1, B2, C1) und die isolierten Tab-Komponenten (E2–E11).

**2. Inline Execution** — Tasks werden in dieser Session ausgeführt mit Checkpoints zwischen Phasen. Mehr Kontrolle, aber langsamer.

**Welche Variante?**
