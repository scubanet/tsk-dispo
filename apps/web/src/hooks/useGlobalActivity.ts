// apps/web/src/hooks/useGlobalActivity.ts
import { useInfiniteQuery } from '@tanstack/react-query'
import { supabase } from '@/lib/supabase'
import type { TimelineEvent, TimelineFilter } from '@/types/contactEvents'

const PAGE_SIZE = 50

interface PageCursor {
  occurred_at: string
  event_id: string
}

/**
 * Globaler Activity-Feed über alle Contacts (die der User per RLS sieht).
 * Speist den /aktivitaet-Screen (Phase 5).
 *
 * RLS-Erinnerung (siehe Migration 0114 Header-NOTE): einige Source-Tables
 * sind permissiver als andere — z.B. contact_audit_log zeigt Role-Changes
 * org-weit, pipeline_stage_changes nur owner-scoped. Konsequenz: der globale
 * Feed ist asymmetrisch. Akzeptiert für Phase G.
 *
 * Pagination: cursor auf (occurred_at, event_id) — stable bei concurrent inserts.
 * Filter-Mapping: nur `event_types` / `date_from` / `date_to` werden hier
 * angewandt. `channel` und `owner_scope` aus TimelineFilter sind UI-Layer.
 */
export function useGlobalActivity(filter?: TimelineFilter) {
  return useInfiniteQuery({
    queryKey: ['global-activity', filter],
    initialPageParam: undefined as PageCursor | undefined,
    queryFn: async ({ pageParam }) => {
      let q = supabase
        .from('v_contact_timeline')
        .select('*')
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
  })
}
