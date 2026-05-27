// apps/web/src/hooks/__tests__/useContactTimeline.test.tsx
import { describe, it, expect, vi, beforeEach } from 'vitest'
import { renderHook, waitFor } from '@testing-library/react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { useContactTimeline } from '../useContactTimeline'

// Shared chain-spies so individual tests can assert against them.
// Use vi.hoisted so the chain object exists before vi.mock factory runs.
const { chain, resetChain } = vi.hoisted(() => {
  const chain = {
    in:   vi.fn(),
    gte:  vi.fn(),
    lte:  vi.fn(),
    or:   vi.fn(),
  }

  function resetChain(rows: unknown[] = []) {
    // The query builder is a thenable — await q resolves to { data, error },
    // but it's also chainable via .or/.in/.gte/.lte before that.
    // Each call returns the same builder so chains accumulate.
    const result = { data: rows, error: null }
    const builder: Record<string, unknown> = {}
    chain.lte = vi.fn().mockReturnValue(builder)
    chain.gte = vi.fn().mockReturnValue(builder)
    chain.in  = vi.fn().mockReturnValue(builder)
    chain.or  = vi.fn().mockReturnValue(builder)
    const limit = vi.fn().mockReturnValue(builder)
    builder.in   = chain.in
    builder.gte  = chain.gte
    builder.lte  = chain.lte
    builder.or   = chain.or
    builder.limit = limit
    builder.then = (resolve: (v: typeof result) => unknown) => resolve(result)
    const order2 = vi.fn().mockReturnValue(builder)
    const order1 = vi.fn().mockReturnValue({ order: order2 })
    const eq = vi.fn().mockReturnValue({ order: order1 })
    const select = vi.fn().mockReturnValue({ eq })
    return { from: vi.fn().mockReturnValue({ select }) }
  }

  return { chain, resetChain }
})

vi.mock('@/lib/supabase', () => {
  return {
    supabase: resetChain([
      { event_id: 'a', contact_id: 'c1', event_type: 'note', occurred_at: '2026-05-01', summary: 'one', source_table: 'contact_events' },
    ]),
  }
})

import { supabase } from '@/lib/supabase'

function wrapper({ children }: { children: React.ReactNode }) {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } })
  return <QueryClientProvider client={qc}>{children}</QueryClientProvider>
}

describe('useContactTimeline', () => {
  beforeEach(() => {
    // Default: 1-row page. Individual tests override.
    const rebuilt = resetChain([
      { event_id: 'a', contact_id: 'c1', event_type: 'note', occurred_at: '2026-05-01', summary: 'one', source_table: 'contact_events' },
    ])
    vi.mocked(supabase.from).mockImplementation(rebuilt.from)
  })

  it('fetches events for a contact ordered by occurred_at desc', async () => {
    const { result } = renderHook(() => useContactTimeline('c1'), { wrapper })
    await waitFor(() => expect(result.current.isSuccess).toBe(true))
    expect(result.current.data?.pages[0].length).toBe(1)
    expect(result.current.data?.pages[0][0].summary).toBe('one')
  })

  it('advances cursor on fetchNextPage when page is full', async () => {
    // 50 mock rows (PAGE_SIZE) — sorted DESC by occurred_at
    const fullPage = Array.from({ length: 50 }, (_, i) => ({
      event_id:     `ev-${50 - i}`,
      contact_id:   'c1',
      event_type:   'note',
      occurred_at:  `2026-05-${String(50 - i).padStart(2, '0')}`,
      summary:      `event ${50 - i}`,
      source_table: 'contact_events',
    }))
    const rebuilt = resetChain(fullPage)
    vi.mocked(supabase.from).mockImplementation(rebuilt.from)

    const { result } = renderHook(() => useContactTimeline('c1'), { wrapper })
    await waitFor(() => expect(result.current.isSuccess).toBe(true))
    expect(result.current.hasNextPage).toBe(true)

    await result.current.fetchNextPage()
    await waitFor(() => expect(result.current.isFetchingNextPage).toBe(false))

    // Cursor: .or() was called EXACTLY ONCE with the last row's (occurred_at,
    // event_id) packed into a single composite string. Asserting both substrings
    // on the SAME call (not two separate calls) — sonst würde ein Refactor das
    // den cursor in zwei .or()-Calls aufsplittet (was Supabase AND-en würde,
    // nicht OR-en) den Test trotzdem grün durchlaufen.
    // Last row in DESC sort is the smallest — ev-1, 2026-05-01.
    expect(chain.or).toHaveBeenCalledTimes(1)
    const orArg = chain.or.mock.calls[0][0] as string
    expect(orArg).toContain('occurred_at.lt.2026-05-01')
    expect(orArg).toContain('event_id.lt.ev-1')
  })
})
