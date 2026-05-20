import { useQuery } from '@tanstack/react-query'
import { fetchCourseAssignments, type AssignmentRow } from '@/lib/queries'

type CourseAssignmentRow = AssignmentRow & { assigned_for_dates: string[] }

/**
 * React-Query hook around `fetchCourseAssignments`. Loads the instructor
 * assignments for one specific course, including per-day-selection metadata.
 *
 * Cache key: `['assignments', 'forCourse', courseId]`. Shares the
 * `'assignments'` namespace so a generic invalidate refreshes both the
 * per-course view and the cross-course views (Calendar / Today / Cockpit).
 */
export function useCourseAssignments(courseId: string | null | undefined) {
  return useQuery<CourseAssignmentRow[], Error>({
    queryKey: ['assignments', 'forCourse', courseId],
    queryFn: () => fetchCourseAssignments(courseId as string),
    enabled: Boolean(courseId),
  })
}
