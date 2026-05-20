import { useQuery } from '@tanstack/react-query'
import { fetchCoursesInRange, type CourseRow } from '@/lib/queries'

/**
 * React-Query hook around `fetchCoursesInRange`. **Reference implementation
 * for the data-layer migration** (see
 * `Deliverables/2026-05-20-tanstack-query-migration-guide.md`).
 *
 * Usage in a screen:
 *
 *   const { data: courses = [], isLoading, error } = useCoursesInRange(from, to)
 *
 * Behaviour upgrade over the raw `useEffect + fetchCoursesInRange + setState`:
 *
 *   - Dedup: ten components asking for the same `(from, to)` issue exactly one
 *     network request.
 *   - Cache: 30 s `staleTime` matches the existing debounce in AtollEventLoader.
 *   - Refetch on focus: returning to the tab refreshes silently.
 *   - Error & loading flags: returned by the hook, no manual state.
 *
 * `enabled` lets the caller defer the query (e.g., while the user is still
 * picking a date range). Default true.
 */
export function useCoursesInRange(
  from: string,
  to: string,
  enabled: boolean = true,
) {
  return useQuery<CourseRow[], Error>({
    queryKey: ['courses', 'range', from, to],
    queryFn: () => fetchCoursesInRange(from, to),
    enabled: enabled && Boolean(from) && Boolean(to),
  })
}
