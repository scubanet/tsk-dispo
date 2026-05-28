// apps/web/src/screens/contacts/__tests__/AddressbookScreen.test.tsx
//
// Phase G Phase 4 — Hotfix Task 1: conditional layout test.
// Verifies that the AddressbookScreen renders the full-width
// AddressbookTable when no contact is selected and switches to the
// CompactContactList + ContactDetailPanel master-detail when ?contact=
// is set in the URL.

import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, screen } from '@testing-library/react'
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

vi.mock('@/hooks/useContactList', () => ({
  useContactList: () => ({ data: { rows: mockRows }, isFetching: false }),
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
