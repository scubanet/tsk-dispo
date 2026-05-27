// apps/web/src/screens/contacts/timeline/__tests__/TimelineFeed.test.tsx
import { describe, it, expect, vi } from 'vitest'
import { render, screen, waitFor } from '@testing-library/react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { TimelineFeed } from '../TimelineFeed'

vi.mock('@/lib/supabase', () => {
  const builder: Record<string, unknown> = {}
  const limit = vi.fn().mockReturnValue(builder)
  const order2 = vi.fn().mockReturnValue(builder)
  const order1 = vi.fn().mockReturnValue({ order: order2 })
  const eq = vi.fn().mockReturnValue({ order: order1 })
  builder.in = vi.fn().mockReturnValue(builder)
  builder.gte = vi.fn().mockReturnValue(builder)
  builder.lte = vi.fn().mockReturnValue(builder)
  builder.or = vi.fn().mockReturnValue(builder)
  builder.limit = limit
  // Default: 2 rows
  builder.then = (resolve: (v: { data: unknown; error: null }) => unknown) => resolve({
    data: [
      { event_id: 'a', contact_id: 'c1', event_type: 'note', occurred_at: '2026-05-01', summary: 'one', source_table: 'contact_events', actor_contact_id: null, body: null, payload: null, status: 'open', source_id: 'a' },
      { event_id: 'b', contact_id: 'c1', event_type: 'call', occurred_at: '2026-04-01', summary: 'two', source_table: 'contact_events', actor_contact_id: null, body: null, payload: null, status: 'open', source_id: 'b' },
    ],
    error: null,
  })
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

  it('renders composer stub and filter bar', async () => {
    render(<TimelineFeed contactId="c1" />, { wrapper })
    expect(screen.getByTestId('event-composer-stub')).toBeTruthy()
    expect(screen.getByText('Alle')).toBeTruthy()
  })
})
