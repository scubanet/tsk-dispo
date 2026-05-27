# Phase G — Phase 3: Properties-Sidebar + Inline-Edit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** ContactDetailPanelV2 vollwertige Properties-Sidebar geben: Sticky-Top (Avatar/Name/Roles/Actions) + Stat-Band (Saldo/Kurse/letzter Kontakt/nächste Action) + 7 collapsible Sections mit Inline-Edit. Plus drei Phase-2-Carry-Forwards (Icon-System, audit_edit-Cleanup, Panel-Refactor).

**Architecture:** PropertiesSidebar liest Contact-Daten via neuen `useContactWithProperties`-Hook (erweitert das Phase-2-Minimal-Fetch um Sidecars, Org-Affiliations, Tags). Sections sind eigene Komponenten unter `sidebar/sections/`, jede mit eigenen `useUpdateContactField`/`useUpdateSidecarField`-Mutations für Inline-Edit. SidebarSection ist die collapsible-primitive (state in localStorage pro Section).

**Tech Stack:** React 18 + TS · TanStack Query · Tabler-Icons via Foundation · libphonenumber-js (für Phone-Validierung) · existing primitives in `apps/web/src/foundation/`.

**Builds on:**
- [Spec 2026-05-27-contacts-crm-redesign.md](../specs/2026-05-27-contacts-crm-redesign.md) §5
- [Phase 2 Plan + Code](2026-05-27-phase-g-phase2-detail-panel.md) — ContactDetailPanelV2 hat sidebar-placeholder slot
- [Phase G Memory](../../../../memory/project_phase_g.md) — Carry-Forward Items

---

## File Structure

**Hook-Layer:**
- `apps/web/src/hooks/useContactWithProperties.ts` — NEU, lädt Contact + Sidecars + Org + Tags
- `apps/web/src/hooks/useContactFieldMutation.ts` — NEU, generic Field-Edit hook
- Modify: `apps/web/src/hooks/useEventComposer.ts` — optional optimistic-insert (Carry-Forward)

**Sidebar-Komponenten:**
- `apps/web/src/screens/contacts/sidebar/PropertiesSidebar.tsx` — NEU, Container
- `apps/web/src/screens/contacts/sidebar/StatBand.tsx` — NEU
- `apps/web/src/screens/contacts/sidebar/SidebarSection.tsx` — NEU, collapsible primitive
- `apps/web/src/screens/contacts/sidebar/EditableField.tsx` — NEU, Inline-Edit primitive
- `apps/web/src/screens/contacts/sidebar/sections/ContactSection.tsx` — NEU
- `apps/web/src/screens/contacts/sidebar/sections/RolesStatusSection.tsx` — NEU
- `apps/web/src/screens/contacts/sidebar/sections/OrgRelationsSection.tsx` — NEU
- `apps/web/src/screens/contacts/sidebar/sections/TagsSection.tsx` — NEU
- `apps/web/src/screens/contacts/sidebar/sections/KeyDatesSection.tsx` — NEU
- `apps/web/src/screens/contacts/sidebar/sections/PadiSection.tsx` — NEU
- `apps/web/src/screens/contacts/sidebar/sections/SourceAuditSection.tsx` — NEU

**ContactDetailPanelV2-Anpassung:**
- Modify: `apps/web/src/screens/contacts/ContactDetailPanelV2.tsx` — Sidebar-Placeholder durch echte PropertiesSidebar ersetzen, Sidebar-Toggle einbauen
- Modify: `apps/web/src/screens/contacts/ContactDetailHeader.tsx` — Avatar links neben Name (war Phase-2-Minimal)

**Refactor (Carry-Forward C3):**
- Modify: `apps/web/src/screens/contacts/ContactDetailPanel.tsx` — extract legacy into separate component
- Create: `apps/web/src/screens/contacts/ContactDetailPanelLegacy.tsx` (renamed from current impl)

**Foundation-Icon-System (Carry-Forward C1):**
- Modify: `apps/web/src/screens/contacts/timeline/EventCard.tsx` — Tabler-Icons statt 3-Char-Text-Placeholder
- Modify (maybe): `apps/web/src/foundation/Icon.tsx` — alle 15 Event-Typen registrieren

**audit_edit-Cleanup (Carry-Forward C2):**
- Migration: `supabase/migrations/0117_v_contact_timeline_audit_filter.sql` — View aktualisieren: filter `updated_at` aus `changed_fields` raus
- Modify: `docs/superpowers/specs/2026-05-27-contacts-crm-redesign.md` — RLS-NOTE entsprechend ergänzen

