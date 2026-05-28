// apps/web/src/screens/contacts/__tests__/AddressbookScreen.test.tsx
//
// Phase G Phase 4 — Hotfix Task 1: conditional layout test.
// Verifies that the AddressbookScreen renders the full-width
// AddressbookTable when no contact is selected and switches to the
// CompactContactList + ContactDetailPanel master-detail when ?contact=
// is set in the URL.

import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, screen, fireEvent } from '@testing-library/react'
import { MemoryRouter } from 'react-router-dom'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import type { Contact } from '@/types/contacts'

// ── Mocks ────────────────────────────────────────────────────────────────

// Mock useContactList so the screen renders synchronously.
const mockRows: Contact[] = [
  {
    id: 'c1',
    kind: 'person',
    first_name: 'Hugo',
    last_name: 'Eugster',
    display_name: 'Hugo Eugster',
    primary_email: 'hugo@example.com',
    emails: [],
    phones: [],
    addresses: [],
    languages: [],
    roles: ['student'],
    tags: [],
    consent_marketing: false,
    created_at: '2026-01-01T00:00:00Z',
    updated_at: '2026-01-01T00:00:00Z',
  },
  {
    id: 'c2',
    kind: 'person',
    first_name: 'Anna',
    last_name: 'Meier',
    display_name: 'Anna Meier',
    primary_email: 'anna@example.com',
    emails: [],
    phones: [],
    addresses: [],
    languages: [],
    roles: ['instructor'],
    tags: [],
    consent_marketing: false,
    created_at: '2026-01-01T00:00:00Z',
    updated_at: '2026-01-01T00:00:00Z',
  },
]

const useContactListSpy = vi.fn()
vi.mock('@/hooks/useContactList', () => ({
  useContactList: (...args: unknown[]) => {
    useContactListSpy(...args)
    return { data: { rows: mockRows }, isFetching: false }
  },
}))

// Mock the ContactDetailPanel so we don't drag the RLS/Supabase roundtrip in.
vi.mock('../ContactDetailPanel', () => ({
  ContactDetailPanel: ({ contactId }: { contactId: string }) => (
    <div data-testid="contact-detail-panel-mock">detail:{contactId}</div>
  ),
}))

// CreateContactSheet does a Supabase look-up on mount; stub it.
vi.mock('../CreateContactSheet', () => ({
  CreateContactSheet: () => null,
}))

// useContactSavedViews hits Supabase; stub query + mutations.
import type { ContactSavedView } from '@/types/contactEvents'
const savedViewsData: ContactSavedView[] = []
const createMutateAsync = vi.fn()
const deleteMutate = vi.fn()
vi.mock('@/hooks/useContactSavedViews', () => ({
  useContactSavedViews: () => ({ data: savedViewsData, isLoading: false }),
  useCreateSavedView: () => ({
    mutateAsync: createMutateAsync,
    isPending: false,
  }),
  useDeleteSavedView: () => ({
    mutate: deleteMutate,
    isPending: false,
  }),
}))

// ── Helpers ──────────────────────────────────────────────────────────────

import { AddressbookScreen } from '../AddressbookScreen'

function renderAt(url: string) {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } })
  return render(
    <MemoryRouter initialEntries={[url]}>
      <QueryClientProvider client={qc}>
        <AddressbookScreen />
      </QueryClientProvider>
    </MemoryRouter>,
  )
}

// ── Tests ────────────────────────────────────────────────────────────────

