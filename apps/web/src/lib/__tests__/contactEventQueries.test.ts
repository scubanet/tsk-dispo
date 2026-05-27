// apps/web/src/lib/__tests__/contactEventQueries.test.ts
import { describe, it, expect, vi, beforeEach } from 'vitest'
import {
  insertContactEvent,
  updateContactEvent,
  deleteContactEvent,
} from '../contactEventQueries'

// Mock Supabase
vi.mock('@/lib/supabase', () => ({
  supabase: {
    from: vi.fn(),
  },
}))

import { supabase } from '@/lib/supabase'

describe('contactEventQueries', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  describe('insertContactEvent', () => {
    it('inserts a note event with summary + body', async () => {
      const single = vi.fn().mockResolvedValue({ data: { id: 'ev-1' }, error: null })
      const select = vi.fn().mockReturnValue({ single })
      const insert = vi.fn().mockReturnValue({ select })
      vi.mocked(supabase.from).mockReturnValue({ insert } as never)

      const result = await insertContactEvent('contact-1', {
        event_type: 'note',
        summary: 'hello',
        body: 'longer body',
      })

      expect(supabase.from).toHaveBeenCalledWith('contact_events')
      expect(insert).toHaveBeenCalledWith({
        contact_id: 'contact-1',
        event_type: 'note',
        summary: 'hello',
        body: 'longer body',
      })
      expect(result).toEqual({ id: 'ev-1' })
    })

    it('throws on supabase error', async () => {
      const single = vi.fn().mockResolvedValue({
        data: null,
        error: { message: 'RLS denied' },
      })
      const select = vi.fn().mockReturnValue({ single })
      const insert = vi.fn().mockReturnValue({ select })
      vi.mocked(supabase.from).mockReturnValue({ insert } as never)

      await expect(
        insertContactEvent('contact-1', { event_type: 'note', summary: 'x' })
      ).rejects.toThrow('RLS denied')
    })
  })

  describe('updateContactEvent', () => {
    it('updates summary + body by id and returns id', async () => {
      const single = vi.fn().mockResolvedValue({ data: { id: 'ev-1' }, error: null })
      const select = vi.fn().mockReturnValue({ single })
      const eq = vi.fn().mockReturnValue({ select })
      const update = vi.fn().mockReturnValue({ eq })
      vi.mocked(supabase.from).mockReturnValue({ update } as never)

      const result = await updateContactEvent('ev-1', { summary: 'updated' })

      expect(update).toHaveBeenCalledWith({ summary: 'updated' })
      expect(eq).toHaveBeenCalledWith('id', 'ev-1')
      expect(result).toEqual({ id: 'ev-1' })
    })

    it('throws on supabase error', async () => {
      const single = vi.fn().mockResolvedValue({
        data: null,
        error: { message: 'event not found' },
      })
      const select = vi.fn().mockReturnValue({ single })
      const eq = vi.fn().mockReturnValue({ select })
      const update = vi.fn().mockReturnValue({ eq })
      vi.mocked(supabase.from).mockReturnValue({ update } as never)

      await expect(
        updateContactEvent('ev-missing', { summary: 'x' })
      ).rejects.toThrow('event not found')
    })
  })

  describe('deleteContactEvent', () => {
    it('deletes by id', async () => {
      const eq = vi.fn().mockResolvedValue({ error: null })
      const del = vi.fn().mockReturnValue({ eq })
      vi.mocked(supabase.from).mockReturnValue({ delete: del } as never)

      await deleteContactEvent('ev-1')

      expect(del).toHaveBeenCalled()
      expect(eq).toHaveBeenCalledWith('id', 'ev-1')
    })

    it('throws on supabase error', async () => {
      const eq = vi.fn().mockResolvedValue({ error: { message: 'RLS denied' } })
      const del = vi.fn().mockReturnValue({ eq })
      vi.mocked(supabase.from).mockReturnValue({ delete: del } as never)

      await expect(deleteContactEvent('ev-1')).rejects.toThrow('RLS denied')
    })
  })
})
