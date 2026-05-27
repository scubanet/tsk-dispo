# Phase G — Phase 2: Detail-Panel Timeline + Composer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refactor `ContactDetailPanel` zu HubSpot-Stil 3-Pane-Layout mit zentraler Activity-Timeline und User-Composer. Hinter `crm_v2`-Feature-Flag. Alte Tabs (Activity, Communications, NotesAndDocs) bleiben parallel sichtbar als Safety bis Phase 6.

**Architecture:** Feature-Flag wraped Re-Mount. Bei `crm_v2=true` rendert ein neues `ContactDetailPanelV2` Layout (Header + Timeline + Sidebar-Slot). Sidebar bleibt in Phase 2 leer/Placeholder — wird in Phase 3 gefüllt. Timeline liest aus `useContactTimeline` (Phase 1 Hook), schreibt via `useEventComposer`. Composer ist segmented control mit 6 Type-spezifischen Forms.

**Tech Stack:** React 18 + TypeScript · TanStack Query (vorhandene Hooks aus Phase 1) · Vitest · Playwright · Tabler-Icons via Foundation · existing primitives in `apps/web/src/foundation/`.

**Builds on:**
- [Spec 2026-05-27-contacts-crm-redesign.md](../specs/2026-05-27-contacts-crm-redesign.md) §3, §4, §9
- [Phase 1 Plan (Foundation)](2026-05-27-phase-g-foundation.md) — Hooks, Types, View live auf Prod
- [Phase G Memory](../../../../memory/project_phase_g.md) — Carry-Forward Items

---

## File Structure

**Feature-Flag Infrastructure:**
- `apps/web/src/lib/featureFlags.ts` — URL → localStorage → default lookup
- `apps/web/src/lib/__tests__/featureFlags.test.ts` — Vitest

**Detail-Panel Refactor:**
- `apps/web/src/screens/contacts/ContactDetailPanel.tsx` — modify: gate via flag, route to V2 or legacy
- `apps/web/src/screens/contacts/ContactDetailPanelV2.tsx` — NEW: 3-pane frame

**Header:**
- `apps/web/src/screens/contacts/ContactDetailHeader.tsx` — NEW

**Timeline-Komponenten:**
- `apps/web/src/screens/contacts/timeline/TimelineFeed.tsx` — NEW
- `apps/web/src/screens/contacts/timeline/EventCard.tsx` — NEW (polymorphic per event_type)
- `apps/web/src/screens/contacts/timeline/TimelineFilterBar.tsx` — NEW
- `apps/web/src/screens/contacts/timeline/EventComposer.tsx` — NEW (segmented orchestrator)

**Composer-Subkomponenten** (jeweils 1 Datei):
- `apps/web/src/screens/contacts/timeline/composers/NoteComposer.tsx`
- `apps/web/src/screens/contacts/timeline/composers/CallComposer.tsx`
- `apps/web/src/screens/contacts/timeline/composers/EmailLogComposer.tsx`
- `apps/web/src/screens/contacts/timeline/composers/MeetingComposer.tsx`
- `apps/web/src/screens/contacts/timeline/composers/TaskComposer.tsx`
- `apps/web/src/screens/contacts/timeline/composers/WhatsAppLogComposer.tsx`

**Tests:**
- Vitest unit-tests pro Komponente (in `__tests__/` Nachbarordner)
- 1 Playwright E2E in `apps/web/tests/e2e/phase-g-timeline.spec.ts`

**Pre-Phase-2-Backfill:**
- Erweitert `apps/web/src/hooks/__tests__/useContactTimeline.test.tsx` mit Cursor-Advance + Filter-Tests (Task 0)

---

## Tasks

### Task 0: Pre-Phase-2-Audit + Test-Backfill

Zwei Carry-Forward-Items aus Phase 1 müssen vor UI-Hängung an die Hooks abgehakt werden.

**Files:**
- Modify: `apps/web/src/hooks/__tests__/useContactTimeline.test.tsx`
- Doc: `docs/superpowers/plans/2026-05-27-phase-g-foundation-schema-audit-notes.md` (append)

- [ ] **Step 1: Actor-UUID-Orphan-Probe**

Im Supabase Studio SQL-Editor laufen lassen (Production):

```sql
-- Probe 1: account_movements.created_by
SELECT count(*) AS orphan_count
FROM account_movements am
LEFT JOIN contacts c ON c.id = am.created_by
WHERE am.created_by IS NOT NULL AND c.id IS NULL;

-- Probe 2: padi_skill_records.instructor_id
SELECT count(*) AS orphan_count
FROM padi_skill_records psr
LEFT JOIN contacts c ON c.id = psr.instructor_id
WHERE psr.instructor_id IS NOT NULL AND c.id IS NULL;

-- Probe 3: certifications.issued_by_person_id
SELECT count(*) AS orphan_count
FROM certifications cert
LEFT JOIN contacts c ON c.id = cert.issued_by_person_id
WHERE cert.issued_by_person_id IS NOT NULL AND c.id IS NULL;
```

Falls eine Probe >0 zurückgibt: notiere die Zahl in `2026-05-27-phase-g-foundation-schema-audit-notes.md` unter neuer Sektion `## Actor-UUID Orphan-Probe (Pre-Phase-2)`. `EventCard` muss dann „Unbekannter Actor" rendern für nicht-auflösbare UUIDs.

Falls alle drei Proben 0 zurückgeben: nur Zeile ergänzen `Actor-UUIDs sauber per Phase-F1 — kein Orphan-Fallback im UI nötig`.

- [ ] **Step 2: Cursor-Advancement-Test in `useContactTimeline.test.tsx`**

Öffne `apps/web/src/hooks/__tests__/useContactTimeline.test.tsx` und ergänze einen Test am Ende des `describe`-Blocks. Der Test soll: 50 mock-rows zurückgeben (PAGE_SIZE), assertieren dass `hasNextPage=true`, dann `fetchNextPage()` aufrufen und assertieren dass die `.or()`-Chain mit Cursor-Args aufgerufen wurde.

```tsx
  it('advances cursor on fetchNextPage when page is full', async () => {
    // 50 mock rows (PAGE_SIZE) — sorted DESC by occurred_at
    const fullPage = Array.from({ length: 50 }, (_, i) => ({
      event_id:     `ev-${50 - i}`,
      contact_id:   'c1',
      event_type:   'note',
      occurred_at:  `2026-05-${String(50 - i).padStart(2, '0')}`,
      summary:      `event ${50 - i}`,
      source_table: 'contact_events',
    }))
    const rebuilt = resetChain(fullPage)
    vi.mocked(supabase.from).mockImplementation(rebuilt.from)

    const { result } = renderHook(() => useContactTimeline('c1'), { wrapper })
    await waitFor(() => expect(result.current.isSuccess).toBe(true))
    expect(result.current.hasNextPage).toBe(true)

    await result.current.fetchNextPage()
    await waitFor(() => expect(result.current.isFetchingNextPage).toBe(false))

    // Cursor: .or() was called with the last row's (occurred_at, event_id)
    expect(chain.or).toHaveBeenCalledWith(
      expect.stringContaining('occurred_at.lt.2026-05-01')
    )
    expect(chain.or).toHaveBeenCalledWith(
      expect.stringContaining('event_id.lt.ev-1')
    )
  })
```

Dieser Test verlangt dass die existierenden `resetChain` und `chain`-Helper aus dem ersten Test wiederverwendet werden — falls die nicht existieren (Phase 1 hatte sie nur inline), erst die test-file-Struktur anpassen wie in Phase 1 Code-Review-Notes vermerkt.

- [ ] **Step 3: Tests laufen — alle grün**

```bash
cd ~/Desktop/Developer/Dispo/apps/web && npx vitest run src/hooks/__tests__/useContactTimeline.test.tsx 2>&1 | tail -10
```

Expected: Tests 2 passed (2) (war 1, jetzt + 1 cursor-advance).

- [ ] **Step 4: Commit**

```bash
cd ~/Desktop/Developer/Dispo
git add apps/web/src/hooks/__tests__/useContactTimeline.test.tsx \
        docs/superpowers/plans/2026-05-27-phase-g-foundation-schema-audit-notes.md
git commit -m 'test(web): cursor-advance test for useContactTimeline + actor-orphan probe (Phase G Phase 2 prep)'
```

---

### Task 1: Feature-Flag-Infrastructure

URL → localStorage → default lookup. URL setzt + persistiert. Aktivieren via `?crm_v2=1`. Deaktivieren via `?crm_v2=0`.

**Files:**
- Create: `apps/web/src/lib/featureFlags.ts`
- Create: `apps/web/src/lib/__tests__/featureFlags.test.ts`

- [ ] **Step 1: Test schreiben**

```ts
// apps/web/src/lib/__tests__/featureFlags.test.ts
import { describe, it, expect, beforeEach } from 'vitest'
import { isFeatureEnabled, FEATURE_FLAGS } from '../featureFlags'

describe('featureFlags', () => {
  beforeEach(() => {
    localStorage.clear()
    // Reset URL — happy-dom supports this
    window.history.replaceState({}, '', '/')
  })

  it('returns default (false) when no override set', () => {
    expect(isFeatureEnabled('crm_v2')).toBe(false)
  })

  it('returns true when localStorage set', () => {
    localStorage.setItem('crm_v2', 'true')
    expect(isFeatureEnabled('crm_v2')).toBe(true)
  })

  it('URL ?crm_v2=1 sets and returns true', () => {
    window.history.replaceState({}, '', '/?crm_v2=1')
    expect(isFeatureEnabled('crm_v2')).toBe(true)
    expect(localStorage.getItem('crm_v2')).toBe('true')
  })

  it('URL ?crm_v2=0 unsets and returns false', () => {
    localStorage.setItem('crm_v2', 'true')
    window.history.replaceState({}, '', '/?crm_v2=0')
    expect(isFeatureEnabled('crm_v2')).toBe(false)
    expect(localStorage.getItem('crm_v2')).toBeNull()
  })

  it('FEATURE_FLAGS enumerates known flags', () => {
    expect(FEATURE_FLAGS).toContain('crm_v2')
  })
})
```

- [ ] **Step 2: Test fail (module not found)**

```bash
cd ~/Desktop/Developer/Dispo/apps/web && npx vitest run src/lib/__tests__/featureFlags.test.ts 2>&1 | tail -10
```

Expected: FAIL — `Cannot find module '../featureFlags'`.

- [ ] **Step 3: Impl**

