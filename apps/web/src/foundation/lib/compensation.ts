/**
 * Compensation calculator — translates points × role-rate → CHF.
 *
 * Role rates (CHF per point):
 *   instructor = 28
 *   dm         = 14
 *   shop_staff = 12
 *   cd         = 35
 *
 * Rates can be overridden per call (e.g., from settings) — the defaults
 * encode the values the project owner uses today.
 */

import type { CompensationResult, PayeeRate } from '@/types/foundation'

export const DEFAULT_RATES: Record<PayeeRate, number> = {
  instructor: 28,
  dm: 14,
  shop_staff: 12,
  cd: 35,
}

export interface CompensationInput {
  totalPoints: number
  payeeRate: PayeeRate
  rates?: Partial<Record<PayeeRate, number>>
}

export function calculateCompensation(input: CompensationInput): CompensationResult {
  const { totalPoints, payeeRate } = input
  const rate = input.rates?.[payeeRate] ?? DEFAULT_RATES[payeeRate]
  const chf = Math.round(totalPoints * rate * 100) / 100   // 2 decimal places
  return { totalPoints, rate, chf, payeeRate }
}

/**
 * Convenience: derive the payee rate from a person's pro tier.
 * - CD          → 'cd'
 * - DM          → 'dm'
 * - OWSI / IDC Staff / MI → 'instructor'
 * - everything else → 'shop_staff'
 */
import type { ProTier } from '@/types/foundation'

export function payeeRateFromProTier(tier: ProTier): PayeeRate {
  switch (tier) {
    case 'CD':
      return 'cd'
    case 'DM':
      return 'dm'
    case 'OWSI':
    case 'IDC Staff':
    case 'MI':
      return 'instructor'
    default:
      return 'shop_staff'
  }
}
