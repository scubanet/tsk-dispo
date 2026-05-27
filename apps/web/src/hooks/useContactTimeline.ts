// apps/web/src/hooks/useContactTimeline.ts
import { useInfiniteQuery } from '@tanstack/react-query'
import { supabase } from '@/lib/supabase'
import type { TimelineEvent, TimelineFilter } from '@/types/contactEvents'

const PAGE_SIZE = 50

interface PageCursor {
  occurred_at: string
  event_id: string
}

/**
 * Paginated timeline für einen Contact.
 * Liest aus v_contact_timeline (Migration 0114) — vereint contact_events
 * und alle System-Event-Source-Tables.
 *
 * Pagination: cursor auf (occurred_at, event_id) — stable bei concurrent inserts.
 * Edge case: wenn die letzte Page genau PAGE_SIZE Rows liefert, gibt der Cursor
 * noch eine weitere (leere) Fetch frei. Akzeptabel.
 *
 * `enabled: !!contactId` — leerer String disabled die Query (Master-Detail
 * „kein Contact ausgewählt"-Zustand).
 *
 * Filter-Mapping: nur `event_types` / `date_from` / `date_to` werden hier
 * angewandt. `channel` und `owner_scope` aus TimelineFilter sind für andere
 * Layer reserviert (kanal-zentrische UI-Filter / globaler Activity-Scope).
 *
 * Follow-up vor Phase 2 (siehe Code-Review zu Task 10): Unit-Tests für
 * (a) Cursor-Advancement (fetchNextPage mit PAGE_SIZE rows in page 1) und
 * (b) Filter-Anwendung via mock-chain-Spy ergänzen.
 */
export function useContactTimeline(contactId: string, filter?: TimelineFilter) {
  return useInfiniteQuery({
    queryKey: ['contact-timeline', contactId, filter],
    initialPageParam: undefined as PageCursor | undefined,
    queryFn: async ({ pageParam }) => {
      let q = supabase
        .from('v_contact_timeline')
        .select('*')
        .eq('contact_id', contactId)
        .order('occurred_at', { ascending: false })
        .order('event_id', { ascending: false })
        .limit(PAGE_SIZE)

      if (filter?.event_types?.length) {
        q = q.in('event_type', filter.event_types)
      }
      if (filter?.date_from) {
        q = q.gte('occurred_at', filter.date_from)
      }
      if (filter?.date_to) {
        q = q.lte('occurred_at', filter.date_to)
      }
      if (pageParam) {
        // Cursor: (occurred_at, event_id) strict less-than (DESC sort)
        q = q.or(
          `occurred_at.lt.${pageParam.occurred_at},and(occurred_at.eq.${pageParam.occurred_at},event_id.lt.${pageParam.event_id})`
        )
      }

      const { data, error } = await q
      if (error) throw new Error(error.message)
      return (data ?? []) as TimelineEvent[]
    },
    getNextPageParam: (lastPage) => {
      const last = lastPage.at(-1)
      if (!last || lastPage.length < PAGE_SIZE) return undefined
      return { occurred_at: last.occurred_at, event_id: last.event_id }
    },
    enabled: !!contactId,
  })
}
