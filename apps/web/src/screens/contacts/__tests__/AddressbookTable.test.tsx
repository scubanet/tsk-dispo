// apps/web/src/screens/contacts/__tests__/AddressbookTable.test.tsx
import { describe, it, expect, vi } from 'vitest'
import { render, screen, fireEvent } from '@testing-library/react'
import { AddressbookTable } from '../AddressbookTable'
import type { Contact } from '@/types/contacts'

function makeContact(over: Partial<Contact> = {}): Contact {
  return {
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
    ...over,
  }
}

describe('AddressbookTable', () => {
  it('renders header cells (Name, Rollen, Email, Letzter Kontakt)', () => {
    render(<AddressbookTable rows={[]} selectedId={null} onSelect={vi.fn()} />)
    // Header is rendered as `role="columnheader"` cells inside `role="row"`.
    expect(screen.getByRole('columnheader', { name: /Name/i })).toBeTruthy()
    expect(screen.getByRole('columnheader', { name: /Rollen/i })).toBeTruthy()
    expect(screen.getByRole('columnheader', { name: /Email/i })).toBeTruthy()
    expect(screen.getByRole('columnheader', { name: /Letzter Kontakt/i })).toBeTruthy()
  })

  it('renders a row per contact with display_name', () => {
    const rows = [
      makeContact({ id: 'c1', display_name: 'Hugo Eugster' }),
      makeContact({ id: 'c2', display_name: 'Anna Meier' }),
    ]
    render(<AddressbookTable rows={rows} selectedId={null} onSelect={vi.fn()} />)
    expect(screen.getByText('Hugo Eugster')).toBeTruthy()
    expect(screen.getByText('Anna Meier')).toBeTruthy()
  })

  it('click on row triggers onSelect(contact.id)', () => {
    const onSelect = vi.fn()
    const rows = [makeContact({ id: 'c1' }), makeContact({ id: 'c2', display_name: 'Anna' })]
    render(<AddressbookTable rows={rows} selectedId={null} onSelect={onSelect} />)
    fireEvent.click(screen.getByText('Anna'))
    expect(onSelect).toHaveBeenCalledWith('c2')
  })

  it('click on action button (⋯) does NOT trigger onSelect', () => {
    const onSelect = vi.fn()
    const rows = [makeContact({ id: 'c1' })]
    render(<AddressbookTable rows={rows} selectedId={null} onSelect={onSelect} />)
    const actionButtons = screen.getAllByRole('button', { name: /Aktionen/i })
    fireEvent.click(actionButtons[0])
    expect(onSelect).not.toHaveBeenCalled()
  })

  it('active row has aria-selected="true" when selectedId matches', () => {
    const rows = [
      makeContact({ id: 'c1', display_name: 'Hugo' }),
      makeContact({ id: 'c2', display_name: 'Anna' }),
    ]
    const { container } = render(
      <AddressbookTable rows={rows} selectedId="c2" onSelect={vi.fn()} />
    )
    const selected = container.querySelectorAll('[aria-selected="true"]')
    expect(selected.length).toBe(1)
    expect(selected[0].textContent).toContain('Anna')
  })

  it('density="compact" sets data-density="compact" on table root', () => {
    const { container } = render(
      <AddressbookTable rows={[]} selectedId={null} onSelect={vi.fn()} density="compact" />
    )
    const root = container.querySelector('[data-density="compact"]')
    expect(root).toBeTruthy()
  })

  it('density defaults to comfortable', () => {
    const { container } = render(
      <AddressbookTable rows={[]} selectedId={null} onSelect={vi.fn()} />
    )
    const root = container.querySelector('[data-density="comfortable"]')
    expect(root).toBeTruthy()
  })
})
