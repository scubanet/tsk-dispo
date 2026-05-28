// apps/web/src/screens/contacts/activity/__tests__/ContactPicker.test.tsx
//
// Phase G Phase 5 Task 2 — Tests für den ContactPicker (Autocomplete-Combobox).

import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, screen, fireEvent } from '@testing-library/react'
import type { Contact } from '@/types/contacts'

// ── Mock useContactList ──────────────────────────────────────────────────

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
  {
    id: 'c2',
    kind: 'person',
    first_name: 'Anna',
    last_name: 'Meier',
    display_name: 'Anna Meier',
    primary_email: 'anna@example.com',
    emails: [],
    phones: [],
    addresses: [],
    languages: [],
    roles: ['instructor'],
    tags: [],
    consent_marketing: false,
    created_at: '2026-01-01T00:00:00Z',
    updated_at: '2026-01-01T00:00:00Z',
  },
]

let mockData: { rows: Contact[] } = { rows: mockRows }
let mockIsFetching = false
const useContactListSpy = vi.fn()

vi.mock('@/hooks/useContactList', () => ({
  useContactList: (...args: unknown[]) => {
    useContactListSpy(...args)
    return { data: mockData, isFetching: mockIsFetching }
  },
}))

import { ContactPicker } from '../ContactPicker'

beforeEach(() => {
  useContactListSpy.mockClear()
  mockData = { rows: mockRows }
  mockIsFetching = false
})

describe('ContactPicker', () => {
  it('renders input with placeholder when value === null', () => {
    render(
      <ContactPicker
        value={null}
        onChange={vi.fn()}
        placeholder="Contact suchen…"
      />,
    )
    const input = screen.getByRole('combobox')
    expect(input).toBeTruthy()
    expect((input as HTMLInputElement).placeholder).toBe('Contact suchen…')
  })

  it('renders chip instead of input when value is set', () => {
    render(
      <ContactPicker
        value={{ id: 'c1', display_name: 'Hugo Eugster' }}
        onChange={vi.fn()}
      />,
    )
    expect(screen.queryByRole('combobox')).toBeNull()
    expect(screen.getByTestId('contact-picker-chip-name').textContent).toBe(
      'Hugo Eugster',
    )
  })

  it('clicking the ✕ in the chip calls onChange(null)', () => {
    const onChange = vi.fn()
    render(
      <ContactPicker
        value={{ id: 'c1', display_name: 'Hugo Eugster' }}
        onChange={onChange}
      />,
    )
    fireEvent.click(screen.getByRole('button', { name: 'Auswahl entfernen' }))
    expect(onChange).toHaveBeenCalledTimes(1)
    expect(onChange).toHaveBeenCalledWith(null)
  })

  it('typing a 2-char query opens dropdown with mocked results', () => {
    render(<ContactPicker value={null} onChange={vi.fn()} />)
    const input = screen.getByRole('combobox') as HTMLInputElement
    fireEvent.change(input, { target: { value: 'Hu' } })
    // Dropdown is open
    const listbox = screen.getByRole('listbox', { name: 'Contact-Suche' })
    expect(listbox).toBeTruthy()
    // Both mocked rows shown
    expect(screen.getByTestId('contact-picker-option-c1')).toBeTruthy()
    expect(screen.getByTestId('contact-picker-option-c2')).toBeTruthy()
    // useContactList received the searchText
    const lastCall =
      useContactListSpy.mock.calls[useContactListSpy.mock.calls.length - 1]
    expect((lastCall[0] as { searchText?: string }).searchText).toBe('Hu')
  })

  it('clicking a result calls onChange with {id, display_name}', () => {
    const onChange = vi.fn()
    render(<ContactPicker value={null} onChange={onChange} />)
    const input = screen.getByRole('combobox') as HTMLInputElement
    fireEvent.change(input, { target: { value: 'Hu' } })
    fireEvent.mouseDown(screen.getByTestId('contact-picker-option-c1'))
    expect(onChange).toHaveBeenCalledWith({
      id: 'c1',
      display_name: 'Hugo Eugster',
    })
  })

  it('ArrowDown + Enter selects the next result', () => {
    const onChange = vi.fn()
    render(<ContactPicker value={null} onChange={onChange} />)
    const input = screen.getByRole('combobox') as HTMLInputElement
    fireEvent.change(input, { target: { value: 'me' } })
    // focusedIndex resets to 0 → ArrowDown → 1 → Enter selects c2.
    fireEvent.keyDown(input, { key: 'ArrowDown' })
    fireEvent.keyDown(input, { key: 'Enter' })
    expect(onChange).toHaveBeenCalledWith({
      id: 'c2',
      display_name: 'Anna Meier',
    })
  })

  it('Escape closes the dropdown', () => {
    render(<ContactPicker value={null} onChange={vi.fn()} />)
    const input = screen.getByRole('combobox') as HTMLInputElement
    fireEvent.change(input, { target: { value: 'Hu' } })
    expect(screen.queryByRole('listbox')).toBeTruthy()
    fireEvent.keyDown(input, { key: 'Escape' })
    expect(screen.queryByRole('listbox')).toBeNull()
  })

  it('shows empty-state when query>=2 and zero results', () => {
    mockData = { rows: [] }
    render(<ContactPicker value={null} onChange={vi.fn()} />)
    const input = screen.getByRole('combobox') as HTMLInputElement
    fireEvent.change(input, { target: { value: 'zzz' } })
    expect(screen.getByTestId('contact-picker-empty').textContent).toContain(
      'Keine Treffer',
    )
  })
})