```ts
// apps/web/src/lib/featureFlags.ts
//
// Lightweight feature-flag lookup. URL param > localStorage > default.
// Setzen via URL: /?crm_v2=1 (persistiert in localStorage)
// Unsetzen via URL: /?crm_v2=0 (löscht localStorage)
// Read-only via isFeatureEnabled('crm_v2')
//
// Phase G Phase 2 nutzt `crm_v2` um die neue Detail-Panel-V2-Variante
// hinter einem Flag zu mounten ohne Production zu beeinflussen.

export const FEATURE_FLAGS = ['crm_v2'] as const
export type FeatureFlag = (typeof FEATURE_FLAGS)[number]

export function isFeatureEnabled(flag: FeatureFlag): boolean {
  // Side-effect: URL override syncs localStorage so the flag persists
  // across navigations.
  if (typeof window !== 'undefined') {
    const params = new URLSearchParams(window.location.search)
    const fromUrl = params.get(flag)
    if (fromUrl === '1' || fromUrl === 'true') {
      localStorage.setItem(flag, 'true')
      return true
    }
    if (fromUrl === '0' || fromUrl === 'false') {
      localStorage.removeItem(flag)
      return false
    }
    return localStorage.getItem(flag) === 'true'
  }
  return false
}
```

- [ ] **Step 4: Test pass**

```bash
cd ~/Desktop/Developer/Dispo/apps/web && npx vitest run src/lib/__tests__/featureFlags.test.ts 2>&1 | tail -10
```

Expected: 5 passed.

- [ ] **Step 5: Commit**

```bash
cd ~/Desktop/Developer/Dispo
git add apps/web/src/lib/featureFlags.ts apps/web/src/lib/__tests__/featureFlags.test.ts
git commit -m 'feat(web): featureFlags util + tests (URL > localStorage, crm_v2 flag)'
```

---

### Task 2: TimelineFilterBar

Filter-Chips über der Timeline. Multi-select per Event-Typ-Gruppe. Liefert `TimelineFilter` an Parent via `onChange`.

**Files:**
- Create: `apps/web/src/screens/contacts/timeline/TimelineFilterBar.tsx`
- Create: `apps/web/src/screens/contacts/timeline/__tests__/TimelineFilterBar.test.tsx`

- [ ] **Step 1: Test schreiben**

```tsx
// apps/web/src/screens/contacts/timeline/__tests__/TimelineFilterBar.test.tsx
import { describe, it, expect, vi } from 'vitest'
import { render, screen, fireEvent } from '@testing-library/react'
import { TimelineFilterBar } from '../TimelineFilterBar'

describe('TimelineFilterBar', () => {
  it('renders all chip labels', () => {
    render(<TimelineFilterBar value={{}} onChange={vi.fn()} />)
    expect(screen.getByText('Alle')).toBeTruthy()
    expect(screen.getByText('Notiz')).toBeTruthy()
    expect(screen.getByText('Anruf')).toBeTruthy()
    expect(screen.getByText('Mail')).toBeTruthy()
    expect(screen.getByText('Kurs')).toBeTruthy()
    expect(screen.getByText('Saldo')).toBeTruthy()
  })

  it('clicking Notiz emits event_types=[note]', () => {
    const onChange = vi.fn()
    render(<TimelineFilterBar value={{}} onChange={onChange} />)
    fireEvent.click(screen.getByText('Notiz'))
    expect(onChange).toHaveBeenCalledWith({ event_types: ['note'] })
  })

  it('clicking Alle clears event_types', () => {
    const onChange = vi.fn()
    render(<TimelineFilterBar value={{ event_types: ['note'] }} onChange={onChange} />)
    fireEvent.click(screen.getByText('Alle'))
    expect(onChange).toHaveBeenCalledWith({ event_types: undefined })
  })

  it('marks active chip aria-pressed=true', () => {
    render(<TimelineFilterBar value={{ event_types: ['note'] }} onChange={vi.fn()} />)
    expect(screen.getByText('Notiz').getAttribute('aria-pressed')).toBe('true')
    expect(screen.getByText('Anruf').getAttribute('aria-pressed')).toBe('false')
  })
})
```

- [ ] **Step 2: Test fail**

```bash
cd ~/Desktop/Developer/Dispo/apps/web && npx vitest run src/screens/contacts/timeline/__tests__/TimelineFilterBar.test.tsx 2>&1 | tail -10
```

Expected: FAIL — module not found.

- [ ] **Step 3: Impl**

```tsx
// apps/web/src/screens/contacts/timeline/TimelineFilterBar.tsx
import type { TimelineFilter, EventType } from '@/types/contactEvents'

interface Props {
  value: TimelineFilter
  onChange: (next: TimelineFilter) => void
}

// Bucket-Definition: ein UI-Chip kann mehrere event_types zusammenfassen.
// 'Kurs' = course_enrollment + certification_issued + skill_checked + intake_checkpoint.
// 'Saldo' = saldo_movement nur.
// 'Mail' = email_external nur (System-Events haben keinen Mail-Typ in Phase G).
const BUCKETS: { label: string; types: EventType[] }[] = [
  { label: 'Notiz',   types: ['note'] },
  { label: 'Anruf',   types: ['call'] },
  { label: 'Mail',    types: ['email_external'] },
  { label: 'WhatsApp',types: ['whatsapp_log'] },
  { label: 'Termin',  types: ['meeting_past'] },
  { label: 'Task',    types: ['task'] },
  { label: 'Kurs',    types: ['course_enrollment', 'certification_issued', 'skill_checked', 'intake_checkpoint'] },
  { label: 'Saldo',   types: ['saldo_movement'] },
  { label: 'Pipeline',types: ['pipeline_change'] },
  { label: 'Audit',   types: ['role_change', 'audit_edit'] },
]

export function TimelineFilterBar({ value, onChange }: Props) {
  const activeSet = new Set(value.event_types ?? [])
  const noFilter = !value.event_types?.length

  function toggleBucket(types: EventType[]) {
    // If all types in bucket are active, remove them; otherwise add them.
    const allActive = types.every(t => activeSet.has(t))
    const next = new Set(activeSet)
    if (allActive) {
      types.forEach(t => next.delete(t))
    } else {
      types.forEach(t => next.add(t))
    }
    onChange({ ...value, event_types: next.size > 0 ? Array.from(next) : undefined })
  }

  function pressed(types: EventType[]): boolean {
    return types.every(t => activeSet.has(t))
  }

  return (
    <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6, padding: '8px 0' }}>
      <button
        type="button"
        aria-pressed={noFilter}
        onClick={() => onChange({ ...value, event_types: undefined })}
        style={chipStyle(noFilter)}
      >
        Alle
      </button>
      {BUCKETS.map(b => (
        <button
          key={b.label}
          type="button"
          aria-pressed={pressed(b.types)}
          onClick={() => toggleBucket(b.types)}
          style={chipStyle(pressed(b.types))}
        >
          {b.label}
        </button>
      ))}
    </div>
  )
}

function chipStyle(active: boolean): React.CSSProperties {
  return {
    padding: '4px 10px',
    borderRadius: 999,
    border: `1px solid ${active ? 'var(--brand-blue, #4a90e2)' : 'var(--border-subtle, #ddd)'}`,
    background: active ? 'var(--brand-blue-soft, #e8f0fb)' : 'transparent',
    color: active ? 'var(--brand-blue, #4a90e2)' : 'var(--text-secondary, #555)',
    cursor: 'pointer',
    fontSize: 13,
    fontWeight: active ? 500 : 400,
  }
}
```

- [ ] **Step 4: Test pass**

```bash
cd ~/Desktop/Developer/Dispo/apps/web && npx vitest run src/screens/contacts/timeline/__tests__/TimelineFilterBar.test.tsx 2>&1 | tail -10
```

Expected: 4 passed.

- [ ] **Step 5: Commit**

```bash
cd ~/Desktop/Developer/Dispo
git add apps/web/src/screens/contacts/timeline/TimelineFilterBar.tsx \
        apps/web/src/screens/contacts/timeline/__tests__/TimelineFilterBar.test.tsx
git commit -m 'feat(web): TimelineFilterBar with 10 buckets (Phase G Phase 2)'
```

---

### Task 3: EventCard — polymorpher Renderer

Polymorpher Renderer pro `event_type`. Icon-Mapping aus Spec §4.1. Body bei `note` mit Markdown-Lite rendern (line-breaks).

**Files:**
- Create: `apps/web/src/screens/contacts/timeline/EventCard.tsx`
- Create: `apps/web/src/screens/contacts/timeline/__tests__/EventCard.test.tsx`

- [ ] **Step 1: Test schreiben**

```tsx
// apps/web/src/screens/contacts/timeline/__tests__/EventCard.test.tsx
import { describe, it, expect } from 'vitest'
import { render, screen } from '@testing-library/react'
import { EventCard } from '../EventCard'
import type { TimelineEvent } from '@/types/contactEvents'

const baseEvent: TimelineEvent = {
  event_id: 'a',
  contact_id: 'c1',
  event_type: 'note',
  occurred_at: '2026-05-27T10:00:00Z',
  actor_contact_id: null,
  summary: 'hello world',
  body: null,
  payload: null,
  status: 'open',
  source_table: 'contact_events',
  source_id: 'a',
}

describe('EventCard', () => {
  it('renders summary and relative date', () => {
    render(<EventCard event={baseEvent} />)
    expect(screen.getByText('hello world')).toBeTruthy()
  })

  it('shows body when present', () => {
    render(<EventCard event={{ ...baseEvent, body: 'longer note text' }} />)
    expect(screen.getByText('longer note text')).toBeTruthy()
  })

  it('picks icon class based on event_type', () => {
    const { container } = render(<EventCard event={{ ...baseEvent, event_type: 'call' }} />)
    expect(container.querySelector('[data-icon="call"]')).toBeTruthy()
  })

  it('shows audit_edit summary with field-list', () => {
    render(<EventCard event={{
      ...baseEvent,
      event_type: 'audit_edit',
      summary: 'Daten bearbeitet: email, phone',
      source_table: 'contact_audit_log',
    }} />)
    expect(screen.getByText(/Daten bearbeitet:/)).toBeTruthy()
  })
})
```

- [ ] **Step 2: Test fail**

```bash
cd ~/Desktop/Developer/Dispo/apps/web && npx vitest run src/screens/contacts/timeline/__tests__/EventCard.test.tsx 2>&1 | tail -10
```

Expected: FAIL.

- [ ] **Step 3: Impl**

