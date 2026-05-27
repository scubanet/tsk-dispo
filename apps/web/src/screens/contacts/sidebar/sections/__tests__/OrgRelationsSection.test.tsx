import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, screen, fireEvent } from '@testing-library/react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { OrgRelationsSection } from '../OrgRelationsSection'
import type { ContactWithProperties } from '@/types/contactProperties'
import type { ContactRelationship } from '@/types/contacts'

// Mock the hook — return-shape: { data, isLoading, error }
const mockHook = vi.fn()
vi.mock('@/hooks/useContactTabs', () => ({
  useContactRelationships: (id: string | null | undefined) => mockHook(id),
}))

function wrapper({ children }: { children: React.ReactNode }) {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } })
  return <QueryClientProvider client={qc}>{children}</QueryClientProvider>
}

const baseContact: ContactWithProperties = {
  id: 'c1', kind: 'person', display_name: 'Hugo Eugster',
  first_name: 'Hugo', last_name: 'Eugster', birth_date: null,
  primary_email: null, primary_phone: null, primary_language: null,
  source: 'manual',
  created_at: '2026-01-01T00:00:00Z',
  updated_at: '2026-05-27T00:00:00Z',
  owner_id: null,
  instructor: null, student: null, organization: null,
  balance_chf: null, last_movement_date: null,
  roles: [],
}

function makeRel(overrides: Partial<ContactRelationship> = {}): ContactRelationship {
  return {
    id: 'r1',
    from_contact_id: 'c1',
    to_contact_id: 'o1',
    kind: 'works_at',
    role_at_org: null,
    started_at: null,
    ended_at: null,
    is_primary: false,
    notes: null,
    created_at: '2026-01-01T00:00:00Z',
    to_contact: { id: 'o1', display_name: 'SeaExplorers', kind: 'organization', roles: [] },
    ...overrides,
  }
}

/** SidebarSection is default closed — open the header to inspect the body. */
function openSection() {
  fireEvent.click(screen.getByText('Organisationen'))
}

beforeEach(() => {
  mockHook.mockReset()
  try { window.localStorage.clear() } catch { /* noop */ }
})

describe('OrgRelationsSection', () => {
  it('renders title "Organisationen"', () => {
    mockHook.mockReturnValue({ data: [], isLoading: false, error: null })
    render(<OrgRelationsSection contact={baseContact} />, { wrapper })
    expect(screen.getByText('Organisationen')).toBeTruthy()
  })

  it('is default closed (body hidden)', () => {
    mockHook.mockReturnValue({
      data: [makeRel({ to_contact: { id: 'o1', display_name: 'SeaExplorers', kind: 'organization', roles: [] } })],
      isLoading: false,
      error: null,
    })
    render(<OrgRelationsSection contact={baseContact} />, { wrapper })
    const body = document.getElementById('sidebar-section-orgs-body')
    expect(body).toBeTruthy()
    expect(body?.hasAttribute('hidden')).toBe(true)
  })

  it('after open: shows works_at relationship with display_name and role_at_org', () => {
    mockHook.mockReturnValue({
      data: [
        makeRel({
          role_at_org: 'Course Director',
          to_contact: { id: 'o1', display_name: 'SeaExplorers', kind: 'organization', roles: [] },
        }),
      ],
      isLoading: false,
      error: null,
    })
    render(<OrgRelationsSection contact={baseContact} />, { wrapper })
    openSection()
    expect(screen.getByText('SeaExplorers')).toBeTruthy()
    expect(screen.getByText('Course Director')).toBeTruthy()
  })

  it('after open: filters out other kinds (spouse_of, parent_of)', () => {
    mockHook.mockReturnValue({
      data: [
        makeRel({
          id: 'r-spouse',
          kind: 'spouse_of',
          to_contact: { id: 'o2', display_name: 'Spouse Person', kind: 'person', roles: [] },
        }),
        makeRel({
          id: 'r-parent',
          kind: 'parent_of',
          to_contact: { id: 'o3', display_name: 'Child Person', kind: 'person', roles: [] },
        }),
        makeRel({
          id: 'r-works',
          kind: 'works_at',
          role_at_org: 'CD',
          to_contact: { id: 'o4', display_name: 'SeaExplorers', kind: 'organization', roles: [] },
        }),
      ],
      isLoading: false,
      error: null,
    })
    render(<OrgRelationsSection contact={baseContact} />, { wrapper })
    openSection()
    expect(screen.getByText('SeaExplorers')).toBeTruthy()
    expect(screen.queryByText('Spouse Person')).toBeNull()
    expect(screen.queryByText('Child Person')).toBeNull()
  })

  it('after open: filters out reverse-direction items (to_contact_id === contact.id)', () => {
    mockHook.mockReturnValue({
      data: [
        // wrong direction — contact c1 is on the to-side
        makeRel({
          id: 'r-reverse',
          from_contact_id: 'someone-else',
          to_contact_id: 'c1',
          kind: 'works_at',
          to_contact: { id: 'c1', display_name: 'Hugo Eugster', kind: 'person', roles: [] },
        }),
      ],
      isLoading: false,
      error: null,
    })
    render(<OrgRelationsSection contact={baseContact} />, { wrapper })
    openSection()
    // The body should show the empty dash since no matching from-direction works_at
    expect(screen.queryByText('Hugo Eugster')).toBeNull()
    expect(screen.getByText('—')).toBeTruthy()
  })

  it('loading state: shows "Lädt…"', () => {
    mockHook.mockReturnValue({ data: undefined, isLoading: true, error: null })
    render(<OrgRelationsSection contact={baseContact} />, { wrapper })
    openSection()
    expect(screen.getByText(/Lädt/)).toBeTruthy()
  })

  it('error state: shows error text in role="alert"', () => {
    mockHook.mockReturnValue({
      data: undefined,
      isLoading: false,
      error: new Error('Boom'),
    })
    render(<OrgRelationsSection contact={baseContact} />, { wrapper })
    openSection()
    const alert = screen.getByRole('alert')
    expect(alert).toBeTruthy()
    expect(alert.textContent).toMatch(/Boom/)
  })

  it('empty state: shows dash when no matching relationships', () => {
    mockHook.mockReturnValue({ data: [], isLoading: false, error: null })
    render(<OrgRelationsSection contact={baseContact} />, { wrapper })
    openSection()
    expect(screen.getByText('—')).toBeTruthy()
  })

  it('renders primary badge when is_primary === true', () => {
    mockHook.mockReturnValue({
      data: [
        makeRel({
          is_primary: true,
          to_contact: { id: 'o1', display_name: 'SeaExplorers', kind: 'organization', roles: [] },
        }),
      ],
      isLoading: false,
      error: null,
    })
    render(<OrgRelationsSection contact={baseContact} />, { wrapper })
    openSection()
    expect(screen.getByText(/primary/i)).toBeTruthy()
  })
})
