// apps/web/src/screens/contacts/timeline/__tests__/TimelineFilterBar.test.tsx
import { describe, it, expect, vi } from 'vitest'
import { render, screen, fireEvent } from '@testing-library/react'
import { TimelineFilterBar } from '../TimelineFilterBar'

describe('TimelineFilterBar', () => {
  it('renders all chip labels', () => {
    render(<TimelineFilterBar value={{}} onChange={vi.fn()} />)
    expect(screen.getByText('Alle')).toBeTruthy()
    expect(screen.getByText('Notiz')).toBeTruthy()
    expect(screen.getByText('Anruf')).toBeTruthy()
    expect(screen.getByText('Mail')).toBeTruthy()
    expect(screen.getByText('Kurs')).toBeTruthy()
    expect(screen.getByText('Saldo')).toBeTruthy()
  })

  it('clicking Notiz emits event_types=[note]', () => {
    const onChange = vi.fn()
    render(<TimelineFilterBar value={{}} onChange={onChange} />)
    fireEvent.click(screen.getByText('Notiz'))
    expect(onChange).toHaveBeenCalledWith({ event_types: ['note'] })
  })

  it('clicking Alle clears event_types', () => {
    const onChange = vi.fn()
    render(<TimelineFilterBar value={{ event_types: ['note'] }} onChange={onChange} />)
    fireEvent.click(screen.getByText('Alle'))
    expect(onChange).toHaveBeenCalledWith({ event_types: undefined })
  })

  it('marks active chip aria-pressed=true', () => {
    render(<TimelineFilterBar value={{ event_types: ['note'] }} onChange={vi.fn()} />)
    expect(screen.getByText('Notiz').getAttribute('aria-pressed')).toBe('true')
    expect(screen.getByText('Anruf').getAttribute('aria-pressed')).toBe('false')
  })
})
