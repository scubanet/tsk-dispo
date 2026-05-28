// apps/web/src/lib/__tests__/contactQueries.test.ts
//
// Phase G Phase 4 T0 — covers the multi-sort + filter-extension surface of
// listContacts. Mocks supabase with a thenable chainable builder so each
// query-method call is recorded as a vi.fn() invocation.

import { describe, it, expect, vi, beforeEach } from 'vitest'
import { listContacts } from '../contactQueries'

// ─────────────────────────────────────────────────────────────────────
// Chainable builder mock
// ─────────────────────────────────────────────────────────────────────

interface BuilderRecord {
  select: ReturnType<typeof vi.fn>
  is: ReturnType<typeof vi.fn>
  not: ReturnType<typeof vi.fn>
  eq: ReturnType<typeof vi.fn>
  overlaps: ReturnType<typeof vi.fn>
  in: ReturnType<typeof vi.fn>
  gt: ReturnType<typeof vi.fn>
  lt: ReturnType<typeof vi.fn>
  or: ReturnType<typeof vi.fn>
  range: ReturnType<typeof vi.fn>
  order: ReturnType<typeof vi.fn>
  /** then-handler used by `await query` — resolves the builder. */
  then: ReturnType<typeof vi.fn>
}

/** Builds one chainable thenable. Every query-builder method returns `self`. */
function makeBuilder(result: { data: unknown[]; error: unknown; count: number }): BuilderRecord {
  const self = {} as BuilderRecord
  // Each method gets its own vi.fn so call-counts stay independent.
  self.select = vi.fn(() => self)
  self.is = vi.fn(() => self)
  self.not = vi.fn(() => self)
  self.eq = vi.fn(() => self)
  self.overlaps = vi.fn(() => self)
  self.in = vi.fn(() => self)
  self.gt = vi.fn(() => self)
  self.lt = vi.fn(() => self)
  self.or = vi.fn(() => self)
  self.range = vi.fn(() => self)
  self.order = vi.fn(() => self)
  // `await query` calls .then(resolve) on the builder.
  self.then = vi.fn((resolve: (v: unknown) => unknown) => Promise.resolve(resolve(result)))
  return self
}

let builder: BuilderRecord

vi.mock('@/lib/supabase', () => ({
  supabase: {
    from: vi.fn(() => builder),
  },
}))

beforeEach(() => {
  builder = makeBuilder({ data: [], error: null, count: 0 })
})

// ─────────────────────────────────────────────────────────────────────
// Default sort
// ─────────────────────────────────────────────────────────────────────

describe('listContacts — default sort', () => {
  it('uses display_name asc when no sort is given', async () => {
    await listContacts({})
    const orderCalls = builder.order.mock.calls
    expect(orderCalls).toHaveLength(1)
    expect(orderCalls[0][0]).toBe('display_name')
    expect(orderCalls[0][1]).toEqual({ ascending: true })
  })
})

// ─────────────────────────────────────────────────────────────────────
// Custom sort
// ─────────────────────────────────────────────────────────────────────

describe('listContacts — custom sort', () => {
  it('passes ascending:false for name desc', async () => {
    await listContacts({ sort: [{ field: 'name', direction: 'desc' }] })
    expect(builder.order).toHaveBeenCalledWith('display_name', { ascending: false })
  })

  it('applies multi-sort in order: name asc then created_at desc', async () => {
    await listContacts({
      sort: [
        { field: 'name', direction: 'asc' },
        { field: 'created_at', direction: 'desc' },
      ],
    })
    const calls = builder.order.mock.calls
    expect(calls).toHaveLength(2)
    expect(calls[0]).toEqual(['display_name', { ascending: true }])
    expect(calls[1]).toEqual(['created_at', { ascending: false }])
  })

  it('maps balance sort to contact_instructor.account_balance via foreignTable', async () => {
    await listContacts({ sort: [{ field: 'balance', direction: 'desc' }] })
    expect(builder.order).toHaveBeenCalledWith('account_balance', {
      ascending: false,
      foreignTable: 'contact_instructor',
    })
  })
})

// ─────────────────────────────────────────────────────────────────────
// Simple filter expansions
// ─────────────────────────────────────────────────────────────────────

describe('listContacts — tags / languages / sources filters', () => {
  it('applies tags via overlaps', async () => {
    await listContacts({ tags: ['vip'] })
    expect(builder.overlaps).toHaveBeenCalledWith('tags', ['vip'])
  })

  it('applies languages via overlaps with the full list', async () => {
    await listContacts({ languages: ['de', 'fr'] })
    expect(builder.overlaps).toHaveBeenCalledWith('languages', ['de', 'fr'])
  })

  it('applies sources via in()', async () => {
    await listContacts({ sources: ['manual', 'card'] })
    expect(builder.in).toHaveBeenCalledWith('source', ['manual', 'card'])
  })
})

// ─────────────────────────────────────────────────────────────────────
// Embedded sidecar filters
// ─────────────────────────────────────────────────────────────────────

describe('listContacts — embedded sidecar filters', () => {
  it('inner-joins contact_student and filters by pipeline_stage', async () => {
    await listContacts({ pipeline_stages: ['lead'] })

    // Select string must contain the explicit FK + !inner alias
    const selectArg = builder.select.mock.calls[0][0] as string
    expect(selectArg).toContain('contact_student!contact_student_contact_id_fkey!inner')

    // And the embedded-column filter must have been applied
    expect(builder.in).toHaveBeenCalledWith(
      'contact_student.pipeline_stage',
      ['lead'],
    )
  })

  it('inner-joins contact_instructor and filters balance > 0 for saldo_bucket=positive', async () => {
    await listContacts({ saldo_bucket: 'positive' })

    const selectArg = builder.select.mock.calls[0][0] as string
    expect(selectArg).toContain('contact_instructor!contact_instructor_contact_id_fkey!inner')

    expect(builder.gt).toHaveBeenCalledWith('contact_instructor.account_balance', 0)
  })
})
