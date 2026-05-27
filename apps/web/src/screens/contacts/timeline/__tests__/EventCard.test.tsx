// apps/web/src/screens/contacts/timeline/__tests__/EventCard.test.tsx
import { describe, it, expect } from 'vitest'
import { render, screen } from '@testing-library/react'
import { EventCard } from '../EventCard'
import type { TimelineEvent } from '@/types/contactEvents'

const baseEvent: TimelineEvent = {
  event_id: 'a',
  contact_id: 'c1',
  event_type: 'note',
  occurred_at: '2026-05-27T10:00:00Z',
  actor_contact_id: null,
  summary: 'hello world',
  body: null,
  payload: null,
  status: 'open',
  source_table: 'contact_events',
  source_id: 'a',
}

describe('EventCard', () => {
  it('renders summary and relative date', () => {
    render(<EventCard event={baseEvent} />)
    expect(screen.getByText('hello world')).toBeTruthy()
  })

  it('shows body when present', () => {
    render(<EventCard event={{ ...baseEvent, body: 'longer note text' }} />)
    expect(screen.getByText('longer note text')).toBeTruthy()
  })

  it('picks icon class based on event_type', () => {
    const { container } = render(<EventCard event={{ ...baseEvent, event_type: 'call' }} />)
    expect(container.querySelector('[data-icon="phone"]')).toBeTruthy()
  })

  it('rendert ein inline-SVG für das Icon', () => {
    const { container } = render(<EventCard event={baseEvent} />)
    expect(container.querySelector('svg')).toBeTruthy()
  })

  it('shows audit_edit summary with field-list', () => {
    render(<EventCard event={{
      ...baseEvent,
      event_type: 'audit_edit',
      summary: 'Daten bearbeitet: email, phone',
      source_table: 'contact_audit_log',
    }} />)
    expect(screen.getByText(/Daten bearbeitet:/)).toBeTruthy()
  })
})
