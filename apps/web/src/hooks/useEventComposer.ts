// apps/web/src/hooks/useEventComposer.ts
import { useMutation, useQueryClient } from '@tanstack/react-query'
import {
  deleteContactEvent,
  insertContactEvent,
  updateContactEvent,
} from '@/lib/contactEventQueries'
import type { EventComposerInput, TimelineEvent } from '@/types/contactEvents'

/**
 * Insert a new event for a contact + invalidate timeline & global-activity.
 * Phase 1: plain invalidate (Refetch nach Server-Round-Trip).
 * Phase 2 (Composer-UI): optimistic insert in die erste Page damit
 * die Karte schon vor Server-Response erscheint.
 */
export function useInsertContactEvent(contactId: string) {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: (input: EventComposerInput) => insertContactEvent(contactId, input),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['contact-timeline', contactId] })
      qc.invalidateQueries({ queryKey: ['global-activity'] })
    },
  })
}

/**
 * Update event — z.B. Task auf resolved setzen, Note korrigieren.
 */
export function useUpdateContactEvent(contactId: string) {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: ({ eventId, patch }: {
      eventId: string
      patch: Partial<Pick<TimelineEvent, 'summary' | 'body' | 'status' | 'payload'>>
    }) => updateContactEvent(eventId, patch),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['contact-timeline', contactId] })
      qc.invalidateQueries({ queryKey: ['global-activity'] })
    },
  })
}

/**
 * Delete event — RLS sorgt für owner-only.
 * Phase 1: plain invalidate. Phase 2: optimistic remove + rollback bei Fehler.
 */
export function useDeleteContactEvent(contactId: string) {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: (eventId: string) => deleteContactEvent(eventId),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['contact-timeline', contactId] })
      qc.invalidateQueries({ queryKey: ['global-activity'] })
    },
  })
}
