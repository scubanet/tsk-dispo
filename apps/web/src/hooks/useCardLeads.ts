/**
 * React-Query hook for the card-inbox list.
 *
 * Stale-time 30s — the realtime channel (useCardLeadRealtime) handles
 * invalidation on INSERT events, so we don't need aggressive polling.
 */
import { useQuery } from '@tanstack/react-query'
import {
  buildCardLeadsFilter,
  fetchCardLeads,
  type CardLeadViewId,
} from '@/lib/cardLeadQueries'

export function cardLeadsQueryKey(view: CardLeadViewId, search?: string) {
  return ['card-leads', view, search ?? ''] as const
}

export function useCardLeads(view: CardLeadViewId, search?: string) {
  const filter = buildCardLeadsFilter({ view, search })

  return useQuery({
    queryKey: cardLeadsQueryKey(view, search),
    queryFn: () => fetchCardLeads(filter),
    staleTime: 30_000,
    refetchOnWindowFocus: true,
  })
}