```tsx
// apps/web/src/screens/contacts/timeline/EventCard.tsx
import type { TimelineEvent, EventType } from '@/types/contactEvents'

interface Props {
  event: TimelineEvent
}

// Icon-Mapping (Tabler-Icons via Foundation). 'note' → ti-note etc.
// Subagents schreiben hier `data-icon` attribute statt SVG-rendering —
// das eigentliche Icon-Mounting machen wir in Phase 3 wenn Foundation-Icon
// auf alle 15 Typen erweitert ist. Phase 2 zeigt das Label.
const ICON_FOR: Record<EventType, string> = {
  note:                'note',
  call:                'phone',
  email_external:      'mail',
  meeting_past:        'calendar-event',
  task:                'checkbox',
  whatsapp_log:        'brand-whatsapp',
  course_enrollment:   'school',
  certification_issued:'certificate',
  saldo_movement:      'cash',
  pipeline_change:     'arrow-right',
  intake_checkpoint:   'checkbox',
  skill_checked:       'anchor',
  card_lead_imported:  'id-badge',
  role_change:         'user-cog',
  audit_edit:          'edit',
}

export function EventCard({ event }: Props) {
  return (
    <article style={{
      display: 'flex', gap: 10, padding: '10px 12px',
      borderBottom: '1px solid var(--border-subtle, #eee)',
    }}>
      <span
        data-icon={ICON_FOR[event.event_type] ?? 'point'}
        aria-hidden="true"
        style={{
          width: 24, height: 24, flexShrink: 0,
          borderRadius: 4, background: 'var(--surface-secondary, #f3f3f3)',
          display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
          fontSize: 11, color: 'var(--text-secondary, #555)',
        }}
      >
        {/* Placeholder bis Foundation-Icon erweitert ist; data-icon attr für test */}
        {ICON_FOR[event.event_type]?.slice(0, 3) ?? '·'}
      </span>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ fontSize: 14, fontWeight: 500 }}>{event.summary}</div>
        {event.body && (
          <div style={{ marginTop: 4, fontSize: 13, color: 'var(--text-secondary, #555)', whiteSpace: 'pre-wrap' }}>
            {event.body}
          </div>
        )}
        <div style={{ marginTop: 4, fontSize: 11, color: 'var(--text-tertiary, #888)' }}>
          {new Date(event.occurred_at).toLocaleString()} · {event.source_table}
        </div>
      </div>
    </article>
  )
}
```

- [ ] **Step 4: Test pass**

```bash
cd ~/Desktop/Developer/Dispo/apps/web && npx vitest run src/screens/contacts/timeline/__tests__/EventCard.test.tsx 2>&1 | tail -10
```

Expected: 4 passed.

- [ ] **Step 5: Commit**

```bash
cd ~/Desktop/Developer/Dispo
git add apps/web/src/screens/contacts/timeline/EventCard.tsx \
        apps/web/src/screens/contacts/timeline/__tests__/EventCard.test.tsx
git commit -m 'feat(web): EventCard polymorphic renderer for 15 event_types (Phase G Phase 2)'
```

---

### Task 4: TimelineFeed

Composer + FilterBar + Liste-of-EventCard + Infinite-Scroll Pagination via `useContactTimeline`.

**Files:**
- Create: `apps/web/src/screens/contacts/timeline/TimelineFeed.tsx`
- Create: `apps/web/src/screens/contacts/timeline/__tests__/TimelineFeed.test.tsx`

- [ ] **Step 1: Test schreiben**

```tsx
// apps/web/src/screens/contacts/timeline/__tests__/TimelineFeed.test.tsx
import { describe, it, expect, vi } from 'vitest'
import { render, screen, waitFor } from '@testing-library/react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { TimelineFeed } from '../TimelineFeed'

vi.mock('@/lib/supabase', () => {
  const limit = vi.fn().mockResolvedValue({
    data: [
      { event_id: 'a', contact_id: 'c1', event_type: 'note', occurred_at: '2026-05-01', summary: 'one', source_table: 'contact_events', actor_contact_id: null, body: null, payload: null, status: 'open', source_id: 'a' },
      { event_id: 'b', contact_id: 'c1', event_type: 'call', occurred_at: '2026-04-01', summary: 'two', source_table: 'contact_events', actor_contact_id: null, body: null, payload: null, status: 'open', source_id: 'b' },
    ],
    error: null,
  })
  const order2 = vi.fn().mockReturnValue({ limit, in: vi.fn().mockReturnValue({ limit }), gte: vi.fn().mockReturnValue({ limit }), lte: vi.fn().mockReturnValue({ limit }) })
  const order1 = vi.fn().mockReturnValue({ order: order2 })
  const eq = vi.fn().mockReturnValue({ order: order1 })
  const select = vi.fn().mockReturnValue({ eq })
  return { supabase: { from: vi.fn().mockReturnValue({ select }) } }
})

function wrapper({ children }: { children: React.ReactNode }) {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } })
  return <QueryClientProvider client={qc}>{children}</QueryClientProvider>
}

describe('TimelineFeed', () => {
  it('renders events from useContactTimeline', async () => {
    render(<TimelineFeed contactId="c1" />, { wrapper })
    await waitFor(() => expect(screen.getByText('one')).toBeTruthy())
    expect(screen.getByText('two')).toBeTruthy()
  })

  it('shows skeleton while loading', () => {
    render(<TimelineFeed contactId="c1" />, { wrapper })
    expect(screen.getByText(/Lade Timeline/i)).toBeTruthy()
  })

  it('shows empty state when no events', async () => {
    const qcEmpty = new QueryClient({ defaultOptions: { queries: { retry: false } } })
    // Override mock to return empty:
    const { supabase } = await import('@/lib/supabase')
    const emptyLimit = vi.fn().mockResolvedValue({ data: [], error: null })
    const emptyOrder = vi.fn().mockReturnValue({ limit: emptyLimit })
    const emptyOrder1 = vi.fn().mockReturnValue({ order: emptyOrder })
    const emptyEq = vi.fn().mockReturnValue({ order: emptyOrder1 })
    const emptySelect = vi.fn().mockReturnValue({ eq: emptyEq })
    vi.mocked(supabase.from).mockReturnValueOnce({ select: emptySelect } as never)

    render(
      <QueryClientProvider client={qcEmpty}>
        <TimelineFeed contactId="c2" />
      </QueryClientProvider>
    )
    await waitFor(() => expect(screen.getByText(/Noch keine Events/i)).toBeTruthy())
  })
})
```

- [ ] **Step 2: Test fail**

```bash
cd ~/Desktop/Developer/Dispo/apps/web && npx vitest run src/screens/contacts/timeline/__tests__/TimelineFeed.test.tsx 2>&1 | tail -10
```

Expected: FAIL.

- [ ] **Step 3: Impl**

```tsx
// apps/web/src/screens/contacts/timeline/TimelineFeed.tsx
import { useState } from 'react'
import { useContactTimeline } from '@/hooks/useContactTimeline'
import type { TimelineFilter } from '@/types/contactEvents'
import { EventCard } from './EventCard'
import { TimelineFilterBar } from './TimelineFilterBar'
import { EventComposer } from './EventComposer'

interface Props {
  contactId: string
}

export function TimelineFeed({ contactId }: Props) {
  const [filter, setFilter] = useState<TimelineFilter>({})
  const tl = useContactTimeline(contactId, filter)
  const events = tl.data?.pages.flat() ?? []

  return (
    <div style={{ display: 'flex', flexDirection: 'column', height: '100%' }}>
      <EventComposer contactId={contactId} />
      <TimelineFilterBar value={filter} onChange={setFilter} />
      <div style={{ flex: 1, overflowY: 'auto', minHeight: 0 }}>
        {tl.isLoading && (
          <div style={{ padding: 20, color: 'var(--text-secondary)' }}>Lade Timeline…</div>
        )}
        {tl.error && (
          <div style={{ padding: 20, color: 'var(--color-text-danger, #c0392b)' }}>
            Fehler: {tl.error.message}
            <button type="button" onClick={() => tl.refetch()} style={{ marginLeft: 12 }}>↻ Retry</button>
          </div>
        )}
        {!tl.isLoading && !tl.error && events.length === 0 && (
          <div style={{ padding: 20, color: 'var(--text-tertiary)', textAlign: 'center' }}>
            Noch keine Events. Erfasse oben eine Notiz, einen Anruf oder Task.
          </div>
        )}
        {events.map(e => <EventCard key={e.event_id} event={e} />)}
        {tl.hasNextPage && (
          <div style={{ padding: 16, textAlign: 'center' }}>
            <button
              type="button"
              onClick={() => tl.fetchNextPage()}
              disabled={tl.isFetchingNextPage}
              style={{ padding: '6px 14px' }}
            >
              {tl.isFetchingNextPage ? 'Lade…' : 'Mehr anzeigen'}
            </button>
          </div>
        )}
      </div>
    </div>
  )
}
```

- [ ] **Step 4: Test pass**

```bash
cd ~/Desktop/Developer/Dispo/apps/web && npx vitest run src/screens/contacts/timeline/__tests__/TimelineFeed.test.tsx 2>&1 | tail -10
```

Expected: 3 passed.

- [ ] **Step 5: Commit**

```bash
cd ~/Desktop/Developer/Dispo
git add apps/web/src/screens/contacts/timeline/TimelineFeed.tsx \
        apps/web/src/screens/contacts/timeline/__tests__/TimelineFeed.test.tsx
git commit -m 'feat(web): TimelineFeed with composer + filter + infinite-scroll (Phase G Phase 2)'
```

---

### Task 5: ContactDetailHeader

Header oben in Detail-Panel. Avatar + Name + Roles (links), Quick-Actions (Mail/Call/Note/Task/Calendar) Mitte, Edit + ⋯ rechts.

**Files:**
- Create: `apps/web/src/screens/contacts/ContactDetailHeader.tsx`
- Create: `apps/web/src/screens/contacts/__tests__/ContactDetailHeader.test.tsx`

- [ ] **Step 1: Test schreiben**

```tsx
// apps/web/src/screens/contacts/__tests__/ContactDetailHeader.test.tsx
import { describe, it, expect, vi } from 'vitest'
import { render, screen, fireEvent } from '@testing-library/react'
import { ContactDetailHeader } from '../ContactDetailHeader'

describe('ContactDetailHeader', () => {
  it('renders contact name', () => {
    render(<ContactDetailHeader
      contactId="c1"
      displayName="Hugo Eugster"
      roles={['student']}
      onEdit={vi.fn()}
      onClose={vi.fn()}
    />)
    expect(screen.getByText('Hugo Eugster')).toBeTruthy()
  })

  it('renders role badges', () => {
    render(<ContactDetailHeader
      contactId="c1"
      displayName="Hugo"
      roles={['student', 'candidate']}
      onEdit={vi.fn()}
      onClose={vi.fn()}
    />)
    expect(screen.getByText('student')).toBeTruthy()
    expect(screen.getByText('candidate')).toBeTruthy()
  })

  it('Edit button calls onEdit', () => {
    const onEdit = vi.fn()
    render(<ContactDetailHeader
      contactId="c1"
      displayName="Hugo"
      roles={[]}
      onEdit={onEdit}
      onClose={vi.fn()}
    />)
    fireEvent.click(screen.getByRole('button', { name: /Bearbeiten/i }))
    expect(onEdit).toHaveBeenCalledOnce()
  })

  it('Close button calls onClose', () => {
    const onClose = vi.fn()
    render(<ContactDetailHeader
      contactId="c1"
      displayName="Hugo"
      roles={[]}
      onEdit={vi.fn()}
      onClose={onClose}
    />)
    fireEvent.click(screen.getByRole('button', { name: /Schliessen/i }))
    expect(onClose).toHaveBeenCalledOnce()
  })
})
```

