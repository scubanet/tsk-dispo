import { useQuery, keepPreviousData } from '@tanstack/react-query'
import { fetchCockpitData, type CockpitData } from '@/lib/queries'

/**
 * React-Query hook around `fetchCockpitData`. The cockpit RPC computes the
 * full dashboard in a single round-trip, so the cache key is just the date
 * range.
 *
 * `placeholderData: keepPreviousData` — when the user switches the period
 * (Monat / Quartal / Jahr), the previous numbers stay on screen until the
 * new RPC returns, avoiding the dashboard going blank for ~500 ms.
 *
 * `staleTime: 5 min` — aggregate analytics. The data isn't second-by-second
 * fresh and aggressive refetching would hit the database unnecessarily.
 *
 * Cache key: `['cockpit', start, end]`. Triggering a mutation that changes
 * KPI inputs (e.g. a saldo correction) should invalidate `['cockpit']`.
 */
export function useCockpitData(start: string, end: string) {
  return useQuery<CockpitData, Error>({
    queryKey: ['cockpit', start, end],
    queryFn: () => fetchCockpitData(start, end),
    placeholderData: keepPreviousData,
    staleTime: 5 * 60_000,
  })
}
