import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { RolesStatusSection } from '../RolesStatusSection'
import type {
  ContactWithProperties,
  InstructorSidecar,
  StudentSidecar,
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

const studentSidecar: StudentSidecar = {
  pipeline_stage: 'lead',
  intake_status: 'erstkontakt',
  highest_brevet: 'OWD',
}

const instructorSidecar: InstructorSidecar = {
  padi_level: 'IDC Staff',
  padi_pro_number: '123456',
  active: true,
}

beforeEach(() => {
  mockMutate.mockClear()
  // Clean localStorage to ensure defaultOpen wins
  try { window.localStorage.clear() } catch { /* noop */ }
})

describe('RolesStatusSection', () => {
  it('renders title "Rollen & Status"', () => {
    render(
      <RolesStatusSection contact={{ ...baseContact, student: studentSidecar }} />,
      { wrapper },
    )
    expect(screen.getByText('Rollen & Status')).toBeTruthy()
  })

  it('with student-only contact: renders pipeline-stage, intake-status, brevet, NO active toggle', () => {
    render(
      <RolesStatusSection contact={{ ...baseContact, student: studentSidecar }} />,
      { wrapper },
    )
    expect(screen.getByText('Pipeline-Stage')).toBeTruthy()
    expect(screen.getByText('Intake-Status')).toBeTruthy()
    expect(screen.getByText('Brevet')).toBeTruthy()
    expect(screen.getByText('lead')).toBeTruthy()
    expect(screen.getByText('erstkontakt')).toBeTruthy()
    expect(screen.getByText('OWD')).toBeTruthy()
    expect(screen.queryByRole('button', { name: /Aktiv|Inaktiv/ })).toBeNull()
  })

  it('with instructor-only contact: renders active toggle, NO student fields', () => {
    render(
      <RolesStatusSection contact={{ ...baseContact, instructor: instructorSidecar }} />,
      { wrapper },
    )
    expect(screen.queryByText('Pipeline-Stage')).toBeNull()
    expect(screen.queryByText('Intake-Status')).toBeNull()
    expect(screen.queryByText('Brevet')).toBeNull()
    expect(screen.getByRole('button', { name: /Aktiv/ })).toBeTruthy()
  })

  it('with both sidecars: renders both sets', () => {
    render(
      <RolesStatusSection contact={{
        ...baseContact, student: studentSidecar, instructor: instructorSidecar,
      }} />,
      { wrapper },
    )
    expect(screen.getByText('Pipeline-Stage')).toBeTruthy()
    expect(screen.getByText('Intake-Status')).toBeTruthy()
    expect(screen.getByText('Brevet')).toBeTruthy()
    expect(screen.getByRole('button', { name: /Aktiv/ })).toBeTruthy()
  })

  it('with neither student nor instructor: renders no content fields', () => {
    render(<RolesStatusSection contact={baseContact} />, { wrapper })
    expect(screen.queryByText('Pipeline-Stage')).toBeNull()
    expect(screen.queryByText('Intake-Status')).toBeNull()
    expect(screen.queryByText('Brevet')).toBeNull()
    expect(screen.queryByRole('button', { name: /Aktiv|Inaktiv/ })).toBeNull()
  })

  it('editing pipeline_stage calls mutate with contact_student/pipeline_stage', async () => {
    render(
      <RolesStatusSection contact={{ ...baseContact, student: studentSidecar }} />,
      { wrapper },
    )
    fireEvent.click(screen.getByText('lead'))
    const input = screen.getByDisplayValue('lead') as HTMLInputElement
    fireEvent.change(input, { target: { value: 'qualified' } })
    fireEvent.keyDown(input, { key: 'Enter' })
    await waitFor(() =>
      expect(mockMutate).toHaveBeenCalledWith({
        table: 'contact_student',
        field: 'pipeline_stage',
        value: 'qualified',
      }),
    )
  })

  it('clicking active toggle (currently true) calls mutate with active=false', async () => {
    render(
      <RolesStatusSection contact={{ ...baseContact, instructor: instructorSidecar }} />,
      { wrapper },
    )
    const toggle = screen.getByRole('button', { name: /Aktiv/ })
    fireEvent.click(toggle)
    await waitFor(() =>
      expect(mockMutate).toHaveBeenCalledWith({
        table: 'contact_instructor',
        field: 'active',
        value: false,
      }),
    )
  })

  it('invalid pipeline_stage shows error and does NOT call mutate', async () => {
    render(
      <RolesStatusSection contact={{ ...baseContact, student: studentSidecar }} />,
      { wrapper },
    )
    fireEvent.click(screen.getByText('lead'))
    const input = screen.getByDisplayValue('lead') as HTMLInputElement
    fireEvent.change(input, { target: { value: 'foo' } })
    fireEvent.keyDown(input, { key: 'Enter' })
    await waitFor(() => expect(screen.getByRole('alert')).toBeTruthy())
    expect(mockMutate).not.toHaveBeenCalled()
  })
})
