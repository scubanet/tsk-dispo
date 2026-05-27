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
  primary_phone: '+41791234567',
  primary_language: 'de',
  source: 'manual',
  created_at: '2026-01-01T00:00:00Z',
  updated_at: '2026-05-27T00:00:00Z',
  owner_id: null,
  instructor: null, student: null, organization: null,
  balance_chf: null, last_movement_date: null,
  roles: [],
}

describe('ContactSection', () => {
  it('renders email, phone, and language values', () => {
    render(<ContactSection contact={baseContact} />, { wrapper })
    expect(screen.getByText('hugo@test.com')).toBeTruthy()
    expect(screen.getByText('+41791234567')).toBeTruthy()
    expect(screen.getByText('de')).toBeTruthy()
  })

  it('renders dash for null fields', () => {
    render(<ContactSection contact={{ ...baseContact, primary_phone: null }} />, { wrapper })
    // EditableField renders '—' for null values
    expect(screen.getAllByText('—').length).toBeGreaterThanOrEqual(1)
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
})
