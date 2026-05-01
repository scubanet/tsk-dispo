import { describe, expect, it } from 'vitest'
import { normalizeStatus, normalizeCourseCode } from '@/lib/normalize'

describe('normalizeStatus', () => {
  it.each([
    ['sicher ', 'confirmed'],
    ['sicher',  'confirmed'],
    ['Sicher',  'confirmed'],
    ['evtl.',   'tentative'],
    ['evtl. ',  'tentative'],
    ['evtl',    'tentative'],
    ['CXL',     'cancelled'],
    ['cxl',     'cancelled'],
  ] as const)('normalizes %j to %j', (input, expected) => {
    expect(normalizeStatus(input)).toBe(expected)
  })

  it('returns null for unknown values', () => {
    expect(normalizeStatus('???')).toBeNull()
  })
})

describe('normalizeCourseCode', () => {
  it.each([
    ['DRY',  'DRY'],
    ['Dry ', 'DRY'],
    ['dry',  'DRY'],
    ['OWD',  'OWD'],
    ['OWD ', 'OWD'],
  ] as const)('normalizes %j to %j', (input, expected) => {
    expect(normalizeCourseCode(input)).toBe(expected)
  })
})
