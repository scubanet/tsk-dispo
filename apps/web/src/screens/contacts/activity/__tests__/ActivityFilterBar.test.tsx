// apps/web/src/screens/contacts/activity/__tests__/ActivityFilterBar.test.tsx
//
// Phase G Phase 5 Task 0 — Tests für die ActivityFilterBar (3 Chips + Reset).
import { describe, it, expect, vi } from 'vitest'
import { render, screen, fireEvent, within } from '@testing-library/react'
import { ActivityFilterBar } from '../ActivityFilterBar'
import { EMPTY_ACTIVITY_FILTER } from '@/hooks/useActivityFilter'

describe('ActivityFilterBar', () => {
  it('renders the three filter chips', () => {
    render(
      <ActivityFilterBar
        filter={EMPTY_ACTIVITY_FILTER}
        onChange={vi.fn()}
        onClear={vi.fn()}
      />,
    )
    const bar = screen.getByTestId('activity-filter-bar')
    for (const l of ['Event-Typ', 'Owner', 'Zeitraum']) {
      expect(within(bar).getByRole('button', { name: l })).toBeTruthy()
    }
  })

  it('clicking Event-Typ chip opens dropdown with all 15 EventType options', () => {
    render(
      <ActivityFilterBar
        filter={EMPTY_ACTIVITY_FILTER}
        onChange={vi.fn()}
        onClear={vi.fn()}
      />,
    )
    fireEvent.click(screen.getByRole('button', { name: 'Event-Typ' }))
    const listbox = screen.getByRole('listbox', { name: 'Event-Typ' })
    const checkboxes = within(listbox).getAllByRole('checkbox')
    expect(checkboxes.length).toBe(15)
  })

  it('selecting Owner=Mein triggers onChange with owner_scope:"mine"', () => {
    const onChange = vi.fn()
    render(
      <ActivityFilterBar
        filter={EMPTY_ACTIVITY_FILTER}
        onChange={onChange}
        onClear={vi.fn()}
      />,
    )
    fireEvent.click(screen.getByRole('button', { name: 'Owner' }))
    const listbox = screen.getByRole('listbox', { name: 'Owner' })
    fireEvent.click(within(listbox).getByLabelText('Mein'))
    expect(onChange).toHaveBeenCalledWith(
      expect.objectContaining({ owner_scope: 'mine' }),
    )
  })

  it('selecting Zeitraum=Custom reveals two date inputs', () => {
    const { rerender } = render(
      <ActivityFilterBar
        filter={EMPTY_ACTIVITY_FILTER}
        onChange={vi.fn()}
        onClear={vi.fn()}
      />,
    )
    expect(screen.queryByTestId('activity-filter-custom-range')).toBeNull()

    rerender(
      <ActivityFilterBar
        filter={{ ...EMPTY_ACTIVITY_FILTER, date_bucket: 'custom' }}
        onChange={vi.fn()}
        onClear={vi.fn()}
      />,
    )
    expect(screen.getByTestId('activity-filter-custom-range')).toBeTruthy()
    expect(screen.getByLabelText('Von')).toBeTruthy()
    expect(screen.getByLabelText('Bis')).toBeTruthy()
  })

  it('reset-button only shows when ≥1 filter is active', () => {
    const { rerender } = render(
      <ActivityFilterBar
        filter={EMPTY_ACTIVITY_FILTER}
        onChange={vi.fn()}
        onClear={vi.fn()}
      />,
    )
    expect(
      screen.queryByRole('button', { name: /Filter zurücksetzen/i }),
    ).toBeNull()

    rerender(
      <ActivityFilterBar
        filter={{ ...EMPTY_ACTIVITY_FILTER, event_types: ['note'] }}
        onChange={vi.fn()}
        onClear={vi.fn()}
      />,
    )
    expect(
      screen.getByRole('button', { name: /Filter zurücksetzen/i }),
    ).toBeTruthy()
  })
})
