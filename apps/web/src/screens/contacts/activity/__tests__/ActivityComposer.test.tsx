// apps/web/src/screens/contacts/activity/__tests__/ActivityComposer.test.tsx
//
// Phase G Phase 5 Task 3 — Tests für den ActivityComposer.

import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, screen, fireEvent } from '@testing-library/react'
import type { Contact } from '@/types/contacts'

// ── Mock EventComposer to avoid Supabase roundtrips ──────────────────────
vi.mock('@/screens/contacts/timeline/EventComposer', () => ({
  EventComposer: ({ contactId }: { contactId: string }) => (
    <div data-testid="event-composer-mock" data-contact-id={contactId}>
      EventComposer({contactId})
    </div>
  ),
}))

// ── Mock useContactList for the ContactPicker ────────────────────────────
const mockRows: Contact[] = [
  {
    id: 'c1',
    kind: 'person',
    first_name: 'Hugo',
    last_name: 'Eugster',
    display_name: 'Hugo Eugster',
    primary_email: 'hugo@example.com',
    emails: [],
    phones: [],
    addresses: [],
    languages: [],
    roles: ['student'],
    tags: [],
    consent_marketing: false,
    created_at: '2026-01-01T00:00:00Z',
    updated_at: '2026-01-01T00:00:00Z',
  },
]

let mockData: { rows: Contact[] } = { rows: mockRows }
let mockIsFetching = false

vi.mock('@/hooks/useContactList', () => ({
  useContactList: () => ({ data: mockData, isFetching: mockIsFetching }),
}))

import { ActivityComposer } from '../ActivityComposer'

beforeEach(() => {
  mockData = { rows: mockRows }
  mockIsFetching = false
})

describe('ActivityComposer', () => {
  it('initial: rendert ContactPicker (Empty), KEIN EventComposer', () => {
    render(<ActivityComposer />)
    const input = screen.getByRole('combobox') as HTMLInputElement
    expect(input).toBeTruthy()
    expect(input.placeholder).toBe('Welcher Contact?')
    expect(screen.queryByTestId('event-composer-mock')).toBeNull()
  })

  it('nach Auswahl: rendert EventComposer mit korrekter contactId', () => {
    render(<ActivityComposer />)
    const input = screen.getByRole('combobox') as HTMLInputElement
    fireEvent.change(input, { target: { value: 'Hu' } })
    fireEvent.mouseDown(screen.getByTestId('contact-picker-option-c1'))

    const ec = screen.getByTestId('event-composer-mock')
    expect(ec).toBeTruthy()
    expect(ec.getAttribute('data-contact-id')).toBe('c1')
    // Chip is shown instead of combobox
    expect(screen.queryByRole('combobox')).toBeNull()
    expect(screen.getByTestId('contact-picker-chip-name').textContent).toBe(
      'Hugo Eugster',
    )
  })

  it('Klick ✕ im Chip clear\'d Selection → EventComposer verschwindet', () => {
    render(<ActivityComposer />)
    // Select a contact first.
    const input = screen.getByRole('combobox') as HTMLInputElement
    fireEvent.change(input, { target: { value: 'Hu' } })
    fireEvent.mouseDown(screen.getByTestId('contact-picker-option-c1'))
    expect(screen.getByTestId('event-composer-mock')).toBeTruthy()

    // Click ✕.
    fireEvent.click(screen.getByRole('button', { name: 'Auswahl entfernen' }))

    // EventComposer gone, picker back to empty mode.
    expect(screen.queryByTestId('event-composer-mock')).toBeNull()
    expect(screen.getByRole('combobox')).toBeTruthy()
  })

  it('Composer-Header ist sticky-top mit konsistentem Layout', () => {
    render(<ActivityComposer />)
    const wrapper = screen.getByTestId('activity-composer') as HTMLElement
    // Sticky-top so the picker bleibt sichtbar beim Scrollen.
    expect(wrapper.style.position).toBe('sticky')
    expect(wrapper.style.top).toBe('0px')
    // Visuelle Konsistenz zum EventComposer: 1px Bottom-Border.
    expect(wrapper.style.borderBottomWidth).toBe('1px')
    expect(wrapper.style.borderBottomStyle).toBe('solid')
    // Inner padding matches EventComposer recipe.
    const inner = wrapper.firstElementChild as HTMLElement
    expect(inner.style.padding).toBe('12px 14px')
  })
})
