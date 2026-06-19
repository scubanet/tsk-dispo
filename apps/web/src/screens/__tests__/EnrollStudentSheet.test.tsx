import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, screen } from '@testing-library/react'
import { EnrollStudentSheet } from '../EnrollStudentSheet'
import type { Student } from '@/lib/queries'

function makeStudent(index: number): Student {
  const padded = String(index).padStart(3, '0')
  return {
    id: `s${padded}`,
    name: `Student ${padded}`,
    email: `student${padded}@example.com`,
    phone: null,
    birthday: null,
    level: null,
    notes: null,
    active: true,
    created_at: '2026-01-01T00:00:00Z',
    is_student: true,
    is_candidate: false,
    pipeline_stage: null,
  }
}

let studentRows: Student[] = []

vi.mock('@/hooks/useEnrollStudent', () => ({
  useStudents: () => ({ data: studentRows }),
  useCandidates: () => ({ data: [] }),
  useSaveParticipation: () => ({ isPending: false, mutateAsync: vi.fn() }),
  useDeleteParticipation: () => ({ isPending: false, mutateAsync: vi.fn() }),
}))

vi.mock('@/hooks/useActiveInstructors', () => ({
  useActiveInstructors: () => ({ data: [] }),
}))

describe('EnrollStudentSheet', () => {
  beforeEach(() => {
    studentRows = Array.from({ length: 75 }, (_, index) => makeStudent(index + 1))
  })

  it('shows all eligible students instead of cutting the picker at 50 rows', () => {
    render(
      <EnrollStudentSheet
        open
        onClose={vi.fn()}
        onSaved={vi.fn()}
        courseId="course-1"
        courseTypeCode="OWD"
      />,
    )

    expect(screen.getByText('Student 001')).toBeTruthy()
    expect(screen.getByText('Student 050')).toBeTruthy()
    expect(screen.getByText('Student 075')).toBeTruthy()
  })
})
