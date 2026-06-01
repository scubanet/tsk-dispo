// apps/web/src/hooks/__tests__/useContactTimelineRealtime.test.tsx
import { describe, it, expect, vi, beforeEach } from 'vitest'
import { renderHook } from '@testing-library/react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import type { ReactNode } from 'react'

// Realtime-Kanal stubben + die postgres_changes-Handler einfangen.
const h = vi.hoisted(() => {
  const handlers: Array<(p: unknown) => void> = []
  const on = vi.fn()
  const subscribe = vi.fn()
  const channelStub: Record<string, unknown> = { on, subscribe }
  on.mockImplementation((_evt: string, _opts: unknown, cb: (p: unknown) => void) => {
    if (typeof cb === 'function') handlers.push(cb)
    return channelStub
  })
  subscribe.mockImplementation(() => channelStub)
  const channel = vi.fn(() => channelStub)
  const removeChannel = vi.fn()
  return { handlers, on, subscribe, channel, removeChannel }
})

vi.mock('@/lib/supabase', () => ({
  supabase: { channel: h.channel, removeChannel: h.removeChannel },
}))

import { useContactTimelineRealtime } from '../useContactTimelineRealtime'

function makeWrapper(qc: QueryClient) {
  return function Wrapper({ children }: { children: ReactNode }) {
    return <QueryClientProvider client={qc}>{children}</QueryClientProvider>
  }
}

describe('useContactTimelineRealtime', () => {
  beforeEach(() => {
    h.handlers.length = 0
    h.channel.mockClear()
    h.removeChannel.mockClear()
    h.on.mockClear()
    h.subscribe.mockClear()
  })

  it('abonniert contact_events und invalidiert die Timeline bei einem Event', () => {
    const qc = new QueryClient()
    const spy = vi.spyOn(qc, 'invalidateQueries')
    const { unmount } = renderHook(() => useContactTimelineRealtime('c1'), { wrapper: makeWrapper(qc) })

    expect(h.channel).toHaveBeenCalledWith('contact_events:c1')
    expect(h.subscribe).toHaveBeenCalled()
    expect(h.handlers.length).toBeGreaterThanOrEqual(1)

    // Eingehendes Event simulieren → Timeline-Query wird invalidiert.
    h.handlers[0]({})
    expect(spy).toHaveBeenCalledWith({ queryKey: ['contact-timeline', 'c1'] })

    unmount()
    expect(h.removeChannel).toHaveBeenCalled()
  })

  it('abonniert nicht ohne contactId', () => {
    const qc = new QueryClient()
    renderHook(() => useContactTimelineRealtime(''), { wrapper: makeWrapper(qc) })
    expect(h.channel).not.toHaveBeenCalled()
  })
})
