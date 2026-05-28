// apps/web/src/screens/contacts/activity/__tests__/ActivityScreen.test.tsx
//
// Phase G Phase 5 Task 4 — Tests für ActivityScreen.
//
// Mock-Strategie:
//   - useGlobalActivity → liefert pages-Array deterministisch.
//   - useCurrentUser    → liefert { instructorId: 'me-uid' } (für actorId).
//   - listContacts      → Contact-Lookup-Map mit display_name.
//   - useContactList    → Stub für ContactPicker im ActivityComposer.
//   - EventComposer     → Stub (Supabase-Insert vermeiden).
//   - supabase          → Final-Fallback, falls noch ein Modul durchschlüpft.

import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, screen } from '@testing-library/react'
import { MemoryRouter } from 'react-router-dom'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import type { ReactNode } from 'react'
import type { TimelineEvent } from '@/types/contactEvents'
import type { Contact } from '@/types/contacts'

// ── Mock useGlobalActivity ───────────────────────────────────────────
const useGlobalActivityMock = vi.fn()
vi.mock('@/hooks/useGlobalActivity', () => ({
  useGlobalActivity: (...args: unknown[]) => useGlobalActivityMock(...args),
}))

// ── Mock useCurrentUser ──────────────────────────────────────────────
const useCurrentUserMock = vi.fn()
vi.mock('@/hooks/useCurrentUser', () => ({
  useCurrentUser: () => useCurrentUserMock(),
}))

// ── Mock listContacts (Batch-Name-Lookup) ────────────────────────────
const listContactsMock = vi.fn()
vi.mock('@/lib/contactQueries', () => ({
  listContacts: (...args: unknown[]) => listContactsMock(...args),
}))

// ── Mock useContactList (used by the ContactPicker inside ActivityComposer) ─
vi.mock('@/hooks/useContactList', () => ({
  useContactList: () => ({ data: { rows: [] }, isFetching: false }),
}))

// ── Mock EventComposer (Supabase-roundtrip vermeiden) ────────────────
vi.mock('@/screens/contacts/timeline/EventComposer', () => ({
  EventComposer: ({ contactId }: { contactId: string }) => (
    <div data-testid="event-composer-mock">{contactId}</div>
  ),
}))

// ── Safety-net supabase mock (falls ein Modul den Import noch zieht) ──
vi.mock('@/lib/supabase', () => ({
  supabase: {
    from: vi.fn(() => ({
      select: vi.fn().mockReturnThis(),
      eq: vi.fn().mockReturnThis(),
      single: vi.fn().mockResolvedValue({ data: null, error: null }),
    })),
    auth: {
      getUser: vi.fn().mockResolvedValue({ data: { user: null } }),
    },
  },
}))

// ── Fixtures ─────────────────────────────────────────────────────────
const event1: TimelineEvent = {
  event_id: 'evt-1',
  contact_id: 'c-1',
  event_type: 'note',
  occurred_at: '2026-05-28T09:00:00Z',
  actor_contact_id: 'me-uid',
  summary: 'Erste Notiz',
  body: null,
  payload: null,
  status: 'open',
  source_table: 'contact_events',
  source_id: 'evt-1',
}

const event2: TimelineEvent = {
  event_id: 'evt-2',
  contact_id: 'c-2',
  event_type: 'call',
  occurred_at: '2026-05-27T18:00:00Z',
  actor_contact_id: 'me-uid',
  summary: 'Telefonat Mama',
  body: null,
  payload: null,
  status: 'open',
  source_table: 'contact_events',
  source_id: 'evt-2',
}

const contact1 = {
  id: 'c-1',
  kind: 'person',
  first_name: 'Anna',
  last_name: 'Beispiel',
  display_name: 'Anna Beispiel',
  primary_email: null,
  emails: [],
  phones: [],
  addresses: [],
  languages: [],
  roles: [],
  tags: [],
  consent_marketing: false,
  created_at: '',
  updated_at: '',
} as unknown as Contact

