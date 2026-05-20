import { useQuery } from '@tanstack/react-query'
import { fetchMyMovements, type MyMovement } from '@/lib/queries'

/**
 * React-Query hook around `fetchMyMovements`. Loads the personal saldo
 * movements (one entry per Vergütung / Übertrag / Korrektur) for an
 * instructor.
 *
 * Cache key: `['myMovements', instructorId]`. Disabled when the user isn't
 * linked to an instructor record yet.
 */
export function useMyMovements(instructorId: string | null | undefined) {
  return useQuery<MyMovement[], Error>({
    queryKey: ['myMovements', instructorId],
    queryFn: () => fetchMyMovements(instructorId as string),
    enabled: Boolean(instructorId),
    staleTime: 5 * 60_000,
  })
}
