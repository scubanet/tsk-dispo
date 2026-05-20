import { useQuery } from '@tanstack/react-query'
import { fetchKpis, type Kpis } from '@/lib/queries'

/**
 * React-Query hook around `fetchKpis`. Provides the dashboard KPI row
 * (total / confirmed courses, active instructors, assignments this week).
 *
 * KPI snapshots tolerate a slightly longer cache than the default — 5 min —
 * because they are aggregate counts shown on Today/Cockpit, not live data.
 * Override per-call if a screen wants tighter freshness.
 */
export function useKpis() {
  return useQuery<Kpis, Error>({
    queryKey: ['kpis'],
    queryFn: () => fetchKpis(),
    staleTime: 5 * 60_000,
  })
}
