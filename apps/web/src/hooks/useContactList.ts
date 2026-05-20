import { useQuery, keepPreviousData } from '@tanstack/react-query'
import { listContacts, type ContactListFilter } from '@/lib/contactQueries'
import type { Contact } from '@/types/contacts'

interface ContactListResult {
  rows: Contact[]
  total?: number
}

/**
 * React-Query hook around `listContacts`. The whole contact directory lives
 * behind this single hook; `filter` controls which saved view (people /
 * organizations / instructors / students / …), pagination is exposed via
 * `page` and `pageSize`.
 *
 * `placeholderData: keepPreviousData` — when the user changes filters or
 * pages, the *current* result stays on screen until the new one arrives.
 * Avoids the harsh empty-state flash that the old useEffect implementation
 * showed for ~200 ms on every saved-view click.
 *
 * Cache key: `['contacts', 'list', filter, page, pageSize]`. Mutations
 * (create / update / archive contact) should call
 * `qc.invalidateQueries({ queryKey: ['contacts'] })` to refresh every view
 * at once.
 */
export function useContactList(
  filter: ContactListFilter = {},
  page = 0,
  pageSize = 500,
) {
  return useQuery<ContactListResult, Error>({
    queryKey: ['contacts', 'list', filter, page, pageSize],
    queryFn: () => listContacts(filter, page, pageSize),
    placeholderData: keepPreviousData,
  })
}
