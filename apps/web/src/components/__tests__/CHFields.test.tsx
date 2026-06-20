import { describe, it, expect, vi } from 'vitest'
import { render, screen, fireEvent } from '@testing-library/react'
import {
  CHDateField, CHTimeField,
  isoToChDate, chToIsoDate, normalizeChTime,
} from '../CHFields'

describe('CH date helpers', () => {
  it('formats ISO → dd.MM.yyyy', () => {
    expect(isoToChDate('2026-06-18')).toBe('18.06.2026')
    expect(isoToChDate('')).toBe('')
    expect(isoToChDate(null)).toBe('')
  })

  it('parses dd.MM.yyyy → ISO (and variants)', () => {
    expect(chToIsoDate('18.06.2026')).toBe('2026-06-18')
    expect(chToIsoDate('1.6.2026')).toBe('2026-06-01')
    expect(chToIsoDate('18/06/2026')).toBe('2026-06-18')
    expect(chToIsoDate('18.06.26')).toBe('2026-06-18')
    expect(chToIsoDate('')).toBe('')
  })

  it('rejects impossible / malformed dates', () => {
    expect(chToIsoDate('31.02.2026')).toBeNull()
    expect(chToIsoDate('00.06.2026')).toBeNull()
    expect(chToIsoDate('hello')).toBeNull()
    expect(chToIsoDate('2026-06-18')).toBeNull() // ISO is not CH input
  })
})

describe('CH time helper', () => {
  it('normalizes to HH:mm 24h', () => {
    expect(normalizeChTime('9:5')).toBeNull()       // minutes must be 2 digits
    expect(normalizeChTime('09:05')).toBe('09:05')
    expect(normalizeChTime('9:05')).toBe('09:05')
    expect(normalizeChTime('0930')).toBe('09:30')
    expect(normalizeChTime('23:59')).toBe('23:59')
    expect(normalizeChTime('24:00')).toBeNull()
    expect(normalizeChTime('12:60')).toBeNull()
    expect(normalizeChTime('')).toBe('')
  })
})

describe('CHDateField component', () => {
  it('shows the ISO value as Swiss text and emits ISO on edit', () => {
    const onChange = vi.fn()
    render(<CHDateField value="2026-06-18" onChange={onChange} />)
    const input = screen.getByDisplayValue('18.06.2026') as HTMLInputElement
    expect(input.type).toBe('text')
    fireEvent.change(input, { target: { value: '20.07.2026' } })
    expect(onChange).toHaveBeenLastCalledWith('2026-07-20')
  })
})

describe('CHTimeField component', () => {
  it('emits normalized HH:mm', () => {
    const onChange = vi.fn()
    render(<CHTimeField value="12:30" onChange={onChange} />)
    const input = screen.getByPlaceholderText('HH:MM') as HTMLInputElement
    expect(input.value).toBe('12:30')
    fireEvent.change(input, { target: { value: '0830' } })
    expect(onChange).toHaveBeenLastCalledWith('08:30')
  })
})
