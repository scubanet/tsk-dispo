// apps/web/src/screens/contacts/__tests__/RowQuickActions.test.tsx
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest'
import { render, screen, fireEvent } from '@testing-library/react'
import { RowQuickActions } from '../RowQuickActions'
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

describe('RowQuickActions', () => {
  let alertSpy: ReturnType<typeof vi.fn>

  beforeEach(() => {
    alertSpy = vi.fn()
    window.alert = alertSpy
  })

  afterEach(() => {
    vi.restoreAllMocks()
  })

  it('rendert zwei Icon-Buttons (Mail + Notiz) für einen Contact', () => {
    const c = makeContact({ id: 'c1', display_name: 'Hugo Eugster' })
    render(<RowQuickActions contact={c} density="comfortable" />)
    const mailBtn = screen.getByRole('button', { name: /Quick-Mail an Hugo Eugster/i })
    const noteBtn = screen.getByRole('button', { name: /Quick-Notiz für Hugo Eugster/i })
    expect(mailBtn).toBeTruthy()
    expect(noteBtn).toBeTruthy()
  })

  it('Click auf Mail-Button triggert window.alert mit Phase-5-Text', () => {
    const c = makeContact({ id: 'c1' })
    render(<RowQuickActions contact={c} density="comfortable" />)
    const mailBtn = screen.getByRole('button', { name: /Quick-Mail/i })
    fireEvent.click(mailBtn)
    expect(alertSpy).toHaveBeenCalledTimes(1)
    expect(alertSpy.mock.calls[0][0]).toMatch(/Phase 5/i)
  })

  it('Click auf Note-Button triggert window.alert mit Phase-5-Text', () => {
    const c = makeContact({ id: 'c1' })
    render(<RowQuickActions contact={c} density="comfortable" />)
    const noteBtn = screen.getByRole('button', { name: /Quick-Notiz/i })
    fireEvent.click(noteBtn)
    expect(alertSpy).toHaveBeenCalledTimes(1)
    expect(alertSpy.mock.calls[0][0]).toMatch(/Phase 5/i)
  })

  it('Click auf einen Quick-Action-Button stoppt Propagation zum Parent', () => {
    const onParentClick = vi.fn()
    const c = makeContact({ id: 'c1' })
    render(
      <div onClick={onParentClick}>
        <RowQuickActions contact={c} density="comfortable" />
      </div>
    )
    const mailBtn = screen.getByRole('button', { name: /Quick-Mail/i })
    fireEvent.click(mailBtn)
    expect(onParentClick).not.toHaveBeenCalled()

    const noteBtn = screen.getByRole('button', { name: /Quick-Notiz/i })
    fireEvent.click(noteBtn)
    expect(onParentClick).not.toHaveBeenCalled()
  })
})