describe('AddressbookScreen conditional layout', () => {
  beforeEach(() => {
    window.localStorage.clear()
    useContactListSpy.mockClear()
    savedViewsData.length = 0
    createMutateAsync.mockReset()
    deleteMutate.mockReset()
  })

  it('without ?contact= renders full-width AddressbookTable, no DetailPanel', () => {
    const { container } = renderAt('/addressbook')

    // Full-width wrapper present
    expect(screen.getByTestId('addressbook-fullwidth')).toBeTruthy()

    // Table headers (Name, Email, Letzter Kontakt) visible
    expect(screen.getByRole('columnheader', { name: /Name/i })).toBeTruthy()
    expect(screen.getByRole('columnheader', { name: /Letzter Kontakt/i })).toBeTruthy()

    // DetailPanel mock NOT mounted
    expect(screen.queryByTestId('contact-detail-panel-mock')).toBeNull()

    // No CompactContactList rendered
    expect(container.querySelector('.atoll-people-list')).toBeNull()
  })

  it('forwards ?sort=name:asc from URL into useContactList filter', () => {
    renderAt('/addressbook?sort=name:asc')
    // The hook may have been called multiple times (re-renders) — pick the
    // last invocation, which reflects the settled state.
    expect(useContactListSpy).toHaveBeenCalled()
    const lastCall = useContactListSpy.mock.calls[useContactListSpy.mock.calls.length - 1]
    const filterArg = lastCall[0] as { sort?: unknown }
    expect(filterArg.sort).toEqual([{ field: 'name', direction: 'asc' }])
  })

  it('BulkActionBar visibility depends on selection size', () => {
    renderAt('/addressbook')
    // No selection → no bar.
    expect(screen.queryByTestId('addressbook-bulk-action-bar')).toBeNull()

    // Toggle the row checkbox for c1 (first body checkbox after the
    // header checkbox in the table).
    const checkboxes = screen.getAllByRole('checkbox')
    // checkboxes[0] = header toggle-all
    fireEvent.click(checkboxes[1])
    expect(screen.getByTestId('addressbook-bulk-action-bar')).toBeTruthy()
    expect(screen.getByTestId('bulk-action-counter').textContent).toBe(
      '1 ausgewählt',
    )
  })

  it('renders SavedViewsMenu chip even with zero custom views (saving entry)', () => {
    renderAt('/addressbook')
    expect(
      screen.getByRole('button', { name: 'Eigene Ansichten' }),
    ).toBeTruthy()
  })

  it('opens dropdown showing custom views and triggers apply', () => {
    savedViewsData.push({
      id: 'sv1',
      user_id: 'u1',
      name: 'Meine Studenten',
      filter: { roles: ['student'] },
      columns: ['name', 'email', 'last_contact'],
      sort: [{ field: 'name', direction: 'asc' }],
      density: 'compact',
      created_at: '2026-05-28T00:00:00Z',
      updated_at: '2026-05-28T00:00:00Z',
    })

    renderAt('/addressbook')

    fireEvent.click(
      screen.getByRole('button', { name: 'Eigene Ansichten' }),
    )
    const row = screen.getByTestId('saved-view-row-sv1')
    expect(row).toBeTruthy()
    expect(row.textContent).toContain('Meine Studenten')

    // Click the menu-item (first button inside the row) → applies the view.
    const applyBtn = row.querySelector('button[role="menuitem"]') as HTMLButtonElement
    fireEvent.click(applyBtn)

    // Density persisted to localStorage by the hook.
    expect(window.localStorage.getItem('addressbook.density')).toBe('compact')
    // visibleIds persisted as JSON.
    const cols = JSON.parse(
      window.localStorage.getItem('addressbook.columns') ?? '[]',
    )
    expect(cols).toContain('name')
    expect(cols).toContain('email')
  })

  it('with ?contact= renders CompactContactList + ContactDetailPanel', () => {
    const { container } = renderAt('/addressbook?contact=c1')

    // Detail-panel mock IS mounted with the correct contactId
    const detail = screen.getByTestId('contact-detail-panel-mock')
    expect(detail.textContent).toContain('detail:c1')

    // Compact list rendered (legacy atoll-people-row layout)
    expect(container.querySelector('.atoll-people-list')).toBeTruthy()

    // Full-width wrapper NOT present in this mode
    expect(screen.queryByTestId('addressbook-fullwidth')).toBeNull()

    // Table headers must NOT exist in master-detail mode
    expect(screen.queryByRole('columnheader', { name: /Letzter Kontakt/i })).toBeNull()
  })
})
