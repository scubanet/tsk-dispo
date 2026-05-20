import { useQuery } from '@tanstack/react-query'
import { fetchMyAssignments, type MyAssignment } from '@/lib/queries'

/**
 * React-Query hook around `fetchMyAssignments`. Loads every assignment for
 * the current instructor (used by the Instructor view of Today + the
 * MyAssignments screen).
 *
 * Pass `instructorId` (typically `user.instructorId` from the auth context).
 * Query is disabled when `instructorId` is empty/undefined so the hook is
 * safe to call before the user is fully hydrated.
 *
 * Cache key: `['myAssignments', instructorId]`. Mutations to assignments
 * elsewhere should invalidate `['myAssignments']` *and* `['assignments']`
 * to keep both the per-instructor and per-course views in sync.
 */
export function useMyAssignments(instructorId: string | null | undefined) {
  return useQuery<MyAssignment[], Error>({
    queryKey: ['myAssignments', instructorId],
    queryFn: () => fetchMyAssignments(instructorId as string),
    enabled: Boolean(instructorId),
  })
}