- [ ] **Step 2: Test fail**

```bash
cd ~/Desktop/Developer/Dispo/apps/web && npx vitest run src/screens/contacts/__tests__/ContactDetailHeader.test.tsx 2>&1 | tail -10
```

Expected: FAIL.

- [ ] **Step 3: Impl**

```tsx
// apps/web/src/screens/contacts/ContactDetailHeader.tsx
//
// Phase G Phase 2 Header für ContactDetailPanelV2. Layout:
// [Avatar · Name + Role-Pills] [spacer] [Edit-Button] [⋯-Menü] [✕-Close]
//
// Quick-Actions (Mail/Call/Note/...) leben PHASE 3 in der Properties-Sidebar
// (oder unterhalb des Headers wenn Sidebar collapsed). In Phase 2 nur die
// minimalen Header-Controls. EventComposer in TimelineFeed deckt das Erfassen.
import type { ContactRole } from '@/types/contacts'

interface Props {
  contactId: string
  displayName: string
  roles: ContactRole[]
  onEdit: () => void
  onClose: () => void
}

export function ContactDetailHeader({ contactId: _contactId, displayName, roles, onEdit, onClose }: Props) {
  return (
    <header style={{
      display: 'flex', alignItems: 'center', gap: 12,
      padding: '10px 14px',
      borderBottom: '1px solid var(--border-subtle, #eee)',
      background: 'var(--surface-primary, white)',
    }}>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ fontSize: 17, fontWeight: 500 }}>{displayName}</div>
        {roles.length > 0 && (
          <div style={{ display: 'flex', gap: 4, marginTop: 4, flexWrap: 'wrap' }}>
            {roles.map(r => (
              <span
                key={r}
                style={{
                  padding: '2px 8px', borderRadius: 999,
                  background: 'var(--surface-secondary, #f3f3f3)',
                  fontSize: 11, color: 'var(--text-secondary, #555)',
                }}
              >
                {r}
              </span>
            ))}
          </div>
        )}
      </div>
      <button
        type="button"
        onClick={onEdit}
        style={{ padding: '6px 12px' }}
      >
        Bearbeiten
      </button>
      <button
        type="button"
        onClick={onClose}
        aria-label="Schliessen"
        style={{ padding: '6px 10px', background: 'transparent', border: 'none', cursor: 'pointer' }}
      >
        ✕
      </button>
    </header>
  )
}
```

- [ ] **Step 4: Test pass**

```bash
cd ~/Desktop/Developer/Dispo/apps/web && npx vitest run src/screens/contacts/__tests__/ContactDetailHeader.test.tsx 2>&1 | tail -10
```

Expected: 4 passed.

- [ ] **Step 5: Commit**

```bash
cd ~/Desktop/Developer/Dispo
git add apps/web/src/screens/contacts/ContactDetailHeader.tsx \
        apps/web/src/screens/contacts/__tests__/ContactDetailHeader.test.tsx
git commit -m 'feat(web): ContactDetailHeader with name + roles + edit/close (Phase G Phase 2)'
```

---

### Task 6: NoteComposer (simplest, sets pattern)

Erste Composer-Komponente. Setzt das Pattern für die anderen 5: kontrolliertes Form mit `summary` + `body`, ruft `useInsertContactEvent.mutate` mit `EventComposerInput`.

**Files:**
- Create: `apps/web/src/screens/contacts/timeline/composers/NoteComposer.tsx`
- Create: `apps/web/src/screens/contacts/timeline/composers/__tests__/NoteComposer.test.tsx`

- [ ] **Step 1: Test schreiben**

```tsx
// apps/web/src/screens/contacts/timeline/composers/__tests__/NoteComposer.test.tsx
import { describe, it, expect, vi } from 'vitest'
import { render, screen, fireEvent } from '@testing-library/react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { NoteComposer } from '../NoteComposer'

const mockMutate = vi.fn()
vi.mock('@/hooks/useEventComposer', () => ({
  useInsertContactEvent: () => ({
    mutate: mockMutate, isPending: false, error: null,
  }),
}))

function wrapper({ children }: { children: React.ReactNode }) {
  const qc = new QueryClient()
  return <QueryClientProvider client={qc}>{children}</QueryClientProvider>
}

describe('NoteComposer', () => {
  it('submit calls mutate with event_type=note', () => {
    const onDone = vi.fn()
    render(<NoteComposer contactId="c1" onDone={onDone} />, { wrapper })
    fireEvent.change(screen.getByPlaceholderText(/Titel/), { target: { value: 'My note' } })
    fireEvent.change(screen.getByPlaceholderText(/Text/), { target: { value: 'Body content' } })
    fireEvent.click(screen.getByRole('button', { name: /Speichern/i }))
    expect(mockMutate).toHaveBeenCalledWith(
      { event_type: 'note', summary: 'My note', body: 'Body content' },
      expect.objectContaining({ onSuccess: expect.any(Function) }),
    )
  })

  it('empty summary disables submit', () => {
    render(<NoteComposer contactId="c1" onDone={vi.fn()} />, { wrapper })
    const submit = screen.getByRole('button', { name: /Speichern/i })
    expect(submit.hasAttribute('disabled')).toBe(true)
    fireEvent.change(screen.getByPlaceholderText(/Titel/), { target: { value: 'X' } })
    expect(submit.hasAttribute('disabled')).toBe(false)
  })
})
```

- [ ] **Step 2: Test fail**

```bash
cd ~/Desktop/Developer/Dispo/apps/web && npx vitest run src/screens/contacts/timeline/composers/__tests__/NoteComposer.test.tsx 2>&1 | tail -10
```

Expected: FAIL.

- [ ] **Step 3: Impl**

```tsx
// apps/web/src/screens/contacts/timeline/composers/NoteComposer.tsx
import { useState } from 'react'
import { useInsertContactEvent } from '@/hooks/useEventComposer'

interface Props {
  contactId: string
  onDone: () => void
}

export function NoteComposer({ contactId, onDone }: Props) {
  const [summary, setSummary] = useState('')
  const [body, setBody] = useState('')
  const insert = useInsertContactEvent(contactId)

  function submit() {
    if (!summary.trim()) return
    insert.mutate(
      { event_type: 'note', summary: summary.trim(), body: body.trim() || undefined },
      {
        onSuccess: () => {
          setSummary('')
          setBody('')
          onDone()
        },
      },
    )
  }

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
      <input
        type="text"
        placeholder="Titel der Notiz"
        value={summary}
        onChange={e => setSummary(e.target.value)}
        style={{ padding: 8 }}
      />
      <textarea
        placeholder="Text (optional)"
        value={body}
        onChange={e => setBody(e.target.value)}
        rows={3}
        style={{ padding: 8, resize: 'vertical' }}
      />
      {insert.error && (
        <div style={{ color: 'var(--color-text-danger, #c0392b)', fontSize: 12 }}>
          {insert.error.message}
        </div>
      )}
      <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 6 }}>
        <button type="button" onClick={onDone} style={{ padding: '6px 12px' }}>
          Abbrechen
        </button>
        <button
          type="button"
          onClick={submit}
          disabled={!summary.trim() || insert.isPending}
          style={{ padding: '6px 14px' }}
        >
          {insert.isPending ? 'Speichere…' : 'Speichern'}
        </button>
      </div>
    </div>
  )
}
```

- [ ] **Step 4: Test pass**

```bash
cd ~/Desktop/Developer/Dispo/apps/web && npx vitest run src/screens/contacts/timeline/composers/__tests__/NoteComposer.test.tsx 2>&1 | tail -10
```

Expected: 2 passed.

- [ ] **Step 5: Commit**

```bash
cd ~/Desktop/Developer/Dispo
git add apps/web/src/screens/contacts/timeline/composers/NoteComposer.tsx \
        apps/web/src/screens/contacts/timeline/composers/__tests__/NoteComposer.test.tsx
git commit -m 'feat(web): NoteComposer with TDD pattern (Phase G Phase 2)'
```

---

### Tasks 7-11: 5 weitere Composer (analog NoteComposer)

Jeder Composer folgt dem NoteComposer-Pattern. Pro Composer:
- Eigene Form-Fields per `EventComposerInput`-Branch
- `useInsertContactEvent.mutate(...)` Submit
- Test mit `{ event_type, ...fields }` Assertion

**Wegen Längen-Budget: alle 5 in einem Task-Block zusammengefasst — pro Composer Code + Test in eigenem Sub-Commit.**

### Task 7: CallComposer

**Files:**
- Create: `apps/web/src/screens/contacts/timeline/composers/CallComposer.tsx`
- Create: `apps/web/src/screens/contacts/timeline/composers/__tests__/CallComposer.test.tsx`

- [ ] **Step 1: Test**

```tsx
import { describe, it, expect, vi } from 'vitest'
import { render, screen, fireEvent } from '@testing-library/react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { CallComposer } from '../CallComposer'

const mockMutate = vi.fn()
vi.mock('@/hooks/useEventComposer', () => ({
  useInsertContactEvent: () => ({ mutate: mockMutate, isPending: false, error: null }),
}))

function wrapper({ children }: { children: React.ReactNode }) {
  const qc = new QueryClient()
  return <QueryClientProvider client={qc}>{children}</QueryClientProvider>
}

describe('CallComposer', () => {
  it('submits event_type=call with summary, payload.duration_min, direction', () => {
    render(<CallComposer contactId="c1" onDone={vi.fn()} />, { wrapper })
    fireEvent.change(screen.getByPlaceholderText(/Worum ging/i), { target: { value: 'Test call' } })
    fireEvent.change(screen.getByLabelText(/Dauer/), { target: { value: '15' } })
    fireEvent.click(screen.getByLabelText(/Eingehend/i))
    fireEvent.click(screen.getByRole('button', { name: /Speichern/i }))
    expect(mockMutate).toHaveBeenCalledWith(
      expect.objectContaining({
        event_type: 'call',
        summary: 'Test call',
        payload: { duration_min: 15, direction: 'inbound' },
      }),
      expect.any(Object),
    )
  })
})
```

