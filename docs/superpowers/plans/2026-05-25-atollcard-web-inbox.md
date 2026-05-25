# AtollCard Web-Inbox + Adressbuch-Import — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Owner-/CD-Inbox in Atoll Web für eingehende AtollCard-Leads bauen, plus atomarer Adressbuch-Import via Postgres-RPC mit Audit-Trail und bidirektionaler Bridge.

**Architecture:** Master-Detail-Screen parallel zum bestehenden `AddressbookScreen`, eine neue Migration mit `card_leads.imported_contact_id` plus Helper-View, eine `import_card_lead(uuid)` RPC mit Email-Match-Merge in einer Transaktion, Realtime-Updates via Supabase-Channel, kleines iOS-CTA-Update auf Deep-Link.

**Tech Stack:** Vite + React 18 + TypeScript + React-Query + Supabase JS Client + Vitest + Playwright + Postgres 15 + plpgsql + SwiftUI (für iOS-CTA).

**Spec:** `docs/superpowers/specs/2026-05-25-atollcard-web-inbox-design.md`

---

## Phase A — Schema-Foundation

### Task 1: Migration 0102 — Bridge-Spalte + Helper-View

**Files:**
- Create: `supabase/migrations/0102_card_leads_imported_contact.sql`

- [ ] **Step 1: Migration anlegen**

Inhalt von `supabase/migrations/0102_card_leads_imported_contact.sql`:

```sql
-- 0102_card_leads_imported_contact.sql
-- ─────────────────────────────────────────────────────────────────
-- AtollCard Web-Inbox Phase 1: Bridge-Spalte zwischen card_leads und
-- contacts, plus ein Inbox-View, der Card-Title joined.
-- Spec: docs/superpowers/specs/2026-05-25-atollcard-web-inbox-design.md
-- ─────────────────────────────────────────────────────────────────

-- Bridge-Spalte: welcher Contact wurde aus diesem Lead erstellt.
ALTER TABLE public.card_leads
  ADD COLUMN IF NOT EXISTS imported_contact_id uuid
    REFERENCES public.contacts(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_card_leads_imported_contact
  ON public.card_leads(imported_contact_id)
  WHERE imported_contact_id IS NOT NULL;

-- Convenience-View für die Inbox: joined card.title/slug/badge in einem Schritt.
-- security_invoker = on heisst: die RLS der Basistabellen (card_leads, cards)
-- wird vom Aufrufer angewendet — kein bypass.
CREATE OR REPLACE VIEW public.v_card_leads_inbox AS
SELECT
  l.id, l.card_id, l.first_name, l.last_name, l.email, l.phone,
  l.message, l.topic, l.captured_at, l.status, l.avatar_color,
  l.imported_to_address_book, l.imported_contact_id,
  c.slug      AS card_slug,
  c.title     AS card_title,
  c.badge     AS card_badge,
  c.person_id AS card_person_id
FROM public.card_leads l
JOIN public.cards c ON c.id = l.card_id;

ALTER VIEW public.v_card_leads_inbox SET (security_invoker = on);

-- Read-Permission für die View an authenticated Role.
GRANT SELECT ON public.v_card_leads_inbox TO authenticated;
```

- [ ] **Step 2: Migration lokal anwenden**

```bash
cd ~/Desktop/Developer/Dispo
supabase db push
```

Expected: `Applying migration 0102_card_leads_imported_contact.sql...` ohne Fehler.

- [ ] **Step 3: Schema verifizieren via psql**

```bash
supabase db inspect | grep -i imported_contact
psql "$DATABASE_URL" -c "\d public.card_leads" | grep imported_contact_id
psql "$DATABASE_URL" -c "SELECT count(*) FROM public.v_card_leads_inbox;"
```

