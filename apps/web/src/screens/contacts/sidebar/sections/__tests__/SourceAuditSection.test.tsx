import { describe, it, expect, beforeEach } from 'vitest'
import { render, screen } from '@testing-library/react'
import { SourceAuditSection } from '../SourceAuditSection'
import type { ContactWithProperties } from '@/types/contactProperties'

const baseContact: ContactWithProperties = {
  id: 'a1b2c3d4-e5f6-7890-1234-567890abcdef',
  kind: 'person',
  display_name: 'Hugo Eugster',
  first_name: 'Hugo',
  last_name: 'Eugster',
  birth_date: null,
  primary_email: null,
  phones: [], addresses: [], languages: [],
  
  source: 'manual',
  created_at: '2026-01-01T00:00:00Z',
  updated_at: '2026-05-27T00:00:00Z',
  owner_id: 'f1e2d3c4-b5a6-9870-4321-fedcba098765',
  tags: [],
  instructor: null,
  student: null,
  organization: null,
  balance_chf: null,
  last_movement_date: null,
  roles: [],
}

/** Open the section by pre-seeding localStorage (SidebarSection reads it on mount). */
function openAudit() {
  try { window.localStorage.setItem('sidebar-section-audit', 'true') } catch { /* noop */ }
}

beforeEach(() => {
  try { window.localStorage.clear() } catch { /* noop */ }
})

describe('SourceAuditSection', () => {
  it('renders title "Quelle & Audit"', () => {
    render(<SourceAuditSection contact={baseContact} />)
    expect(screen.getByText('Quelle & Audit')).toBeTruthy()
  })

  it('is default closed (body hidden)', () => {
    render(<SourceAuditSection contact={baseContact} />)
    const body = document.getElementById('sidebar-section-audit-body')
    expect(body).toBeTruthy()
    expect(body?.hasAttribute('hidden')).toBe(true)
  })

  it('after open: renders source value', () => {
    openAudit()
    render(<SourceAuditSection contact={baseContact} />)
    const label = screen.getByText('Quelle')
    expect(label.parentElement?.textContent ?? '').toContain('manual')
  })

  it('after open: renders dash for null source', () => {
    openAudit()
    render(<SourceAuditSection contact={{ ...baseContact, source: null }} />)
    const label = screen.getByText('Quelle')
    expect(label.parentElement?.textContent ?? '').toContain('—')
  })

  it('after open: renders owner_id truncated to 8 chars + ellipsis', () => {
    openAudit()
    render(<SourceAuditSection contact={baseContact} />)
    const label = screen.getByText('Owner ID')
    expect(label.parentElement?.textContent ?? '').toContain('f1e2d3c4…')
  })

  it('after open: renders dash for null owner_id', () => {
    openAudit()
    render(<SourceAuditSection contact={{ ...baseContact, owner_id: null }} />)
    const label = screen.getByText('Owner ID')
    expect(label.parentElement?.textContent ?? '').toContain('—')
  })

  it('after open: renders contact id truncated to 8 chars + ellipsis', () => {
    openAudit()
    render(<SourceAuditSection contact={baseContact} />)
    const label = screen.getByText('Contact ID')
    expect(label.parentElement?.textContent ?? '').toContain('a1b2c3d4…')
  })
})