**Tests:**
- Vitest unit-tests pro Section + EditableField + SidebarSection + neue Hooks
- 1 Playwright E2E: Inline-Edit eines Phone-Felds → persist nach Reload

---

## Tasks

### Task 0: Pre-Phase-3 Schema-Audit

Verifizieren dass die Properties-Sidebar alle Daten laden kann.

**Files:**
- Update: `docs/superpowers/plans/2026-05-27-phase-g-foundation-schema-audit-notes.md` (append Section)

- [ ] **Step 1: `v_contact_balance` Smoke**

Studio SQL:
```sql
SELECT contact_id, display_name, balance_chf, last_movement_date, movement_count
FROM v_contact_balance
WHERE balance_chf <> 0
ORDER BY ABS(balance_chf) DESC
LIMIT 10;
```
Erwartet: 10 Zeilen für aktive Instructors. Notiere wenn das view sauber liefert.

- [ ] **Step 2: contact_instructor / contact_student / contact_organization Sidecars-Schema**

```sql
\d contact_instructor
\d contact_student
\d contact_organization
```

Liste die Spalten in `phase-g-foundation-schema-audit-notes.md` Section `## Phase 3 Sidecar-Schema (2026-05-27)`. Phase 3 PropertiesSidebar muss role-aware sein — sie zeigt nur Sections für Sidecars die der Contact tatsächlich hat.

- [ ] **Step 3: contact_organizations-Membership-View** (für OrgRelationsSection)

```sql
-- Welche Tabelle/View speichert "Contact X gehört zu Org Y"?
\d+ contact_org_memberships
-- Falls nicht existiert: prüfen ob über contact_relationships gehandled wird
SELECT * FROM contact_relationships WHERE kind = 'employment' LIMIT 5;
```

Notiere wie Org-Zugehörigkeiten in der DB stehen.

- [ ] **Step 4: contact_tags**

```sql
\d contact_tags
SELECT * FROM contact_tags LIMIT 5;
```

Tag-Schema dokumentieren (vermutlich `(contact_id, tag)` rows).

- [ ] **Step 5: Notes ergänzen + Commit**

```bash
cd ~/Desktop/Developer/Dispo
git add docs/superpowers/plans/2026-05-27-phase-g-foundation-schema-audit-notes.md
git commit -m 'docs(phase-g): pre-Phase-3 schema audit notes (sidecars, balance view, tags)'
```

---

### Task 1: useContactWithProperties Hook

Vollwertiger Contact-Loader: lädt aus `contacts` + alle relevanten Sidecars (instructor/student/organization) + balance + tags + relationships. Liefert alles in einem einzigen React-Query.

**Files:**
- Create: `apps/web/src/hooks/useContactWithProperties.ts`
- Create: `apps/web/src/hooks/__tests__/useContactWithProperties.test.ts`

- [ ] **Step 1: Types ergänzen** in `apps/web/src/types/contactEvents.ts` oder neuem `contactProperties.ts`

```ts
// apps/web/src/types/contactProperties.ts
export interface ContactWithProperties {
  id: string
  kind: 'person' | 'organization'
  display_name: string
  first_name: string | null
  last_name: string | null
  birth_date: string | null
  primary_email: string | null
  primary_phone: string | null
  primary_language: 'de' | 'en' | 'fr' | null
  source: 'card_inbox' | 'excel_import' | 'manual' | null
  created_at: string
  updated_at: string
  owner_id: string | null
  // Sidecars
  instructor: InstructorSidecar | null
  student: StudentSidecar | null
  organization: OrgSidecar | null
  // Aggregierte
  balance: { chf: number; last_movement_date: string | null } | null
  active_courses_count: number
  last_contact_at: string | null
  next_due_task: { id: string; due_date: string; summary: string } | null
  // Lists
  roles: string[]    // derived: ['instructor'] if instructor != null, etc.
  tags: string[]
  org_memberships: Array<{ org_id: string; org_name: string; role: string | null }>
}

export interface InstructorSidecar {
  padi_level: string | null
  padi_pro_number: string | null
  member_status: 'active' | 'inactive' | null
  active: boolean
}

export interface StudentSidecar {
  pipeline_stage: 'lead' | 'qualified' | 'candidate' | 'customer' | null
  intake_status: string | null
  current_level: string | null
}

export interface OrgSidecar {
  legal_name: string | null
  trading_name: string | null
  category: 'dive_shop' | 'partner' | 'supplier' | 'authority' | null
}
```

- [ ] **Step 2: Test schreiben (mocked Supabase)**

[full TDD pattern — test asserts hook fetches all expected fields, derives roles correctly, exposes loading/error states]

- [ ] **Step 3: Test fail**

