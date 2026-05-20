import { useQuery } from '@tanstack/react-query'
import { fetchCommunicationEntries, type CommunicationEntry } from '@/lib/contactQueries'

/**
 * React-Query hook around `fetchCommunicationEntries`. Loads the most recent
 * 500 touchpoints across all contacts (used by the CommunicationHub).
 *
 * Cache key: `['communicationEntries', 'recent']`. Mutations (create / edit
 * touchpoint) should invalidate `['communicationEntries']`.
 */
export function useCommunicationEntries(enabled: boolean = true) {
  return useQuery<CommunicationEntry[], Error>({
    queryKey: ['communicationEntries', 'recent'],
    queryFn: () => fetchCommunicationEntries(),
    enabled,
  })
}
