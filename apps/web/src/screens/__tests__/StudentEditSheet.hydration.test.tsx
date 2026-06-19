// Regression test for the "input reverts while typing" bug.
//
// Root cause: the form-hydration useEffect depended on `relationships`, a
// React-Query result defaulted with `= []`. In non-CD mode that query is
// disabled, so `data` is undefined and `relationships` is a brand-new []
// reference on every render. The effect therefore re-ran on every render and
// called setForm(serverValues), reverting each keystroke.
//
// This test types into the first_name field and asserts the typed value
// survives the re-render (i.e. is NOT reverted to the server value).
import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, screen, fireEvent } from '@testing-library/react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { StudentEditSheet } from '../StudentEditSheet'
import type { ContactWithSidecars } from '@/types/contacts'

let mockCws: ContactWithSidecars | null = null

// Stub the presentational shell so the test doesn't transform the whole
// @/foundation barrel (keeps memory + time down; we only exercise form logic).
vi.mock('@/components/Sheet', () => ({
  Sheet: ({ children }: { children: React.ReactNode }) => <div data-sheet>{children}</div>,
}))
vi.mock('@/components/Icon', () => ({ Icon: () => null }))
vi.mock('react-i18next', () => ({ useTranslation: () => ({ t: (k: string) => k }) }))

vi.mock('@/hooks/useContactWithSidecars', () => ({
  useContactWithSidecars: () => ({ data: mockCws, isLoading: mockCws === null, error: null }),
}))

// Mimic the real disabled-query behaviour: undefined data, so the component's
// `?? []` / `= []` default produces a fresh array reference every render.
vi.mock('@/hooks/useContactTabs', () => ({
  useContactRelationships: () => ({ data: undefined, isLoading: false, isSuccess: false, error: null }),
}))

vi.mock('@/hooks/useStudentEdit', () => ({
  useOrganizations: () => ({ data: [] }),
  useUpsertStudent: () => ({ mutateAsync: vi.fn().mockResolvedValue('s1'), isPending: false }),
  useDeleteContact: () => ({ mutateAsync: vi.fn().mockResolvedValue(undefined), isPending: false }),
}))

const SAMPLE: ContactWithSidecars = {
  id: 's1',
  kind: 'person',
  first_name: 'Zorro',
  last_name: 'Tester',
  display_name: 'Zorro Tester',
  primary_email: null,
  emails: [],
  phones: [],
  addresses: [],
  languages: [],
  roles: ['student'],
  tags: [],
  notes: null,
  birth_date: null,
  student: { level: 'OWD' },
} as unknown as ContactWithSidecars

function wrapper({ children }: { children: React.ReactNode }) {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } })
  return <QueryClientProvider client={qc}>{children}</QueryClientProvider>
}

describe('StudentEditSheet — input does not revert while typing', () => {
  beforeEach(() => {
    mockCws = SAMPLE
  })

  it('keeps the typed first_name value (non-CD mode)', () => {
    render(
      <StudentEditSheet open onClose={vi.fn()} onSaved={vi.fn()} studentId="s1" showCdFields={false} />,
      { wrapper },
    )

    // Form hydrated from the server: first_name === "Zorro".
    const input = screen.getByDisplayValue('Zorro') as HTMLInputElement

    // Simulate the user typing one more character.
    fireEvent.change(input, { target: { value: 'Zorrox' } })

    // With the bug, the hydration effect re-runs on the resulting render and
    // reverts this back to "Zorro". After the fix it must stay "Zorrox".
    expect(input.value).toBe('Zorrox')
  })
})
