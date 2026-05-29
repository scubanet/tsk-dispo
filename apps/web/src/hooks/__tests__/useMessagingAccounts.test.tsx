import { describe, it, expect, vi, beforeEach } from 'vitest'
import { renderHook, waitFor } from '@testing-library/react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { createElement, type ReactNode } from 'react'
import { useMessagingAccounts } from '../useMessagingAccounts'

const rows = [{ id: 'a1', channel: 'email', unipile_account_id: 'u1', provider: 'gmail',
  label: 'lena@gmail.com', owner_user_id: 'me', status: 'connected', connected_at: 'x', last_event_at: null }]

vi.mock('@/lib/supabase', () => ({
  supabase: { from: () => ({ select: () => ({ order: () => Promise.resolve({ data: rows, error: null }) }) }) },
}))

function wrapper({ children }: { children: ReactNode }) {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } })
  return createElement(QueryClientProvider, { client: qc }, children)
}

describe('useMessagingAccounts', () => {
  beforeEach(() => vi.clearAllMocks())
  it('lädt verbundene Konten', async () => {
    const { result } = renderHook(() => useMessagingAccounts(), { wrapper })
    await waitFor(() => expect(result.current.data).toHaveLength(1))
    expect(result.current.data![0].label).toBe('lena@gmail.com')
  })
})
