// apps/web/src/screens/contacts/__tests__/AddressbookFilterBar.test.tsx
//
// Phase G Phase 4 Task 5 — Tests für die FilterBar (8 Chips + Reset).
import { describe, it, expect, vi } from 'vitest'
import { render, screen, fireEvent, within } from '@testing-library/react'
import { AddressbookFilterBar } from '../AddressbookFilterBar'
import { EMPTY_FILTER } from '@/hooks/useAddressbookFilter'

describe('AddressbookFilterBar', () => {
  it('renders all 8 filter chips', () => {
    render(
      <AddressbookFilterBar
        filter={EMPTY_FILTER}
        onChange={vi.fn()}
        onClear={vi.fn()}
      />,
    )
    const bar = screen.getByTestId('addressbook-filter-bar')
    const labels = [
      'Rolle',
      'Tag',
      'Status',
      'Pipeline',
      'Letzter Kontakt',
      'Saldo',
      'Sprache',
      'Quelle',
    ]
    for (const l of labels) {
      expect(within(bar).getByRole('button', { name: l })).toBeTruthy()
    }
  })

  it('clicking Rolle chip opens dropdown with 11 ContactRole options', () => {
    render(
      <AddressbookFilterBar
        filter={EMPTY_FILTER}
        onChange={vi.fn()}
        onClear={vi.fn()}
      />,
    )
    fireEvent.click(screen.getByRole('button', { name: 'Rolle' }))
    // Listbox has one checkbox per role; 11 ContactRole values total.
    const listbox = screen.getByRole('listbox', { name: 'Rolle' })
    const checkboxes = within(listbox).getAllByRole('checkbox')
    expect(checkboxes.length).toBe(11)
  })

  it('selecting an option triggers onChange with the matching key', () => {
    const onChange = vi.fn()
    render(
      <AddressbookFilterBar
        filter={EMPTY_FILTER}
        onChange={onChange}
        onClear={vi.fn()}
      />,
    )
    fireEvent.click(screen.getByRole('button', { name: 'Saldo' }))
    const listbox = screen.getByRole('listbox', { name: 'Saldo' })
    fireEvent.click(within(listbox).getByLabelText('Negativ'))
    expect(onChange).toHaveBeenCalledWith('saldo_buckets', ['negative'])
  })

  it('reset-button only shows when at least one filter is active', () => {
    const { rerender } = render(
      <AddressbookFilterBar
        filter={EMPTY_FILTER}
        onChange={vi.fn()}
        onClear={vi.fn()}
      />,
    )
    expect(
      screen.queryByRole('button', { name: /Filter zurücksetzen/i }),
    ).toBeNull()

    rerender(
      <AddressbookFilterBar
        filter={{ ...EMPTY_FILTER, roles: ['instructor'] }}
        onChange={vi.fn()}
        onClear={vi.fn()}
      />,
    )
    expect(
      screen.getByRole('button', { name: /Filter zurücksetzen/i }),
    ).toBeTruthy()
  })
})