Expected:
- Spalte `imported_contact_id uuid` mit FK zu contacts(id) ist da
- Index `idx_card_leads_imported_contact` ist da
- View liefert eine Zahl (RLS wirkt — als authenticated-User: nur eigene)

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/0102_card_leads_imported_contact.sql
git commit -m "feat(db): card_leads.imported_contact_id + v_card_leads_inbox view"
```

---

### Task 2: Migration 0103 — RPC `import_card_lead` (Create-Path)

**Files:**
- Create: `supabase/migrations/0103_rpc_import_card_lead.sql`

- [ ] **Step 1: RPC mit Create-Path schreiben**

Inhalt von `supabase/migrations/0103_rpc_import_card_lead.sql`:

```sql
-- 0103_rpc_import_card_lead.sql
-- ─────────────────────────────────────────────────────────────────
-- AtollCard Web-Inbox Phase 1: RPC zum atomaren Import eines Card-Leads
-- in die contacts-Tabelle, mit Email-Match-Merge, Audit-Note und Bridge.
-- ─────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.import_card_lead(p_lead_id uuid)
RETURNS TABLE (contact_id uuid, action text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_lead        public.card_leads%ROWTYPE;
  v_email_norm  text;
  v_existing    public.contacts%ROWTYPE;
  v_new_id      uuid;
  v_card_slug   text;
  v_audit_note  text;
BEGIN
  -- 1. Lead laden + RLS-Check (SELECT ist via card_leads_owner-Policy gefiltert)
  SELECT * INTO v_lead
  FROM public.card_leads
  WHERE id = p_lead_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'lead_not_found' USING ERRCODE = 'P0002';
  END IF;

  -- 2. Schon importiert? Idempotent: return existing.
  IF v_lead.imported_to_address_book = true
     AND v_lead.imported_contact_id IS NOT NULL THEN
    RETURN QUERY SELECT v_lead.imported_contact_id, 'already_imported'::text;
    RETURN;
  END IF;

  -- 3. Email normalisieren
  v_email_norm := lower(trim(v_lead.email));
  IF v_email_norm = '' THEN v_email_norm := NULL; END IF;

  -- 4. Email-Match suchen (primary_email ODER emails[] JSONB)
  IF v_email_norm IS NOT NULL THEN
    SELECT * INTO v_existing
    FROM public.contacts
    WHERE archived_at IS NULL
      AND (
        lower(primary_email) = v_email_norm
        OR EXISTS (
          SELECT 1 FROM jsonb_array_elements(emails) AS e
          WHERE lower(e->>'email') = v_email_norm
        )
      )
    ORDER BY created_at ASC
    LIMIT 1;
  END IF;

  -- 5. Audit-Note bauen (format konsistent über Merge- und Create-Pfad)
  SELECT slug INTO v_card_slug FROM public.cards WHERE id = v_lead.card_id;

  v_audit_note := format(
    E'\n\n[%s · aus Card-Inbox] Lead von "%s %s" (Karte: %s%s)\n  > "%s"',
    to_char(now(), 'YYYY-MM-DD HH24:MI'),
    coalesce(v_lead.first_name, ''),
    coalesce(v_lead.last_name, ''),
    v_card_slug,
    coalesce(', ' || v_lead.topic, ''),
    coalesce(v_lead.message, '(keine Nachricht)')
  );

  -- 6a. CREATE-Pfad (für Task 3 wird hier ein MERGE-Branch dazu kommen)
  INSERT INTO public.contacts (
    kind, first_name, last_name, primary_email,
    emails, phones, roles, tags, notes, source
  ) VALUES (
    'person',
    v_lead.first_name,
    v_lead.last_name,
    v_email_norm,
    CASE
      WHEN v_email_norm IS NULL THEN '[]'::jsonb
      ELSE jsonb_build_array(jsonb_build_object(
        'label',   'card-inbox',
        'email',   v_email_norm,
        'primary', true
      ))
    END,
    CASE
      WHEN v_lead.phone IS NULL OR v_lead.phone = '' THEN '[]'::jsonb
      ELSE jsonb_build_array(jsonb_build_object(
        'label', 'card-inbox',
        'e164',  v_lead.phone
      ))
    END,
    ARRAY[]::text[],
    ARRAY['card-inbox']::text[],
    v_audit_note,
    'atollcard:lead:' || v_lead.id::text
  )
  RETURNING id INTO v_new_id;

  -- Side-Effects auf den Lead
  UPDATE public.card_leads
  SET imported_to_address_book = true,
      status                   = 'imported',
      imported_contact_id      = v_new_id
  WHERE id = p_lead_id;

  RETURN QUERY SELECT v_new_id, 'created'::text;
END;
$$;

GRANT EXECUTE ON FUNCTION public.import_card_lead(uuid) TO authenticated;
```

Note: Step 1 enthält bewusst nur den CREATE-Path. Task 3 baut den MERGE-Branch ein. Das macht beide Migrationen reviewbar.

- [ ] **Step 2: Anwenden**

```bash
supabase db push
```

Expected: `Applying migration 0103_rpc_import_card_lead.sql...` ohne Fehler.

- [ ] **Step 3: Smoke-Test gegen DB (happy path)**

```bash
# Erstmal manuell einen Test-Lead anlegen (mit Email die NICHT in contacts existiert):
psql "$DATABASE_URL" <<'SQL'
INSERT INTO public.card_leads (card_id, first_name, last_name, email, phone, message, topic)
SELECT id, 'Testa', 'Testovic', 'testa.testovic.import@example.invalid',
       '+41791234567', 'Test-Message für RPC', 'Trial-Dive'
FROM public.cards WHERE slug = 'dominik-cd' LIMIT 1
RETURNING id;
SQL

# RPC aufrufen mit der zurückgegebenen Lead-ID:
psql "$DATABASE_URL" -c "SELECT * FROM import_card_lead('<lead-id-aus-step-zuvor>');"

# Erwarteter Output: contact_id + action='created'
# Verifizieren:
psql "$DATABASE_URL" -c "SELECT id, first_name, last_name, primary_email, source, tags
  FROM contacts
  WHERE source LIKE 'atollcard:lead:%'
  ORDER BY created_at DESC LIMIT 1;"

psql "$DATABASE_URL" -c "SELECT status, imported_to_address_book, imported_contact_id
  FROM card_leads
  WHERE email = 'testa.testovic.import@example.invalid';"
```

Expected:
- Contact erstellt mit `source='atollcard:lead:<uuid>'`, `tags='{card-inbox}'`, `primary_email='testa.testovic.import@example.invalid'`
- Lead: `status='imported'`, `imported_to_address_book=true`, `imported_contact_id=<contact-id>`

Aufräumen:
```sql
DELETE FROM contacts WHERE primary_email = 'testa.testovic.import@example.invalid';
DELETE FROM card_leads WHERE email = 'testa.testovic.import@example.invalid';
```

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/0103_rpc_import_card_lead.sql
git commit -m "feat(db): RPC import_card_lead — create path"
```

---

### Task 3: Migration 0104 — RPC erweitern um Merge-Path + Idempotenz

**Files:**
- Create: `supabase/migrations/0104_rpc_import_card_lead_merge.sql`

- [ ] **Step 1: Erweiterte RPC schreiben (CREATE OR REPLACE)**

Inhalt von `supabase/migrations/0104_rpc_import_card_lead_merge.sql`:

```sql
-- 0104_rpc_import_card_lead_merge.sql
-- ─────────────────────────────────────────────────────────────────
-- Erweitert import_card_lead um den MERGE-Path: bei Email-Match wird
-- in den bestehenden Contact gemergt, nur leere Felder werden gefüllt,
-- Email + Phone werden in den JSONB-Arrays angehängt, Audit-Note dranhängt.
-- ─────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.import_card_lead(p_lead_id uuid)
RETURNS TABLE (contact_id uuid, action text)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_lead        public.card_leads%ROWTYPE;
  v_email_norm  text;
  v_existing    public.contacts%ROWTYPE;
  v_new_id      uuid;
  v_card_slug   text;
  v_audit_note  text;
BEGIN
  SELECT * INTO v_lead FROM public.card_leads WHERE id = p_lead_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'lead_not_found' USING ERRCODE = 'P0002';
  END IF;

  IF v_lead.imported_to_address_book = true
     AND v_lead.imported_contact_id IS NOT NULL THEN
    RETURN QUERY SELECT v_lead.imported_contact_id, 'already_imported'::text;
    RETURN;
  END IF;

  v_email_norm := lower(trim(v_lead.email));
  IF v_email_norm = '' THEN v_email_norm := NULL; END IF;

  IF v_email_norm IS NOT NULL THEN
    SELECT * INTO v_existing
    FROM public.contacts
    WHERE archived_at IS NULL
      AND (
        lower(primary_email) = v_email_norm
        OR EXISTS (
          SELECT 1 FROM jsonb_array_elements(emails) AS e
          WHERE lower(e->>'email') = v_email_norm
        )
      )
    ORDER BY created_at ASC
    LIMIT 1;
  END IF;

  SELECT slug INTO v_card_slug FROM public.cards WHERE id = v_lead.card_id;

  v_audit_note := format(
    E'\n\n[%s · aus Card-Inbox] Lead von "%s %s" (Karte: %s%s)\n  > "%s"',
    to_char(now(), 'YYYY-MM-DD HH24:MI'),
    coalesce(v_lead.first_name, ''),
    coalesce(v_lead.last_name, ''),
    v_card_slug,
    coalesce(', ' || v_lead.topic, ''),
    coalesce(v_lead.message, '(keine Nachricht)')
  );

  IF v_existing.id IS NOT NULL THEN
    -- MERGE-Pfad: nur leere Felder füllen, JSONB-Arrays anhängen wo Wert neu ist
    UPDATE public.contacts
    SET
      first_name = coalesce(nullif(first_name, ''), v_lead.first_name),
      last_name  = coalesce(nullif(last_name, ''),  v_lead.last_name),
      primary_email = coalesce(nullif(primary_email, ''), v_email_norm),
      emails = CASE
        WHEN v_email_norm IS NULL THEN emails
        WHEN EXISTS (
          SELECT 1 FROM jsonb_array_elements(emails) e
          WHERE lower(e->>'email') = v_email_norm
        ) THEN emails
        ELSE emails || jsonb_build_array(jsonb_build_object(
          'label', 'card-inbox', 'email', v_email_norm))
      END,
      phones = CASE
        WHEN v_lead.phone IS NULL OR v_lead.phone = '' THEN phones
        WHEN EXISTS (
          SELECT 1 FROM jsonb_array_elements(phones) p
          WHERE p->>'e164' = v_lead.phone
        ) THEN phones
        ELSE phones || jsonb_build_array(jsonb_build_object(
          'label', 'card-inbox', 'e164', v_lead.phone))
      END,
      notes = coalesce(notes, '') || v_audit_note,
      updated_at = now()
    WHERE id = v_existing.id;

    UPDATE public.card_leads
    SET imported_to_address_book = true,
        status                   = 'imported',
        imported_contact_id      = v_existing.id
    WHERE id = p_lead_id;

    RETURN QUERY SELECT v_existing.id, 'merged'::text;

  ELSE
    -- CREATE-Pfad (identisch zu 0103)
    INSERT INTO public.contacts (
      kind, first_name, last_name, primary_email,
      emails, phones, roles, tags, notes, source
    ) VALUES (
      'person', v_lead.first_name, v_lead.last_name, v_email_norm,
      CASE WHEN v_email_norm IS NULL THEN '[]'::jsonb
           ELSE jsonb_build_array(jsonb_build_object(
             'label','card-inbox','email',v_email_norm,'primary',true))
      END,
      CASE WHEN v_lead.phone IS NULL OR v_lead.phone = '' THEN '[]'::jsonb
           ELSE jsonb_build_array(jsonb_build_object(
             'label','card-inbox','e164',v_lead.phone))
      END,
      ARRAY[]::text[],
      ARRAY['card-inbox']::text[],
      v_audit_note,
      'atollcard:lead:' || v_lead.id::text
    )
    RETURNING id INTO v_new_id;

    UPDATE public.card_leads
    SET imported_to_address_book = true,
        status                   = 'imported',
        imported_contact_id      = v_new_id
    WHERE id = p_lead_id;

    RETURN QUERY SELECT v_new_id, 'created'::text;
  END IF;
END;
$$;
```

- [ ] **Step 2: Anwenden**

```bash
supabase db push
```

- [ ] **Step 3: Smoke-Test gegen DB (alle 3 Paths)**

```bash
# Setup: bestehenden Contact anlegen
psql "$DATABASE_URL" <<'SQL'
INSERT INTO public.contacts (kind, first_name, primary_email, emails)
VALUES ('person', 'Alex', 'alex.merge.test@example.invalid',
        '[{"label":"work","email":"alex.merge.test@example.invalid","primary":true}]'::jsonb)
RETURNING id;
SQL

# Lead mit derselben Email (MERGE-Path)
psql "$DATABASE_URL" <<'SQL'
INSERT INTO public.card_leads (card_id, first_name, last_name, email, phone, message, topic)
SELECT id, 'Alex', 'Müller', 'alex.merge.test@example.invalid',
       '+41799999999', 'Will IDC machen', 'IDC-Anfrage'
FROM public.cards WHERE slug = 'dominik-cd' LIMIT 1
RETURNING id;
SQL

# RPC aufrufen — sollte 'merged' returnen
psql "$DATABASE_URL" -c "SELECT * FROM import_card_lead('<lead-id>');"

# Verifizieren: bestehender Contact, last_name gefüllt, phone in array, note gewachsen
psql "$DATABASE_URL" -c "SELECT first_name, last_name, primary_email,
  jsonb_array_length(emails), jsonb_array_length(phones),
  length(notes) FROM contacts
  WHERE primary_email = 'alex.merge.test@example.invalid';"

# Idempotenz-Test: zweimal aufrufen → 'already_imported'
psql "$DATABASE_URL" -c "SELECT * FROM import_card_lead('<lead-id>');"

# Aufräumen
psql "$DATABASE_URL" -c "
  DELETE FROM card_leads WHERE email LIKE '%.merge.test@example.invalid';
  DELETE FROM contacts WHERE primary_email LIKE '%.merge.test@example.invalid';
"
```

Expected:
- 1. Aufruf: `action='merged'`, contact_id = der bestehende
- Contact danach: first_name='Alex' (unverändert), last_name='Müller' (neu), 1 email, 1 phone, notes gewachsen
- 2. Aufruf: `action='already_imported'`, gleicher contact_id

- [ ] **Step 4: Commit**

```bash
git add supabase/migrations/0104_rpc_import_card_lead_merge.sql
git commit -m "feat(db): import_card_lead RPC — merge path + idempotency"
```

---

## Phase B — TypeScript-Backbone

### Task 4: TypeScript-Types für CardLead

**Files:**
- Create: `apps/web/src/types/cardLeads.ts`

- [ ] **Step 1: Type-File schreiben**

Inhalt von `apps/web/src/types/cardLeads.ts`:

```typescript
/**
 * AtollCard Card-Lead Types
 *
 * Mirrors the v_card_leads_inbox view (defined in migration 0102).
 * Inserts/updates write directly to public.card_leads.
 */

export type CardLeadStatus =
  | 'new'
  | 'opened'
  | 'contacted'
  | 'imported'
  | 'archived'
  | 'spam'

export interface CardLeadRow {
  id: string
  card_id: string

  first_name: string
  last_name: string | null
  email: string | null
  phone: string | null
  message: string | null
  topic: string | null

  captured_at: string       // ISO timestamp
  status: CardLeadStatus
  avatar_color: string | null

  imported_to_address_book: boolean
  imported_contact_id: string | null

  // Joined from cards
  card_slug: string
  card_title: string
  card_badge: string | null
  card_person_id: string
}

/** RPC return type for public.import_card_lead(p_lead_id) */
export interface ImportCardLeadResult {
  contact_id: string
  action: 'created' | 'merged' | 'already_imported'
}
```

- [ ] **Step 2: Commit**

```bash
git add apps/web/src/types/cardLeads.ts
git commit -m "feat(types): CardLead + ImportCardLeadResult types"
```

---

### Task 5: Queries-Lib mit Unit-Tests

**Files:**
- Create: `apps/web/src/lib/cardLeadQueries.ts`
- Create: `apps/web/src/lib/__tests__/cardLeadQueries.test.ts`

- [ ] **Step 1: Failing Tests schreiben**

Inhalt von `apps/web/src/lib/__tests__/cardLeadQueries.test.ts`:

```typescript
import { describe, it, expect, vi, beforeEach } from 'vitest'
import {
  buildCardLeadsFilter,
  importCardLeadRpc,
  updateLeadStatus,
} from '../cardLeadQueries'

// ─── Supabase mock ──────────────────────────────────────────────────
const mockRpc = vi.fn()
const mockFrom = vi.fn()
const mockUpdate = vi.fn()
const mockEq = vi.fn()

vi.mock('@/lib/supabase', () => ({
  supabase: {
    rpc: (...args: unknown[]) => mockRpc(...args),
    from: (...args: unknown[]) => mockFrom(...args),
  },
}))

beforeEach(() => {
  mockRpc.mockReset()
  mockFrom.mockReset()
  mockUpdate.mockReset()
  mockEq.mockReset()

  mockEq.mockResolvedValue({ data: null, error: null })
  mockUpdate.mockReturnValue({ eq: mockEq })
  mockFrom.mockReturnValue({ update: mockUpdate })
})

// ─── buildCardLeadsFilter ───────────────────────────────────────────
describe('buildCardLeadsFilter', () => {
  it('returns empty filters for view=all without search', () => {
    expect(buildCardLeadsFilter({ view: 'all' })).toEqual({})
  })

  it('returns single status for view=new', () => {
    expect(buildCardLeadsFilter({ view: 'new' })).toEqual({ statuses: ['new'] })
  })

  it('returns two statuses for view=in_progress (opened + contacted)', () => {
    expect(buildCardLeadsFilter({ view: 'in_progress' })).toEqual({
      statuses: ['opened', 'contacted'],
    })
  })

  it('returns search text trimmed and lowercased', () => {
    expect(buildCardLeadsFilter({ view: 'all', search: '  Alex  ' })).toEqual({
      search: 'alex',
    })
  })

  it('drops empty search', () => {
    expect(buildCardLeadsFilter({ view: 'all', search: '   ' })).toEqual({})
  })
})

// ─── importCardLeadRpc ──────────────────────────────────────────────
describe('importCardLeadRpc', () => {
  it('calls supabase.rpc with import_card_lead + lead id', async () => {
    mockRpc.mockResolvedValue({
      data: [{ contact_id: 'c-1', action: 'created' }],
      error: null,
    })
    const result = await importCardLeadRpc('lead-42')
    expect(mockRpc).toHaveBeenCalledWith('import_card_lead', { p_lead_id: 'lead-42' })
    expect(result).toEqual({ contact_id: 'c-1', action: 'created' })
  })

  it('throws when RPC returns an error', async () => {
    mockRpc.mockResolvedValue({
      data: null,
      error: { message: 'lead_not_found', code: 'P0002' },
    })
    await expect(importCardLeadRpc('missing')).rejects.toThrow(/lead_not_found/)
  })

  it('returns first row when RPC returns array', async () => {
    mockRpc.mockResolvedValue({
      data: [{ contact_id: 'c-9', action: 'merged' }],
      error: null,
    })
    const result = await importCardLeadRpc('lead-9')
    expect(result.action).toBe('merged')
  })
})

// ─── updateLeadStatus ───────────────────────────────────────────────
describe('updateLeadStatus', () => {
  it('updates status via from().update().eq()', async () => {
    await updateLeadStatus('lead-1', 'archived')
    expect(mockFrom).toHaveBeenCalledWith('card_leads')
    expect(mockUpdate).toHaveBeenCalledWith({ status: 'archived' })
    expect(mockEq).toHaveBeenCalledWith('id', 'lead-1')
  })

  it('throws when update errors', async () => {
    mockEq.mockResolvedValue({ data: null, error: { message: 'rls_violation' } })
    await expect(updateLeadStatus('lead-1', 'spam')).rejects.toThrow(/rls_violation/)
  })
})
```

- [ ] **Step 2: Run Tests, verify they fail**

```bash
cd apps/web
npm run test -- src/lib/__tests__/cardLeadQueries.test.ts
```

Expected: All tests FAIL with "Cannot find module '../cardLeadQueries'".

- [ ] **Step 3: Queries-Lib implementieren**

Inhalt von `apps/web/src/lib/cardLeadQueries.ts`:

```typescript
/**
 * AtollCard Card-Lead Queries
 *
 * PostgREST wrappers + RPC client for the card-inbox.
 * Reads go via the v_card_leads_inbox view; writes go to card_leads.
 */
import { supabase } from '@/lib/supabase'
import type {
  CardLeadRow,
  CardLeadStatus,
  ImportCardLeadResult,
} from '@/types/cardLeads'

export type CardLeadViewId =
  | 'all' | 'new' | 'in_progress' | 'imported' | 'archived' | 'spam'

export interface CardLeadFilterInput {
  view: CardLeadViewId
  search?: string
}

export interface CardLeadFilter {
  statuses?: CardLeadStatus[]
  search?: string
}

/**
 * Convert URL-state into a Postgres-friendly filter object.
 * `in_progress` is a UI alias for status IN (opened, contacted).
 */
export function buildCardLeadsFilter(input: CardLeadFilterInput): CardLeadFilter {
  const out: CardLeadFilter = {}

  switch (input.view) {
    case 'new':         out.statuses = ['new']; break
    case 'in_progress': out.statuses = ['opened', 'contacted']; break
    case 'imported':    out.statuses = ['imported']; break
    case 'archived':    out.statuses = ['archived']; break
    case 'spam':        out.statuses = ['spam']; break
    case 'all':         /* no status filter */ break
  }

  const search = input.search?.trim().toLowerCase()
  if (search) out.search = search

  return out
}

/**
 * Fetch a page of card-leads from the inbox view.
 * RLS does the owner-scoping; we order by captured_at desc and cap at 500
 * (same convention as AddressbookScreen).
 */
export async function fetchCardLeads(
  filter: CardLeadFilter,
  limit = 500,
): Promise<CardLeadRow[]> {
  let q = supabase
    .from('v_card_leads_inbox')
    .select('*')
    .order('captured_at', { ascending: false })
    .limit(limit)

  if (filter.statuses && filter.statuses.length > 0) {
    q = q.in('status', filter.statuses)
  }

  if (filter.search) {
    // OR across first_name, last_name, email, topic, message
    const s = filter.search.replace(/[%,]/g, ' ')
    q = q.or(
      `first_name.ilike.%${s}%,` +
      `last_name.ilike.%${s}%,` +
      `email.ilike.%${s}%,` +
      `topic.ilike.%${s}%,` +
      `message.ilike.%${s}%`
    )
  }

  const { data, error } = await q
  if (error) throw new Error(error.message)
  return (data ?? []) as CardLeadRow[]
}

/**
 * Count of unread (status='new') leads — for the Sidebar badge.
 */
export async function fetchUnreadCount(): Promise<number> {
  const { count, error } = await supabase
    .from('v_card_leads_inbox')
    .select('id', { count: 'exact', head: true })
    .eq('status', 'new')

  if (error) throw new Error(error.message)
  return count ?? 0
}

/**
 * Update a single lead's status. Returns void on success, throws on RLS / FK.
 */
export async function updateLeadStatus(
  leadId: string,
  status: CardLeadStatus,
): Promise<void> {
  const { error } = await supabase
    .from('card_leads')
    .update({ status })
    .eq('id', leadId)

  if (error) throw new Error(error.message)
}

/**
 * Trigger the import_card_lead RPC.
 * Returns { contact_id, action: 'created' | 'merged' | 'already_imported' }.
 */
export async function importCardLeadRpc(
  leadId: string,
): Promise<ImportCardLeadResult> {
  const { data, error } = await supabase.rpc('import_card_lead', {
    p_lead_id: leadId,
  })

  if (error) throw new Error(error.message)

  // RPC returns SETOF — Supabase serializes that as an array of rows.
  const row = Array.isArray(data) ? data[0] : data
  if (!row) throw new Error('import_card_lead returned no row')

  return row as ImportCardLeadResult
}
```

- [ ] **Step 4: Run Tests, verify they pass**

```bash
cd apps/web
npm run test -- src/lib/__tests__/cardLeadQueries.test.ts
```

Expected: All 11 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add apps/web/src/lib/cardLeadQueries.ts apps/web/src/lib/__tests__/cardLeadQueries.test.ts
git commit -m "feat(web): cardLeadQueries lib + unit tests"
```

---

### Task 6: React-Query Hook `useCardLeads`

**Files:**
- Create: `apps/web/src/hooks/useCardLeads.ts`

- [ ] **Step 1: Hook schreiben**

Inhalt von `apps/web/src/hooks/useCardLeads.ts`:

```typescript
/**
 * React-Query hook for the card-inbox list.
 *
 * Stale-time 30s — the realtime channel (useCardLeadRealtime) handles
 * invalidation on INSERT events, so we don't need aggressive polling.
 */
import { useQuery } from '@tanstack/react-query'
import {
  buildCardLeadsFilter,
  fetchCardLeads,
  type CardLeadViewId,
} from '@/lib/cardLeadQueries'

export function cardLeadsQueryKey(view: CardLeadViewId, search?: string) {
  return ['card-leads', view, search ?? ''] as const
}

export function useCardLeads(view: CardLeadViewId, search?: string) {
  const filter = buildCardLeadsFilter({ view, search })

  return useQuery({
    queryKey: cardLeadsQueryKey(view, search),
    queryFn: () => fetchCardLeads(filter),
    staleTime: 30_000,
    refetchOnWindowFocus: true,
  })
}
```

- [ ] **Step 2: Commit**

```bash
git add apps/web/src/hooks/useCardLeads.ts
git commit -m "feat(web): useCardLeads React-Query hook"
```

---

### Task 7: Action-, Realtime- und Unread-Count-Hooks

**Files:**
- Create: `apps/web/src/hooks/useCardLeadActions.ts`
- Create: `apps/web/src/hooks/useCardLeadRealtime.ts`
- Create: `apps/web/src/hooks/useCardLeadsUnreadCount.ts`

- [ ] **Step 1: Actions-Hook schreiben**

Inhalt von `apps/web/src/hooks/useCardLeadActions.ts`:

```typescript
/**
 * Mutation actions for card-inbox.
 *
 * Optimistic update on status changes — roll back on error.
 * Import goes through the RPC and invalidates BOTH the card-leads list
 * and the contacts list (the new/merged contact appears in Adressbuch).
 */
import { useMutation, useQueryClient } from '@tanstack/react-query'
import {
  importCardLeadRpc,
  updateLeadStatus,
} from '@/lib/cardLeadQueries'
import type { CardLeadStatus, CardLeadRow } from '@/types/cardLeads'

export function useUpdateLeadStatus() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: ({ id, status }: { id: string; status: CardLeadStatus }) =>
      updateLeadStatus(id, status),
    onMutate: async ({ id, status }) => {
      // Optimistically patch every cached card-leads page
      await qc.cancelQueries({ queryKey: ['card-leads'] })
      const snapshots: Array<[unknown, CardLeadRow[] | undefined]> = []
      qc.getQueriesData<CardLeadRow[]>({ queryKey: ['card-leads'] }).forEach(([key, rows]) => {
        snapshots.push([key, rows])
        if (rows) {
          qc.setQueryData<CardLeadRow[]>(key, rows.map((r) => r.id === id ? { ...r, status } : r))
        }
      })
      return { snapshots }
    },
    onError: (_err, _vars, ctx) => {
      // Rollback
      ctx?.snapshots.forEach(([key, rows]) => qc.setQueryData(key, rows))
    },
    onSettled: () => {
      qc.invalidateQueries({ queryKey: ['card-leads'] })
      qc.invalidateQueries({ queryKey: ['card-leads-unread'] })
    },
  })
}

