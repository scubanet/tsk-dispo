/**
 * ATOLL Contacts — domain types.
 *
 * Mirrors the `contacts` schema (Phase A–C migrations).
 * All JSONB columns are typed as structured arrays.
 */

// ─────────────────────── Role & Kind enums ───────────────────────────

export type ContactKind = 'person' | 'organization'

export type ContactRole =
  | 'instructor'
  | 'student'
  | 'candidate'
  | 'organization_profile'
  | 'cd'
  | 'owner'
  | 'dispatcher'
  | 'newsletter'
  | 'supplier'
  | 'partner_rep'
  | 'authority'

export type RelationshipKind =
  | 'works_at'
  | 'owns'
  | 'spouse_of'
  | 'child_of'
  | 'parent_of'
  | 'referred_by'
  | 'subsidiary_of'
  | 'partner_of'
  | 'supplier_of'
  | 'student_of'
  | 'mentor_of'

// ─────────────────── JSONB sub-structures ────────────────────────────

export interface PhoneEntry {
  label: string         // 'mobile' | 'work' | 'home' | etc.
  e164: string          // e.g. '+41791234567'
  whatsapp?: boolean
  primary?: boolean
}

export interface EmailEntry {
  label: string         // 'work' | 'personal' | etc.
  email: string
  primary?: boolean
}

export interface AddressEntry {
  label: string         // 'home' | 'work' | etc.
  street?: string
  postal?: string
  city?: string
  country?: string
  primary?: boolean
}

// ───────────────────────── Core contact ──────────────────────────────

export interface Contact {
  id: string
  kind: ContactKind

  // Person fields (null for organizations)
  first_name?: string | null
  last_name?: string | null
  birth_date?: string | null
  gender?: string | null

  // Organization fields (null for persons)
  legal_name?: string | null
  trading_name?: string | null

  // Generated on DB side — always present
  display_name: string

  primary_email?: string | null
  emails: EmailEntry[]
  phones: PhoneEntry[]
  addresses: AddressEntry[]

  languages?: string[]
  roles: ContactRole[]
  tags?: string[]

  notes?: string | null
  owner_id?: string | null

  consent_marketing: boolean
  consent_marketing_at?: string | null
  consent_marketing_source?: string | null

  source?: string | null

  archived_at?: string | null
  merged_into_id?: string | null

  created_at: string
  updated_at: string
  created_by?: string | null
}

// ──────────────────────── Sidecar types ──────────────────────────────

export interface ContactInstructor {
  contact_id: string
  auth_user_id?: string | null
  padi_pro_number?: string | null
  padi_level?: string | null
  account_balance: number
  hourly_rate_chf?: number | null
  daily_rate_chf?: number | null
  active: boolean
  hire_date?: string | null
  termination_date?: string | null
  emergency_contact_name?: string | null
  emergency_contact_phone?: string | null
  notes_internal?: string | null
  created_at: string
  updated_at: string
}

export interface ContactStudent {
  contact_id: string
  pipeline_stage?: string | null
  lead_source?: string | null
  highest_brevet?: string | null
  intake_status?: string | null
  external_brevet_history?: unknown[]
  is_candidate: boolean
  candidate_target_level?: string | null
  medical_clearance_at?: string | null
  insurance_provider?: string | null
  created_at: string
  updated_at: string
}

export interface ContactOrganization {
  contact_id: string
  org_kind: string
  tax_id?: string | null
  billing_email?: string | null
  parent_org_id?: string | null
  contract_type?: string | null
  contract_until?: string | null
  payment_terms?: string | null
  created_at: string
  updated_at: string
}

// ──────────────────────── Relationships ──────────────────────────────

export interface ContactRelationship {
  id: string
  from_contact_id: string
  to_contact_id: string
  kind: RelationshipKind
  role_at_org?: string | null
  started_at?: string | null
  ended_at?: string | null
  is_primary: boolean
  notes?: string | null
  created_at: string
  // Populated by joins in the query layer
  from_contact?: Pick<Contact, 'id' | 'display_name' | 'kind' | 'roles'> | null
  to_contact?: Pick<Contact, 'id' | 'display_name' | 'kind' | 'roles'> | null
}

// ────────────────────── Composite view type ──────────────────────────

export interface ContactWithSidecars extends Contact {
  instructor?: ContactInstructor | null
  student?: ContactStudent | null
  organization?: ContactOrganization | null
}
