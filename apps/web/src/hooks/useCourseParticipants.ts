import { useQuery } from '@tanstack/react-query'
import { fetchCourseParticipants, type CourseParticipant } from '@/lib/queries'

/**
 * React-Query hook around `fetchCourseParticipants`. Loads every enrolled
 * student for one course (with their certification & status).
 *
 * Cache key: `['participants', 'forCourse', courseId]`.
 */
export function useCourseParticipants(courseId: string | null | undefined) {
  return useQuery<CourseParticipant[], Error>({
    queryKey: ['participants', 'forCourse', courseId],
    queryFn: () => fetchCourseParticipants(courseId as string),
    enabled: Boolean(courseId),
  })
}
