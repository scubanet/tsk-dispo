// apps/web/src/screens/contacts/activity/__tests__/ActivityEventCard.test.tsx
//
// Phase G Phase 5 Task 1 — Tests für ActivityEventCard.
//
// useNavigate wird via vi.mock gespyt. Der MemoryRouter ist trotzdem da, weil
// useNavigate ohne Router-Context wirft.

import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, screen, fireEvent } from '@testing-library/react'
import { MemoryRouter } from 'react-router-dom'
import type { ReactNode } from 'react'
import { ActivityEventCard } from '../ActivityEventCard'
import type { TimelineEvent } from '@/types/contactEvents'

// ── useNavigate spy ────────────────────────────────────────────────────
const navigateSpy = vi.fn()
vi.mock('react-router-dom', async () => {
  const actual = await vi.importActual<typeof import('react-router-dom')>('react-router-dom')
  return {
    ...actual,
    useNavigate: () => navigateSpy,
  }
})

// ── Fixtures ───────────────────────────────────────────────────────────
const baseEvent: TimelineEvent = {
  event_id: 'evt-1',
  contact_id: 'c-123',
  event_type: 'note',
  occurred_at: '2026-05-27T10:00:00Z',
  actor_contact_id: null,
  summary: 'Probetauchen gut gelaufen',
  body: null,
  payload: null,
  status: 'open',
  source_table: 'contact_events',
  source_id: 'evt-1',
}

function wrap(node: ReactNode) {
  return render(<MemoryRouter>{node}</MemoryRouter>)
}

beforeEach(() => {
  navigateSpy.mockReset()
})

describe('ActivityEventCard', () => {
  it('rendert die Event-Summary', () => {
    wrap(<ActivityEventCard event={baseEvent} contactName="Anna Beispiel" />)
    expect(screen.getByText('Probetauchen gut gelaufen')).toBeTruthy()
  })

  it('rendert den Contact-Namen wenn übergeben', () => {
    wrap(<ActivityEventCard event={baseEvent} contactName="Anna Beispiel" />)
    const anchor = screen.getByTestId('contact-anchor')
    expect(anchor.textContent).toContain('Anna Beispiel')
  })

  it('fällt auf "Contact" zurück wenn contactName fehlt', () => {
    wrap(<ActivityEventCard event={baseEvent} />)
    const anchor = screen.getByTestId('contact-anchor')
    expect(anchor.textContent).toContain('Contact')
  })

  it('navigiert beim Click zu /contacts?contact=<id>&event=<eid>', () => {
    wrap(<ActivityEventCard event={baseEvent} contactName="Anna Beispiel" />)
    const card = screen.getByRole('button', { name: /Probetauchen/ })
    fireEvent.click(card)
    expect(navigateSpy).toHaveBeenCalledTimes(1)
    expect(navigateSpy).toHaveBeenCalledWith('/contacts?contact=c-123&event=evt-1')
  })

  it('navigiert ebenfalls bei Keyboard-Enter', () => {
    wrap(<ActivityEventCard event={baseEvent} contactName="Anna Beispiel" />)
    const card = screen.getByRole('button', { name: /Probetauchen/ })
    fireEvent.keyDown(card, { key: 'Enter' })
    expect(navigateSpy).toHaveBeenCalledWith('/contacts?contact=c-123&event=evt-1')
  })

  it('navigiert auch bei Space-Key', () => {
    wrap(<ActivityEventCard event={baseEvent} contactName="Anna Beispiel" />)
    const card = screen.getByRole('button', { name: /Probetauchen/ })
    fireEvent.keyDown(card, { key: ' ' })
    expect(navigateSpy).toHaveBeenCalledWith('/contacts?contact=c-123&event=evt-1')
  })
})
