/**
 * Hooks for the ContactDetailPanel tabs. Grouped in one file because they
 * share the `'contact'` cache namespace and the lifecycle (mount, contactId
 * change, invalidate after sidecar mutation) is identical across them.
 *
 * Cache-key convention: `['contact', '<tabKey>', contactId, ...extras]`.
 * A blanket `qc.invalidateQueries({ queryKey: ['contact'] })` refreshes
 * every open tab; per-tab invalidation works via the `<tabKey>` segment.
 */

import { useQuery } from '@tanstack/react-query'
import {
  fetchContactAuditLog,
  fetchContactCommunications,
  fetchContactSkills,
  fetchInstructorCourses,
  fetchStudentParticipations,
  fetchContactBookingCount,
  fetchOrgMembers,
  listRelationships,
  type ContactAuditRow,
  type ContactCommunicationRow,
  type ContactSkillRow,
  type ContactCourseAssignment,
  type ContactCourseParticipation,
  type OrgMemberRow,
} from '@/lib/contactQueries'
import { fetchAvailability, type AvailabilityRow } from '@/lib/queries'
import type { ContactRelationship } from '@/types/contacts'

export function useContactAuditLog(contactId: string | null | undefined, limit: number = 100) {
  return useQuery<ContactAuditRow[], Error>({
    queryKey: ['contact', 'audit', contactId, limit],
    queryFn: () => fetchContactAuditLog(contactId as string, limit),
    enabled: Boolean(contactId),
  })
}

export function useContactCommunications(contactId: string | null | undefined) {
  return useQuery<ContactCommunicationRow[], Error>({
    queryKey: ['contact', 'communications', contactId],
    queryFn: () => fetchContactCommunications(contactId as string),
    enabled: Boolean(contactId),
  })
}

export function useContactSkills(contactId: string | null | undefined) {
  return useQuery<ContactSkillRow[], Error>({
    queryKey: ['contact', 'skills', contactId],
    queryFn: () => fetchContactSkills(contactId as string),
    enabled: Boolean(contactId),
  })
}

export function useInstructorCourses(
  contactId: string | null | undefined,
  enabled: boolean = true,
) {
  return useQuery<ContactCourseAssignment[], Error>({
    queryKey: ['contact', 'instructorCourses', contactId],
    queryFn: () => fetchInstructorCourses(contactId as string),
    enabled: enabled && Boolean(contactId),
  })
}

export function useStudentParticipations(
  contactId: string | null | undefined,
  enabled: boolean = true,
) {
  return useQuery<ContactCourseParticipation[], Error>({
    queryKey: ['contact', 'studentParticipations', contactId],
    queryFn: () => fetchStudentParticipations(contactId as string),
    enabled: enabled && Boolean(contactId),
  })
}

export function useContactBookingCount(contactId: string | null | undefined) {
  return useQuery<number, Error>({
    queryKey: ['contact', 'bookingCount', contactId],
    queryFn: () => fetchContactBookingCount(contactId as string),
    enabled: Boolean(contactId),
  })
}

export function useOrgMembers(orgId: string | null | undefined) {
  return useQuery<OrgMemberRow[], Error>({
    queryKey: ['contact', 'orgMembers', orgId],
    queryFn: () => fetchOrgMembers(orgId as string),
    enabled: Boolean(orgId),
  })
}

export function useContactRelationships(contactId: string | null | undefined) {
  return useQuery<ContactRelationship[], Error>({
    queryKey: ['contact', 'relationships', contactId],
    queryFn: () => listRelationships(contactId as string),
    enabled: Boolean(contactId),
  })
}

export function useContactAvailability(contactId: string | null | undefined) {
  return useQuery<AvailabilityRow[], Error>({
    queryKey: ['contact', 'availability', contactId],
    queryFn: () => fetchAvailability(contactId as string),
    enabled: Boolean(contactId),
  })
}
