/**
 * Color helpers — deterministic avatar colors and course-type colors.
 *
 * Rules:
 *   - Avatar colors are deterministic: same id → same color, every render.
 *   - Avatar palette excludes red (red is reserved for danger/alerts).
 *   - Course-type colors map directly to brand tokens.
 */

import type { CourseType } from '@/types/foundation'

// ──────────────────────── Avatar palette ────────────────────────
// Excludes red. Order is irrelevant — hash determines the slot.

export const AVATAR_PALETTE = [
  'var(--brand-blue)',
  'var(--brand-teal)',
  'var(--brand-amber)',
  'var(--brand-purple)',
  'var(--brand-pink)',
  'var(--brand-deep)',
  'var(--brand-blue-800)',
  'var(--brand-teal-800)',
] as const

/**
 * Deterministic hash-based color picker. Same `id` always returns the same
 * palette slot. Stable across reloads, language switches, and reorderings.
 */
export function avatarColor(id: string | null | undefined): string {
  if (!id) return AVATAR_PALETTE[0]
  let hash = 0
  for (let i = 0; i < id.length; i++) {
    hash = (hash * 31 + id.charCodeAt(i)) >>> 0
  }
  return AVATAR_PALETTE[hash % AVATAR_PALETTE.length]
}

// ──────────────────────── Course-type color ────────────────────────

/**
 * Course-type accent color. Used for course pills, calendar markers, list dots.
 * Returns a CSS variable reference — never a literal hex.
 */
export function courseTypeColor(course: CourseType): string {
  if (typeof course === 'object') {
    if (course.type === 'SPECIALTY') return 'var(--brand-teal)'
    if (course.type === 'SPEI') return 'var(--brand-pink)'
  }

  switch (course) {
    case 'OWD':
    case 'OWD_DRY':
    case 'ADVENTURE_DIVER':
    case 'AOWD':
    case 'AOWD_DRY':
      return 'var(--brand-blue)'
    case 'RESCUE':
    case 'MASTER_SCUBA_DIVER':
      return 'var(--brand-teal)'
    case 'DSD':
    case 'TSCHIGGI':
    case 'SEAL_TEAM':
    case 'SNORKELING':
    case 'ADV_SNORKELING':
    case 'REACTIVATE':
      return 'var(--brand-amber)'
    case 'DM':
      return 'var(--brand-purple)'
    case 'IDC':
    case 'IDC_STAFF':
      return 'var(--brand-pink)'
    case 'EFR':
    case 'EFR_REFRESHER':
    case 'EFR_IT':
      return 'var(--brand-red)'
    default:
      return 'var(--brand-gray-60)'
  }
}

// ──────────────────────── Pro-tier color ────────────────────────

import type { ProTier } from '@/types/foundation'

/**
 * Pure cert-first pro-tier color (CD / MI / IDC Staff / OWSI / DM / null).
 * Hierarchy goes pink → purple → blue-800 → blue → teal → gray.
 */
export function proTierColor(tier: ProTier): string {
  switch (tier) {
    case 'CD': return 'var(--brand-pink)'
    case 'MI': return 'var(--brand-purple)'
    case 'IDC Staff': return 'var(--brand-blue-800)'
    case 'OWSI': return 'var(--brand-blue)'
    case 'DM': return 'var(--brand-teal)'
    default: return 'var(--brand-gray-60)'
  }
}

/**
 * Legacy padi_level string → avatar color.
 * Handles all values used in the `instructors.padi_level` column:
 *   CD, MI, IDC Staff, OWSI, MSDT, AI, DM, Shop Staff, Andere
 *
 * MSDT / AI both collapse to OWSI-blue (in cert-first they're OWSIs).
 * Shop Staff gets amber to distinguish from Andere (gray).
 */
export function padiLevelColor(level: string | null | undefined): string {
  switch (level) {
    case 'CD': return 'var(--brand-pink)'
    case 'MI': return 'var(--brand-purple)'
    case 'IDC Staff': return 'var(--brand-blue-800)'
    case 'OWSI':
    case 'MSDT':
    case 'AI':
      return 'var(--brand-blue)'
    case 'DM': return 'var(--brand-teal)'
    case 'Shop Staff': return 'var(--brand-amber)'
    default: return 'var(--brand-gray-80)'   // 'Andere' or unknown
  }
}
