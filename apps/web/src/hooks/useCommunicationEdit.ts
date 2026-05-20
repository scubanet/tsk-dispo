/**
 * Hooks for CommunicationEditSheet — picker list, contact basics for the
 * send-buttons row, single-entry read for edit-mode, plus save/delete
 * mutations.
 *
 * Save/delete invalidate both the global ['communicationEntries'] cache
 * (CommunicationHub) and the per-contact ['contact', 'communications', id]
 * cache (CommunicationsTab inside ContactDetailPanel).
 */

import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import {
  fetchContactPickerList,
  fetchContactBasics,
  fetchCommunicationEntry,
  insertCommunicationEntry,
  updateCommunicationEntry,
  deleteCommunicationEntry,
  type ContactPickerOption,
  type ContactBasics,
  type CommunicationEntryForEdit,
  type CommunicationEntryInput,
} from '@/lib/contactQueries'

export function useContactPickerList(enabled: boolean = true) {
  return useQuery<ContactPickerOption[], Error>({
    queryKey: ['contacts', 'pickerList'],
    queryFn: () => fetchContactPickerList(),
    enabled,
    staleTime: 60_000,
  })
}

export function useContactBasics(contactId: string | null | undefined) {
  return useQuery<ContactBasics | null, Error>({
    queryKey: ['contact', 'basics', contactId],
    queryFn: () => fetchContactBasics(contactId as string),
    enabled: Boolean(contactId),
  })
}

export function useCommunicationEntry(entryId: string | null | undefined) {
  return useQuery<CommunicationEntryForEdit | null, Error>({
    queryKey: ['communicationEntries', 'detail', entryId],
    queryFn: () => fetchCommunicationEntry(entryId as string),
    enabled: Boolean(entryId),
  })
}

function invalidateCommunicationScope(
  qc: ReturnType<typeof useQueryClient>,
  contactId: string,
) {
  qc.invalidateQueries({ queryKey: ['communicationEntries'] })
  qc.invalidateQueries({ queryKey: ['contact', 'communications', contactId] })
}

export interface SaveCommunicationVars {
  /** When set, updates this entry; otherwise inserts a new one. */
  entryId?: string | null
  input: CommunicationEntryInput
}

export function useSaveCommunicationEntry() {
  const qc = useQueryClient()
  return useMutation<void, Error, SaveCommunicationVars>({
    mutationFn: async ({ entryId, input }) => {
      if (entryId) {
        await updateCommunicationEntry(entryId, input)
      } else {
        await insertCommunicationEntry(input)
      }
    },
    onSuccess: (_data, vars) => invalidateCommunicationScope(qc, vars.input.contact_id),
  })
}

export interface DeleteCommunicationVars {
  entryId: string
  contactId: string
}

export function useDeleteCommunicationEntry() {
  const qc = useQueryClient()
  return useMutation<void, Error, DeleteCommunicationVars>({
    mutationFn: ({ entryId }) => deleteCommunicationEntry(entryId),
    onSuccess: (_data, vars) => invalidateCommunicationScope(qc, vars.contactId),
  })
}
