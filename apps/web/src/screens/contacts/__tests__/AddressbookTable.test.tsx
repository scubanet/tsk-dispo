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

  it('renders exactly the columns supplied via the columns prop', () => {
    render(
      <AddressbookTable
        rows={[]}
        selectedId={null}
        onSelect={vi.fn()}
        columns={['name', 'phone', 'tags']}
      />,
    )
    // Header sollte genau diese 3 Spalten zeigen (+ Auswahl + Aktionen)
    const headers = screen.getAllByRole('columnheader')
    // 1 Auswahl + 3 dynamische + 1 Aktionen = 5
    expect(headers.length).toBe(5)
    expect(screen.getByRole('columnheader', { name: /^Name$/i })).toBeTruthy()
    expect(screen.getByRole('columnheader', { name: /^Telefon$/i })).toBeTruthy()
    expect(screen.getByRole('columnheader', { name: /^Tags$/i })).toBeTruthy()
    // Email-Header darf NICHT vorhanden sein
    expect(screen.queryByRole('columnheader', { name: /^Email$/i })).toBeNull()
  })

  it('renders non-default column headers when opted in', () => {
    render(
      <AddressbookTable
        rows={[]}
        selectedId={null}
        onSelect={vi.fn()}
        columns={['name', 'org', 'sprache', 'quelle', 'geburtstag', 'created_at']}
      />,
    )
    expect(screen.getByRole('columnheader', { name: /^Sprache$/i })).toBeTruthy()
    expect(screen.getByRole('columnheader', { name: /^Quelle$/i })).toBeTruthy()
    expect(screen.getByRole('columnheader', { name: /^Geburtstag$/i })).toBeTruthy()
    expect(screen.getByRole('columnheader', { name: /^Erstellt$/i })).toBeTruthy()
  })

  it('renders ↑ indicator next to sortable header when sort=[{field:"name",asc}]', () => {
    render(
      <AddressbookTable
        rows={[]}
        selectedId={null}
        onSelect={vi.fn()}
        sort={[{ field: 'name', direction: 'asc' }]}
        onHeaderClick={vi.fn()}
      />,
    )
    const nameHeader = screen.getByRole('columnheader', { name: /Name/i })
    expect(nameHeader.textContent).toContain('↑')
    expect(nameHeader.textContent).not.toContain('↓')
  })

  it('renders ↓ indicator for desc + click on sortable header triggers onHeaderClick', () => {
    const onHeaderClick = vi.fn()
    render(
      <AddressbookTable
        rows={[]}
        selectedId={null}
        onSelect={vi.fn()}
        sort={[{ field: 'name', direction: 'desc' }]}
        onHeaderClick={onHeaderClick}
      />,
    )
    const nameHeader = screen.getByRole('columnheader', { name: /Name/i })
    expect(nameHeader.textContent).toContain('↓')
    const button = nameHeader.querySelector('button')
    expect(button).toBeTruthy()
    fireEvent.click(button!)
    expect(onHeaderClick).toHaveBeenCalledWith('name', false)
  })

  it('non-sortable header (roles) is NOT a button and does not call onHeaderClick', () => {
    const onHeaderClick = vi.fn()
    render(
      <AddressbookTable
        rows={[]}
        selectedId={null}
        onSelect={vi.fn()}
        columns={['name', 'roles', 'email']}
        onHeaderClick={onHeaderClick}
      />,
    )
    const rolesHeader = screen.getByRole('columnheader', { name: /^Rollen$/i })
    expect(rolesHeader.querySelector('button')).toBeNull()
    fireEvent.click(rolesHeader)
    expect(onHeaderClick).not.toHaveBeenCalled()
  })

  it('renders cell values for opted-in columns (phone, tags, sprache, geburtstag, created_at, quelle)', () => {
    const row = makeContact({
      id: 'cP',
      display_name: 'Phone User',
      phones: [{ label: 'mobile', e164: '+41791234567' }],
      tags: ['vip', 'taucher', 'medic', 'extra'],
      languages: ['de'],
      birth_date: '1990-04-15',
      source: 'newsletter',
      created_at: '2025-12-31T00:00:00Z',
    })
    render(
      <AddressbookTable
        rows={[row]}
        selectedId={null}
        onSelect={vi.fn()}
        columns={['name', 'phone', 'tags', 'sprache', 'geburtstag', 'created_at', 'quelle']}
      />,
    )
    expect(screen.getByText('+41791234567')).toBeTruthy()
    // tags: erste 3 + +N
    expect(screen.getByText(/vip, taucher, medic \+1/)).toBeTruthy()
    expect(screen.getByText('de')).toBeTruthy()
    expect(screen.getByText('newsletter')).toBeTruthy()
    // Date formatted de-CH (15.04.1990 / 15.4.1990 — happy-dom variiert; wir
    // prüfen nur einen markanten Bestandteil)
    expect(screen.getByText(/1990/)).toBeTruthy()
    expect(screen.getByText(/2025/)).toBeTruthy()
  })
})