const contact2 = {
  ...contact1,
  id: 'c-2',
  first_name: 'Bea',
  last_name: 'Test',
  display_name: 'Bea Test',
} as unknown as Contact

// ── Helpers ──────────────────────────────────────────────────────────
import { ActivityScreen } from '../ActivityScreen'

function wrap(node: ReactNode) {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } })
  return render(
    <MemoryRouter initialEntries={['/aktivitaet']}>
      <QueryClientProvider client={qc}>{node}</QueryClientProvider>
    </MemoryRouter>,
  )
}

beforeEach(() => {
  useGlobalActivityMock.mockReset()
  useCurrentUserMock.mockReset()
  listContactsMock.mockReset()

  useCurrentUserMock.mockReturnValue({
    data: {
      authUserId: 'auth-me',
      instructorId: 'me-uid',
      name: 'Me',
      role: 'cd',
      email: 'me@example.com',
    },
    isLoading: false,
  })

  listContactsMock.mockResolvedValue({
    rows: [contact1, contact2],
    count: 2,
  })
})

// ── Tests ────────────────────────────────────────────────────────────
describe('ActivityScreen', () => {
  it('rendert Header „Aktivität" + FilterBar + Composer', () => {
    useGlobalActivityMock.mockReturnValue({
      data: { pages: [[]] },
      isLoading: false,
      isError: false,
      error: null,
      hasNextPage: false,
      isFetchingNextPage: false,
      fetchNextPage: vi.fn(),
    })
    wrap(<ActivityScreen />)
    expect(
      screen.getByRole('heading', { level: 1, name: 'Aktivität' }),
    ).toBeTruthy()
    expect(screen.getByTestId('activity-filter-bar')).toBeTruthy()
    expect(screen.getByTestId('activity-composer')).toBeTruthy()
  })

  it('rendert eine Karte pro Event aus data.pages', () => {
    useGlobalActivityMock.mockReturnValue({
      data: { pages: [[event1, event2]] },
      isLoading: false,
      isError: false,
      error: null,
      hasNextPage: false,
      isFetchingNextPage: false,
      fetchNextPage: vi.fn(),
    })
    wrap(<ActivityScreen />)
    expect(screen.getByText('Erste Notiz')).toBeTruthy()
    expect(screen.getByText('Telefonat Mama')).toBeTruthy()
    // Beide Karten haben einen Contact-Anchor
    expect(screen.getAllByTestId('contact-anchor').length).toBe(2)
  })

  it('Empty-State wenn pages leer sind', () => {
    useGlobalActivityMock.mockReturnValue({
      data: { pages: [[]] },
      isLoading: false,
      isError: false,
      error: null,
      hasNextPage: false,
      isFetchingNextPage: false,
      fetchNextPage: vi.fn(),
    })
    wrap(<ActivityScreen />)
    expect(screen.getByTestId('activity-empty')).toBeTruthy()
    expect(screen.getByTestId('activity-empty').textContent).toContain(
      'Keine Aktivität',
    )
  })

  it('Loading-State wenn isLoading && noch keine Events', () => {
    useGlobalActivityMock.mockReturnValue({
      data: undefined,
      isLoading: true,
      isError: false,
      error: null,
      hasNextPage: false,
      isFetchingNextPage: false,
      fetchNextPage: vi.fn(),
    })
    wrap(<ActivityScreen />)
    expect(screen.getByTestId('activity-loading')).toBeTruthy()
    // Kein Empty-State gleichzeitig
    expect(screen.queryByTestId('activity-empty')).toBeNull()
  })

  it('„Mehr laden"-Button erscheint wenn hasNextPage=true', () => {
    const fetchNextPageSpy = vi.fn()
    useGlobalActivityMock.mockReturnValue({
      data: { pages: [[event1]] },
      isLoading: false,
      isError: false,
      error: null,
      hasNextPage: true,
      isFetchingNextPage: false,
      fetchNextPage: fetchNextPageSpy,
    })
    wrap(<ActivityScreen />)
    const more = screen.getByRole('button', { name: /Mehr laden/i })
    expect(more).toBeTruthy()
  })
})
