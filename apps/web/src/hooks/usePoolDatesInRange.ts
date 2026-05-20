import { useQuery, keepPreviousData } from '@tanstack/react-query'
import { fetchPoolDatesInRange, type PoolDateRow } from '@/lib/queries'

/**
 * React-Query hook around `fetchPoolDatesInRange`. Loads pool reservations
 * (course_dates of type=pool with a location) within an ISO-date range —
 * the dataset for the weekly pool grid.
 *
 * `keepPreviousData` — clicking ←/→ for week navigation keeps last week's
 * grid visible until the new one arrives, eliminating the empty-flash.
 *
 * Cache key: `['poolDates', 'range', from, to]`. Shares the `'poolDates'`
 * namespace so any future per-day-detail hook can invalidate the grid in
 * one shot.
 */
export function usePoolDatesInRange(from: string, to: string) {
  return useQuery<PoolDateRow[], Error>({
    queryKey: ['poolDates', 'range', from, to],
    queryFn: () => fetchPoolDatesInRange(from, to),
    enabled: Boolean(from) && Boolean(to),
    placeholderData: keepPreviousData,
  })
}