export function useImportCardLead() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: (leadId: string) => importCardLeadRpc(leadId),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['card-leads'] })
      qc.invalidateQueries({ queryKey: ['card-leads-unread'] })
      qc.invalidateQueries({ queryKey: ['contacts'] })
    },
  })
}
```

- [ ] **Step 2: Realtime-Hook schreiben**

Inhalt von `apps/web/src/hooks/useCardLeadRealtime.ts`:

```typescript
/**
 * Realtime channel for card-leads. Invalidates the React-Query cache on
 * any INSERT/UPDATE/DELETE event so the list and badge stay live.
 *
 * Reconnect strategy: Supabase JS client handles backoff internally.
 * If the channel closes unexpectedly we expose onClose so the caller
 * can show a toast.
 */
import { useEffect } from 'react'
import { useQueryClient } from '@tanstack/react-query'
import { supabase } from '@/lib/supabase'

export interface UseCardLeadRealtimeOpts {
  onInsert?: (row: { id: string }) => void
  onClose?: () => void
}

export function useCardLeadRealtime(opts: UseCardLeadRealtimeOpts = {}) {
  const qc = useQueryClient()

  useEffect(() => {
    const channel = supabase
      .channel('card_leads_inbox')
      .on(
        'postgres_changes',
        { event: 'INSERT', schema: 'public', table: 'card_leads' },
        (payload) => {
          qc.invalidateQueries({ queryKey: ['card-leads'] })
          qc.invalidateQueries({ queryKey: ['card-leads-unread'] })
          opts.onInsert?.(payload.new as { id: string })
        },
      )
      .on(
        'postgres_changes',
        { event: 'UPDATE', schema: 'public', table: 'card_leads' },
        () => {
          qc.invalidateQueries({ queryKey: ['card-leads'] })
          qc.invalidateQueries({ queryKey: ['card-leads-unread'] })
        },
      )
      .on('system', { event: 'disconnect' }, () => opts.onClose?.())
      .subscribe()

    return () => {
      void supabase.removeChannel(channel)
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])
}
```

- [ ] **Step 3: Unread-Count-Hook schreiben**

Inhalt von `apps/web/src/hooks/useCardLeadsUnreadCount.ts`:

```typescript
/**
 * Sidebar badge — count of card-leads with status='new'.
 *
 * Refetches on window focus + whenever the realtime channel (in
 * useCardLeadRealtime, attached at the screen level) invalidates the
 * 'card-leads-unread' query key.
 */
import { useQuery } from '@tanstack/react-query'
import { fetchUnreadCount } from '@/lib/cardLeadQueries'

export function useCardLeadsUnreadCount() {
  return useQuery({
    queryKey: ['card-leads-unread'],
    queryFn: fetchUnreadCount,
    staleTime: 30_000,
    refetchOnWindowFocus: true,
  })
}
```

- [ ] **Step 4: Smoke-Build**

```bash
cd apps/web
npm run build 2>&1 | tail -20
```

Expected: build succeeds, no TS errors mentioning the new hook files.

- [ ] **Step 5: Commit**

```bash
git add apps/web/src/hooks/useCardLead*.ts
git commit -m "feat(web): card-lead hooks (actions, realtime, unread-count)"
```

---

## Phase C — UI-Komponenten

### Task 8: `CardLeadStatusPill` Komponente

**Files:**
- Create: `apps/web/src/components/CardLeadStatusPill.tsx`

- [ ] **Step 1: Pill-Komponente schreiben**

Inhalt von `apps/web/src/components/CardLeadStatusPill.tsx`:

```typescript
import type { CardLeadStatus } from '@/types/cardLeads'

const STATUS_COLOR: Record<CardLeadStatus, string> = {
  new:       'var(--brand-red)',
  opened:    'var(--brand-amber)',
  contacted: 'var(--brand-blue)',
  imported:  'var(--brand-teal)',
  archived:  'var(--text-tertiary)',
  spam:      'var(--text-tertiary)',
}

const STATUS_LABEL: Record<CardLeadStatus, string> = {
  new:       'Neu',
  opened:    'Geöffnet',
  contacted: 'Kontaktiert',
  imported:  'Importiert',
  archived:  'Archiviert',
  spam:      'Spam',
}

export function CardLeadStatusPill({ status }: { status: CardLeadStatus }) {
  const color = STATUS_COLOR[status]
  const label = STATUS_LABEL[status]
  const strikethrough = status === 'spam'

  return (
    <span
      style={{
        display: 'inline-flex',
        alignItems: 'center',
        padding: '2px 8px',
        borderRadius: 12,
        background: `color-mix(in srgb, ${color} 14%, transparent)`,
        color,
        fontSize: 11,
        fontWeight: 600,
        textTransform: 'uppercase',
        letterSpacing: '.05em',
        textDecoration: strikethrough ? 'line-through' : 'none',
      }}
    >
      {label}
    </span>
  )
}
```

- [ ] **Step 2: Commit**

```bash
git add apps/web/src/components/CardLeadStatusPill.tsx
git commit -m "feat(web): CardLeadStatusPill component"
```

---

### Task 9: `CardLeadRow` Komponente

**Files:**
- Create: `apps/web/src/components/CardLeadRow.tsx`

- [ ] **Step 1: Row-Komponente schreiben**

Inhalt von `apps/web/src/components/CardLeadRow.tsx`:

```typescript
import { Avatar } from '@/foundation'
import { CardLeadStatusPill } from './CardLeadStatusPill'
import type { CardLeadRow as CardLeadRowData } from '@/types/cardLeads'

interface Props {
  lead: CardLeadRowData
  selected: boolean
  onClick: () => void
}

function formatRelative(iso: string): string {
  const d = new Date(iso)
  const now = new Date()
  const diffMin = Math.floor((now.getTime() - d.getTime()) / 60_000)
  if (diffMin < 1) return 'jetzt'
  if (diffMin < 60) return `vor ${diffMin} Min`
  const diffH = Math.floor(diffMin / 60)
  if (diffH < 24) return `vor ${diffH} h`
  const diffD = Math.floor(diffH / 24)
  if (diffD < 7) return `vor ${diffD} d`
  return d.toLocaleDateString('de-CH', { day: '2-digit', month: 'short' })
}

export function CardLeadRow({ lead, selected, onClick }: Props) {
  const displayName = [lead.first_name, lead.last_name].filter(Boolean).join(' ') || '(ohne Namen)'
  const initials = displayName.split(' ').map(p => p[0]).slice(0, 2).join('').toUpperCase()

  return (
    <button
      type="button"
      onClick={onClick}
      style={{
        display: 'flex',
        gap: 12,
        alignItems: 'flex-start',
        padding: '12px 14px',
        background: selected ? 'var(--surface-selected)' : 'transparent',
        border: 'none',
        borderBottom: '1px solid var(--border-subtle)',
        width: '100%',
        textAlign: 'left',
        cursor: 'pointer',
      }}
    >
      <Avatar name={displayName} initials={initials} color={lead.avatar_color ?? undefined} size={36} />

      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', gap: 8 }}>
          <span style={{
            fontSize: 14,
            fontWeight: lead.status === 'new' ? 700 : 500,
            overflow: 'hidden',
            textOverflow: 'ellipsis',
            whiteSpace: 'nowrap',
          }}>
            {displayName}
          </span>
          <span style={{ fontSize: 11, color: 'var(--text-tertiary)', flexShrink: 0 }}>
            {formatRelative(lead.captured_at)}
          </span>
        </div>

        <div style={{ fontSize: 12, color: 'var(--text-secondary)', marginTop: 2 }}>
          {lead.card_title}{lead.topic ? ` · ${lead.topic}` : ''}
        </div>

        <div style={{ marginTop: 6 }}>
          <CardLeadStatusPill status={lead.status} />
        </div>
      </div>
    </button>
  )
}
```

- [ ] **Step 2: Commit**

```bash
git add apps/web/src/components/CardLeadRow.tsx
git commit -m "feat(web): CardLeadRow list-pane row component"
```

---

### Task 10: `CardInboxScreen` — Master-Detail-Shell

**Files:**
- Create: `apps/web/src/screens/contacts/CardInboxScreen.tsx`

- [ ] **Step 1: Screen schreiben**

Inhalt von `apps/web/src/screens/contacts/CardInboxScreen.tsx`:

```typescript
/**
 * AtollCard Card-Inbox screen — owner/CD-only view of incoming card_leads.
 *
 * URL params:
 *   ?view=<id>       saved view (default: 'new')
 *   ?q=<text>        search
 *   ?lead=<id>       selected lead (deep-link target from iOS)
 */
import { useEffect } from 'react'
import { useSearchParams } from 'react-router-dom'
import {
  MasterDetail, ListPane, DetailPane, SearchInput, EmptyState, Loader,
} from '@/foundation'
import { useCardLeads } from '@/hooks/useCardLeads'
import { useCardLeadRealtime } from '@/hooks/useCardLeadRealtime'
import { useUpdateLeadStatus } from '@/hooks/useCardLeadActions'
import { CardLeadRow } from '@/components/CardLeadRow'
import { CardInboxDetailPanel } from './CardInboxDetailPanel'
import type { CardLeadViewId } from '@/lib/cardLeadQueries'

const SAVED_VIEWS: Array<{ id: CardLeadViewId; label: string }> = [
  { id: 'all',         label: 'Alle' },
  { id: 'new',         label: 'Neu' },
  { id: 'in_progress', label: 'In Bearbeitung' },
  { id: 'imported',    label: 'Importiert' },
  { id: 'archived',    label: 'Archiv' },
  { id: 'spam',        label: 'Spam' },
]

export function CardInboxScreen() {
  const [params, setParams] = useSearchParams()
  const view   = (params.get('view') ?? 'new') as CardLeadViewId
  const search = params.get('q') ?? ''
  const leadId = params.get('lead')

  const { data: leads = [], isFetching } = useCardLeads(view, search)
  const updateStatus = useUpdateLeadStatus()

  useCardLeadRealtime()

  // Auto-set status='opened' when a lead is opened for the first time
  const selectedLead = leads.find((l) => l.id === leadId)
  useEffect(() => {
    if (selectedLead && selectedLead.status === 'new') {
      updateStatus.mutate({ id: selectedLead.id, status: 'opened' })
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [selectedLead?.id])

  function setView(id: CardLeadViewId) {
    setParams((prev) => {
      const next = new URLSearchParams(prev)
      next.set('view', id)
      next.delete('lead')
      return next
    })
  }

  function setSearch(value: string) {
    setParams((prev) => {
      const next = new URLSearchParams(prev)
      if (value) next.set('q', value); else next.delete('q')
      return next
    })
  }

  function selectLead(id: string) {
    setParams((prev) => {
      const next = new URLSearchParams(prev)
      next.set('lead', id)
      return next
    })
  }

  function clearLead() {
    setParams((prev) => {
      const next = new URLSearchParams(prev)
      next.delete('lead')
      return next
    })
  }

  return (
    <div className="atoll-screen">
      <div
        className="atoll-page-header"
        style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between',
                 padding: '16px 24px 0', flexShrink: 0 }}
      >
        <h1 style={{ fontSize: 22, fontWeight: 700, margin: 0 }}>Card-Inbox</h1>
      </div>

      <div className="atoll-screen__body atoll-screen__body--full">
        <MasterDetail>
          <ListPane
            toolbar={
              <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--space-2)',
                            padding: '8px 12px 0' }}>
                <SearchInput
                  value={search}
                  onChange={setSearch}
                  ariaLabel="Card-Leads durchsuchen"
                  placeholder="Name, Email, Topic …"
                />
                <div style={{ display: 'flex', gap: 6, overflowX: 'auto',
                              paddingBottom: 'var(--space-1)', scrollbarWidth: 'none' }}>
                  {SAVED_VIEWS.map((v) => (
                    <button
                      key={v.id}
                      type="button"
                      onClick={() => setView(v.id)}
                      className={`atoll-chip ${view === v.id ? 'atoll-chip--active' : ''}`}
                    >
                      {v.label}
                    </button>
                  ))}
                </div>
              </div>
            }
          >
            {isFetching && leads.length === 0 ? (
              <Loader />
            ) : leads.length === 0 ? (
              <EmptyState
                title={
                  view === 'new'      ? 'Alle Leads sind bearbeitet. ✓'
                : view === 'spam'     ? 'Kein Spam — die Welt ist freundlich.'
                : 'Noch keine Card-Leads. Sobald jemand deine Public-Card-Seite ausfüllt, landet die Anfrage hier.'
                }
              />
            ) : (
              <div role="list">
                {leads.map((lead) => (
                  <CardLeadRow
                    key={lead.id}
                    lead={lead}
                    selected={lead.id === leadId}
                    onClick={() => selectLead(lead.id)}
                  />
                ))}
              </div>
            )}
          </ListPane>

          <DetailPane>
            {selectedLead ? (
              <CardInboxDetailPanel lead={selectedLead} onClose={clearLead} />
            ) : (
              <EmptyState title="Wähle einen Lead aus der Liste." />
            )}
          </DetailPane>
        </MasterDetail>
      </div>
    </div>
  )
}
```

- [ ] **Step 2: Commit (auch wenn CardInboxDetailPanel noch fehlt — Build wird in Task 11 grün)**

```bash
git add apps/web/src/screens/contacts/CardInboxScreen.tsx
git commit -m "feat(web): CardInboxScreen master-detail shell (detail panel follows)"
```

---

### Task 11: `CardInboxDetailPanel` — Lead-Details + Aktionen

**Files:**
- Create: `apps/web/src/screens/contacts/CardInboxDetailPanel.tsx`

- [ ] **Step 1: Detail-Panel schreiben**

Inhalt von `apps/web/src/screens/contacts/CardInboxDetailPanel.tsx`:

```typescript
import { useNavigate } from 'react-router-dom'
import { Avatar, Icon } from '@/foundation'
import { CardLeadStatusPill } from '@/components/CardLeadStatusPill'
import {
  useUpdateLeadStatus,
  useImportCardLead,
} from '@/hooks/useCardLeadActions'
import type { CardLeadRow } from '@/types/cardLeads'