```bash
cd /sessions/festive-charming-meitner/mnt/Dispo/apps/web && npx vitest run src/hooks/__tests__/useContactWithProperties.test.ts 2>&1 | tail -10
```

- [ ] **Step 4: Hook implementieren**

```ts
// apps/web/src/hooks/useContactWithProperties.ts
import { useQuery } from '@tanstack/react-query'
import { supabase } from '@/lib/supabase'
import type { ContactWithProperties } from '@/types/contactProperties'

export function useContactWithProperties(contactId: string) {
  return useQuery({
    queryKey: ['contact-properties', contactId],
    queryFn: async (): Promise<ContactWithProperties> => {
      // Single-roundtrip via Supabase's join syntax
      const { data, error } = await supabase
        .from('contacts')
        .select(`
          *,
          instructor:contact_instructor(*),
          student:contact_student(*),
          organization:contact_organization(*),
          balance:v_contact_balance(balance_chf, last_movement_date),
          tags:contact_tags(tag)
        `)
        .eq('id', contactId)
        .single()

      if (error) throw new Error(error.message)
      return normalizeContactProperties(data)
    },
    enabled: !!contactId,
  })
}

function normalizeContactProperties(raw: any): ContactWithProperties {
  // Map row → ContactWithProperties + derive roles + flatten tags
  // ... [full impl]
}
```

- [ ] **Step 5: Test pass + Typecheck**

- [ ] **Step 6: Commit**

```bash
git add apps/web/src/hooks/useContactWithProperties.ts \
        apps/web/src/hooks/__tests__/useContactWithProperties.test.ts \
        apps/web/src/types/contactProperties.ts
git commit -m 'feat(web): useContactWithProperties hook with sidecars + balance + tags (Phase G Phase 3)'
```

---

### Task 2: SidebarSection collapsible primitive

Wiederverwendbare collapsible Section mit localStorage-Persistence pro Section-ID.

**Files:**
- Create: `apps/web/src/screens/contacts/sidebar/SidebarSection.tsx`
- Create: `apps/web/src/screens/contacts/sidebar/__tests__/SidebarSection.test.tsx`

TDD: Test → Fail → Impl → Pass → Commit.

```tsx
// SidebarSection.tsx
interface Props {
  id: string  // localStorage key
  title: string
  defaultOpen?: boolean
  children: React.ReactNode
}
// Uses useState + useEffect to persist open state in localStorage
// at key `sidebar-section-${id}`. Header is clickable, body collapses with CSS.
```

---

### Task 3: EditableField primitive

Inline-Edit primitive für single Werte. Klick auf den Wert → wird zum Input → Tab/Enter committet, Esc cancelt.

**Files:**
- Create: `apps/web/src/screens/contacts/sidebar/EditableField.tsx`
- Create: `apps/web/src/screens/contacts/sidebar/__tests__/EditableField.test.tsx`

Props-Signatur:
```tsx
interface Props<T extends string | number | null> {
  value: T
  label: string
  onSave: (next: T) => Promise<void> | void
  type?: 'text' | 'email' | 'phone' | 'date' | 'number'
  validate?: (value: T) => string | null  // null = ok, string = error message
  placeholder?: string
}
```

Verhalten:
- Click outside / Esc → cancel
- Tab / Enter → commit (calls onSave), shows loading-spinner, then blur
- Validation-error → roter Border + Tooltip
- onSave error → revert + toast

---

### Task 4: useContactFieldMutation hook

Generic mutation für Single-Field-Edits. Wird von allen Inline-Edits genutzt.

**Files:**
- Create: `apps/web/src/hooks/useContactFieldMutation.ts`

```ts
export function useContactFieldMutation(contactId: string) {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: async ({ table, field, value }: { table: string; field: string; value: unknown }) => {
      const { error } = await supabase.from(table).update({ [field]: value }).eq('contact_id', contactId)
      if (error) throw new Error(error.message)
    },
    onSuccess: () => qc.invalidateQueries({ queryKey: ['contact-properties', contactId] }),
  })
}
```

---

### Task 5: PropertiesSidebar Container

Top-level Container der die 7 Sections in der richtigen Reihenfolge rendert. Liest aus `useContactWithProperties`, übergibt Daten + Mutation-Hooks an Sections.

**Files:**
- Create: `apps/web/src/screens/contacts/sidebar/PropertiesSidebar.tsx`