- [ ] **Step 2: Test fail** — `npx vitest run src/screens/contacts/timeline/composers/__tests__/CallComposer.test.tsx`

- [ ] **Step 3: Impl**

```tsx
// apps/web/src/screens/contacts/timeline/composers/CallComposer.tsx
import { useState } from 'react'
import { useInsertContactEvent } from '@/hooks/useEventComposer'
import type { Direction } from '@/types/contactEvents'

interface Props {
  contactId: string
  onDone: () => void
}

export function CallComposer({ contactId, onDone }: Props) {
  const [summary, setSummary] = useState('')
  const [body, setBody] = useState('')
  const [duration, setDuration] = useState('')
  const [direction, setDirection] = useState<Direction>('outbound')
  const insert = useInsertContactEvent(contactId)

  function submit() {
    if (!summary.trim()) return
    const minutes = duration.trim() ? Number(duration) : undefined
    insert.mutate(
      {
        event_type: 'call',
        summary: summary.trim(),
        body: body.trim() || undefined,
        payload: {
          ...(minutes !== undefined && !Number.isNaN(minutes) ? { duration_min: minutes } : {}),
          direction,
        },
      },
      {
        onSuccess: () => {
          setSummary(''); setBody(''); setDuration(''); setDirection('outbound')
          onDone()
        },
      },
    )
  }

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
      <input
        type="text"
        placeholder="Worum ging der Anruf"
        value={summary}
        onChange={e => setSummary(e.target.value)}
        style={{ padding: 8 }}
      />
      <textarea
        placeholder="Notizen (optional)"
        value={body}
        onChange={e => setBody(e.target.value)}
        rows={2}
        style={{ padding: 8 }}
      />
      <div style={{ display: 'flex', gap: 12, alignItems: 'center' }}>
        <label style={{ fontSize: 13 }}>
          Dauer
          <input
            type="number"
            value={duration}
            onChange={e => setDuration(e.target.value)}
            placeholder="Min."
            min="0"
            style={{ marginLeft: 6, width: 70, padding: 4 }}
          />
        </label>
        <label style={{ fontSize: 13 }}>
          <input
            type="radio"
            name="dir"
            checked={direction === 'outbound'}
            onChange={() => setDirection('outbound')}
          /> Ausgehend
        </label>
        <label style={{ fontSize: 13 }}>
          <input
            type="radio"
            name="dir"
            checked={direction === 'inbound'}
            onChange={() => setDirection('inbound')}
          /> Eingehend
        </label>
      </div>
      <SubmitButtons disabled={!summary.trim() || insert.isPending} onCancel={onDone} onSave={submit} pending={insert.isPending} />
    </div>
  )
}

// Shared helper (würde in eigenes File, aber für Phase-2-Plan inline halten).
function SubmitButtons({ disabled, onCancel, onSave, pending }: {
  disabled: boolean; onCancel: () => void; onSave: () => void; pending: boolean
}) {
  return (
    <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 6 }}>
      <button type="button" onClick={onCancel} style={{ padding: '6px 12px' }}>Abbrechen</button>
      <button type="button" onClick={onSave} disabled={disabled} style={{ padding: '6px 14px' }}>
        {pending ? 'Speichere…' : 'Speichern'}
      </button>
    </div>
  )
}
```

- [ ] **Step 4: Test pass** — Expected: 1 passed

- [ ] **Step 5: Commit**

```bash
cd ~/Desktop/Developer/Dispo
git add apps/web/src/screens/contacts/timeline/composers/CallComposer.tsx \
        apps/web/src/screens/contacts/timeline/composers/__tests__/CallComposer.test.tsx
git commit -m 'feat(web): CallComposer with duration + direction (Phase G Phase 2)'
```

---

### Task 8: EmailLogComposer

Strukturell wie CallComposer: subject (required), direction (sent/received). Implementation siehe Spec §4.2 `email_external` Payload-Shape.

**Files:**
- Create: `apps/web/src/screens/contacts/timeline/composers/EmailLogComposer.tsx`
- Create: `apps/web/src/screens/contacts/timeline/composers/__tests__/EmailLogComposer.test.tsx`

- [ ] **Step 1: Test**

```tsx
import { describe, it, expect, vi } from 'vitest'
import { render, screen, fireEvent } from '@testing-library/react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { EmailLogComposer } from '../EmailLogComposer'

const mockMutate = vi.fn()
vi.mock('@/hooks/useEventComposer', () => ({
  useInsertContactEvent: () => ({ mutate: mockMutate, isPending: false, error: null }),
}))

function wrapper({ children }: { children: React.ReactNode }) {
  const qc = new QueryClient()
  return <QueryClientProvider client={qc}>{children}</QueryClientProvider>
}

describe('EmailLogComposer', () => {
  it('submits event_type=email_external with subject + direction', () => {
    render(<EmailLogComposer contactId="c1" onDone={vi.fn()} />, { wrapper })
    fireEvent.change(screen.getByPlaceholderText(/Subject/i), { target: { value: 'Re: OWD Anmeldung' } })
    fireEvent.change(screen.getByPlaceholderText(/Zusammenfassung/i), { target: { value: 'Bestätigt für Juli' } })
    fireEvent.click(screen.getByRole('button', { name: /Speichern/i }))
    expect(mockMutate).toHaveBeenCalledWith(
      expect.objectContaining({
        event_type: 'email_external',
        summary: 'Bestätigt für Juli',
        payload: expect.objectContaining({ subject: 'Re: OWD Anmeldung', direction: 'outbound' }),
      }),
      expect.any(Object),
    )
  })
})
```

- [ ] **Step 2: Test fail**

- [ ] **Step 3: Impl**

```tsx
// apps/web/src/screens/contacts/timeline/composers/EmailLogComposer.tsx
import { useState } from 'react'
import { useInsertContactEvent } from '@/hooks/useEventComposer'
import type { Direction } from '@/types/contactEvents'

interface Props {
  contactId: string
  onDone: () => void
}

export function EmailLogComposer({ contactId, onDone }: Props) {
  const [subject, setSubject] = useState('')
  const [summary, setSummary] = useState('')
  const [direction, setDirection] = useState<Direction>('outbound')
  const insert = useInsertContactEvent(contactId)

  function submit() {
    if (!subject.trim() || !summary.trim()) return
    insert.mutate(
      {
        event_type: 'email_external',
        summary: summary.trim(),
        payload: { subject: subject.trim(), direction },
      },
      {
        onSuccess: () => {
          setSubject(''); setSummary(''); setDirection('outbound')
          onDone()
        },
      },
    )
  }

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
      <input
        type="text"
        placeholder="Subject der Mail"
        value={subject}
        onChange={e => setSubject(e.target.value)}
        style={{ padding: 8 }}
      />
      <textarea
        placeholder="Zusammenfassung des Inhalts"
        value={summary}
        onChange={e => setSummary(e.target.value)}
        rows={3}
        style={{ padding: 8 }}
      />
      <div style={{ display: 'flex', gap: 12 }}>
        <label style={{ fontSize: 13 }}>
          <input type="radio" name="dir" checked={direction === 'outbound'} onChange={() => setDirection('outbound')} /> Gesendet
        </label>
        <label style={{ fontSize: 13 }}>
          <input type="radio" name="dir" checked={direction === 'inbound'} onChange={() => setDirection('inbound')} /> Empfangen
        </label>
      </div>
      {insert.error && (
        <div style={{ color: 'var(--color-text-danger)', fontSize: 12 }}>{insert.error.message}</div>
      )}
      <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 6 }}>
        <button type="button" onClick={onDone}>Abbrechen</button>
        <button
          type="button"
          onClick={submit}
          disabled={!subject.trim() || !summary.trim() || insert.isPending}
        >
          {insert.isPending ? 'Speichere…' : 'Speichern'}
        </button>
      </div>
    </div>
  )
}
```

- [ ] **Step 4: Test pass**

- [ ] **Step 5: Commit**

```bash
cd ~/Desktop/Developer/Dispo
git add apps/web/src/screens/contacts/timeline/composers/EmailLogComposer.tsx \
        apps/web/src/screens/contacts/timeline/composers/__tests__/EmailLogComposer.test.tsx
git commit -m 'feat(web): EmailLogComposer with subject + direction (Phase G Phase 2)'
```

---

### Task 9: MeetingComposer

`meeting_past`: summary + occurred_at (date) + duration + optional location.

**Files:**
- Create: `apps/web/src/screens/contacts/timeline/composers/MeetingComposer.tsx`
- Create: `apps/web/src/screens/contacts/timeline/composers/__tests__/MeetingComposer.test.tsx`

- [ ] **Step 1: Test**

```tsx
import { describe, it, expect, vi } from 'vitest'
import { render, screen, fireEvent } from '@testing-library/react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { MeetingComposer } from '../MeetingComposer'

const mockMutate = vi.fn()
vi.mock('@/hooks/useEventComposer', () => ({
  useInsertContactEvent: () => ({ mutate: mockMutate, isPending: false, error: null }),
}))

function wrapper({ children }: { children: React.ReactNode }) {
  const qc = new QueryClient()
  return <QueryClientProvider client={qc}>{children}</QueryClientProvider>
}

describe('MeetingComposer', () => {
  it('submits event_type=meeting_past with payload.duration_min and occurred_at', () => {
    render(<MeetingComposer contactId="c1" onDone={vi.fn()} />, { wrapper })
    fireEvent.change(screen.getByPlaceholderText(/Worum ging/i), { target: { value: 'Kaffee am See' } })
    fireEvent.change(screen.getByLabelText(/Dauer/), { target: { value: '60' } })
    fireEvent.change(screen.getByLabelText(/Datum/), { target: { value: '2026-05-15' } })
    fireEvent.click(screen.getByRole('button', { name: /Speichern/i }))
    expect(mockMutate).toHaveBeenCalledWith(
      expect.objectContaining({
        event_type: 'meeting_past',
        summary: 'Kaffee am See',
        occurred_at: '2026-05-15',
        payload: expect.objectContaining({ duration_min: 60 }),
      }),
      expect.any(Object),
    )
  })
})
```

- [ ] **Step 2: Test fail**

- [ ] **Step 3: Impl**

