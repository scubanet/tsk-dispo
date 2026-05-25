/**
 * Mutation actions for card-inbox.
 *
 * Optimistic update on status changes — roll back on error.
 * Import goes through the RPC and invalidates BOTH the card-leads list
 * and the contacts list (the new/merged contact appears in Adressbuch).
 */
import { useMutation, useQueryClient, type QueryKey } from '@tanstack/react-query'
import {
  deleteLead,
  importCardLeadRpc,
  updateLeadStatus,
} from '@/lib/cardLeadQueries'
import type { CardLeadStatus, CardLeadRow } from '@/types/cardLeads'

export function useUpdateLeadStatus() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: ({ id, status }: { id: string; status: CardLeadStatus }) =>
      updateLeadStatus(id, status),
    onMutate: async ({ id, status }) => {
      // Optimistically patch every cached card-leads page
      await qc.cancelQueries({ queryKey: ['card-leads'] })
      const snapshots: Array<[QueryKey, CardLeadRow[] | undefined]> = []
      qc.getQueriesData<CardLeadRow[]>({ queryKey: ['card-leads'] }).forEach(([key, rows]) => {
        snapshots.push([key, rows])
        if (rows) {
          qc.setQueryData<CardLeadRow[]>(key, rows.map((r) => r.id === id ? { ...r, status } : r))
        }
      })
      return { snapshots }
    },
    onError: (_err, _vars, ctx) => {
      // Rollback
      ctx?.snapshots.forEach(([key, rows]) => qc.setQueryData(key, rows))
    },
    onSettled: () => {
      qc.invalidateQueries({ queryKey: ['card-leads'] })
      qc.invalidateQueries({ queryKey: ['card-leads-unread'] })
    },
  })
}

export function useImportCardLead() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: (leadId: string) => importCardLeadRpc(leadId),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['card-leads'] })
      qc.invalidateQueries({ queryKey: ['card-leads-unread'] })
      qc.invalidateQueries({ queryKey: ['contacts'] })
    },
  })
}

export function useDeleteLead() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: (leadId: string) => deleteLead(leadId),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['card-leads'] })
      qc.invalidateQueries({ queryKey: ['card-leads-unread'] })
    },
  })
}
