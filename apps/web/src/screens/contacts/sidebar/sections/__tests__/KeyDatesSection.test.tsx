import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest'
import { render, screen } from '@testing-library/react'
import { KeyDatesSection } from '../KeyDatesSection'
import type { ContactWithProperties } from '@/types/contactProperties'

const baseContact: ContactWithProperties = {
  id: 'c1',
  kind: 'person',
  display_name: 'Hugo Eugster',
  first_name: 'Hugo',
  last_name: 'Eugster',
  birth_date: '1985-03-12',
  primary_email: null,
  phones: [], addresses: [], languages: [],
  
  source: 'manual',
  created_at: '2024-01-15T10:00:00Z',
  updated_at: '2026-05-20T08:30:00Z',
  owner_id: null,
  tags: [],
  instructor: null,
  student: null,
  organization: null,
  balance_chf: null,
  last_movement_date: '2026-04-10',
  roles: [],
}

/** Open the section by pre-seeding localStorage (SidebarSection reads it on mount). */
function openKeyDates() {
  try { window.localStorage.setItem('sidebar-section-keydates', 'true') } catch { /* noop */ }
}

beforeEach(() => {
  try { window.localStorage.clear() } catch { /* noop */ }
  vi.useFakeTimers()
  // Deterministic "now" — Hugo turned 41 on 12.03.2026, so on 27.05.2026 he is 41.
  vi.setSystemTime(new Date('2026-05-27T12:00:00Z'))
})

afterEach(() => {
  vi.useRealTimers()
})

describe('KeyDatesSection', () => {
  it('renders title "Wichtige Daten"', () => {
    render(<KeyDatesSection contact={baseContact} />)
    expect(screen.getByText('Wichtige Daten')).toBeTruthy()
  })

  it('is default closed (body hidden)', () => {
    render(<KeyDatesSection contact={baseContact} />)
    const body = document.getElementById('sidebar-section-keydates-body')
    expect(body).toBeTruthy()
    expect(body?.hasAttribute('hidden')).toBe(true)
  })

  it('after open: renders birth_date formatted (year matches)', () => {
    openKeyDates()
    render(<KeyDatesSection contact={baseContact} />)
    const body = document.getElementById('sidebar-section-keydates-body')
    expect(body?.hasAttribute('hidden')).toBe(false)
    expect(body?.textContent ?? '').toMatch(/1985/)
  })

  it('after open: renders dash for null birth_date', () => {
    openKeyDates()
    render(<KeyDatesSection contact={{ ...baseContact, birth_date: null }} />)
    // Find the "Geburtsdatum" label and check sibling renders dash
    const label = screen.getByText('Geburtsdatum')
    const row = label.parentElement
    expect(row).toBeTruthy()
    expect(row?.textContent ?? '').toContain('—')
  })

  it('after open: renders dash for null last_movement_date', () => {
    openKeyDates()
    render(<KeyDatesSection contact={{ ...baseContact, last_movement_date: null }} />)
    const label = screen.getByText('Letzte Bewegung')
    const row = label.parentElement
    expect(row).toBeTruthy()
    expect(row?.textContent ?? '').toContain('—')
  })

  it('after open: renders Erstellt and Zuletzt geändert dates (year match)', () => {
    openKeyDates()
    render(<KeyDatesSection contact={baseContact} />)
    const createdRow = screen.getByText('Erstellt').parentElement
    const updatedRow = screen.getByText('Zuletzt geändert').parentElement
    expect(createdRow?.textContent ?? '').toMatch(/2024/)
    expect(updatedRow?.textContent ?? '').toMatch(/2026/)
  })

  it('after open: renders age (41) for birth_date 1985-03-12 with fixed now 2026-05-27', () => {
    openKeyDates()
    render(<KeyDatesSection contact={baseContact} />)
    const row = screen.getByText('Geburtsdatum').parentElement
    expect(row?.textContent ?? '').toMatch(/\(41\)/)
  })

  it('after open: omits age when birth_date is null', () => {
    openKeyDates()
    render(<KeyDatesSection contact={{ ...baseContact, birth_date: null }} />)
    const row = screen.getByText('Geburtsdatum').parentElement
    // No (NN) pattern when no birthday
    expect(row?.textContent ?? '').not.toMatch(/\(\d+\)/)
  })
})
