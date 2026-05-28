// apps/web/src/screens/contacts/__tests__/CompactContactList.test.tsx
import { describe, it, expect, vi } from 'vitest'
import { render, screen, fireEvent } from '@testing-library/react'
import { CompactContactList } from '../CompactContactList'
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

describe('CompactContactList', () => {
  it('renders one button-row per contact with display_name + email subtitle', () => {
    const rows = [
      makeContact({ id: 'c1', display_name: 'Hugo Eugster', primary_email: 'hugo@example.com' }),
      makeContact({ id: 'c2', display_name: 'Anna Meier', primary_email: 'anna@example.com' }),
    ]
    render(<CompactContactList rows={rows} selectedId={null} onSelect={vi.fn()} />)
    expect(screen.getByText('Hugo Eugster')).toBeTruthy()
    expect(screen.getByText('Anna Meier')).toBeTruthy()
    expect(screen.getByText('hugo@example.com')).toBeTruthy()
    expect(screen.getByText('anna@example.com')).toBeTruthy()
  })

  it('click on row triggers onSelect(contact.id)', () => {
    const onSelect = vi.fn()
    const rows = [
      makeContact({ id: 'c1', display_name: 'Hugo' }),
      makeContact({ id: 'c2', display_name: 'Anna' }),
    ]
    render(<CompactContactList rows={rows} selectedId={null} onSelect={onSelect} />)
    fireEvent.click(screen.getByText('Anna'))
    expect(onSelect).toHaveBeenCalledWith('c2')
  })

  it('active row has atoll-people-row--active class + aria-current', () => {
    const rows = [
      makeContact({ id: 'c1', display_name: 'Hugo' }),
      makeContact({ id: 'c2', display_name: 'Anna' }),
    ]
    const { container } = render(
      <CompactContactList rows={rows} selectedId="c2" onSelect={vi.fn()} />
    )
    const active = container.querySelectorAll('.atoll-people-row--active')
    expect(active.length).toBe(1)
    expect(active[0].textContent).toContain('Anna')
    expect(active[0].getAttribute('aria-current')).toBe('true')
  })

  it('falls back to "Organisation" subtitle for organizations without email', () => {
    const rows = [
      makeContact({
        id: 'o1',
        kind: 'organization',
        display_name: 'Acme GmbH',
        primary_email: null,
        first_name: null,
        last_name: null,
        legal_name: 'Acme GmbH',
      }),
    ]
    render(<CompactContactList rows={rows} selectedId={null} onSelect={vi.fn()} />)
    expect(screen.getByText('Acme GmbH')).toBeTruthy()
    expect(screen.getByText('Organisation')).toBeTruthy()
  })
})
