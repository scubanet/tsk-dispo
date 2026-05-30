import { describe, it, expect, vi } from 'vitest'
import { renderHook, waitFor, act } from '@testing-library/react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { createElement, type ReactNode } from 'react'
import { useSendMessage } from '../useSendMessage'

const invoke = vi.fn().mockResolvedValue({ data: { ok: true, provider_message_id: 'm1' }, error: null })
vi.mock('@/lib/supabase', () => ({ supabase: { functions: { invoke: (...a: unknown[]) => invoke(...a) } } }))

function wrapper({ children }: { children: ReactNode }) {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false }, mutations: { retry: false } } })
  return createElement(QueryClientProvider, { client: qc }, children)
}

describe('useSendMessage', () => {
  it('ruft comms-outbound mit dem Input', async () => {
    const { result } = renderHook(() => useSendMessage('c1'), { wrapper })
    await act(async () => {
      await result.current.mutateAsync({ contact_id: 'c1', channel: 'email', body: 'Hi', subject: 'S' })
    })
    await waitFor(() => expect(invoke).toHaveBeenCalledWith('comms-outbound',
      { body: { contact_id: 'c1', channel: 'email', body: 'Hi', subject: 'S' } }))
  })
})
