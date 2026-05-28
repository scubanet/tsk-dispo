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
  PhoneJsonbEntry,
  AddressJsonbEntry,
} from '@/types/contactProperties'

interface RawContactWithRelations {
  id: string
  kind: 'person' | 'organization'
  display_name: string
  first_name: string | null
  last_name: string | null
  birth_date: string | null
  primary_email: string | null
  phones: PhoneJsonbEntry[] | null
  addresses: AddressJsonbEntry[] | null
  languages: string[] | null
  source: string | null
  created_at: string
  updated_at: string
  owner_id: string | null
  tags: string[] | null
  instructor: InstructorSidecar | null
  student: StudentSidecar | null
  organization: OrgSidecar | null
}

interface RawBalance {
  balance_chf: number | null
  last_movement_date: string | null
}

export function useContactWithProperties(contactId: string) {
  return useQuery({
    queryKey: ['contact-properties', contactId],
    queryFn: async (): Promise<ContactWithProperties> => {
      // Main contact + sidecars (single query with explicit FK constraint
      // names to disambiguate contact_organization's two FKs to contacts).
      const contactRes = await supabase
        .from('contacts')
        .select(`
          id, kind, display_name, first_name, last_name, birth_date,
          primary_email, phones, addresses, languages, source,
          created_at, updated_at, owner_id, tags,
          instructor:contact_instructor!contact_instructor_contact_id_fkey(padi_level, padi_pro_number, active),
          student:contact_student!contact_student_contact_id_fkey(pipeline_stage, intake_status, highest_brevet),
          organization:contact_organization!contact_organization_contact_id_fkey(org_kind)
        `)
        .eq('id', contactId)
        .single()
      if (contactRes.error) throw new Error(contactRes.error.message)

      // Balance separat — v_contact_balance hat keine eindeutige FK-Beziehung
      // zu contacts (mehrfach via instructor + account_movements verkettet),
      // PostgREST kann das Embedding nicht auflösen. Daher ein zweiter Hit.
      // maybeSingle() weil Contacts ohne Instructor-Sidecar keine Saldo-Row haben.
      const balanceRes = await supabase
        .from('v_contact_balance')
        .select('balance_chf, last_movement_date')
        .eq('contact_id', contactId)
        .maybeSingle()
      if (balanceRes.error) throw new Error(balanceRes.error.message)

      return normalize(
        contactRes.data as unknown as RawContactWithRelations,
        balanceRes.data as RawBalance | null,
      )
    },
    enabled: !!contactId,
  })
}

function normalize(
  raw: RawContactWithRelations,
  balance: RawBalance | null,
): ContactWithProperties {
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
    phones: raw.phones ?? [],
    addresses: raw.addresses ?? [],
    languages: raw.languages ?? [],
    source: raw.source,
    created_at: raw.created_at,
    updated_at: raw.updated_at,
    owner_id: raw.owner_id,
    tags: raw.tags ?? [],
    instructor: raw.instructor,
    student: raw.student,
    organization: raw.organization,
    balance_chf: balance?.balance_chf ?? null,
    last_movement_date: balance?.last_movement_date ?? null,
    roles,
  }
}
