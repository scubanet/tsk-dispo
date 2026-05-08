/**
 * Teaching permissions — `canTeach()` central business logic.
 *
 * Returns:
 *   { canTeach: true }
 *   { canTeach: false, reason: 'localized message' }
 *
 * The dispatcher UI surfaces `reason` as a *warning banner*, not a block —
 * the user can override (per locked decision: warning, not block).
 *
 * PADI exceptions:
 *   - Equipment & O2 specialty: DM with permit can teach (not just OWSI)
 *   - OWSI auto-includes AWARE / DEBRIS / PPB specialty teaching permits
 *   - SPEI workshops: CD only
 *   - DM courses: OWSI minimum
 *   - IDC: IDC Staff minimum
 *   - IDC Staff: MI minimum (only MI/CD can train staff)
 *   - DSD/Tschiggi: any active OWSI+
 */

import type {
  Certification,
  CourseType,
  TeachResult,
  SpecialtyCode,
  SpecialtyTeacherCode,
  ProTier,
} from '@/types/foundation'
import { activeOnly, deriveProTier, compareProTier } from './tier'

// ──────────────────────── Helpers ────────────────────────

function hasActiveCode(certs: Certification[], code: string): boolean {
  return activeOnly(certs).some((c) => c.code === code)
}

function isAtLeastTier(certs: Certification[], minimum: ProTier): boolean {
  return compareProTier(deriveProTier(certs), minimum) >= 0
}

function specialtyToTeacherCode(specialty: SpecialtyCode): SpecialtyTeacherCode {
  return `SPEC_TEACHER_${specialty}` as SpecialtyTeacherCode
}

const DM_TEACHABLE_SPECIALTIES: SpecialtyCode[] = ['EQUIPMENT', 'O2']

// ──────────────────────── canTeach ────────────────────────

export function canTeach(
  certs: Certification[],
  course: CourseType
): TeachResult {
  // Discriminate compound CourseType objects first
  if (typeof course === 'object') {
    if (course.type === 'SPECIALTY') {
      return canTeachSpecialty(certs, course.specialty)
    }
    if (course.type === 'SPEI') {
      return canTeachSpei(certs)
    }
  }

  // String course types
  switch (course) {
    case 'OWD':
    case 'OWD_DRY':
    case 'ADVENTURE_DIVER':
    case 'AOWD':
    case 'AOWD_DRY':
    case 'RESCUE':
    case 'MASTER_SCUBA_DIVER':
    case 'DSD':
    case 'TSCHIGGI':
    case 'SEAL_TEAM':
    case 'SNORKELING':
    case 'ADV_SNORKELING':
    case 'REACTIVATE':
      return requireProTier(certs, 'OWSI', course)

    case 'DM':
      return requireProTier(certs, 'OWSI', 'DM-Kurs')

    case 'IDC':
      return requireProTier(certs, 'IDC Staff', 'IDC')

    case 'IDC_STAFF':
      return requireProTier(certs, 'MI', 'IDC Staff Training')

    case 'EFR':
    case 'EFR_REFRESHER':
      return canTeachEfr(certs)

    case 'EFR_IT':
      // EFR Instructor Trainer training — only EFR ITs (or higher) can train new EFRIs.
      // Pragmatic check: requires EFRI + CD tier.
      if (!hasActiveCode(certs, 'EFRI')) {
        return { canTeach: false, reason: 'EFR-IT-Kurse erfordern EFRI-Zertifizierung.' }
      }
      return requireProTier(certs, 'CD', 'EFR Instructor Trainer')

    default:
      // Exhaustive check — TS will flag unhandled cases at compile time
      return assertExhaustive(course)
  }
}

// ──────────────────────── Subroutines ────────────────────────

function requireProTier(
  certs: Certification[],
  minimum: NonNullable<ProTier>,
  courseLabel: string
): TeachResult {
  if (isAtLeastTier(certs, minimum)) return { canTeach: true }
  const current = deriveProTier(certs) ?? 'kein Pro-Brevet'
  return {
    canTeach: false,
    reason: `${courseLabel} darf erst ab ${minimum} unterrichtet werden (aktuell: ${current}).`,
  }
}

function canTeachSpecialty(
  certs: Certification[],
  specialty: SpecialtyCode
): TeachResult {
  const tier = deriveProTier(certs)
  if (!tier) {
    return {
      canTeach: false,
      reason: 'Specialty-Kurse erfordern mindestens DM mit passendem Permit.',
    }
  }

  // PADI exception: DM with permit can teach Equipment / O2
  if (DM_TEACHABLE_SPECIALTIES.includes(specialty)) {
    if (hasActiveCode(certs, specialtyToTeacherCode(specialty))) {
      return { canTeach: true }
    }
    return {
      canTeach: false,
      reason: `Specialty "${specialty}" erfordert SPEI-Workshop (DM oder höher mit Permit).`,
    }
  }

  // Standard: OWSI minimum + specialty-teacher permit
  if (compareProTier(tier, 'OWSI') < 0) {
    return {
      canTeach: false,
      reason: `Specialty "${specialty}" darf erst ab OWSI unterrichtet werden (aktuell: ${tier}).`,
    }
  }

  if (!hasActiveCode(certs, specialtyToTeacherCode(specialty))) {
    return {
      canTeach: false,
      reason: `Specialty "${specialty}" erfordert SPEI-Workshop (Teaching Permit fehlt).`,
    }
  }

  return { canTeach: true }
}

function canTeachSpei(certs: Certification[]): TeachResult {
  // SPEI workshops train OWSIs to teach a specialty — CD only.
  if (isAtLeastTier(certs, 'CD')) return { canTeach: true }
  const current = deriveProTier(certs) ?? 'kein Pro-Brevet'
  return {
    canTeach: false,
    reason: `SPEI-Workshops dürfen nur von Course Directors gehalten werden (aktuell: ${current}).`,
  }
}

function canTeachEfr(certs: Certification[]): TeachResult {
  if (hasActiveCode(certs, 'EFRI')) return { canTeach: true }
  return {
    canTeach: false,
    reason: 'EFR-Kurse erfordern aktive EFRI-Zertifizierung.',
  }
}

function assertExhaustive(value: never): never {
  throw new Error(`Unhandled CourseType: ${JSON.stringify(value)}`)
}
