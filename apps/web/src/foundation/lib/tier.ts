/**
 * Tier derivation — pure functions over Certifications.
 *
 * The cert-first model holds *only* the immutable audit records.
 * `deriveDiverTier` and `deriveProTier` compute the highest active level
 * from a person's certifications. They never read DB columns.
 *
 * Active = invalidatedAt is null/undefined.
 */

import type {
  Certification,
  DiverTier,
  ProTier,
  DiverBrevetCode,
  ProBrevetCode,
} from '@/types/foundation'

// ──────────────────────── Active filter ────────────────────────

export function isActive(cert: Certification): boolean {
  return !cert.invalidatedAt
}

export function activeOnly(certs: Certification[]): Certification[] {
  return certs.filter(isActive)
}

// ──────────────────────── Diver tier ────────────────────────

const DIVER_TIER_ORDER: Record<DiverBrevetCode, DiverTier> = {
  SCUBA_DIVER: 'Scuba Diver',
  OWD: 'OWD',
  OWD_DRY: 'OWD',                  // dry-suit bundle still counts as OWD tier
  AOWD: 'AOWD',
  RESCUE_DIVER: 'Rescue Diver',
  MASTER_SCUBA_DIVER: 'Master Scuba Diver',
}

const DIVER_TIER_RANK: DiverTier[] = [
  'Anfänger',
  'Schüler',
  'Scuba Diver',
  'OWD',
  'AOWD',
  'Rescue Diver',
  'Master Scuba Diver',
]

/**
 * Highest active diver tier. Returns 'Anfänger' if no diver brevets exist.
 *
 * @param certs   All certifications for a person
 * @param options Optional flags
 * @param options.isCurrentlyEnrolled  If true and no brevets, return 'Schüler'
 */
export function deriveDiverTier(
  certs: Certification[],
  options?: { isCurrentlyEnrolled?: boolean }
): DiverTier {
  const diverCerts = activeOnly(certs).filter((c) => c.category === 'diver')

  if (diverCerts.length === 0) {
    return options?.isCurrentlyEnrolled ? 'Schüler' : 'Anfänger'
  }

  let highest: DiverTier = 'Anfänger'
  let highestRank = -1

  for (const cert of diverCerts) {
    const tier = DIVER_TIER_ORDER[cert.code as DiverBrevetCode]
    if (!tier) continue
    const rank = DIVER_TIER_RANK.indexOf(tier)
    if (rank > highestRank) {
      highest = tier
      highestRank = rank
    }
  }

  return highest
}

// ──────────────────────── Pro tier ────────────────────────

const PRO_TIER_RANK: ProTier[] = [null, 'DM', 'OWSI', 'IDC Staff', 'MI', 'CD']

const PRO_BREVET_TO_TIER: Record<ProBrevetCode, NonNullable<ProTier>> = {
  DM: 'DM',
  OWSI: 'OWSI',
  IDC_STAFF: 'IDC Staff',
  MI: 'MI',
  CD: 'CD',
}

/**
 * Highest active pro tier. Returns null if not a pro.
 *
 * Rank order: DM < OWSI < IDC Staff < MI < CD
 */
export function deriveProTier(certs: Certification[]): ProTier {
  const proCerts = activeOnly(certs).filter((c) => c.category === 'pro')
  if (proCerts.length === 0) return null

  let highest: ProTier = null
  let highestRank = 0

  for (const cert of proCerts) {
    const tier = PRO_BREVET_TO_TIER[cert.code as ProBrevetCode]
    if (!tier) continue
    const rank = PRO_TIER_RANK.indexOf(tier)
    if (rank > highestRank) {
      highest = tier
      highestRank = rank
    }
  }

  return highest
}

// ──────────────────────── Display ────────────────────────

/**
 * Formatted tier for UI display. Pro tier wins over diver tier when both exist
 * (a CD shouldn't be displayed as "OWD" just because they have an OWD cert).
 */
export function displayTier(certs: Certification[]): string {
  const pro = deriveProTier(certs)
  if (pro) return pro
  return deriveDiverTier(certs)
}

/**
 * Compare two pro tiers. Returns negative if a < b, positive if a > b, 0 equal.
 * null is the lowest.
 */
export function compareProTier(a: ProTier, b: ProTier): number {
  return PRO_TIER_RANK.indexOf(a) - PRO_TIER_RANK.indexOf(b)
}

export function compareDiverTier(a: DiverTier, b: DiverTier): number {
  return DIVER_TIER_RANK.indexOf(a) - DIVER_TIER_RANK.indexOf(b)
}
