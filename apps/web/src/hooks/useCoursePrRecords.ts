import { useQuery } from '@tanstack/react-query'
import { fetchCoursePrRecords, type PrRecordRow } from '@/lib/queries'

/**
 * React-Query hook around `fetchCoursePrRecords`. Loads every performance
 * record attached to a course (for the PR tab in CourseDetailPanel).
 *
 * Cache key: `['prRecords', 'forCourse', courseId]`. Saving a record via
 * PrCheckOffSheet should invalidate `['prRecords']`.
 */
export function useCoursePrRecords(courseId: string | null | undefined, enabled: boolean = true) {
  return useQuery<PrRecordRow[], Error>({
    queryKey: ['prRecords', 'forCourse', courseId],
    queryFn: () => fetchCoursePrRecords(courseId as string),
    enabled: enabled && Boolean(courseId),
  })
}
