import { describe, it, expect, vi } from 'vitest'
import { render, screen, waitFor } from '@testing-library/react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { PropertiesSidebar } from '../PropertiesSidebar'

vi.mock('@/lib/supabase', () => {
  // Two-Table-Pattern: `contacts` (single) + `v_contact_balance` (maybeSingle).
  const baseContact = {
    id: 'c1',
    kind: 'person',
    display_name: 'Hugo Eugster',
    first_name: 'Hugo',
    last_name: 'Eugster',
    birth_date: null,
    primary_email: 'hugo@test.com',
    phones: [], languages: ['de'],
    source: 'manual',
    created_at: '2026-01-01T00:00:00Z',
    updated_at: '2026-05-27T00:00:00Z',
    owner_id: null,
    tags: [],
    instructor: { padi_level: 'OWSI', padi_pro_number: null, active: true },
    student: null,
    organization: null,
  }
  function contactsBuilder() {
    const single = vi.fn().mockResolvedValue({ data: baseContact, error: null })
    const eq = vi.fn().mockReturnValue({ single })
    const select = vi.fn().mockReturnValue({ eq })
    return { select }
  }
  function balanceBuilder() {
    const maybeSingle = vi.fn().mockResolvedValue({ data: null, error: null })
    const eq = vi.fn().mockReturnValue({ maybeSingle })
    const select = vi.fn().mockReturnValue({ eq })
    return { select }
  }
  return {
    supabase: {
      from: vi.fn((table: string) =>
        table === 'v_contact_balance' ? balanceBuilder() : contactsBuilder(),
      ),
    },
  }
})

function wrapper({ children }: { children: React.ReactNode }) {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } })
  return <QueryClientProvider client={qc}>{children}</QueryClientProvider>
}

describe('PropertiesSidebar', () => {
  it('renders display name + 6 always-on stubs + PADI stub (when instructor sidecar present)', async () => {
    render(<PropertiesSidebar contactId="c1" />, { wrapper })
    await waitFor(() => expect(screen.getByText('Hugo Eugster')).toBeTruthy())
    expect(screen.getByTestId('stat-band')).toBeTruthy()
    expect(screen.getByText('Saldo')).toBeTruthy()
    expect(screen.getByText('Kontakt')).toBeTruthy()
    expect(screen.getByText('Rollen & Status')).toBeTruthy()
    expect(screen.getByText('Organisationen')).toBeTruthy()
    expect(screen.getByText('Tags')).toBeTruthy()
    expect(screen.getByText('Wichtige Daten')).toBeTruthy()
    expect(screen.getByText('PADI')).toBeTruthy()  // role-gated: instructor sidecar present
    expect(screen.getByText('Quelle & Audit')).toBeTruthy()
  })

  it('shows loading skeleton initially', () => {
    render(<PropertiesSidebar contactId="c1" />, { wrapper })
    expect(screen.getByText(/Lade Properties/i)).toBeTruthy()
  })

  it('omits PADI stub when no instructor + no student sidecar', async () => {
    // Override mock to return an org-only contact for the next `contacts`-call.
    const { supabase } = await import('@/lib/supabase')
    const orgContact = {
      id: 'c2', kind: 'organization', display_name: 'TSK Zürich',
      first_name: null, last_name: null, birth_date: null,
      primary_email: null, phones: [], languages: [], 
      source: null, created_at: '2026-01-01', updated_at: '2026-01-01', owner_id: null,
      tags: [],
      instructor: null, student: null,
      organization: { org_kind: 'dive_shop' },
    }
    const single = vi.fn().mockResolvedValue({ data: orgContact, error: null })
    const eqContacts = vi.fn().mockReturnValue({ single })
    const selectContacts = vi.fn().mockReturnValue({ eq: eqContacts })
    // Balance-query bleibt mit dem default-mock (maybeSingle → null).
    const maybeSingle = vi.fn().mockResolvedValue({ data: null, error: null })
    const eqBalance = vi.fn().mockReturnValue({ maybeSingle })
    const selectBalance = vi.fn().mockReturnValue({ eq: eqBalance })
    vi.mocked(supabase.from).mockImplementationOnce((t: string) =>
      (t === 'v_contact_balance' ? { select: selectBalance } : { select: selectContacts }) as never,
    )
    vi.mocked(supabase.from).mockImplementationOnce((t: string) =>
      (t === 'v_contact_balance' ? { select: selectBalance } : { select: selectContacts }) as never,
    )

    const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } })
    render(
      <QueryClientProvider client={qc}>
        <PropertiesSidebar contactId="c2" />
      </QueryClientProvider>
    )
    await waitFor(() => expect(screen.getByText('TSK Zürich')).toBeTruthy())
    expect(screen.queryByText('PADI')).toBeNull()
  })
})
