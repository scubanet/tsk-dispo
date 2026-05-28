// apps/web/src/hooks/__tests__/useBulkContactMutation.test.tsx
//
// Phase G Phase 4 Task 7 — Tests für useBulkContactMutation.
import { describe, it, expect, vi, beforeEach } from 'vitest'
import { renderHook, waitFor } from '@testing-library/react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { useBulkContactMutation } from '../useBulkContactMutation'

// ── Supabase-mock builder ───────────────────────────────────────────────
// Wir bauen ein chainable mock-objekt: from(...).update(...).in(...) → resolves.
// Bei `add_tags` brauchen wir zusätzlich select(...).in(...) → resolves mit rows.

type Row = { id: string; tags: string[] | null }

interface MockState {
  selectRows: Row[]
  selectError: { message: string } | null
  updateError: { message: string } | null
  // calls log
  fromCalls: string[]
  updateCalls: Array<{ table: string; payload: Record<string, unknown> }>
  inCalls: Array<{ col: string; values: string[] }>
  eqCalls: Array<{ col: string; value: string }>
}

const state: MockState = {
  selectRows: [],
  selectError: null,
  updateError: null,
  fromCalls: [],
  updateCalls: [],
  inCalls: [],
  eqCalls: [],
}

vi.mock('@/lib/supabase', () => {
  function from(table: string) {
    state.fromCalls.push(table)
    let pendingPayload: Record<string, unknown> | null = null
    const api = {
      select: (_cols: string) => ({
        in: (col: string, values: string[]) => {
          state.inCalls.push({ col, values })
          return Promise.resolve({
            data: state.selectError ? null : state.selectRows,
            error: state.selectError,
          })
        },
      }),
      update: (payload: Record<string, unknown>) => {
        pendingPayload = payload
        state.updateCalls.push({ table, payload })
        return {
          in: (col: string, values: string[]) => {
            state.inCalls.push({ col, values })
            return Promise.resolve({ error: state.updateError })
          },
          eq: (col: string, value: string) => {
            state.eqCalls.push({ col, value })
            return Promise.resolve({ error: state.updateError })
          },
        }
      },
    }
    // referenced by TypeScript noUnused — guard
    void pendingPayload
    return api
  }
  return { supabase: { from } }
})

function wrapper({ children }: { children: React.ReactNode }) {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } })
  return <QueryClientProvider client={qc}>{children}</QueryClientProvider>
}

function resetState() {
  state.selectRows = []
  state.selectError = null
  state.updateError = null
  state.fromCalls = []
  state.updateCalls = []
  state.inCalls = []
  state.eqCalls = []
}

describe('useBulkContactMutation', () => {
  beforeEach(() => {
    resetState()
  })

  it('add_tags: selects existing tags then updates each contact with merged set', async () => {
    state.selectRows = [
      { id: 'c1', tags: ['vip'] },
      { id: 'c2', tags: null },
    ]
    const { result } = renderHook(() => useBulkContactMutation(), { wrapper })
    await result.current.mutateAsync({
      type: 'add_tags',
      ids: ['c1', 'c2'],
      tags: ['lead'],
    })
    // 1 SELECT + 2 UPDATEs auf contacts
    expect(state.fromCalls.filter((t) => t === 'contacts').length).toBe(3)
    expect(state.updateCalls).toEqual([
      { table: 'contacts', payload: { tags: ['vip', 'lead'] } },
      { table: 'contacts', payload: { tags: ['lead'] } },
    ])
    // Per-id .eq Aufrufe
    expect(state.eqCalls).toEqual([
      { col: 'id', value: 'c1' },
      { col: 'id', value: 'c2' },
    ])
  })

  it('set_pipeline_stage: updates contact_student.in(ids)', async () => {
    const { result } = renderHook(() => useBulkContactMutation(), { wrapper })
    await result.current.mutateAsync({
      type: 'set_pipeline_stage',
      ids: ['c1', 'c2'],
      stage: 'qualified',
    })
    expect(state.fromCalls).toEqual(['contact_student'])
    expect(state.updateCalls).toEqual([
      { table: 'contact_student', payload: { pipeline_stage: 'qualified' } },
    ])
    expect(state.inCalls).toEqual([{ col: 'contact_id', values: ['c1', 'c2'] }])
  })

  it('archive: sets archived_at on contacts.in(ids)', async () => {
    const { result } = renderHook(() => useBulkContactMutation(), { wrapper })
    await result.current.mutateAsync({ type: 'archive', ids: ['c1'] })
    expect(state.fromCalls).toEqual(['contacts'])
    expect(state.updateCalls.length).toBe(1)
    const payload = state.updateCalls[0].payload
    expect(typeof payload.archived_at).toBe('string')
    expect(state.inCalls).toEqual([{ col: 'id', values: ['c1'] }])
  })

  it('set_active: updates contact_instructor.active', async () => {
    const { result } = renderHook(() => useBulkContactMutation(), { wrapper })
    await result.current.mutateAsync({
      type: 'set_active',
      ids: ['c1', 'c2'],
      active: false,
    })
    expect(state.fromCalls).toEqual(['contact_instructor'])
    expect(state.updateCalls).toEqual([
      { table: 'contact_instructor', payload: { active: false } },
    ])
    expect(state.inCalls).toEqual([{ col: 'contact_id', values: ['c1', 'c2'] }])
  })

  it('invalidates ["contacts"] on success', async () => {
    const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } })
    const spy = vi.spyOn(qc, 'invalidateQueries')
    const localWrapper = ({ children }: { children: React.ReactNode }) => (
      <QueryClientProvider client={qc}>{children}</QueryClientProvider>
    )
    const { result } = renderHook(() => useBulkContactMutation(), {
      wrapper: localWrapper,
    })
    await result.current.mutateAsync({ type: 'archive', ids: ['c1'] })
    await waitFor(() => {
      expect(spy).toHaveBeenCalledWith({ queryKey: ['contacts'] })
    })
  })
})