Struktur:
```tsx
export function PropertiesSidebar({ contactId }: Props) {
  const { data, isLoading, error } = useContactWithProperties(contactId)
  if (isLoading) return <Skeleton />
  if (error) return <ErrorBlock />
  return (
    <aside>
      <StickyTop contact={data} />
      <StatBand contact={data} />
      <ContactSection contact={data} />
      <RolesStatusSection contact={data} />
      <OrgRelationsSection contact={data} />
      <TagsSection contact={data} />
      <KeyDatesSection contact={data} />
      {/* PADI nur wenn instructor || student */}
      {(data.instructor || data.student) && <PadiSection contact={data} />}
      <SourceAuditSection contact={data} />
    </aside>
  )
}
```

---

### Tasks 6-12: 7 individuelle Sections

Jede Section folgt dem gleichen Pattern: nimmt `contact` als prop, rendert die relevanten Felder, jeder Wert ist ein `<EditableField>` mit eigenem `onSave`.

**Task 6: ContactSection** (Email/Phone/WhatsApp/Sprache, default open)\
**Task 7: RolesStatusSection** (role-aware: Pipeline-Stage / Intake / Aktiv-Flag / Brevet, default open)\
**Task 8: OrgRelationsSection** (default closed)\
**Task 9: TagsSection** (default closed, multi-tag-Adder)\
**Task 10: KeyDatesSection** (default closed, read-only display)\
**Task 11: PadiSection** (default closed, role-gated)\
**Task 12: SourceAuditSection** (default closed, read-only)

Jeweils: TDD-Pattern, Tests für „rendert die richtigen Felder" + „onSave triggert Mutation" + „handles loading/error".

---

### Task 13: Stat-Band

4-Tile-Stat-Band als Top-Element der Sidebar.

**Files:**
- Create: `apps/web/src/screens/contacts/sidebar/StatBand.tsx`

Tiles:
- Saldo (CHF, color-coded green/red, only if `balance != null`)
- Aktive Kurse (count, integer)
- Letzter Kontakt (relative time)
- Nächste Action (relative time, only if `next_due_task != null`)

---

### Task 14: Sidebar-Toggle

Collapse/Expand der gesamten Sidebar via `⟶`-Toggle. Zustand in localStorage als `contactDetail.sidebarOpen`.

**Files:**
- Modify: `apps/web/src/screens/contacts/ContactDetailPanelV2.tsx`

---

### Task 15: ContactDetailHeader Avatar links

Heutige Header zeigt nur Name+Roles. Avatar links daneben (Initialen oder Bild) — folgt dem bestehenden Avatar-Pattern aus `apps/web/src/components/Avatar.tsx`.

**Files:**
- Modify: `apps/web/src/screens/contacts/ContactDetailHeader.tsx`

---

### Task 16: ContactDetailPanel-Refactor (Carry-Forward C3)

Extract legacy in eigene Component, outer Panel zu reinem Flag-Dispatcher.

**Files:**
- Create: `apps/web/src/screens/contacts/ContactDetailPanelLegacy.tsx` (rename from current impl)
- Modify: `apps/web/src/screens/contacts/ContactDetailPanel.tsx` — wird:

```tsx
import { isFeatureEnabled } from '@/lib/featureFlags'
import { ContactDetailPanelV2 } from './ContactDetailPanelV2'
import { ContactDetailPanelLegacy } from './ContactDetailPanelLegacy'

export function ContactDetailPanel(props: Props) {
  if (isFeatureEnabled('crm_v2')) return <ContactDetailPanelV2 {...props} />
  return <ContactDetailPanelLegacy {...props} />
}
```

Zero hooks im outer Component → kein Rules-of-Hooks-Risiko. Legacy hat alle Hooks isoliert. V2 hat seine eigenen.

---

### Task 17: Foundation-Icon-Erweiterung (Carry-Forward C1)

EventCard rendert aktuell `data-icon="phone"` + `pho`-Text-Placeholder. Phase 3 ersetzt durch echte Tabler-Icons via Foundation.

**Files:**
- Modify: `apps/web/src/foundation/Icon.tsx` (oder wo die Foundation Icons leben — Phase 1 hatte `Icon.Close`, `Icon.Calendar`, etc.)
- Modify: `apps/web/src/screens/contacts/timeline/EventCard.tsx` — `<Icon name={ICON_FOR[event.event_type]} />` statt placeholder
- Modify: `apps/web/src/screens/contacts/timeline/__tests__/EventCard.test.tsx` — neue assertion auf Icon-render statt `data-icon`

Mapping bleibt wie Phase 2:
- note → ti-note
- call → ti-phone
- email_external → ti-mail
- meeting_past → ti-calendar-event
- task → ti-checkbox
- whatsapp_log → ti-brand-whatsapp
- course_enrollment → ti-school
- certification_issued → ti-certificate
- saldo_movement → ti-cash
- pipeline_change → ti-arrow-right
- intake_checkpoint → ti-checkbox
- skill_checked → ti-anchor
- card_lead_imported → ti-id-badge
- role_change → ti-user-cog
- audit_edit → ti-edit

