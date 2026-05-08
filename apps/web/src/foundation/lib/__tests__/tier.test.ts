import { describe, expect, it } from 'vitest'
import {
  deriveDiverTier,
  deriveProTier,
  displayTier,
  compareProTier,
  isActive,
} from '../tier'
import type { Certification } from '@/types/foundation'

// ──────────────────────── Test fixtures ────────────────────────

function cert(overrides: Partial<Certification>): Certification {
  return {
    id: overrides.id ?? `c-${Math.random()}`,
    personId: overrides.personId ?? 'p-1',
    agency: overrides.agency ?? 'PADI',
    category: overrides.category ?? 'diver',
    code: overrides.code ?? 'OWD',
    number: overrides.number ?? '12345',
    issuedAt: overrides.issuedAt ?? '2024-01-01',
    origin: overrides.origin ?? 'extern',
    createdAt: overrides.createdAt ?? '2024-01-01T00:00:00Z',
    ...overrides,
  } as Certification
}

// ──────────────────────── isActive ────────────────────────

describe('isActive', () => {
  it('returns true when invalidatedAt is undefined', () => {
    expect(isActive(cert({}))).toBe(true)
  })

  it('returns false when invalidatedAt is set', () => {
    expect(isActive(cert({ invalidatedAt: '2024-06-01T00:00:00Z' }))).toBe(false)
  })
})

// ──────────────────────── deriveDiverTier ────────────────────────

describe('deriveDiverTier', () => {
  it('returns Anfänger for empty list', () => {
    expect(deriveDiverTier([])).toBe('Anfänger')
  })

  it('returns Schüler when enrolled and no certs', () => {
    expect(deriveDiverTier([], { isCurrentlyEnrolled: true })).toBe('Schüler')
  })

  it('returns OWD for OWD cert', () => {
    expect(deriveDiverTier([cert({ category: 'diver', code: 'OWD' })])).toBe('OWD')
  })

  it('returns OWD for OWD_DRY (bundle counts as OWD tier)', () => {
    expect(deriveDiverTier([cert({ category: 'diver', code: 'OWD_DRY' })])).toBe('OWD')
  })

  it('returns highest tier when multiple certs present', () => {
    expect(
      deriveDiverTier([
        cert({ category: 'diver', code: 'OWD' }),
        cert({ category: 'diver', code: 'AOWD' }),
        cert({ category: 'diver', code: 'RESCUE_DIVER' }),
      ])
    ).toBe('Rescue Diver')
  })

  it('returns Master Scuba Diver as the apex', () => {
    expect(
      deriveDiverTier([
        cert({ category: 'diver', code: 'AOWD' }),
        cert({ category: 'diver', code: 'MASTER_SCUBA_DIVER' }),
        cert({ category: 'diver', code: 'RESCUE_DIVER' }),
      ])
    ).toBe('Master Scuba Diver')
  })

  it('ignores invalidated certs', () => {
    expect(
      deriveDiverTier([
        cert({ category: 'diver', code: 'AOWD', invalidatedAt: '2024-06-01T00:00:00Z' }),
        cert({ category: 'diver', code: 'OWD' }),
      ])
    ).toBe('OWD')
  })

  it('ignores non-diver certs', () => {
    expect(
      deriveDiverTier([
        cert({ category: 'pro', code: 'OWSI' }),
        cert({ category: 'diver', code: 'SCUBA_DIVER' }),
      ])
    ).toBe('Scuba Diver')
  })
})

// ──────────────────────── deriveProTier ────────────────────────

describe('deriveProTier', () => {
  it('returns null for non-pros', () => {
    expect(deriveProTier([])).toBe(null)
    expect(deriveProTier([cert({ category: 'diver', code: 'OWD' })])).toBe(null)
  })

  it('returns DM for DM cert', () => {
    expect(deriveProTier([cert({ category: 'pro', code: 'DM' })])).toBe('DM')
  })

  it('returns highest tier when multiple pro certs', () => {
    expect(
      deriveProTier([
        cert({ category: 'pro', code: 'DM' }),
        cert({ category: 'pro', code: 'OWSI' }),
        cert({ category: 'pro', code: 'IDC_STAFF' }),
      ])
    ).toBe('IDC Staff')
  })

  it('returns CD as apex', () => {
    expect(
      deriveProTier([
        cert({ category: 'pro', code: 'OWSI' }),
        cert({ category: 'pro', code: 'MI' }),
        cert({ category: 'pro', code: 'CD' }),
      ])
    ).toBe('CD')
  })

  it('ignores invalidated pro certs', () => {
    expect(
      deriveProTier([
        cert({ category: 'pro', code: 'CD', invalidatedAt: '2024-06-01T00:00:00Z' }),
        cert({ category: 'pro', code: 'OWSI' }),
      ])
    ).toBe('OWSI')
  })
})

// ──────────────────────── displayTier ────────────────────────

describe('displayTier', () => {
  it('prefers pro tier over diver tier', () => {
    expect(
      displayTier([
        cert({ category: 'diver', code: 'OWD' }),
        cert({ category: 'pro', code: 'OWSI' }),
      ])
    ).toBe('OWSI')
  })

  it('falls back to diver tier when no pro tier', () => {
    expect(displayTier([cert({ category: 'diver', code: 'AOWD' })])).toBe('AOWD')
  })

  it('returns Anfänger when no certs at all', () => {
    expect(displayTier([])).toBe('Anfänger')
  })
})

// ──────────────────────── compareProTier ────────────────────────

describe('compareProTier', () => {
  it('null is the lowest', () => {
    expect(compareProTier(null, 'DM')).toBeLessThan(0)
    expect(compareProTier('DM', null)).toBeGreaterThan(0)
  })

  it('CD > MI > IDC Staff > OWSI > DM', () => {
    expect(compareProTier('CD', 'MI')).toBeGreaterThan(0)
    expect(compareProTier('MI', 'IDC Staff')).toBeGreaterThan(0)
    expect(compareProTier('IDC Staff', 'OWSI')).toBeGreaterThan(0)
    expect(compareProTier('OWSI', 'DM')).toBeGreaterThan(0)
  })

  it('returns 0 for same tier', () => {
    expect(compareProTier('OWSI', 'OWSI')).toBe(0)
  })
})