```tsx
// apps/web/src/screens/contacts/timeline/composers/MeetingComposer.tsx
import { useState } from 'react'
import { useInsertContactEvent } from '@/hooks/useEventComposer'

interface Props {
  contactId: string
  onDone: () => void
}

export function MeetingComposer({ contactId, onDone }: Props) {
  const [summary, setSummary] = useState('')
  const [body, setBody] = useState('')
  const [date, setDate] = useState('')
  const [duration, setDuration] = useState('')
  const [location, setLocation] = useState('')
  const insert = useInsertContactEvent(contactId)

  function submit() {
    if (!summary.trim()) return
    const minutes = duration.trim() ? Number(duration) : undefined
    insert.mutate(
      {
        event_type: 'meeting_past',
        summary: summary.trim(),
        body: body.trim() || undefined,
        ...(date.trim() ? { occurred_at: date.trim() } : {}),
        payload: {
          ...(minutes !== undefined && !Number.isNaN(minutes) ? { duration_min: minutes } : {}),
          ...(location.trim() ? { location: location.trim() } : {}),
        },
      },
      {
        onSuccess: () => {
          setSummary(''); setBody(''); setDate(''); setDuration(''); setLocation('')
          onDone()
        },
      },
    )
  }

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
      <input
        type="text"
        placeholder="Worum ging das Meeting"
        value={summary}
        onChange={e => setSummary(e.target.value)}
        style={{ padding: 8 }}
      />
      <textarea
        placeholder="Notizen (optional)"
        value={body}
        onChange={e => setBody(e.target.value)}
        rows={2}
        style={{ padding: 8 }}
      />
      <div style={{ display: 'flex', gap: 12, alignItems: 'center', flexWrap: 'wrap' }}>
        <label style={{ fontSize: 13 }}>
          Datum
          <input
            type="date"
            value={date}
            onChange={e => setDate(e.target.value)}
            style={{ marginLeft: 6, padding: 4 }}
          />
        </label>
        <label style={{ fontSize: 13 }}>
          Dauer
          <input
            type="number"
            value={duration}
            onChange={e => setDuration(e.target.value)}
            placeholder="Min."
            min="0"
            style={{ marginLeft: 6, width: 70, padding: 4 }}
          />
        </label>
        <input
          type="text"
          placeholder="Ort (optional)"
          value={location}
          onChange={e => setLocation(e.target.value)}
          style={{ padding: 4, flex: 1, minWidth: 120 }}
        />
      </div>
      <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 6 }}>
        <button type="button" onClick={onDone}>Abbrechen</button>
        <button type="button" onClick={submit} disabled={!summary.trim() || insert.isPending}>
          {insert.isPending ? 'Speichere…' : 'Speichern'}
        </button>
      </div>
    </div>
  )
}
```

- [ ] **Step 4: Test pass**

- [ ] **Step 5: Commit**

```bash
cd ~/Desktop/Developer/Dispo
git add apps/web/src/screens/contacts/timeline/composers/MeetingComposer.tsx \
        apps/web/src/screens/contacts/timeline/composers/__tests__/MeetingComposer.test.tsx
git commit -m 'feat(web): MeetingComposer with date + duration + location (Phase G Phase 2)'
```

---

### Task 10: TaskComposer

`task`: title (→ summary) + due_date + optional reminder.

**Files:**
- Create: `apps/web/src/screens/contacts/timeline/composers/TaskComposer.tsx`
- Create: `apps/web/src/screens/contacts/timeline/composers/__tests__/TaskComposer.test.tsx`

- [ ] **Step 1: Test**

```tsx
import { describe, it, expect, vi } from 'vitest'
import { render, screen, fireEvent } from '@testing-library/react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { TaskComposer } from '../TaskComposer'

const mockMutate = vi.fn()
vi.mock('@/hooks/useEventComposer', () => ({
  useInsertContactEvent: () => ({ mutate: mockMutate, isPending: false, error: null }),
}))

function wrapper({ children }: { children: React.ReactNode }) {
  const qc = new QueryClient()
  return <QueryClientProvider client={qc}>{children}</QueryClientProvider>
}

describe('TaskComposer', () => {
  it('submits event_type=task with payload.due_date', () => {
    render(<TaskComposer contactId="c1" onDone={vi.fn()} />, { wrapper })
    fireEvent.change(screen.getByPlaceholderText(/Was ist zu tun/), { target: { value: 'Mail nachhaken' } })
    fireEvent.change(screen.getByLabelText(/Fällig/), { target: { value: '2026-06-15' } })
    fireEvent.click(screen.getByRole('button', { name: /Speichern/i }))
    expect(mockMutate).toHaveBeenCalledWith(
      expect.objectContaining({
        event_type: 'task',
        summary: 'Mail nachhaken',
        payload: expect.objectContaining({ due_date: '2026-06-15' }),
      }),
      expect.any(Object),
    )
  })

  it('due_date is required', () => {
    render(<TaskComposer contactId="c1" onDone={vi.fn()} />, { wrapper })
    fireEvent.change(screen.getByPlaceholderText(/Was ist zu tun/), { target: { value: 'Test' } })
    const submit = screen.getByRole('button', { name: /Speichern/i })
    expect(submit.hasAttribute('disabled')).toBe(true)
  })
})
```

- [ ] **Step 2: Test fail**

- [ ] **Step 3: Impl**

```tsx
// apps/web/src/screens/contacts/timeline/composers/TaskComposer.tsx
import { useState } from 'react'
import { useInsertContactEvent } from '@/hooks/useEventComposer'

interface Props {
  contactId: string
  onDone: () => void
}

export function TaskComposer({ contactId, onDone }: Props) {
  const [summary, setSummary] = useState('')
  const [body, setBody] = useState('')
  const [dueDate, setDueDate] = useState('')
  const [reminder, setReminder] = useState('')
  const insert = useInsertContactEvent(contactId)

  function submit() {
    if (!summary.trim() || !dueDate) return
    insert.mutate(
      {
        event_type: 'task',
        summary: summary.trim(),
        body: body.trim() || undefined,
        payload: {
          due_date: dueDate,
          ...(reminder ? { reminder_at: reminder } : {}),
        },
      },
      {
        onSuccess: () => {
          setSummary(''); setBody(''); setDueDate(''); setReminder('')
          onDone()
        },
      },
    )
  }

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
      <input
        type="text"
        placeholder="Was ist zu tun?"
        value={summary}
        onChange={e => setSummary(e.target.value)}
        style={{ padding: 8 }}
      />
      <textarea
        placeholder="Details (optional)"
        value={body}
        onChange={e => setBody(e.target.value)}
        rows={2}
        style={{ padding: 8 }}
      />
      <div style={{ display: 'flex', gap: 12, alignItems: 'center' }}>
        <label style={{ fontSize: 13 }}>
          Fällig am
          <input
            type="date"
            value={dueDate}
            onChange={e => setDueDate(e.target.value)}
            style={{ marginLeft: 6, padding: 4 }}
          />
        </label>
        <label style={{ fontSize: 13 }}>
          Erinnerung (optional)
          <input
            type="datetime-local"
            value={reminder}
            onChange={e => setReminder(e.target.value)}
            style={{ marginLeft: 6, padding: 4 }}
          />
        </label>
      </div>
      <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 6 }}>
        <button type="button" onClick={onDone}>Abbrechen</button>
        <button
          type="button"
          onClick={submit}
          disabled={!summary.trim() || !dueDate || insert.isPending}
        >
          {insert.isPending ? 'Speichere…' : 'Speichern'}
        </button>
      </div>
    </div>
  )
}
```

- [ ] **Step 4: Test pass** — Expected: 2 passed

- [ ] **Step 5: Commit**

```bash
cd ~/Desktop/Developer/Dispo
git add apps/web/src/screens/contacts/timeline/composers/TaskComposer.tsx \
        apps/web/src/screens/contacts/timeline/composers/__tests__/TaskComposer.test.tsx
git commit -m 'feat(web): TaskComposer with due_date + reminder (Phase G Phase 2)'
```

---

### Task 11: WhatsAppLogComposer

`whatsapp_log`: summary + direction (sent/received). Strukturell wie CallComposer minus duration.

**Files:**
- Create: `apps/web/src/screens/contacts/timeline/composers/WhatsAppLogComposer.tsx`
- Create: `apps/web/src/screens/contacts/timeline/composers/__tests__/WhatsAppLogComposer.test.tsx`

- [ ] **Step 1: Test**

```tsx
import { describe, it, expect, vi } from 'vitest'
import { render, screen, fireEvent } from '@testing-library/react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { WhatsAppLogComposer } from '../WhatsAppLogComposer'

const mockMutate = vi.fn()
vi.mock('@/hooks/useEventComposer', () => ({
  useInsertContactEvent: () => ({ mutate: mockMutate, isPending: false, error: null }),
}))

function wrapper({ children }: { children: React.ReactNode }) {
  const qc = new QueryClient()
  return <QueryClientProvider client={qc}>{children}</QueryClientProvider>
}

describe('WhatsAppLogComposer', () => {
  it('submits event_type=whatsapp_log with direction', () => {
    render(<WhatsAppLogComposer contactId="c1" onDone={vi.fn()} />, { wrapper })
    fireEvent.change(screen.getByPlaceholderText(/Inhalt der Nachricht/i), { target: { value: 'Bestätigt für morgen' } })
    fireEvent.click(screen.getByLabelText(/Empfangen/i))
    fireEvent.click(screen.getByRole('button', { name: /Speichern/i }))
    expect(mockMutate).toHaveBeenCalledWith(
      expect.objectContaining({
        event_type: 'whatsapp_log',
        summary: 'Bestätigt für morgen',
        payload: { direction: 'inbound' },
      }),
      expect.any(Object),
    )
  })
})
```

- [ ] **Step 2: Test fail**

- [ ] **Step 3: Impl**

```tsx
// apps/web/src/screens/contacts/timeline/composers/WhatsAppLogComposer.tsx
import { useState } from 'react'
import { useInsertContactEvent } from '@/hooks/useEventComposer'
import type { Direction } from '@/types/contactEvents'

interface Props {
  contactId: string
  onDone: () => void
}

export function WhatsAppLogComposer({ contactId, onDone }: Props) {
  const [summary, setSummary] = useState('')
  const [direction, setDirection] = useState<Direction>('outbound')
  const insert = useInsertContactEvent(contactId)

  function submit() {
    if (!summary.trim()) return
    insert.mutate(
      {
        event_type: 'whatsapp_log',
        summary: summary.trim(),
        payload: { direction },
      },
      {
        onSuccess: () => {
          setSummary(''); setDirection('outbound')
          onDone()
        },
      },
    )
  }

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
      <textarea
        placeholder="Inhalt der Nachricht"
        value={summary}
        onChange={e => setSummary(e.target.value)}
        rows={3}
        style={{ padding: 8 }}
      />
      <div style={{ display: 'flex', gap: 12 }}>
        <label style={{ fontSize: 13 }}>
          <input
            type="radio"
            name="dir"
            checked={direction === 'outbound'}
            onChange={() => setDirection('outbound')}
          /> Gesendet
        </label>
        <label style={{ fontSize: 13 }}>
          <input
            type="radio"
            name="dir"
            checked={direction === 'inbound'}
            onChange={() => setDirection('inbound')}
          /> Empfangen
        </label>
      </div>
      <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 6 }}>
        <button type="button" onClick={onDone}>Abbrechen</button>
        <button type="button" onClick={submit} disabled={!summary.trim() || insert.isPending}>
          {insert.isPending ? 'Speichere…' : 'Speichern'}
        </button>
      </div>
    </div>
  )
}
```

