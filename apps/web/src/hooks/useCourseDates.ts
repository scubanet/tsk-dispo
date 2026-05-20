import { useQuery } from '@tanstack/react-query'
import { fetchCourseDates, type CourseDate } from '@/lib/queries'

/**
 * React-Query hook around `fetchCourseDates`. Loads the multi-day session
 * breakdown (theory / pool / lake times + pool reservation status) for
 * one course.
 *
 * Cache key: `['courseDates', 'forCourse', courseId]`.
 */
export function useCourseDates(courseId: string | null | undefined) {
  return useQuery<CourseDate[], Error>({
    queryKey: ['courseDates', 'forCourse', courseId],
    queryFn: () => fetchCourseDates(courseId as string),
    enabled: Boolean(courseId),
  })
}
