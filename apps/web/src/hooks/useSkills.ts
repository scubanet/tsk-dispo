import { useQuery } from '@tanstack/react-query'
import { fetchSkills, type SkillRow } from '@/lib/queries'

/**
 * React-Query hook around `fetchSkills`. The skill catalog is reference
 * data — `staleTime: 30 min` keeps repeated visits instant.
 */
export function useSkills() {
  return useQuery<SkillRow[], Error>({
    queryKey: ['skills'],
    queryFn: () => fetchSkills(),
    staleTime: 30 * 60_000,
  })
}
