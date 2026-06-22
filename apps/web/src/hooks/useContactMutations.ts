/**
 * Mutations for the four "manage a contact" sheets: RoleManager, Create,
 * AddRelationship, MergeContacts.
 *
 * Each mutation invalidates the whole `'contacts'` and `'contact'` cache
 * namespaces because any of these writes can ripple across the addressbook
 * list, the kanban, and per-contact detail views.
 */

import { useMutation, useQueryClient } from '@tanstack/react-query'
import {
  setContactRoles,
  createContact,
  addRelationship,
  mergeContacts,
  findPotentialDuplicates,
} from '@/lib/contactQueries'
import type { ContactKind, ContactRole, RelationshipKind } from '@/types/contacts'

function invalidateContactWorld(qc: ReturnType<typeof useQueryClient>) {
  qc.invalidateQueries({ queryKey: ['contacts'] })
  qc.invalidateQueries({ queryKey: ['contact'] })
  // Course enroll-picker lists (useStudents / useCandidates) are separate caches;
  // invalidate them so a newly created student/candidate shows in the picker
  // without a full page reload.
  qc.invalidateQueries({ queryKey: ['students'] })
  qc.invalidateQueries({ queryKey: ['candidates'] })
}

export interface SetRolesVars {
  contactId: string
  currentRoles: ContactRole[]
  newRoles: ContactRole[]
}

export function useSetContactRoles() {
  const qc = useQueryClient()
  return useMutation<void, Error, SetRolesVars>({
    mutationFn: ({ contactId, currentRoles, newRoles }) =>
      setContactRoles(contactId, currentRoles, newRoles),
    onSuccess: () => invalidateContactWorld(qc),
  })
}

export type CreateContactVars = Parameters<typeof createContact>[0]

export interface CreateContactResult {
  id: string
  duplicate: {
    display_name: string
    primary_email: string | null | undefined
    kind: ContactKind
  } | null
}

/**
 * Creates the contact, then opportunistically checks for potential
 * duplicates. The returned object includes both the new id and any dup
 * warning the caller may want to surface.
 */
export function useCreateContact() {
  const qc = useQueryClient()
  return useMutation<CreateContactResult, Error, CreateContactVars>({
    mutationFn: async (params) => {
      const id = await createContact(params)
      try {
        const dups = await findPotentialDuplicates(id)
        return {
          id,
          duplicate: dups[0]
            ? {
                display_name: dups[0].display_name,
                primary_email: dups[0].primary_email,
                kind: dups[0].kind,
              }
            : null,
        }
      } catch {
        return { id, duplicate: null }
      }
    },
    onSuccess: () => invalidateContactWorld(qc),
  })
}

export interface AddRelationshipVars {
  from_contact_id: string
  to_contact_id: string
  kind: RelationshipKind
  role_at_org?: string
  is_primary?: boolean
}

export function useAddRelationship() {
  const qc = useQueryClient()
  return useMutation<void, Error, AddRelationshipVars>({
    mutationFn: (params) => addRelationship(params),
    onSuccess: (_data, vars) => {
      qc.invalidateQueries({
        queryKey: ['contact', 'relationships', vars.from_contact_id],
      })
      qc.invalidateQueries({
        queryKey: ['contact', 'relationships', vars.to_contact_id],
      })
      // OrgMembersTab + workspace lists.
      qc.invalidateQueries({ queryKey: ['contact', 'orgMembers'] })
    },
  })
}

export interface MergeContactsVars {
  winnerId: string
  loserId: string
}

export function useMergeContacts() {
  const qc = useQueryClient()
  return useMutation<void, Error, MergeContactsVars>({
    mutationFn: ({ winnerId, loserId }) => mergeContacts(winnerId, loserId),
    onSuccess: () => invalidateContactWorld(qc),
  })
}
