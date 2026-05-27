// apps/web/src/screens/contacts/sidebar/__tests__/StatBand.test.tsx
import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest'
import { render, screen } from '@testing-library/react'
import { StatBand } from '../StatBand'
import type { ContactWithProperties } from '@/types/contactProperties'

function makeContact(over: Partial<ContactWithProperties> = {}): ContactWithProperties {
  return {
    id: 'c1',
    kind: 'person',
    display_name: 'Test Person',
    first_name: 'Test',
    last_name: 'Person',
    birth_date: null,
    primary_email: null,
    primary_phone: null,
    primary_language: null,
    source: null,
    created_at: '2026-01-01T00:00:00Z',
    updated_at: '2026-01-01T00:00:00Z',
    owner_id: null,
    tags: [],
    instructor: null,
    student: null,
    organization: null,
    balance_chf: null,
    last_movement_date: null,
    roles: [],
    ...over,
  }
}

describe('StatBand', () => {
  beforeEach(() => {
    vi.useFakeTimers()
    // Fix "now" so relativeTime is deterministic.
    vi.setSystemTime(new Date('2026-05-27T12:00:00Z'))
  })
  afterEach(() => {
    vi.useRealTimers()
  })

  it('renders positive Saldo with success variant', () => {
    render(<StatBand contact={makeContact({ balance_chf: 12.5 })} />)
    const el = screen.getByText('CHF 12.50')
    expect(el).toBeTruthy()
    expect(el.getAttribute('data-variant')).toBe('positive')
  })

  it('renders negative Saldo with danger variant', () => {
    render(<StatBand contact={makeContact({ balance_chf: -5 })} />)
    const el = screen.getByText('CHF -5.00')
    expect(el).toBeTruthy()
    expect(el.getAttribute('data-variant')).toBe('negative')
  })

  it('renders Saldo Dash when null', () => {
    render(<StatBand contact={makeContact({ balance_chf: null })} />)
    // Saldo tile -> Dash
    const saldoLabel = screen.getByText('Saldo')
    const tile = saldoLabel.parentElement
    expect(tile?.textContent).toMatch(/—/)
  })

  it('renders Letzter Kontakt Dash when null', () => {
    render(<StatBand contact={makeContact({ last_movement_date: null })} />)
    const label = screen.getByText('Letzter Kontakt')
    const tile = label.parentElement
    expect(tile?.textContent).toMatch(/—/)
  })

  it('renders Letzter Kontakt "gerade eben" for 30 min ago', () => {
    const iso = new Date('2026-05-27T11:30:00Z').toISOString() // 30 min before "now"
    render(<StatBand contact={makeContact({ last_movement_date: iso })} />)
    expect(screen.getByText('gerade eben')).toBeTruthy()
  })

  it('renders Letzter Kontakt "vor 3 Tagen" for 3 days ago', () => {
    const iso = new Date('2026-05-24T12:00:00Z').toISOString()
    render(<StatBand contact={makeContact({ last_movement_date: iso })} />)
    expect(screen.getByText('vor 3 Tagen')).toBeTruthy()
  })

  it('renders Aktive Kurse and Nächste Action as Dash (stub)', () => {
    render(<StatBand contact={makeContact()} />)
    const kurseLabel = screen.getByText('Aktive Kurse')
    const actionLabel = screen.getByText('Nächste Action')
    expect(kurseLabel.parentElement?.textContent).toMatch(/—/)
    expect(actionLabel.parentElement?.textContent).toMatch(/—/)
  })

  it('renders all four labels', () => {
    render(<StatBand contact={makeContact()} />)
    expect(screen.getByText('Saldo')).toBeTruthy()
    expect(screen.getByText('Aktive Kurse')).toBeTruthy()
    expect(screen.getByText('Letzter Kontakt')).toBeTruthy()
    expect(screen.getByText('Nächste Action')).toBeTruthy()
  })
})