Falls Foundation kein Icon-Lookup-System hat: in Phase 3 dazu eines erfinden (kleiner Helper, der Tabler-Icon-Name → SVG mapped).

---

### Task 18: audit_edit Summary-Cleanup (Carry-Forward C2)

Migration die `v_contact_timeline` aktualisiert: filter `updated_at` aus der `changed_fields`-Liste raus.

**Files:**
- Create: `supabase/migrations/0117_v_contact_timeline_audit_filter.sql`

```sql
-- 0117: v_contact_timeline — audit_edit Summary cleaner
-- Phase G Phase 3 Carry-Forward: 'updated_at' wird vom Audit-Trigger
-- immer mit in changed_fields aufgenommen — bloated die UI-Summary.
-- Filter heraus für sauberere Anzeige.

CREATE OR REPLACE VIEW public.v_contact_timeline AS
-- ... gleiche UNION-Branches wie 0114, aber audit_edit-Branch ändern:
-- Statt: jsonb_object_keys(cal.changed_fields) → Filter out 'updated_at'
-- Mit:   array_to_string(ARRAY(
--          SELECT k FROM jsonb_object_keys(cal.changed_fields) k
--          WHERE k != 'updated_at'
--          ORDER BY k
--        ), ', ')
-- ... rest identisch
```

Apply via `supabase db push --linked`.

---

### Task 19: Wire-up + Playwright E2E

PropertiesSidebar in ContactDetailPanelV2 einbauen (replace placeholder). Playwright-Spec: open contact → see sidebar → edit phone field inline → verify it persists.

**Files:**
- Modify: `apps/web/src/screens/contacts/ContactDetailPanelV2.tsx` — `<aside data-testid="properties-sidebar-placeholder">` ersetzen durch `<PropertiesSidebar contactId={contactId} />`
- Create: `apps/web/tests/e2e/phase-g-sidebar.spec.ts`

---

### Task 20: Manual-Smoke + Production-Verification

Push, GitHub-Actions deploy abwarten, gegen Prod testen:

```
□ /?crm_v2=1 → V2 mit echter Sidebar (kein Placeholder)
□ Sticky-Top: Avatar + Name + Roles + Edit/Close
□ Stat-Band: 4 Tiles, Saldo color-coded
□ 7 Sections rendern, role-aware (PADI nur bei Inst/Student)
□ Klick auf Email-Wert → wird Input → Tab → Mutation läuft → invalidates query → UI refreshed
□ Phone-Edit mit ungültiger Nummer → roter Border, Toast
□ Section auf-/zuklappen → persistiert in localStorage
□ Sidebar-Toggle ⟶ → collapsed, Timeline volle Breite. ⟵ → expanded
□ Refresh → alle States bleiben (localStorage)
□ EventCard zeigt echte Icons (nicht mehr Text-Placeholder)
□ audit_edit-Summary listet `updated_at` NICHT mehr
```

---

### Task 21: Phase 3 abschliessen

- [ ] Memory-Update in `project_phase_g.md`: Phase 3 done, Phase 4 carry-forwards
- [ ] Tag `phase-g-phase3`
- [ ] Push origin + tags

---

## Verification Gates

| Gate | Wie geprüft |
|---|---|
| Schema-Audit | 5 SQL-Probes durch, notiert |
| Hooks | Vitest pro Hook |
| Primitives (SidebarSection, EditableField) | je 3-5 Vitest |
| 7 Sections | je 2-4 Vitest (renders + onSave) |
| StatBand | Vitest |
| Sidebar-Toggle | Vitest |
| Full Suite | typecheck + vitest grün |
| E2E | Playwright phase-g-sidebar.spec.ts |
| Production-Smoke | manueller Pass durch |

---

## Was bewusst NICHT in Phase 3 ist

- **AddressbookScreen-Liste-Refresh** — Phase 4
- **`/aktivitaet` globaler Screen** — Phase 5
- **CommunicationHub-Auflösung** — Phase 5
- **Flag-Flip + Cleanup** — Phase 6
- **Optimistic-Insert in useEventComposer** — kann zu Phase 3 dazu oder als kleiner Side-Commit. Plan-Slot nicht reserviert.
- **Realtime-Subscriptions** (`useEffect` mit `supabase.channel(...)` zum Live-Update der Sidebar): out of scope, kann in einem Performance-Refactor-Spec landen.