interface Props {
  lead: CardLeadRow
  onClose: () => void
}

export function CardInboxDetailPanel({ lead, onClose }: Props) {
  const updateStatus = useUpdateLeadStatus()
  const importLead   = useImportCardLead()
  const navigate     = useNavigate()

  const displayName = [lead.first_name, lead.last_name].filter(Boolean).join(' ') || '(ohne Namen)'
  const initials    = displayName.split(' ').map(p => p[0]).slice(0, 2).join('').toUpperCase()

  const mailto = lead.email
    ? `mailto:${lead.email}?subject=${encodeURIComponent(`Re: ${lead.topic ?? 'Anfrage'} — via Atoll-Card`)}`
    : null

  const tel       = lead.phone ? `tel:${lead.phone}` : null
  // E.164 strict for WhatsApp — strip non-digits except leading +
  const e164Strict = lead.phone?.match(/^\+\d{8,15}$/)?.[0]
  const whatsapp   = e164Strict ? `https://wa.me/${e164Strict.slice(1)}` : null

  function onActionClick(targetStatus: 'contacted') {
    if (lead.status === 'opened') {
      updateStatus.mutate({ id: lead.id, status: targetStatus })
    }
  }

  async function onImport() {
    if (!lead.email && !lead.phone) {
      const ok = window.confirm(
        'Lead hat keine Kontaktdaten — Import erstellt unvollständigen Contact. Trotzdem?'
      )
      if (!ok) return
    }
    try {
      const { contact_id, action } = await importLead.mutateAsync(lead.id)
      const msg =
        action === 'merged'            ? `In bestehenden Contact gemergt.`
      : action === 'already_imported'  ? `Schon importiert — öffne Contact.`
      : `Neuer Contact angelegt.`
      window.alert(msg) // TODO: replace with toast in a follow-up
      navigate(`/contacts?contact=${contact_id}`)
    } catch (e) {
      window.alert(`Import fehlgeschlagen: ${(e as Error).message}`)
    }
  }

  return (
    <div style={{ display: 'flex', flexDirection: 'column', height: '100%' }}>
      {/* Header */}
      <div style={{ display: 'flex', gap: 12, alignItems: 'flex-start',
                    padding: '16px 20px', borderBottom: '1px solid var(--border-subtle)' }}>
        <Avatar name={displayName} initials={initials} color={lead.avatar_color ?? undefined} size={56} />
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ fontSize: 18, fontWeight: 700 }}>{displayName}</div>
          <div style={{ fontSize: 13, color: 'var(--text-secondary)', marginTop: 2 }}>
            {lead.card_title}{lead.topic ? ` · ${lead.topic}` : ''}
          </div>
          <div style={{ marginTop: 8 }}>
            <CardLeadStatusPill status={lead.status} />
          </div>
        </div>
        <button type="button" onClick={onClose} aria-label="Schliessen"
                style={{ background: 'transparent', border: 'none', cursor: 'pointer' }}>
          <Icon.X size={16} />
        </button>
      </div>

      {/* Body */}
      <div style={{ flex: 1, overflow: 'auto', padding: '16px 20px' }}>
        {lead.email && (
          <div style={{ marginBottom: 8 }}>
            <a href={`mailto:${lead.email}`} style={{ color: 'var(--brand-blue)' }}>
              {lead.email}
            </a>
          </div>
        )}
        {lead.phone && (
          <div style={{ marginBottom: 8 }}>
            <a href={`tel:${lead.phone}`} style={{ color: 'var(--brand-blue)' }}>
              {lead.phone}
            </a>
          </div>
        )}
        {lead.message && (
          <div style={{
            marginTop: 12, padding: 12, background: 'var(--surface-elevated)',
            borderRadius: 8, fontSize: 14, whiteSpace: 'pre-wrap',
          }}>
            {lead.message}
          </div>
        )}
        <div style={{ marginTop: 16, fontSize: 12, color: 'var(--text-tertiary)' }}>
          Eingegangen: {new Date(lead.captured_at).toLocaleString('de-CH')}
        </div>
      </div>

      {/* Actions */}
      <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8,
                    padding: '12px 20px', borderTop: '1px solid var(--border-subtle)' }}>
        {mailto && (
          <a className="atoll-btn" href={mailto} onClick={() => onActionClick('contacted')}>
            Antworten
          </a>
        )}
        {tel && (
          <a className="atoll-btn" href={tel} onClick={() => onActionClick('contacted')}>
            Anrufen
          </a>
        )}
        {whatsapp && (
          <a className="atoll-btn" href={whatsapp} target="_blank" rel="noreferrer"
             onClick={() => onActionClick('contacted')}>
            WhatsApp
          </a>
        )}
        <button
          type="button"
          className="atoll-btn atoll-btn--primary"
          disabled={lead.status === 'spam' || importLead.isPending}
          onClick={onImport}
        >
          {importLead.isPending ? 'Importiere…' : 'Importieren'}
        </button>
        <button
          type="button"
          className="atoll-btn"
          onClick={() => updateStatus.mutate({ id: lead.id, status: 'archived' })}
          disabled={lead.status === 'archived'}
        >
          Archivieren
        </button>
        <button
          type="button"
          className="atoll-btn"
          onClick={() => updateStatus.mutate({ id: lead.id, status: 'spam' })}
          disabled={lead.status === 'spam'}
        >
          Als Spam
        </button>
      </div>
    </div>
  )
}
```

- [ ] **Step 2: Smoke-Build**

```bash
cd apps/web
npm run build 2>&1 | tail -20
```

Expected: build succeeds.

- [ ] **Step 3: Commit**

```bash
git add apps/web/src/screens/contacts/CardInboxDetailPanel.tsx
git commit -m "feat(web): CardInboxDetailPanel with import + status actions"
```

---

### Task 12: Sidebar-Eintrag + Route + Badge

**Files:**
- Modify: `apps/web/src/App.tsx`
- Modify: `apps/web/src/components/Sidebar.tsx`

- [ ] **Step 1: Route registrieren**

Open `apps/web/src/App.tsx`. Above the existing `AddressbookScreen` import line:

```typescript
const CardInboxScreen = lazy(() => import('@/screens/contacts/CardInboxScreen').then(m => ({ default: m.CardInboxScreen })))
```

Add a Route inside the `<Route element={session ? <AppShell /> : ... }>` block, directly below the existing `/contacts` route:

```tsx
<Route path="/contacts/card-inbox" element={<CardInboxScreen />} />
```

- [ ] **Step 2: Sidebar-Eintrag mit Badge-Hook**

Open `apps/web/src/components/Sidebar.tsx`. At the top, add the unread-count import:

```typescript
import { useCardLeadsUnreadCount } from '@/hooks/useCardLeadsUnreadCount'
```

In the `ADRESSEN_ITEMS` array, append the new entry:

```typescript
{ to: '/contacts/card-inbox', icon: 'tag', i18nKey: 'card_inbox', roles: ['owner', 'cd'] },
```

(Use `'tag'` icon if `'inbox'` is not in `IconName`; verify with a quick grep first.)

Inside the `Sidebar` function body, after the `t` helper:

```typescript
const { data: unread = 0 } = useCardLeadsUnreadCount()
```

In the `SidebarLink` render block, wrap the existing `<span>{label}</span>` for the card-inbox item with a badge. Update `SidebarLink`'s props to accept an optional `badge` number, and in the JSX render:

```tsx
{badge != null && badge > 0 && (
  <span style={{
    marginLeft: 'auto',
    background: 'var(--brand-red)',
    color: 'white',
    fontSize: 10,
    fontWeight: 700,
    padding: '1px 6px',
    borderRadius: 10,
    minWidth: 16,
    textAlign: 'center',
  }}>{badge}</span>
)}
```

Pass `badge={item.to === '/contacts/card-inbox' ? unread : undefined}` in the `<SidebarLink>` invocation inside the `adressen.map(...)` loop.

- [ ] **Step 3: Smoke-Build + manuelles Klicken**

```bash
cd apps/web
npm run build 2>&1 | tail -20
npm run dev
```

Im Browser: einloggen als owner-User. Sidebar sollte "Card-Inbox" unter ADRESSEN zeigen. Klick öffnet `/contacts/card-inbox`. Leere Inbox zeigt EmptyState.

- [ ] **Step 4: Commit**

```bash
git add apps/web/src/App.tsx apps/web/src/components/Sidebar.tsx
git commit -m "feat(web): wire up Card-Inbox route + sidebar entry with unread badge"
```

---

## Phase D — i18n + iOS-CTA

### Task 13: i18n-Keys

**Files:**
- Modify: `apps/web/src/i18n/de.json`
- Modify: `apps/web/src/i18n/en.json`
- Modify: `apps/web/src/i18n/fr.json` (falls existent)

- [ ] **Step 1: Keys in de.json eintragen**

In `apps/web/src/i18n/de.json`, im `nav`-Block:

```json
"card_inbox": "Card-Inbox"
```

(Falls die UI-Strings im Screen bislang hardcoded sind statt `t(...)`, kommt das in einem späteren Refactor — MVP nutzt die deutschen Strings direkt im Screen-Code wie oben.)

- [ ] **Step 2: en.json + fr.json analog**

```json
// en.json: "card_inbox": "Card Inbox"
// fr.json: "card_inbox": "Boîte Card"
```

- [ ] **Step 3: Commit**

```bash
git add apps/web/src/i18n/*.json
git commit -m "feat(i18n): nav.card_inbox keys (de/en/fr)"
```

---

### Task 14: iOS LeadDetailSheet-CTA auf Deep-Link

**Files:**
- Modify: `apps/atollcard-native/AtollCard/Views/Leads/LeadDetailSheet.swift`

- [ ] **Step 1: Bestehenden Button-Text + Action identifizieren**

```bash
cd ~/Desktop/Developer/Dispo
grep -n "Adressbuch\|ABook" apps/atollcard-native/AtollCard/Views/Leads/LeadDetailSheet.swift
```

- [ ] **Step 2: CTA umetikettieren und URL öffnen**

In `apps/atollcard-native/AtollCard/Views/Leads/LeadDetailSheet.swift`, den existierenden "In Adressbuch importieren"-Button-Block durch folgenden ersetzen (Lead-ID muss verfügbar sein im Sheet-Scope; sie ist es als `lead.id`):

```swift
Button {
  if let url = URL(string: "https://atoll-os.com/contacts/card-inbox?lead=\(lead.id)") {
    UIApplication.shared.open(url)
  }
} label: {
  Label("In Atoll Web öffnen", systemImage: "safari")
}
.buttonStyle(.borderedProminent)
```

- [ ] **Step 3: XcodeGen + Build verifizieren**

```bash
cd apps/atollcard-native
xcodegen generate
xcodebuild -scheme AtollCard -sdk iphonesimulator -configuration Debug build 2>&1 | tail -10
```

Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Commit**

```bash
git add apps/atollcard-native/AtollCard/Views/Leads/LeadDetailSheet.swift
git commit -m "feat(ios): LeadDetailSheet CTA opens Web Card-Inbox via deep link"
```

---

## Phase E — E2E + Rollout

### Task 15: Playwright E2E-Test

**Files:**
- Create: `apps/web/tests/playwright/card-inbox.spec.ts`

- [ ] **Step 1: E2E-Spec schreiben**

Inhalt von `apps/web/tests/playwright/card-inbox.spec.ts`:

```typescript
/**
 * E2E: Public Card-Page → INSERT in card_leads → Web Inbox zeigt Lead
 * innert 2s (Realtime), Klick auf Importieren → Contact erscheint im Adressbuch.
 *
 * Voraussetzungen:
 *   - Test-DB mit einer existierenden Karte slug='dominik-cd'
 *   - Test-User credentials in .env.test (TEST_USER_EMAIL, TEST_USER_PASSWORD)
 */
