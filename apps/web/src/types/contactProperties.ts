// apps/web/src/types/contactProperties.ts
//
// Phase G Phase 3 — Vollwertiges Contact-Profile-Modell für PropertiesSidebar.
// Enthält Contact-Base + 3 Sidecars + Tags + abgeleitete Roles + Saldo.
// Org-Memberships werden via contact_relationships separat geladen.

export interface InstructorSidecar {
  padi_level: string | null
  padi_pro_number: string | null
  active: boolean
}

export interface StudentSidecar {
  pipeline_stage: string | null
  intake_status: string | null
  highest_brevet: string | null
}

export interface OrgSidecar {
  org_kind: string | null
}

export type ContactRoleDerived = 'instructor' | 'student' | 'organization'

/**
 * Phones-JSONB-Entry — mirrors apps/web/src/types/contacts.ts PhoneEntry shape.
 * Wir typisieren hier minimal weil die Sidebar nur den primary-Eintrag liest.
 */
export interface PhoneJsonbEntry {
  label?: string
  e164: string
  primary?: boolean
}

/**
 * Address-JSONB-Entry — mirrors apps/web/src/types/contacts.ts AddressEntry.
 * Sidebar liest nur den primary-Eintrag und zeigt ihn read-only.
 */
export interface AddressJsonbEntry {
  label?: string
  street?: string
  postal?: string
  city?: string
  country?: string
  primary?: boolean
}

export interface ContactWithProperties {
  // Base
  id: string
  kind: 'person' | 'organization'
  display_name: string
  first_name: string | null
  last_name: string | null
  birth_date: string | null
  primary_email: string | null
  phones: PhoneJsonbEntry[]        // JSONB-Array auf contacts.phones
  addresses: AddressJsonbEntry[]   // JSONB-Array auf contacts.addresses
  languages: string[]              // TEXT[]-Array auf contacts.languages
  source: string | null
  created_at: string
  updated_at: string
  owner_id: string | null
  tags: string[]
  // Sidecars (nullable wenn der Contact diese Rolle nicht hat)
  instructor: InstructorSidecar | null
  student: StudentSidecar | null
  organization: OrgSidecar | null
  // Aggregierte (Phase 3)
  balance_chf: number | null
  last_movement_date: string | null
  // Derived
  roles: ContactRoleDerived[]
}
