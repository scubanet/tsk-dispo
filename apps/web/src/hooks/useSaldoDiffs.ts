import { useQuery } from '@tanstack/react-query'
import { fetchSaldoDiffs, type SaldoDiffRow } from '@/lib/queries'

/**
 * React-Query hook around `fetchSaldoDiffs`. Reads the cross-instructor
 * comparison view (App-Saldo vs. Excel-Saldo with diff).
 *
 * The view is calculation-heavy and changes only when movements are added,
 * so a longer cache pays off: 5 min staleTime + the standard 5 min gcTime
 * means revisits to `/saldi` within a session are instant.
 *
 * Cache key: `['saldi', 'diff']`. Mutations that touch movements should
 * invalidate `['saldi']` (and ideally `['myMovements']`) to refresh.
 */
export function useSaldoDiffs() {
  return useQuery<SaldoDiffRow[], Error>({
    queryKey: ['saldi', 'diff'],
    queryFn: () => fetchSaldoDiffs(),
    staleTime: 5 * 60_000,
  })
}