- [ ] **Step 4: Test pass**

- [ ] **Step 5: Commit**

```bash
cd ~/Desktop/Developer/Dispo
git add apps/web/src/screens/contacts/timeline/composers/WhatsAppLogComposer.tsx \
        apps/web/src/screens/contacts/timeline/composers/__tests__/WhatsAppLogComposer.test.tsx
git commit -m 'feat(web): WhatsAppLogComposer with direction (Phase G Phase 2)'
```

---

### Task 12: EventComposer — Segmented-Control-Orchestrator

Bündelt die 6 Composer-Komponenten. Segmented Control oben, beim Switch wird die expanded Form gewechselt. State: aktuell ausgewählter Typ + ob expanded.

**Files:**
- Create: `apps/web/src/screens/contacts/timeline/EventComposer.tsx`
- Create: `apps/web/src/screens/contacts/timeline/__tests__/EventComposer.test.tsx`

- [ ] **Step 1: Test**

```tsx
import { describe, it, expect, vi } from 'vitest'
import { render, screen, fireEvent } from '@testing-library/react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { EventComposer } from '../EventComposer'

vi.mock('@/hooks/useEventComposer', () => ({
  useInsertContactEvent: () => ({ mutate: vi.fn(), isPending: false, error: null }),
}))

function wrapper({ children }: { children: React.ReactNode }) {
  const qc = new QueryClient()
  return <QueryClientProvider client={qc}>{children}</QueryClientProvider>
}

describe('EventComposer', () => {
  it('renders segmented control with all 6 types', () => {
    render(<EventComposer contactId="c1" />, { wrapper })
    expect(screen.getByRole('button', { name: 'Notiz' })).toBeTruthy()
    expect(screen.getByRole('button', { name: 'Anruf' })).toBeTruthy()
    expect(screen.getByRole('button', { name: 'Mail' })).toBeTruthy()
    expect(screen.getByRole('button', { name: 'Meeting' })).toBeTruthy()
    expect(screen.getByRole('button', { name: 'Task' })).toBeTruthy()
    expect(screen.getByRole('button', { name: 'WhatsApp' })).toBeTruthy()
  })

  it('clicking Notiz expands NoteComposer', () => {
    render(<EventComposer contactId="c1" />, { wrapper })
    fireEvent.click(screen.getByRole('button', { name: 'Notiz' }))
    expect(screen.getByPlaceholderText(/Titel der Notiz/i)).toBeTruthy()
  })

  it('clicking Anruf expands CallComposer', () => {
    render(<EventComposer contactId="c1" />, { wrapper })
    fireEvent.click(screen.getByRole('button', { name: 'Anruf' }))
    expect(screen.getByPlaceholderText(/Worum ging der Anruf/i)).toBeTruthy()
  })

  it('selecting a different type swaps the form', () => {
    render(<EventComposer contactId="c1" />, { wrapper })
    fireEvent.click(screen.getByRole('button', { name: 'Notiz' }))
    expect(screen.getByPlaceholderText(/Titel der Notiz/i)).toBeTruthy()
    fireEvent.click(screen.getByRole('button', { name: 'Task' }))
    expect(screen.queryByPlaceholderText(/Titel der Notiz/i)).toBeNull()
    expect(screen.getByPlaceholderText(/Was ist zu tun/i)).toBeTruthy()
  })
})
```

- [ ] **Step 2: Test fail**

- [ ] **Step 3: Impl**

```tsx
// apps/web/src/screens/contacts/timeline/EventComposer.tsx
import { useState } from 'react'
import type { UserEventType } from '@/types/contactEvents'
import { NoteComposer } from './composers/NoteComposer'
import { CallComposer } from './composers/CallComposer'
import { EmailLogComposer } from './composers/EmailLogComposer'
import { MeetingComposer } from './composers/MeetingComposer'
import { TaskComposer } from './composers/TaskComposer'
import { WhatsAppLogComposer } from './composers/WhatsAppLogComposer'

interface Props {
  contactId: string
}

const TYPES: { type: UserEventType; label: string }[] = [
  { type: 'note',            label: 'Notiz' },
  { type: 'call',            label: 'Anruf' },
  { type: 'email_external',  label: 'Mail' },
  { type: 'meeting_past',    label: 'Meeting' },
  { type: 'task',            label: 'Task' },
  { type: 'whatsapp_log',    label: 'WhatsApp' },
]

export function EventComposer({ contactId }: Props) {
  const [active, setActive] = useState<UserEventType | null>(null)

  return (
    <div style={{
      borderBottom: '1px solid var(--border-subtle, #eee)',
      padding: '12px 14px',
      background: 'var(--surface-primary, white)',
    }}>
      <div style={{ display: 'flex', gap: 4, marginBottom: active ? 12 : 0 }}>
        {TYPES.map(t => (
          <button
            key={t.type}
            type="button"
            onClick={() => setActive(active === t.type ? null : t.type)}
            aria-pressed={active === t.type}
            style={{
              padding: '6px 12px',
              borderRadius: 6,
              border: '1px solid var(--border-subtle, #ddd)',
              background: active === t.type ? 'var(--brand-blue-soft, #e8f0fb)' : 'transparent',
              color: active === t.type ? 'var(--brand-blue, #4a90e2)' : 'var(--text-secondary, #555)',
              fontWeight: active === t.type ? 500 : 400,
              cursor: 'pointer',
              fontSize: 13,
            }}
          >
            {t.label}
          </button>
        ))}
      </div>
      {active === 'note' && <NoteComposer contactId={contactId} onDone={() => setActive(null)} />}
      {active === 'call' && <CallComposer contactId={contactId} onDone={() => setActive(null)} />}
      {active === 'email_external' && <EmailLogComposer contactId={contactId} onDone={() => setActive(null)} />}
      {active === 'meeting_past' && <MeetingComposer contactId={contactId} onDone={() => setActive(null)} />}
      {active === 'task' && <TaskComposer contactId={contactId} onDone={() => setActive(null)} />}
      {active === 'whatsapp_log' && <WhatsAppLogComposer contactId={contactId} onDone={() => setActive(null)} />}
    </div>
  )
}
```

- [ ] **Step 4: Test pass** — Expected: 4 passed

- [ ] **Step 5: Commit**

```bash
cd ~/Desktop/Developer/Dispo
git add apps/web/src/screens/contacts/timeline/EventComposer.tsx \
        apps/web/src/screens/contacts/timeline/__tests__/EventComposer.test.tsx
git commit -m 'feat(web): EventComposer orchestrator with 6 composers (Phase G Phase 2)'
```

---

### Task 13: ContactDetailPanelV2 + Flag-Gate im ContactDetailPanel

3-Pane-Frame mit Header + TimelineFeed center + Sidebar-Placeholder. Bestehender `ContactDetailPanel` wird zur Routing-Komponente: bei `crm_v2`-Flag mountet er V2, sonst die Legacy-Tabs-Variante.

**Files:**
- Create: `apps/web/src/screens/contacts/ContactDetailPanelV2.tsx`
- Modify: `apps/web/src/screens/contacts/ContactDetailPanel.tsx` — wrap with flag gate
- Create: `apps/web/src/screens/contacts/__tests__/ContactDetailPanelV2.test.tsx`

- [ ] **Step 1: Read existing ContactDetailPanel to know its signature**

```bash
cd /sessions/festive-charming-meitner/mnt/Dispo && head -50 apps/web/src/screens/contacts/ContactDetailPanel.tsx
```

Notiere die Props-Signatur (vermutlich `contactId`, `onClose`, possibly tab control). V2 verwendet dieselbe.

- [ ] **Step 2: Test schreiben**

```tsx
// apps/web/src/screens/contacts/__tests__/ContactDetailPanelV2.test.tsx
import { describe, it, expect, vi } from 'vitest'
import { render, screen } from '@testing-library/react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { MemoryRouter } from 'react-router-dom'
import { ContactDetailPanelV2 } from '../ContactDetailPanelV2'

vi.mock('@/lib/supabase', () => {
  const limit = vi.fn().mockResolvedValue({ data: [], error: null })
  const order2 = vi.fn().mockReturnValue({ limit, in: vi.fn().mockReturnValue({ limit }), gte: vi.fn().mockReturnValue({ limit }), lte: vi.fn().mockReturnValue({ limit }) })
  const order1 = vi.fn().mockReturnValue({ order: order2 })
  const eq = vi.fn().mockReturnValue({ order: order1, single: vi.fn().mockResolvedValue({ data: { id: 'c1', display_name: 'Hugo', roles: [] }, error: null }) })
  const select = vi.fn().mockReturnValue({ eq })
  return { supabase: { from: vi.fn().mockReturnValue({ select }) } }
})

function wrapper({ children }: { children: React.ReactNode }) {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } })
  return (
    <MemoryRouter>
      <QueryClientProvider client={qc}>{children}</QueryClientProvider>
    </MemoryRouter>
  )
}

describe('ContactDetailPanelV2', () => {
  it('renders 3-pane shell with header + timeline + sidebar slot', () => {
    render(<ContactDetailPanelV2 contactId="c1" onClose={vi.fn()} />, { wrapper })
    // Header
    expect(screen.queryByLabelText(/Schliessen/i)).toBeTruthy()
    // Timeline shell appears (composer + filter bar visible even before data)
    expect(screen.getByRole('button', { name: /Notiz/i })).toBeTruthy()
    // Sidebar placeholder
    expect(screen.getByTestId('properties-sidebar-placeholder')).toBeTruthy()
  })
})
```

- [ ] **Step 3: Test fail**

- [ ] **Step 4: Impl V2 file**

