import { describe, it, expect, vi } from 'vitest'
import { render, screen, waitFor } from '@testing-library/react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { MemoryRouter } from 'react-router-dom'
import { ContactDetailPanelV2 } from '../ContactDetailPanelV2'

// Mock Supabase: returns contact summary + empty timeline
vi.mock('@/lib/supabase', () => {
  // Contact summary fetch:
  const singleContact = vi.fn().mockResolvedValue({
    data: { id: 'c1', display_name: 'Hugo Eugster' },
    error: null,
  })
  // Timeline fetch:
  const builder: Record<string, unknown> = {}
  const limit = vi.fn().mockReturnValue(builder)
  const order2 = vi.fn().mockReturnValue(builder)
  const order1 = vi.fn().mockReturnValue({ order: order2 })
  builder.in = vi.fn().mockReturnValue(builder)
  builder.gte = vi.fn().mockReturnValue(builder)
  builder.lte = vi.fn().mockReturnValue(builder)
  builder.or = vi.fn().mockReturnValue(builder)
  builder.limit = limit
  builder.then = (resolve: (v: { data: unknown; error: null }) => unknown) => resolve({ data: [], error: null })

  const fromMock = vi.fn().mockImplementation((table: string) => {
    if (table === 'contacts') {
      return {
        select: vi.fn().mockReturnValue({
          eq: vi.fn().mockReturnValue({ single: singleContact }),
        }),
      }
    }
    // Default: timeline-View
    return {
      select: vi.fn().mockReturnValue({
        eq: vi.fn().mockReturnValue({ order: order1 }),
      }),
    }
  })
  return { supabase: { from: fromMock } }
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
  it('renders 3-pane shell with header + timeline + sidebar slot', async () => {
    render(<ContactDetailPanelV2 contactId="c1" onClose={vi.fn()} />, { wrapper })
    // Header has the close button
    await waitFor(() => expect(screen.queryByLabelText(/Schliessen/i)).toBeTruthy())
    // Timeline shell appears (composer segmented control button visible).
    // EventComposer + TimelineFilterBar both expose a 'Notiz' button — both count as "shell rendered".
    expect(screen.getAllByRole('button', { name: 'Notiz' }).length).toBeGreaterThanOrEqual(1)
    // Sidebar placeholder
    expect(screen.getByTestId('properties-sidebar-placeholder')).toBeTruthy()
  })
})
