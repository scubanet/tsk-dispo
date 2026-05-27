// apps/web/src/hooks/useContactWithProperties.ts
//
// Phase G Phase 3 — Lädt Contact + Tags + Sidecars (instructor/student/organization)
// + Saldo aus v_contact_balance in einem React-Query.
// Org-Memberships werden separat via contact_relationships geladen.
import { useQuery } from '@tanstack/react-query'
import { supabase } from '@/lib/supabase'
import type {
  ContactWithProperties,
  ContactRoleDerived,
  InstructorSidecar,
  StudentSidecar,
  OrgSidecar,
} from '@/types/contactProperties'

interface RawContactWithRelations {
  id: string
  kind: 'person' | 'organization'
  display_name: string
  first_name: string | null
  last_name: string | null
  birth_date: string | null
  primary_email: string | null
  primary_phone: string | null
  primary_language: string | null
  source: string | null
  created_at: string
  updated_at: string
  owner_id: string | null
  tags: string[] | null
  instructor: InstructorSidecar | null
  student: StudentSidecar | null
  organization: OrgSidecar | null
  balance: { balance_chf: number; last_movement_date: string | null } | null
}

export function useContactWithProperties(contactId: string) {
  return useQuery({
    queryKey: ['contact-properties', contactId],
    queryFn: async (): Promise<ContactWithProperties> => {
      const { data, error } = await supabase
        .from('contacts')
        .select(`
          id, kind, display_name, first_name, last_name, birth_date,
          primary_email, primary_phone, primary_language, source,
          created_at, updated_at, owner_id, tags,
          instructor:contact_instructor!contact_instructor_contact_id_fkey(padi_level, padi_pro_number, member_status, active),
          student:contact_student!contact_student_contact_id_fkey(pipeline_stage, intake_status, current_level),
          organization:contact_organization!contact_organization_contact_id_fkey(legal_name, trading_name, category),
          balance:v_contact_balance(balance_chf, last_movement_date)
        `)
        .eq('id', contactId)
        .single()

      if (error) throw new Error(error.message)
      return normalize(data as unknown as RawContactWithRelations)
    },
    enabled: !!contactId,
  })
}

function normalize(raw: RawContactWithRelations): ContactWithProperties {
  // Roles derived from sidecar presence.
  const roles: ContactRoleDerived[] = []
  if (raw.instructor) roles.push('instructor')
  if (raw.student) roles.push('student')
  if (raw.organization) roles.push('organization')

  return {
    id: raw.id,
    kind: raw.kind,
    display_name: raw.display_name,
    first_name: raw.first_name,
    last_name: raw.last_name,
    birth_date: raw.birth_date,
    primary_email: raw.primary_email,
    primary_phone: raw.primary_phone,
    primary_language: raw.primary_language,
    source: raw.source,
    created_at: raw.created_at,
    updated_at: raw.updated_at,
    owner_id: raw.owner_id,
    tags: raw.tags ?? [],
    instructor: raw.instructor,
    student: raw.student,
    organization: raw.organization,
    balance_chf: raw.balance?.balance_chf ?? null,
    last_movement_date: raw.balance?.last_movement_date ?? null,
    roles,
  }
}
