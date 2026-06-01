// apps/web/src/screens/contacts/timeline/__tests__/EventCard.test.tsx
import { describe, it, expect, vi } from 'vitest'
import { render, screen, fireEvent } from '@testing-library/react'
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

  // ── Phase G Phase 5 Task 6 — Highlight-Prop ──────────────────────────
  it('sets data-event-id attr immer auf das Outer-Article', () => {
    const { container } = render(<EventCard event={baseEvent} />)
    const article = container.querySelector('article')
    expect(article?.getAttribute('data-event-id')).toBe('a')
  })

  it('setzt data-event-highlighted="true" wenn highlighted-Prop true ist', () => {
    const { container } = render(<EventCard event={baseEvent} highlighted />)
    const article = container.querySelector('article')
    expect(article?.getAttribute('data-event-highlighted')).toBe('true')
  })

  it('omits data-event-highlighted wenn highlighted-Prop false/undefined ist', () => {
    const { container } = render(<EventCard event={baseEvent} />)
    const article = container.querySelector('article')
    expect(article?.hasAttribute('data-event-highlighted')).toBe(false)
  })

  // ── Richtungs-Bubble (rein/raus) ─────────────────────────────────────
  it('zeigt eingehende WhatsApp als "Empfangen"-Bubble (data-direction=inbound)', () => {
    const { container } = render(<EventCard event={{
      ...baseEvent,
      event_type: 'whatsapp_log',
      summary: 'Guten Morgen',
      body: 'Guten Morgen',
      payload: { direction: 'inbound' },
    }} />)
    expect(screen.getByText('Empfangen')).toBeTruthy()
    expect(screen.getByText('Guten Morgen')).toBeTruthy()
    expect(container.querySelector('article')?.getAttribute('data-direction')).toBe('inbound')
    expect(container.querySelector('.event-bubble')).toBeTruthy()
  })

  it('zeigt ausgehende E-Mail als "Gesendet"-Bubble mit Betreff + Text', () => {
    const { container } = render(<EventCard event={{
      ...baseEvent,
      event_type: 'email_external',
      summary: 'Deine Buchung',
      body: 'Hallo, anbei die Details.',
      payload: { direction: 'outbound' },
    }} />)
    expect(screen.getByText('Gesendet')).toBeTruthy()
    expect(screen.getByText('Deine Buchung')).toBeTruthy()
    expect(screen.getByText('Hallo, anbei die Details.')).toBeTruthy()
    expect(container.querySelector('article')?.getAttribute('data-direction')).toBe('outbound')
  })

  it('faellt auf den Zeilen-Marker zurueck, wenn die Nachricht keine Richtung hat', () => {
    const { container } = render(<EventCard event={{
      ...baseEvent,
      event_type: 'whatsapp_log',
      summary: 'Log ohne Richtung',
      payload: null,
    }} />)
    expect(screen.queryByText('Empfangen')).toBeNull()
    expect(screen.queryByText('Gesendet')).toBeNull()
    expect(container.querySelector('.event-bubble')).toBeNull()
    expect(screen.getByText('Log ohne Richtung')).toBeTruthy()
  })

  // ── Nachricht löschen (Mülleimer + Inline-Bestätigung) ───────────────
  it('zeigt einen Löschen-Button auf einer Bubble und ruft onDelete nach Bestätigung mit event_id', () => {
    const onDelete = vi.fn()
    render(<EventCard event={{
      ...baseEvent,
      event_id: 'msg-1',
      event_type: 'whatsapp_log',
      summary: 'Hallo',
      body: 'Hallo',
      payload: { direction: 'outbound' },
    }} onDelete={onDelete} />)
    fireEvent.click(screen.getByLabelText('Nachricht löschen'))
    fireEvent.click(screen.getByText('Löschen'))
    expect(onDelete).toHaveBeenCalledWith('msg-1')
  })

  it('bietet KEIN Löschen auf Nicht-Nachrichten-Events (z.B. Saldo)', () => {
    render(<EventCard event={{
      ...baseEvent,
      event_type: 'saldo_movement',
      summary: 'Saldo +50',
    }} onDelete={vi.fn()} />)
    expect(screen.queryByLabelText('Nachricht löschen')).toBeNull()
  })

  it('Abbrechen schließt die Bestätigung ohne zu löschen', () => {
    const onDelete = vi.fn()
    render(<EventCard event={{
      ...baseEvent,
      event_type: 'email_external',
      summary: 'Betreff',
      body: 'Text',
      payload: { direction: 'inbound' },
    }} onDelete={onDelete} />)
    fireEvent.click(screen.getByLabelText('Nachricht löschen'))
    fireEvent.click(screen.getByText('Abbrechen'))
    expect(onDelete).not.toHaveBeenCalled()
    expect(screen.getByLabelText('Nachricht löschen')).toBeTruthy()
  })
})
