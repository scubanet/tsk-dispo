// Regression test for the "input reverts while typing" bug in edit mode.
//
// Root cause: the edit-mode hydration useEffect depended on `existingDates`, a
// React-Query result defaulted with `= []`. That array is a fresh reference on
// renders where the query has no data yet / refetches, so the effect re-ran and
// called setTitle/setDates(serverValues), reverting in-progress edits.
import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, screen, fireEvent } from '@testing-library/react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { CourseEditSheet } from '../CourseEditSheet'

type CourseForEdit = {
  type_id: string
  title: string
  status: 'tentative' | 'confirmed' | 'completed' | 'cancelled'
  num_participants: number
  info: string | null
  notes: string | null
  start_date: string
  additional_dates: string[]
}

let mockCourse: CourseForEdit | null = null

// Stub the presentational shell so the test doesn't transform the whole
// @/foundation barrel (keeps memory + time down; we only exercise form logic).
vi.mock('@/components/Sheet', () => ({
  Sheet: ({ children }: { children: React.ReactNode }) => <div data-sheet>{children}</div>,
}))
vi.mock('@/components/Icon', () => ({ Icon: () => null }))
vi.mock('react-i18next', () => ({ useTranslation: () => ({ t: (k: string) => k }) }))

vi.mock('@/hooks/useActiveInstructors', () => ({
  useActiveInstructors: () => ({ data: [] }),
}))

vi.mock('@/hooks/useCourseEdit', () => ({
  useCourseTypeOptions: () => ({ data: [] }),
  useCourseForEdit: () => ({ data: mockCourse, isLoading: mockCourse === null, isSuccess: mockCourse !== null }),
  // data undefined → component's `= []` default yields a fresh array each render,
  // reproducing the reference churn. isLoading:false so the fixed code hydrates.
  useCourseDatesForEdit: () => ({ data: undefined, isLoading: false, isSuccess: true }),
  useScheduleConflicts: () => ({ data: [] }),
  useCreateCourse: () => ({ mutateAsync: vi.fn(), isPending: false }),
  useUpdateCourse: () => ({ mutateAsync: vi.fn(), isPending: false }),
  useDeleteCourse: () => ({ mutateAsync: vi.fn(), isPending: false }),
}))

const SAMPLE: CourseForEdit = {
  type_id: 't1',
  title: 'OWDKurs',
  status: 'tentative',
  num_participants: 0,
  info: null,
  notes: null,
  start_date: '2026-07-01',
  additional_dates: [],
}

function wrapper({ children }: { children: React.ReactNode }) {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } })
  return <QueryClientProvider client={qc}>{children}</QueryClientProvider>
}

describe('CourseEditSheet — input does not revert while typing (edit mode)', () => {
  beforeEach(() => {
    mockCourse = SAMPLE
  })

  it('keeps the typed title value', () => {
    render(
      <CourseEditSheet open onClose={vi.fn()} onSaved={vi.fn()} courseId="c1" />,
      { wrapper },
    )

    const input = screen.getByDisplayValue('OWDKurs') as HTMLInputElement
    fireEvent.change(input, { target: { value: 'OWDKurs2' } })

    expect(input.value).toBe('OWDKurs2')
  })
})
