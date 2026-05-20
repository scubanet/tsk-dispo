import { useMemo } from 'react'
import { useQuery } from '@tanstack/react-query'
import { fetchAssignmentsForCourses, type AssignmentRow } from '@/lib/queries'

/**
 * React-Query hook around `fetchAssignmentsForCourses`. Loads every assignment
 * (instructor + role + confirmed flag) for a set of course IDs in one shot.
 *
 * Designed as a **dependent query**: typical usage is to first load courses
 * via `useCoursesInRange` and then pass `cs.map(c => c.id)` here. The cache key
 * sorts the IDs so reordering the list doesn't bust the cache. Empty arrays
 * short-circuit (`enabled` flips false) — no wasted requests on mount.
 *
 *   const { data: courses = [] } = useCoursesInRange(from, to)
 *   const ids = courses.map(c => c.id)
 *   const { data: assignments = [] } = useAssignmentsForCourses(ids)
 *
 * Cache key: `['assignments', 'forCourses', sortedIds]`. Shares the
 * `'assignments'` namespace so mutations can invalidate the whole group with
 * `qc.invalidateQueries({ queryKey: ['assignments'] })`.
 */
export function useAssignmentsForCourses(courseIds: string[]) {
  // Stable, order-independent cache key — sorting in a memo means swapping
  // the order of `courseIds` in the parent doesn't trigger a refetch.
  const sortedIds = useMemo(() => [...courseIds].sort(), [courseIds])

  return useQuery<AssignmentRow[], Error>({
    queryKey: ['assignments', 'forCourses', sortedIds],
    queryFn: () => fetchAssignmentsForCourses(sortedIds),
    enabled: sortedIds.length > 0,
  })
}
