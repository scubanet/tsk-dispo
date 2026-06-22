// Regression test: creating/editing a student must refresh the course
// enroll-picker lists. Those live in the ['students'] / ['candidates'] cache
// namespaces (useEnrollStudent), separate from ['contacts'] — so without
// invalidating them, a newly created student only appeared after a full reload.
import { describe, it, expect, vi } from 'vitest'
import { renderHook, waitFor } from '@testing-library/react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { useUpsertStudent } from '../useStudentEdit'

vi.mock('@/lib/contactQueries', () => ({
  fetchOrganizations: vi.fn().mockResolvedValue([]),
  upsertStudent: vi.fn().mockResolvedValue('new-id'),
  deleteContact: vi.fn().mockResolvedValue(undefined),
}))

describe('useUpsertStudent cache invalidation', () => {
  it('invalidates the enroll-picker students + candidates caches', async () => {
    const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } })
    const spy = vi.spyOn(qc, 'invalidateQueries')
    const wrapper = ({ children }: { children: React.ReactNode }) => (
      <QueryClientProvider client={qc}>{children}</QueryClientProvider>
    )
    const { result } = renderHook(() => useUpsertStudent(), { wrapper })

    await result.current.mutateAsync({
      contactId: null,
      contact: {} as never,
      student: {} as never,
      orgId: null,
    })

    await waitFor(() => {
      const keys = spy.mock.calls.map((c) =>
        JSON.stringify((c[0] as { queryKey: unknown }).queryKey),
      )
      expect(keys).toContain(JSON.stringify(['students']))
      expect(keys).toContain(JSON.stringify(['candidates']))
    })
  })
})
