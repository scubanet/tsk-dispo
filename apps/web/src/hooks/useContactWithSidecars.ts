import { useQuery } from '@tanstack/react-query'
import { getContactWithSidecars } from '@/lib/contactQueries'
import type { ContactWithSidecars } from '@/types/contacts'

/**
 * React-Query hook around `getContactWithSidecars`. Loads one contact plus
 * every joined sidecar table (student / instructor / organization / etc.)
 * in a single round-trip.
 *
 * Cache key: `['contact', 'withSidecars', contactId]`. After a mutation that
 * touches the contact OR any of its sidecars, call
 * `qc.invalidateQueries({ queryKey: ['contact', 'withSidecars', id] })` to
 * refresh just this contact, or `['contact']` to refresh every contact in
 * cache.
 */
export function useContactWithSidecars(
  contactId: string | null | undefined,
  enabled: boolean = true,
) {
  return useQuery<ContactWithSidecars | null, Error>({
    queryKey: ['contact', 'withSidecars', contactId],
    queryFn: () => getContactWithSidecars(contactId as string),
    enabled: enabled && Boolean(contactId),
  })
}
