/**
 * Sidebar badge — count of card-leads with status='new'.
 *
 * Refetches on window focus + whenever the realtime channel (in
 * useCardLeadRealtime, attached at the screen level) invalidates the
 * 'card-leads-unread' query key.
 */
import { useQuery } from '@tanstack/react-query'
import { fetchUnreadCount } from '@/lib/cardLeadQueries'

export function useCardLeadsUnreadCount() {
  return useQuery({
    queryKey: ['card-leads-unread'],
    queryFn: fetchUnreadCount,
    staleTime: 30_000,
    refetchOnWindowFocus: true,
  })
}
