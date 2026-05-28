// apps/web/src/hooks/__tests__/useContactWithProperties.test.tsx
import { describe, it, expect, vi } from 'vitest'
import { renderHook, waitFor } from '@testing-library/react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { useContactWithProperties } from '../useContactWithProperties'

vi.mock('@/lib/supabase', () => {
  // Two separate queries now: 'contacts' (single) and 'v_contact_balance' (maybeSingle).
  // We dispatch on the table-name in `from()` so each builder returns the right shape.
  const contactsResult = {
    data: {
      id: 'c1',
      kind: 'person',
      display_name: 'Hugo Eugster',
      first_name: 'Hugo',
      last_name: 'Eugster',
      birth_date: '1990-01-15',
      primary_email: 'hugo@example.com',
      phones: [{ label: 'mobile', e164: '+41791234567', primary: true }],
      languages: ['de'],
      source: 'manual',
      created_at: '2026-01-01T00:00:00Z',
      updated_at: '2026-05-27T00:00:00Z',
      owner_id: null,
      tags: [],
      instructor: {
        padi_level: 'OWSI',
        padi_pro_number: '123456',
        active: true,
      },
      student: null,
      organization: null,
    },
    error: null,
  }
  const balanceResult = {
    data: { balance_chf: 1250.50, last_movement_date: '2026-05-20' },
    error: null,
  }

  function contactsBuilder() {
    const single = vi.fn().mockResolvedValue(contactsResult)
    const eq = vi.fn().mockReturnValue({ single })
    const select = vi.fn().mockReturnValue({ eq })
    return { select }
  }
  function balanceBuilder() {
    const maybeSingle = vi.fn().mockResolvedValue(balanceResult)
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

describe('useContactWithProperties', () => {
  it('loads contact with sidecars and derives roles', async () => {
    const { result } = renderHook(() => useContactWithProperties('c1'), { wrapper })
    await waitFor(() => expect(result.current.isSuccess).toBe(true))
    expect(result.current.data?.display_name).toBe('Hugo Eugster')
    expect(result.current.data?.instructor?.padi_level).toBe('OWSI')
    expect(result.current.data?.student).toBeNull()
    expect(result.current.data?.organization).toBeNull()
    expect(result.current.data?.roles).toEqual(['instructor'])
  })

  it('exposes balance_chf and last_movement_date at top level', async () => {
    const { result } = renderHook(() => useContactWithProperties('c1'), { wrapper })
    await waitFor(() => expect(result.current.isSuccess).toBe(true))
    expect(result.current.data?.balance_chf).toBe(1250.50)
    expect(result.current.data?.last_movement_date).toBe('2026-05-20')
  })

  it('is disabled when contactId is empty string', () => {
    const { result } = renderHook(() => useContactWithProperties(''), { wrapper })
    expect(result.current.fetchStatus).toBe('idle')
  })
})
