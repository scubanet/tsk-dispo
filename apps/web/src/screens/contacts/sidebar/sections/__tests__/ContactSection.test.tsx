import { describe, it, expect, vi } from 'vitest'
import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { ContactSection } from '../ContactSection'
import type { ContactWithProperties } from '@/types/contactProperties'

const mockMutate = vi.fn().mockResolvedValue(undefined)
vi.mock('@/hooks/useContactFieldMutation', () => ({
  useContactFieldMutation: () => ({
    mutateAsync: mockMutate, isPending: false, error: null,
  }),
}))

function wrapper({ children }: { children: React.ReactNode }) {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } })
  return <QueryClientProvider client={qc}>{children}</QueryClientProvider>
}

const baseContact: ContactWithProperties = {
  id: 'c1', kind: 'person', display_name: 'Hugo Eugster',
  first_name: 'Hugo', last_name: 'Eugster', birth_date: null,
  primary_email: 'hugo@test.com',
  phones: [{ label: 'mobile', e164: '+41791234567', primary: true }],
  addresses: [],
  languages: ['de'],
  source: 'manual',
  created_at: '2026-01-01T00:00:00Z',
  updated_at: '2026-05-27T00:00:00Z',
  owner_id: null,
  tags: [],
  instructor: null, student: null, organization: null,
  balance_chf: null, last_movement_date: null,
  roles: [],
}

describe('ContactSection', () => {
  it('renders email, primary phone, and first language', () => {
    render(<ContactSection contact={baseContact} />, { wrapper })
    expect(screen.getByText('hugo@test.com')).toBeTruthy()
    expect(screen.getByText('+41791234567')).toBeTruthy()
    expect(screen.getByText('de')).toBeTruthy()
  })

  it('renders dash for empty phones/languages', () => {
    render(
      <ContactSection contact={{ ...baseContact, phones: [], addresses: [], languages: [] }} />,
      { wrapper },
    )
    expect(screen.getAllByText('—').length).toBeGreaterThanOrEqual(2)
  })

  it('editing email calls mutation with primary_email field on contacts table', async () => {
    mockMutate.mockClear()
    render(<ContactSection contact={baseContact} />, { wrapper })
    fireEvent.click(screen.getByText('hugo@test.com'))
    const input = screen.getByDisplayValue('hugo@test.com') as HTMLInputElement
    fireEvent.change(input, { target: { value: 'new@test.com' } })
    fireEvent.keyDown(input, { key: 'Enter' })
    await waitFor(() =>
      expect(mockMutate).toHaveBeenCalledWith({
        table: 'contacts',
        field: 'primary_email',
        value: 'new@test.com',
      })
    )
  })

  it('phone is read-only — picks the primary entry from phones[]', () => {
    const contact = {
      ...baseContact,
      phones: [
        { label: 'home', e164: '+41441111111', primary: false },
        { label: 'mobile', e164: '+41792222222', primary: true },
      ],
    }
    render(<ContactSection contact={contact} />, { wrapper })
    expect(screen.getByText('+41792222222')).toBeTruthy()
    expect(screen.queryByText('+41441111111')).toBeNull()
  })
})
