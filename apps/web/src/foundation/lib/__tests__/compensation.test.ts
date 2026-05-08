import { describe, expect, it } from 'vitest'
import { calculateCompensation, payeeRateFromProTier, DEFAULT_RATES } from '../compensation'

describe('calculateCompensation', () => {
  it('uses default rate for instructor', () => {
    const result = calculateCompensation({ totalPoints: 10, payeeRate: 'instructor' })
    expect(result.rate).toBe(28)
    expect(result.chf).toBe(280)
  })

  it('uses default rate for dm', () => {
    const result = calculateCompensation({ totalPoints: 10, payeeRate: 'dm' })
    expect(result.rate).toBe(14)
    expect(result.chf).toBe(140)
  })

  it('uses default rate for shop_staff', () => {
    const result = calculateCompensation({ totalPoints: 10, payeeRate: 'shop_staff' })
    expect(result.rate).toBe(12)
    expect(result.chf).toBe(120)
  })

  it('uses default rate for cd', () => {
    const result = calculateCompensation({ totalPoints: 10, payeeRate: 'cd' })
    expect(result.rate).toBe(35)
    expect(result.chf).toBe(350)
  })

  it('rounds to 2 decimal places', () => {
    const result = calculateCompensation({ totalPoints: 1.333, payeeRate: 'instructor' })
    expect(result.chf).toBe(37.32)   // 1.333 * 28 = 37.324, rounded to 37.32
  })

  it('accepts custom rate overrides', () => {
    const result = calculateCompensation({
      totalPoints: 10,
      payeeRate: 'instructor',
      rates: { instructor: 30 },
    })
    expect(result.rate).toBe(30)
    expect(result.chf).toBe(300)
  })

  it('falls back to default when override key is missing', () => {
    const result = calculateCompensation({
      totalPoints: 10,
      payeeRate: 'cd',
      rates: { instructor: 30 },
    })
    expect(result.rate).toBe(DEFAULT_RATES.cd)
    expect(result.chf).toBe(350)
  })

  it('handles zero points', () => {
    const result = calculateCompensation({ totalPoints: 0, payeeRate: 'instructor' })
    expect(result.chf).toBe(0)
  })
})

describe('payeeRateFromProTier', () => {
  it('CD → cd', () => expect(payeeRateFromProTier('CD')).toBe('cd'))
  it('DM → dm', () => expect(payeeRateFromProTier('DM')).toBe('dm'))
  it('OWSI → instructor', () => expect(payeeRateFromProTier('OWSI')).toBe('instructor'))
  it('IDC Staff → instructor', () => expect(payeeRateFromProTier('IDC Staff')).toBe('instructor'))
  it('MI → instructor', () => expect(payeeRateFromProTier('MI')).toBe('instructor'))
  it('null → shop_staff', () => expect(payeeRateFromProTier(null)).toBe('shop_staff'))
})
