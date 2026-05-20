import { useQuery } from '@tanstack/react-query'
import { listPipelineContacts } from '@/lib/contactQueries'

type PipelineContactRow = Awaited<ReturnType<typeof listPipelineContacts>>[number]

/**
 * React-Query hook around `listPipelineContacts`. Loads every contact that
 * has a non-`none` pipeline stage, used by the CD kanban board.
 *
 * Cache key: `['contacts', 'pipeline']`. Shares the `'contacts'` namespace
 * so a generic `qc.invalidateQueries({ queryKey: ['contacts'] })` from a
 * contact mutation refreshes both the addressbook list and this board.
 */
export function usePipelineContacts() {
  return useQuery<PipelineContactRow[], Error>({
    queryKey: ['contacts', 'pipeline'],
    queryFn: () => listPipelineContacts(),
  })
}
