import { describe, it, expect, vi, beforeEach } from 'vitest'
import {
  buildCardLeadsFilter,
  importCardLeadRpc,
  updateLeadStatus,
} from '../cardLeadQueries'

// ─── Supabase mock ──────────────────────────────────────────────────
const mockRpc = vi.fn()
const mockFrom = vi.fn()
const mockUpdate = vi.fn()
const mockEq = vi.fn()

vi.mock('@/lib/supabase', () => ({
  supabase: {
    rpc: (...args: unknown[]) => mockRpc(...args),
    from: (...args: unknown[]) => mockFrom(...args),
  },
}))

beforeEach(() => {
  mockRpc.mockReset()
  mockFrom.mockReset()
  mockUpdate.mockReset()
  mockEq.mockReset()

  mockEq.mockResolvedValue({ data: null, error: null })
  mockUpdate.mockReturnValue({ eq: mockEq })
  mockFrom.mockReturnValue({ update: mockUpdate })
})

// ─── buildCardLeadsFilter ───────────────────────────────────────────
describe('buildCardLeadsFilter', () => {
  it('returns empty filters for view=all without search', () => {
    expect(buildCardLeadsFilter({ view: 'all' })).toEqual({})
  })

  it('returns single status for view=new', () => {
    expect(buildCardLeadsFilter({ view: 'new' })).toEqual({ statuses: ['new'] })
  })

  it('returns two statuses for view=in_progress (opened + contacted)', () => {
    expect(buildCardLeadsFilter({ view: 'in_progress' })).toEqual({
      statuses: ['opened', 'contacted'],
    })
  })

  it('returns search text trimmed and lowercased', () => {
    expect(buildCardLeadsFilter({ view: 'all', search: '  Alex  ' })).toEqual({
      search: 'alex',
    })
  })

  it('drops empty search', () => {
    expect(buildCardLeadsFilter({ view: 'all', search: '   ' })).toEqual({})
  })
})

// ─── importCardLeadRpc ──────────────────────────────────────────────
describe('importCardLeadRpc', () => {
  it('calls supabase.rpc with import_card_lead + lead id', async () => {
    mockRpc.mockResolvedValue({
      data: [{ contact_id: 'c-1', action: 'created' }],
      error: null,
    })
    const result = await importCardLeadRpc('lead-42')
    expect(mockRpc).toHaveBeenCalledWith('import_card_lead', { p_lead_id: 'lead-42' })
    expect(result).toEqual({ contact_id: 'c-1', action: 'created' })
  })

  it('throws when RPC returns an error', async () => {
    mockRpc.mockResolvedValue({
      data: null,
      error: { message: 'lead_not_found', code: 'P0002' },
    })
    await expect(importCardLeadRpc('missing')).rejects.toThrow(/lead_not_found/)
  })

  it('returns first row when RPC returns array', async () => {
    mockRpc.mockResolvedValue({
      data: [{ contact_id: 'c-9', action: 'merged' }],
      error: null,
    })
    const result = await importCardLeadRpc('lead-9')
    expect(result.action).toBe('merged')
  })
})

// ─── updateLeadStatus ───────────────────────────────────────────────
describe('updateLeadStatus', () => {
  it('updates status via from().update().eq()', async () => {
    await updateLeadStatus('lead-1', 'archived')
    expect(mockFrom).toHaveBeenCalledWith('card_leads')
    expect(mockUpdate).toHaveBeenCalledWith({ status: 'archived' })
    expect(mockEq).toHaveBeenCalledWith('id', 'lead-1')
  })

  it('throws when update errors', async () => {
    mockEq.mockResolvedValue({ data: null, error: { message: 'rls_violation' } })
    await expect(updateLeadStatus('lead-1', 'spam')).rejects.toThrow(/rls_violation/)
  })
})
