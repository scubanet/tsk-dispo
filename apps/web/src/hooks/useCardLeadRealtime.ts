/**
 * Realtime channel for card-leads. Invalidates the React-Query cache on
 * any INSERT/UPDATE/DELETE event so the list and badge stay live.
 *
 * Reconnect strategy: Supabase JS client handles backoff internally.
 * If the channel closes unexpectedly we expose onClose so the caller
 * can show a toast.
 */
import { useEffect } from 'react'
import { useQueryClient } from '@tanstack/react-query'
import { supabase } from '@/lib/supabase'

export interface UseCardLeadRealtimeOpts {
  onInsert?: (row: { id: string }) => void
  onClose?: () => void
}

export function useCardLeadRealtime(opts: UseCardLeadRealtimeOpts = {}) {
  const qc = useQueryClient()

  useEffect(() => {
    const channel = supabase
      .channel('card_leads_inbox')
      .on(
        'postgres_changes',
        { event: 'INSERT', schema: 'public', table: 'card_leads' },
        (payload) => {
          qc.invalidateQueries({ queryKey: ['card-leads'] })
          qc.invalidateQueries({ queryKey: ['card-leads-unread'] })
          opts.onInsert?.(payload.new as { id: string })
        },
      )
      .on(
        'postgres_changes',
        { event: 'UPDATE', schema: 'public', table: 'card_leads' },
        () => {
          qc.invalidateQueries({ queryKey: ['card-leads'] })
          qc.invalidateQueries({ queryKey: ['card-leads-unread'] })
        },
      )
      .on('system', { event: 'disconnect' }, () => opts.onClose?.())
      .subscribe()

    return () => {
      void supabase.removeChannel(channel)
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [])
}
