import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { PadiSection } from '../PadiSection'
import type {
  ContactWithProperties,
  InstructorSidecar,
} from '@/types/contactProperties'

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
  primary_email: null, primary_phone: null, primary_language: null,
  source: 'manual',
  created_at: '2026-01-01T00:00:00Z',
  updated_at: '2026-05-27T00:00:00Z',
  owner_id: null,
  tags: [],
  instructor: null, student: null, organization: null,
  balance_chf: null, last_movement_date: null,
  roles: [],
}

const instructorSidecar: InstructorSidecar = {
  padi_level: 'IDC Staff',
  padi_pro_number: '123456',
  active: true,
}

/** Open the section by pre-seeding localStorage (SidebarSection reads it on mount). */
function openPadi() {
  try { window.localStorage.setItem('sidebar-section-padi', 'true') } catch { /* noop */ }
}

beforeEach(() => {
  mockMutate.mockClear()
  try { window.localStorage.clear() } catch { /* noop */ }
})

describe('PadiSection', () => {
  it('renders title "PADI" when instructor sidecar present', () => {
    render(
      <PadiSection contact={{ ...baseContact, instructor: instructorSidecar }} />,
      { wrapper },
    )
    expect(screen.getByText('PADI')).toBeTruthy()
  })

  it('returns null (renders nothing) when instructor sidecar is null', () => {
    const { container } = render(
      <PadiSection contact={baseContact} />,
      { wrapper },
    )
    expect(container.firstChild).toBeNull()
    expect(screen.queryByText('PADI')).toBeNull()
  })

  it('is default closed (body hidden)', () => {
    render(
      <PadiSection contact={{ ...baseContact, instructor: instructorSidecar }} />,
      { wrapper },
    )
    const body = document.getElementById('sidebar-section-padi-body')
    expect(body).toBeTruthy()
    expect(body?.hasAttribute('hidden')).toBe(true)
  })

  it('after open: renders padi_level + padi_pro_number values', () => {
    openPadi()
    render(
      <PadiSection contact={{ ...baseContact, instructor: instructorSidecar }} />,
      { wrapper },
    )
    expect(screen.getByText('IDC Staff')).toBeTruthy()
    expect(screen.getByText('123456')).toBeTruthy()
  })

  it('editing padi_level calls mutate with contact_instructor/padi_level', async () => {
    openPadi()
    render(
      <PadiSection contact={{ ...baseContact, instructor: instructorSidecar }} />,
      { wrapper },
    )
    fireEvent.click(screen.getByText('IDC Staff'))
    const input = screen.getByDisplayValue('IDC Staff') as HTMLInputElement
    fireEvent.change(input, { target: { value: 'OWSI' } })
    fireEvent.keyDown(input, { key: 'Enter' })
    await waitFor(() =>
      expect(mockMutate).toHaveBeenCalledWith({
        table: 'contact_instructor',
        field: 'padi_level',
        value: 'OWSI',
      }),
    )
  })

  it('editing padi_pro_number calls mutate with contact_instructor/padi_pro_number', async () => {
    openPadi()
    render(
      <PadiSection contact={{ ...baseContact, instructor: instructorSidecar }} />,
      { wrapper },
    )
    fireEvent.click(screen.getByText('123456'))
    const input = screen.getByDisplayValue('123456') as HTMLInputElement
    fireEvent.change(input, { target: { value: '654321' } })
    fireEvent.keyDown(input, { key: 'Enter' })
    await waitFor(() =>
      expect(mockMutate).toHaveBeenCalledWith({
        table: 'contact_instructor',
        field: 'padi_pro_number',
        value: '654321',
      }),
    )
  })

})