import { test, expect } from '@playwright/test'

const TEST_EMAIL = `e2e+${Date.now()}@example.invalid`

test.describe('Card-Inbox E2E', () => {
  test('public form → inbox → import → adressbuch', async ({ page, context }) => {
    // 1. Public form
    await page.goto('/c/dominik-cd')
    await page.getByLabel(/vorname/i).fill('Edna E2E')
    await page.getByLabel(/email/i).fill(TEST_EMAIL)
    await page.getByLabel(/nachricht/i).fill('E2E test message')
    await page.getByRole('button', { name: /senden/i }).click()
    await expect(page.getByText(/danke/i)).toBeVisible()

    // 2. Switch to owner session and open Inbox
    const ownerPage = await context.newPage()
    await ownerPage.goto('/login')
    await ownerPage.getByLabel(/email/i).fill(process.env.TEST_USER_EMAIL!)
    await ownerPage.getByLabel(/passwort|password/i).fill(process.env.TEST_USER_PASSWORD!)
    await ownerPage.getByRole('button', { name: /anmelden|login/i }).click()
    await ownerPage.waitForURL(/heute/)

    await ownerPage.goto('/contacts/card-inbox?view=new')

    // 3. Lead taucht innert 2s auf (Realtime)
    const leadRow = ownerPage.getByText('Edna E2E')
    await expect(leadRow).toBeVisible({ timeout: 5000 })

    // 4. Detail öffnen + importieren
    await leadRow.click()
    ownerPage.on('dialog', async (d) => await d.accept())   // import-success alert
    await ownerPage.getByRole('button', { name: /importieren/i }).click()

    // 5. Browser navigiert zum Adressbuch mit dem neuen Contact
    await ownerPage.waitForURL(/\/contacts\?contact=/)
    await expect(ownerPage.getByText('Edna E2E')).toBeVisible()
  })
})
```

- [ ] **Step 2: Run E2E (gegen lokales `npm run dev`)**

```bash
cd apps/web
npm run dev &
sleep 5
npm run test:e2e -- card-inbox.spec.ts
```

Expected: 1 passed.

Aufräumen:
```bash
psql "$DATABASE_URL" -c "
  DELETE FROM card_leads WHERE email LIKE 'e2e+%@example.invalid';
  DELETE FROM contacts   WHERE primary_email LIKE 'e2e+%@example.invalid';
