import { useQuery } from '@tanstack/react-query'
import { fetchAllCourses, type CourseDetail } from '@/lib/queries'

/**
 * React-Query hook around `fetchAllCourses`. Loads every course in the
 * database (currently the year-bounded set in `lib/queries.ts`).
 *
 * Usage in `CoursesScreen`:
 *
 *   const { data: courses = [], refetch } = useAllCourses()
 *   // ... pass refetch as onSaved={() => { refetch() }} into CourseEditSheet
 *
 * Cache key is `['courses', 'all']` — shares the `'courses'` namespace with
 * `useCoursesInRange` so a single
 *
 *   qc.invalidateQueries({ queryKey: ['courses'] })
 *
 * from a mutation will refresh both the master list and any open range view.
 */
export function useAllCourses() {
  return useQuery<CourseDetail[], Error>({
    queryKey: ['courses', 'all'],
    queryFn: () => fetchAllCourses(),
  })
}
