// apps/web/src/hooks/__tests__/useContactTimeline.test.tsx
import { describe, it, expect, vi } from 'vitest'
import { renderHook, waitFor } from '@testing-library/react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { useContactTimeline } from '../useContactTimeline'

vi.mock('@/lib/supabase', () => {
  const limit = vi.fn().mockResolvedValue({
    data: [
      { event_id: 'a', contact_id: 'c1', event_type: 'note', occurred_at: '2026-05-01', summary: 'one', source_table: 'contact_events' },
    ],
    error: null,
  })
  const order2 = vi.fn().mockReturnValue({ limit })
  const order1 = vi.fn().mockReturnValue({ order: order2 })
  const eq = vi.fn().mockReturnValue({ order: order1 })
  const select = vi.fn().mockReturnValue({ eq })
  const from = vi.fn().mockReturnValue({ select })
  return { supabase: { from } }
})

function wrapper({ children }: { children: React.ReactNode }) {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } })
  return <QueryClientProvider client={qc}>{children}</QueryClientProvider>
}

describe('useContactTimeline', () => {
  it('fetches events for a contact ordered by occurred_at desc', async () => {
    const { result } = renderHook(() => useContactTimeline('c1'), { wrapper })
    await waitFor(() => expect(result.current.isSuccess).toBe(true))
    expect(result.current.data?.pages[0].length).toBe(1)
    expect(result.current.data?.pages[0][0].summary).toBe('one')
  })
})