"
```

- [ ] **Step 3: Commit**

```bash
git add apps/web/tests/playwright/card-inbox.spec.ts
git commit -m "test(e2e): card-inbox flow (public form → inbox → import → adressbuch)"
```

---

### Task 16: Smoke-Test + Feature-Flag-Rollout-Notiz

**Files:**
- Modify: `apps/atollcard-native/CHANGELOG.md`
- Create: `docs/superpowers/runbooks/2026-05-25-atollcard-web-inbox-rollout.md`

- [ ] **Step 1: Runbook für den Rollout schreiben**

Inhalt von `docs/superpowers/runbooks/2026-05-25-atollcard-web-inbox-rollout.md`:

```markdown
# Runbook: AtollCard Web-Inbox Rollout

**Spec:** docs/superpowers/specs/2026-05-25-atollcard-web-inbox-design.md
**Plan:** docs/superpowers/plans/2026-05-25-atollcard-web-inbox.md

## Pre-Deployment

- [ ] Migrations 0102/0103/0104 in Staging-DB anwenden, mit psql verifizieren
- [ ] `tags='card-inbox'`-Kollisions-Check in Production:
      `SELECT count(*) FROM contacts WHERE 'card-inbox' = ANY(tags);` → muss 0 sein
- [ ] Web-Build erfolgreich (`npm run build`), Bundle-Size-Check nicht über +50kB

