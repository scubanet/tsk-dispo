import { describe, it, expect, vi } from 'vitest'
import { render, screen, waitFor } from '@testing-library/react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { PropertiesSidebar } from '../PropertiesSidebar'

vi.mock('@/lib/supabase', () => {
  const baseContact = {
    id: 'c1',
    kind: 'person',
    display_name: 'Hugo Eugster',
    first_name: 'Hugo',
    last_name: 'Eugster',
    birth_date: null,
    primary_email: 'hugo@test.com',
    primary_phone: null,
    primary_language: 'de',
    source: 'manual',
    created_at: '2026-01-01T00:00:00Z',
    updated_at: '2026-05-27T00:00:00Z',
    owner_id: null,
    instructor: { padi_level: 'OWSI', padi_pro_number: null, member_status: 'active', active: true },
    student: null,
    organization: null,
    balance: null,
  }
  const single = vi.fn().mockResolvedValue({ data: baseContact, error: null })
  const eq = vi.fn().mockReturnValue({ single })
  const select = vi.fn().mockReturnValue({ eq })
  return { supabase: { from: vi.fn().mockReturnValue({ select }) } }
})

function wrapper({ children }: { children: React.ReactNode }) {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } })
  return <QueryClientProvider client={qc}>{children}</QueryClientProvider>
}

describe('PropertiesSidebar', () => {
  it('renders display name + 6 always-on stubs + PADI stub (when instructor sidecar present)', async () => {
    render(<PropertiesSidebar contactId="c1" />, { wrapper })
    await waitFor(() => expect(screen.getByText('Hugo Eugster')).toBeTruthy())
    expect(screen.getByTestId('stat-band-stub')).toBeTruthy()
    expect(screen.getByText('Kontakt')).toBeTruthy()
    expect(screen.getByText('Rollen & Status')).toBeTruthy()
    expect(screen.getByText('Organisationen')).toBeTruthy()
    expect(screen.getByText('Tags')).toBeTruthy()
    expect(screen.getByTestId('section-stub-keydates')).toBeTruthy()
    expect(screen.getByTestId('section-stub-padi')).toBeTruthy()  // role-gated: instructor sidecar present
    expect(screen.getByTestId('section-stub-audit')).toBeTruthy()
  })

  it('shows loading skeleton initially', () => {
    render(<PropertiesSidebar contactId="c1" />, { wrapper })
    expect(screen.getByText(/Lade Properties/i)).toBeTruthy()
  })

  it('omits PADI stub when no instructor + no student sidecar', async () => {
    // Override mock to return a contact with no instructor/student sidecars (org only)
    const { supabase } = await import('@/lib/supabase')
    const orgContact = {
      id: 'c2', kind: 'organization', display_name: 'TSK Zürich',
      first_name: null, last_name: null, birth_date: null,
      primary_email: null, primary_phone: null, primary_language: null,
      source: null, created_at: '2026-01-01', updated_at: '2026-01-01', owner_id: null,
      instructor: null, student: null,
      organization: { legal_name: 'TSK', trading_name: null, category: 'dive_shop' },
      balance: null,
    }
    const single = vi.fn().mockResolvedValue({ data: orgContact, error: null })
    const eq = vi.fn().mockReturnValue({ single })
    const select = vi.fn().mockReturnValue({ eq })
    vi.mocked(supabase.from).mockReturnValueOnce({ select } as never)

    const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } })
    render(
      <QueryClientProvider client={qc}>
        <PropertiesSidebar contactId="c2" />
      </QueryClientProvider>
    )
    await waitFor(() => expect(screen.getByText('TSK Zürich')).toBeTruthy())
    expect(screen.queryByTestId('section-stub-padi')).toBeNull()
  })
})
