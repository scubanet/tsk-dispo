// apps/web/src/screens/contacts/timeline/__tests__/TimelineFeed.test.tsx
import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, screen, waitFor } from '@testing-library/react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { MemoryRouter } from 'react-router-dom'
import type { ReactNode } from 'react'
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
  // Realtime-Stub (useContactTimelineRealtime abonniert beim Mount).
  const channelStub: Record<string, unknown> = {}
  channelStub.on = vi.fn().mockReturnValue(channelStub)
  channelStub.subscribe = vi.fn().mockReturnValue(channelStub)
  return {
    supabase: {
      from: vi.fn().mockReturnValue({ select }),
      channel: vi.fn().mockReturnValue(channelStub),
      removeChannel: vi.fn(),
    },
  }
})

function makeWrapper(initialEntries: string[] = ['/']) {
  return function Wrapper({ children }: { children: ReactNode }) {
    const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } })
    return (
      <MemoryRouter initialEntries={initialEntries}>
        <QueryClientProvider client={qc}>{children}</QueryClientProvider>
      </MemoryRouter>
    )
  }
}

describe('TimelineFeed', () => {
  it('renders events from useContactTimeline', async () => {
    render(<TimelineFeed contactId="c1" />, { wrapper: makeWrapper() })
    await waitFor(() => expect(screen.getByText('one')).toBeTruthy())
    expect(screen.getByText('two')).toBeTruthy()
  })

  it('shows skeleton while loading', () => {
    render(<TimelineFeed contactId="c1" />, { wrapper: makeWrapper() })
    expect(screen.getByText(/Lade Timeline/i)).toBeTruthy()
  })

  it('renders composer and filter bar', async () => {
    render(<TimelineFeed contactId="c1" />, { wrapper: makeWrapper() })
    // EventComposer segmented control button + TimelineFilterBar both expose 'Notiz' buttons
    expect(screen.getAllByRole('button', { name: 'Notiz' }).length).toBeGreaterThanOrEqual(1)
    expect(screen.getByText('Alle')).toBeTruthy()
  })

  // ── Phase G Phase 5 Task 6 — Event-Highlighting via ?event=<id> ──────
  describe('event highlighting via ?event=<id>', () => {
    beforeEach(() => {
      // happy-dom hat scrollIntoView nicht implementiert — wir mocken global.
      if (!Element.prototype.scrollIntoView) {
        Element.prototype.scrollIntoView = vi.fn()
      }
    })

    it('highlighted die Card mit matchender event_id und nur diese', async () => {
      render(<TimelineFeed contactId="c1" />, {
        wrapper: makeWrapper(['/contacts?contact=c1&event=a']),
      })
      await waitFor(() => expect(screen.getByText('one')).toBeTruthy())

      const cardA = document.querySelector('article[data-event-id="a"]')
      const cardB = document.querySelector('article[data-event-id="b"]')
      expect(cardA?.getAttribute('data-event-highlighted')).toBe('true')
      expect(cardB?.hasAttribute('data-event-highlighted')).toBe(false)
    })

    it('keine Card highlighted wenn ?event=<id> fehlt', async () => {
      render(<TimelineFeed contactId="c1" />, {
        wrapper: makeWrapper(['/contacts?contact=c1']),
      })
      await waitFor(() => expect(screen.getByText('one')).toBeTruthy())

      const highlighted = document.querySelector('article[data-event-highlighted="true"]')
      expect(highlighted).toBeNull()
    })

    it('ruft scrollIntoView auf der gehighlighteten Card', async () => {
      const scrollSpy = vi.fn()
      Element.prototype.scrollIntoView = scrollSpy

      render(<TimelineFeed contactId="c1" />, {
        wrapper: makeWrapper(['/contacts?contact=c1&event=b']),
      })
      await waitFor(() => expect(screen.getByText('two')).toBeTruthy())
      await waitFor(() => expect(scrollSpy).toHaveBeenCalled())
      // Smooth-scroll + block:center sind die spezifizierten Options.
      expect(scrollSpy).toHaveBeenCalledWith({ behavior: 'smooth', block: 'center' })
    })
  })
})
