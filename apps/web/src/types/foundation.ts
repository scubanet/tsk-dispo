/**
 * ATOLL Foundation — Core types
 *
 * The data model is **cert-first**: a person has 0..n immutable Certifications.
 * Tier and teaching permissions are derived (see /lib/tier.ts and /lib/teaching-rules.ts).
 *
 * Three concepts kept strictly separate:
 *   1. Certification — what a person *is* (audit record)
 *   2. Tier          — highest level reached (derived)
 *   3. canTeach      — what a person *may teach* (derived from certs)
 */

// ─────────────────────────── Brevet codes ──────────────────────────────

export type DiverBrevetCode =
  | 'SCUBA_DIVER'
  | 'OWD'
  | 'OWD_DRY'              // OWD bundle with Dry Suit specialty
  | 'AOWD'
  | 'RESCUE_DIVER'
  | 'MASTER_SCUBA_DIVER'

export type ProBrevetCode =
  | 'DM'                   // Divemaster
  | 'OWSI'                 // Open Water Scuba Instructor
  | 'IDC_STAFF'            // IDC Staff Instructor
  | 'MI'                   // Master Instructor
  | 'CD'                   // Course Director

/**
 * Specialty teaching permits — granted via SPEI Workshop.
 * OWSI auto-includes AWARE / DEBRIS / PPB.
 * Equipment & O2 can be taught by DM with permit (PADI exception).
 */
export type SpecialtyTeacherCode =
  // Auto-included with OWSI
  | 'SPEC_TEACHER_AWARE'
  | 'SPEC_TEACHER_DEBRIS'
  | 'SPEC_TEACHER_PPB'

  // Requires SPEI workshop
  | 'SPEC_TEACHER_NIGHT'
  | 'SPEC_TEACHER_WRECK'
  | 'SPEC_TEACHER_DEEP'
  | 'SPEC_TEACHER_NAV'
  | 'SPEC_TEACHER_PHOTO'
  | 'SPEC_TEACHER_VIDEO'
  | 'SPEC_TEACHER_DRY_SUIT'
  | 'SPEC_TEACHER_NITROX'
  | 'SPEC_TEACHER_EQUIPMENT'   // DM is enough (PADI exception)
  | 'SPEC_TEACHER_O2'          // DM is enough (PADI exception)
  | 'SPEC_TEACHER_SEARCH_RECOVERY'
  | 'SPEC_TEACHER_BOAT'
  | 'SPEC_TEACHER_DRIFT'
  | 'SPEC_TEACHER_MULTILEVEL'
  | 'SPEC_TEACHER_ALTITUDE'
  | 'SPEC_TEACHER_RIVER'
  | 'SPEC_TEACHER_ICE'
  | 'SPEC_TEACHER_CAVERN'
  | 'SPEC_TEACHER_SELF_RELIANT'
  | 'SPEC_TEACHER_REBREATHER'

export type AdditionalCertCode =
  | 'EFRI'                 // Emergency First Response Instructor (24 mo. validity)
  | 'EFR'                  // Emergency First Response (24 mo. validity)
  | 'MEDICAL'              // Medical statement (12 mo. validity)

export type BrevetCode =
  | DiverBrevetCode
  | ProBrevetCode
  | SpecialtyTeacherCode
  | AdditionalCertCode

export type CertCategory = 'diver' | 'pro' | 'specialty-teacher' | 'additional'

export type CertAgency = 'PADI' | 'SSI' | 'CMAS' | 'ANDI' | 'TecRec' | 'Other'

export type CertOrigin = 'tsk-zurich' | 'tsk-bern' | 'extern' | 'auto-with-owsi'

export interface Certification {
  id: string
  personId: string
  agency: CertAgency
  category: CertCategory
  code: BrevetCode
  number: string
  issuedAt: string                // ISO date
  issuedBy?: {
    personId: string
    name: string
    proTier: ProTier
  }
  origin: CertOrigin
  evidence?: { url: string; filename: string }[]
  notes?: string
  invalidatedAt?: string          // Soft-delete timestamp
  invalidatedReason?: string
  createdAt: string
}

// ─────────────────────────────── Tiers ────────────────────────────────

export type DiverTier =
  | 'Anfänger'             // No diver certs at all
  | 'Schüler'              // Currently enrolled in a course
  | 'Scuba Diver'
  | 'OWD'
  | 'AOWD'
  | 'Rescue Diver'
  | 'Master Scuba Diver'

export type ProTier =
  | null
  | 'DM'
  | 'OWSI'
  | 'IDC Staff'
  | 'MI'
  | 'CD'

// ───────────────────────────── Course types ───────────────────────────

export type SpecialtyCode =
  | 'NIGHT' | 'WRECK' | 'DEEP' | 'NAV' | 'PHOTO' | 'VIDEO'
  | 'DRY_SUIT' | 'NITROX' | 'EQUIPMENT' | 'O2'
  | 'SEARCH_RECOVERY' | 'BOAT' | 'DRIFT' | 'MULTILEVEL'
  | 'ALTITUDE' | 'RIVER' | 'ICE' | 'CAVERN'
  | 'SELF_RELIANT' | 'REBREATHER'
  | 'AWARE' | 'DEBRIS' | 'PPB'    // Auto-included with OWSI

/**
 * SPEI is ALWAYS the workshop course type (CD only).
 * NEVER use "SPEI" as a person property — that's `SPEC_TEACHER_*` instead.
 */
export type CourseType =
  | 'OWD' | 'OWD_DRY' | 'AOWD' | 'RESCUE'
  | 'DSD' | 'TSCHIGGI'
  | { type: 'SPECIALTY'; specialty: SpecialtyCode }    // Student specialty course
  | 'DM' | 'IDC' | 'IDC_STAFF'
  | { type: 'SPEI'; specialty: SpecialtyCode }         // Teacher workshop, CD only
  | 'EFR' | 'EFR_REFRESHER'

// ─────────────────────────────── Person ───────────────────────────────

export interface Person {
  id: string
  firstName: string
  lastName: string
  name: string                    // Cached "first last"
  email?: string | null
  phone?: string | null
  birthday?: string | null
  certifications: Certification[]
  // Other fields (address, languages, etc.) live in the existing people table.
}

// ─────────────────────────── canTeach result ─────────────────────────

export type TeachResult =
  | { canTeach: true }
  | { canTeach: false; reason: string }

// ────────────────────────── Compensation ──────────────────────────────

export type PayeeRate = 'instructor' | 'dm' | 'shop_staff' | 'cd'

export interface CompensationResult {
  totalPoints: number
  rate: number                    // CHF per point
  chf: number
  payeeRate: PayeeRate
}
