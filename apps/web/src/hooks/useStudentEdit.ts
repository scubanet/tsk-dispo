/**
 * Hooks for StudentEditSheet — organizations dropdown plus upsert/delete
 * mutations. Reuses useContactWithSidecars and useContactRelationships for
 * loading the edit-mode form, so cache is shared with AddressbookScreen
 * and ContactDetailPanel.
 *
 * Save/delete invalidate every cache namespace that a contact write touches.
 */

import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import {
  fetchOrganizations,
  upsertStudent,
  deleteContact,
  type OrganizationOption,
  type StudentUpsertContact,
  type StudentUpsertStudent,
} from '@/lib/contactQueries'

export function useOrganizations(enabled: boolean = true) {
  return useQuery<OrganizationOption[], Error>({
    queryKey: ['organizations'],
    queryFn: () => fetchOrganizations(),
    enabled,
    staleTime: 5 * 60_000,
  })
}

function invalidateContactScope(
  qc: ReturnType<typeof useQueryClient>,
  contactId: string | null,
) {
  // Whole contact namespace — addressbook, sidecar views, tabs.
  qc.invalidateQueries({ queryKey: ['contacts'] })
  qc.invalidateQueries({ queryKey: ['contact'] })
  // Pipeline kanban depends on student.pipeline_stage.
  qc.invalidateQueries({ queryKey: ['contacts', 'pipeline'] })
  if (contactId) {
    qc.invalidateQueries({ queryKey: ['contact', 'withSidecars', contactId] })
  }
}

export interface UpsertStudentVars {
  contactId: string | null
  contact: StudentUpsertContact
  student: StudentUpsertStudent
  orgId: string | null
}

export function useUpsertStudent() {
  const qc = useQueryClient()
  return useMutation<string, Error, UpsertStudentVars>({
    mutationFn: (vars) => upsertStudent(vars),
    onSuccess: (newId, vars) => invalidateContactScope(qc, vars.contactId ?? newId),
  })
}

export function useDeleteContact() {
  const qc = useQueryClient()
  return useMutation<void, Error, string>({
    mutationFn: (contactId) => deleteContact(contactId),
    onSuccess: (_data, contactId) => invalidateContactScope(qc, contactId),
  })
}
