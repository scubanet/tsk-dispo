import { useQuery } from '@tanstack/react-query'
import { listActiveInstructors } from '@/lib/contactQueries'

type ActiveInstructor = Awaited<ReturnType<typeof listActiveInstructors>>[number]

/**
 * React-Query hook around `listActiveInstructors`. Returns every instructor
 * with `active = true` from the contact_instructor join.
 *
 * Cache key: `['instructors', 'active']`.
 */
export function useActiveInstructors() {
  return useQuery<ActiveInstructor[], Error>({
    queryKey: ['instructors', 'active'],
    queryFn: () => listActiveInstructors(),
  })
}
