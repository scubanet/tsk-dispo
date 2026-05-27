// apps/web/src/hooks/__tests__/useContactFieldMutation.test.tsx
import { describe, it, expect, vi } from 'vitest'
import { renderHook } from '@testing-library/react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { useContactFieldMutation } from '../useContactFieldMutation'

vi.mock('@/lib/supabase', () => {
  const eq = vi.fn().mockResolvedValue({ error: null })
  const update = vi.fn().mockReturnValue({ eq })
  return {
    supabase: {
      from: vi.fn().mockReturnValue({ update }),
    },
  }
})

import { supabase } from '@/lib/supabase'

function wrapper({ children }: { children: React.ReactNode }) {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } })
  return <QueryClientProvider client={qc}>{children}</QueryClientProvider>
}

describe('useContactFieldMutation', () => {
  it('updates contacts.primary_email via WHERE id = contactId', async () => {
    const { result } = renderHook(() => useContactFieldMutation('c1'), { wrapper })
    await result.current.mutateAsync({
      table: 'contacts',
      field: 'primary_email',
      value: 'new@test.com',
    })
    expect(supabase.from).toHaveBeenCalledWith('contacts')
    const update = vi.mocked(supabase.from).mock.results[0].value.update
    expect(update).toHaveBeenCalledWith({ primary_email: 'new@test.com' })
    const eq = update.mock.results[0].value.eq
    expect(eq).toHaveBeenCalledWith('id', 'c1')
  })

  it('updates contact_instructor.padi_level via WHERE contact_id = contactId', async () => {
    vi.clearAllMocks()
    const { result } = renderHook(() => useContactFieldMutation('c1'), { wrapper })
    await result.current.mutateAsync({
      table: 'contact_instructor',
      field: 'padi_level',
      value: 'OWSI',
    })
    expect(supabase.from).toHaveBeenCalledWith('contact_instructor')
    const update = vi.mocked(supabase.from).mock.results[0].value.update
    const eq = update.mock.results[0].value.eq
    expect(eq).toHaveBeenCalledWith('contact_id', 'c1')
  })

  it('throws on supabase error', async () => {
    vi.clearAllMocks()
    const eq = vi.fn().mockResolvedValue({ error: { message: 'RLS denied' } })
    const update = vi.fn().mockReturnValue({ eq })
    vi.mocked(supabase.from).mockReturnValue({ update } as never)

    const { result } = renderHook(() => useContactFieldMutation('c1'), { wrapper })
    await expect(
      result.current.mutateAsync({ table: 'contacts', field: 'primary_email', value: 'x' })
    ).rejects.toThrow('RLS denied')
  })
})