## Deployment Schritt 1 — Feature-Flag aus

- [ ] Migrations auf Produktion: `supabase db push`
- [ ] Web-Code deployen via `vercel --prod`
- [ ] Smoke-Check: `/contacts/card-inbox` ist reachable (200 OK), kein Sidebar-Eintrag

## Deployment Schritt 2 — Feature-Flag an

- [ ] Sidebar-Eintrag für die User-Role `owner` aktivieren (Code-Change oder DB-Flag)
- [ ] Dominik testet selber: Public-Form → Lead erscheint → Import erstellt Contact
- [ ] iOS-Build mit neuem CTA-Text in TestFlight pushen (separater Build)

## Rollback

- [ ] Sidebar-Eintrag entfernen (Code-Revert)
- [ ] Migrations behalten — Bridge-Spalte ist NULL-default, schadet keinem Bestand
- [ ] Bei kritischem Bug der Daten korrumpiert: Restore card_leads + contacts
      auf den Pre-Deployment-Snapshot
```

- [ ] **Step 2: AtollCard-CHANGELOG ergänzen**

In `apps/atollcard-native/CHANGELOG.md`, am Anfang über dem aktuellen Top-Eintrag:

```markdown
## 0.5.0 — Web-Inbox + Adressbuch-Import (Larry, 25.05.2026)