```tsx
// apps/web/src/screens/contacts/ContactDetailPanelV2.tsx
//
// Phase G Phase 2 — neue 3-Pane Detail-Panel-Variante hinter crm_v2-Flag.
// Sidebar ist Placeholder bis Phase 3 fertig ist. Layout:
//   [ Liste in Parent ] [ Header ............................. ] [ Sidebar slot ]
//                       [ TimelineFeed (composer + filter + cards) ]
//
import { useQuery } from '@tanstack/react-query'
import { supabase } from '@/lib/supabase'
import { ContactDetailHeader } from './ContactDetailHeader'
import { TimelineFeed } from './timeline/TimelineFeed'
import type { ContactRole } from '@/types/contacts'

interface Props {
  contactId: string
  onClose: () => void
}

interface ContactSummary {
  id: string
  display_name: string
  roles: ContactRole[]
}

export function ContactDetailPanelV2({ contactId, onClose }: Props) {
  // Minimal contact-summary fetch — Phase 3 ersetzt das durch eine
  // umfassendere Hook die alle Properties lädt. Für Phase 2 reicht Name + Roles.
  const contact = useQuery({
    queryKey: ['contact-summary', contactId],
    queryFn: async (): Promise<ContactSummary> => {
      const { data, error } = await supabase
        .from('contacts')
        .select('id, display_name')
        .eq('id', contactId)
        .single()
      if (error) throw new Error(error.message)
      // Roles separat (Phase 3 in Sidebar-Section).
      return { id: data.id, display_name: data.display_name, roles: [] }
    },
    enabled: !!contactId,
  })

  return (
    <div style={{ display: 'flex', flexDirection: 'column', height: '100%' }}>
      <div style={{ display: 'flex', flex: 1, minHeight: 0 }}>
        {/* Center: Header + Timeline */}
        <div style={{ flex: 1, display: 'flex', flexDirection: 'column', minWidth: 0 }}>
          <ContactDetailHeader
            contactId={contactId}
            displayName={contact.data?.display_name ?? '…'}
            roles={contact.data?.roles ?? []}
            onEdit={() => { /* öffnet existing edit-sheet — Phase 3 nachrüsten */ }}
            onClose={onClose}
          />
          <div style={{ flex: 1, minHeight: 0 }}>
            <TimelineFeed contactId={contactId} />
          </div>
        </div>
        {/* Sidebar slot — Phase 3 füllt das mit Properties */}
        <aside
          data-testid="properties-sidebar-placeholder"
          style={{
            width: 280, flexShrink: 0,
            borderLeft: '1px solid var(--border-subtle, #eee)',
            background: 'var(--surface-tertiary, #fafafa)',
            padding: 16,
            color: 'var(--text-tertiary, #888)',
            fontSize: 13,
          }}
        >
          Properties-Sidebar (Phase 3)
        </aside>
      </div>
    </div>
  )
}
```

- [ ] **Step 5: Modify ContactDetailPanel.tsx mit Flag-Gate**

Read the existing file first to understand structure. Then insert at the top of the component body:

```tsx
import { isFeatureEnabled } from '@/lib/featureFlags'
import { ContactDetailPanelV2 } from './ContactDetailPanelV2'

// inside the component, right at the start of the function body:
if (isFeatureEnabled('crm_v2')) {
  return <ContactDetailPanelV2 contactId={contactId} onClose={onClose} />
}
// ... rest of existing legacy implementation continues here
```

Exakte Stelle hängt vom existing ContactDetailPanel ab — Read-Tool nutzen um die Component-Signature zu finden.

- [ ] **Step 6: Test pass**

```bash
cd ~/Desktop/Developer/Dispo/apps/web && npx vitest run src/screens/contacts/__tests__/ContactDetailPanelV2.test.tsx 2>&1 | tail -10
```

Expected: 1 passed.

- [ ] **Step 7: Volle Test-Suite + Typecheck**

```bash
cd ~/Desktop/Developer/Dispo/apps/web && npx tsc --noEmit && npx vitest run --reporter=dot 2>&1 | tail -10
```

Expected: typecheck exit 0, alle Tests grün.

- [ ] **Step 8: Commit**

```bash
cd ~/Desktop/Developer/Dispo
git add apps/web/src/screens/contacts/ContactDetailPanelV2.tsx \
        apps/web/src/screens/contacts/ContactDetailPanel.tsx \
        apps/web/src/screens/contacts/__tests__/ContactDetailPanelV2.test.tsx
git commit -m 'feat(web): ContactDetailPanelV2 3-pane + flag-gate in legacy panel (Phase G Phase 2)'
```

---

### Task 14: Playwright E2E

End-to-End test: log a note via the new V2 panel → erscheint in Timeline → reload → still da.

**Files:**
- Create: `apps/web/tests/e2e/phase-g-timeline.spec.ts`

- [ ] **Step 1: Test schreiben**

```ts
// apps/web/tests/e2e/phase-g-timeline.spec.ts
//
// E2E smoke für Phase G Phase 2: User loggt eine Notiz im V2 Detail-Panel
// und sieht sie in der Timeline. Reload bestätigt Persistierung.
// Voraussetzung: Test-User existiert in der DB (z.B. Demo-Login auf Staging).

import { test, expect } from '@playwright/test'

const TEST_CONTACT_NAME = process.env.E2E_TEST_CONTACT_NAME ?? 'Hugo Eugster'

test('log note via V2 panel persists across reload', async ({ page }) => {
  await page.goto('/?crm_v2=1')
  // Login screen: tests setup expects pre-authenticated session via storageState
  // ODER manueller Login hier:
  // await page.fill('[type=email]', process.env.E2E_USER_EMAIL!)
  // ...

  // Navigate to Adressbuch
  await page.goto('/contacts')
  await page.getByRole('link', { name: new RegExp(TEST_CONTACT_NAME, 'i') }).click()

  // V2 panel should be mounted (props-sidebar-placeholder is the marker)
  await expect(page.getByTestId('properties-sidebar-placeholder')).toBeVisible()

  // Click Notiz in EventComposer
  await page.getByRole('button', { name: 'Notiz' }).click()
  const stamp = `e2e-${Date.now()}`
  await page.getByPlaceholder(/Titel der Notiz/i).fill(stamp)
  await page.getByPlaceholder(/Text/).fill('e2e body')
  await page.getByRole('button', { name: /Speichern/i }).click()

  // Note appears in timeline
  await expect(page.getByText(stamp)).toBeVisible()

  // Reload + verify persistence
  await page.reload()
  await expect(page.getByText(stamp)).toBeVisible()

  // Cleanup: delete the note via UI? Skip for now — E2E DB gets reset between runs
  // (or accept the noise in Production-Smoke. Manual cleanup via SQL after run.)
})
```

- [ ] **Step 2: Run lokal**

```bash
cd ~/Desktop/Developer/Dispo/apps/web && npx playwright test tests/e2e/phase-g-timeline.spec.ts --headed
```

Expected: 1 passed. Test öffnet Browser, klickt, asserted. Falls Login fehlt: `--headed` zeigt's manuell durchklicken.

Falls die Tests-Infrastruktur in deinem Repo `storageState` für authentifizierte Sessions verwendet (siehe `apps/web/playwright.config.ts`), das gleiche pattern wiederverwenden.

- [ ] **Step 3: Commit**

```bash
cd ~/Desktop/Developer/Dispo
git add apps/web/tests/e2e/phase-g-timeline.spec.ts
git commit -m 'test(e2e): Phase G Phase 2 timeline log-note flow'
```

---

### Task 15: Manual-Smoke + Production-Verification

- [ ] **Step 1: Dev-Server gegen Prod-DB**

```bash
cd ~/Desktop/Developer/Dispo/apps/web && npm run dev
```

Browse `http://localhost:5173/?crm_v2=1` → login → navigate to `/contacts` → click a contact → V2-Panel sichtbar (Header + Timeline + Sidebar-Placeholder).

Test:
- Composer: alle 6 Typen einmal anklicken, expand-collapse Toggle funktioniert
- Erfasse 1 Notiz, 1 Anruf, 1 Task → alle erscheinen in Timeline ohne Reload
- Reload → alle 3 noch da, korrekte Sortierung DESC
- Filter-Chips: klick „Notiz" → nur Notes sichtbar
- Klick „Alle" → alle wieder sichtbar
- Klick „Schliessen" (✕) → Panel schliesst, Liste sichtbar
- Klick anderen Contact → V2-Panel re-mountet, neue Daten

- [ ] **Step 2: Production-Sanity gegen tsk.atoll-os.com**

`git push origin main` → Vercel deployed auto. Browse `https://tsk.atoll-os.com/?crm_v2=1` → login → navigieren wie oben → smoke wie lokal.

Wichtig: Phase 2 ist **hinter Flag**, Production-User ohne `?crm_v2=1` sehen weiterhin den Legacy-Panel. Sicher zum Mergen.

- [ ] **Step 3: Cleanup-DB**

```sql
-- E2E + manual smoke notes wieder weg:
DELETE FROM contact_events
WHERE summary LIKE 'e2e-%' OR summary LIKE '%smoke%';
```

---

### Task 16: Phase 2 abschliessen

- [ ] **Step 1: Memory-Update** in `~/Library/.../memory/project_phase_g.md`: Phase 2 als done markieren, Carry-Forward-Items für Phase 3 (Properties-Sidebar) notieren.

- [ ] **Step 2: Milestone-Tag**

```bash
cd ~/Desktop/Developer/Dispo
git tag phase-g-phase2
git push origin main --tags
```

- [ ] **Step 3: Plan-Doc für Phase 3 anstossen** (in einer neuen Session): „Phase G Phase 3 starten" → Properties-Sidebar Plan.

---

## Verification Gates (zusammengefasst)

| Gate | Wie geprüft |
|---|---|
| Pre-Phase-2 Audit | 3 SQL-Proben durch, dokumentiert |
| Feature-Flag funktioniert | 5/5 Vitest passed |
| TimelineFilterBar | 4/4 Vitest |
| EventCard | 4/4 Vitest |
| TimelineFeed | 3/3 Vitest |
| ContactDetailHeader | 4/4 Vitest |
| 6 Composer | je 1-2 Tests passed |
| EventComposer-Orchestrator | 4/4 Vitest |
| ContactDetailPanelV2 | 1/1 Vitest |
| Cursor-Advance Hook-Test | Vitest +1 |
| Volle Suite | typecheck exit 0, alle Tests grün |
| Playwright E2E | log-note round-trip durch |
| Manual-Smoke | gegen Prod-DB mit `?crm_v2=1` |
| Production-Sanity | tsk.atoll-os.com/?crm_v2=1 |

---

## Was bewusst NICHT in Phase 2 ist

- **Properties-Sidebar-Inhalt** — Phase 3
- **Inline-Edit-Infrastruktur** — Phase 3
- **AddressbookScreen-Refresh** (Spalten, Filter, Bulk) — Phase 4
- **`/aktivitaet` globaler Screen** — Phase 5
- **CommunicationHub-Auflösung** — Phase 5
- **Flag-Flip + Cleanup** (`crm_v2` entfernen, alte Tabs löschen) — Phase 6
- **Foundation-Icon-Erweiterung** für die 15 Event-Typen — Phase 3 nimmt das mit (EventCard zeigt aktuell `data-icon` text-Placeholder)
- **Optimistic-Insert** in `useEventComposer` — Phase 2 nutzt plain invalidate (siehe Phase 1 docstring)