iOS-CTA umetikettiert von "In Adressbuch importieren" auf "In Atoll Web öffnen"
(Universal-Link / Web-Browser-Fallback). Adressbuch-Import passiert ab jetzt
ausschliesslich im Web — Single Source of Truth für Dedup-Logik und
Role-Tagging.

Web-seitige Änderungen (in apps/web): siehe
`docs/superpowers/plans/2026-05-25-atollcard-web-inbox.md`.

### Architektur-Entscheidung: Web-only Import

In der Frühphase hatte das LeadDetailSheet einen "→ ABook"-Button, der ins
Leere führte (Adressdatenbank lebt nur im Web). Statt eine zweite Import-
Implementation in iOS zu bauen, machen wir den CTA zum Deep-Link in die
Web-Inbox. Begründung: Dedup-Logik, Role-Zuweisung und Conflict-Resolution
müssen sonst doppelt gepflegt werden. iOS bleibt der Triage-Modus
(Status setzen, Antworten, Archivieren), der formelle Import passiert
am Mac.
```

- [ ] **Step 3: Commit**

```bash
git add docs/superpowers/runbooks/2026-05-25-atollcard-web-inbox-rollout.md \
        apps/atollcard-native/CHANGELOG.md
git commit -m "docs: rollout runbook + AtollCard 0.5.0 changelog"
```

---

## Self-Review-Checklist (vom Schreiber, post-hoc)

**Spec-Coverage:**
- §3.1 Migration 0102 → Task 1 ✓
- §3.2 RPC import_card_lead → Tasks 2 + 3 ✓
- §4 Merge-Regeln → in den SQL-Snippets enthalten ✓
- §5.1 Sidebar-Anker → Task 12 ✓
- §5.2 Screen Master-Detail → Tasks 10 + 11 ✓
- §5.3 Empty States → Task 10 (im Screen) ✓
- §5.4 Brand-Konventionen / Status-Farben → Task 8 ✓
- §6.1 Auto-Transitions → Task 10 (opened-Auto) + Task 11 (contacted-Auto) ✓
- §6.3 Realtime → Task 7 + Task 10 ✓
- §7 Permissions (owner-only) → Task 12 (roles: ['owner', 'cd']) ✓
- §8 iOS-CTA → Task 14 ✓
- §9 File-Inventar → über alle Tasks abgedeckt ✓
- §10 Error-Handling → in DetailPanel + Hooks + RPC enthalten ✓
- §11 Rollout-Plan → Task 16 ✓
- §14 Akzeptanzkriterien → E2E in Task 15 deckt die wichtigsten ab ✓

**Placeholder-Scan:** keine TBD / TODO / FIXME im Plan (eine TODO-Kommentar
im DetailPanel-Code für Toast-Replacement ist explizit als Follow-up markiert).

**Typkonsistenz:** `CardLeadRow` (Type) vs. `CardLeadRow` (Component) — gleiche
Bezeichnung, unterschiedlicher Namespace. Component-Datei importiert den Type
als `CardLeadRow as CardLeadRowData` (siehe Task 9). Konsistent.

`updateLeadStatus({ id, status })` Signatur durchgängig identisch in Lib-Funktion
(Task 5), Hook (Task 7), und Aufrufstellen (Tasks 10 + 11).

**Bekannte Follow-ups (nicht im Plan):**
- Toast-System ersetzt `window.alert()` (Subprojekt-übergreifender Refactor)
- `tags='card-inbox'`-Kollisions-Check vor Production-Deployment (im Runbook erfasst)
- i18n der UI-Strings im Screen (MVP nutzt deutsche Strings direkt, Refactor später)
