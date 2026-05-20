/**
 * Hooks for AssignmentEditSheet — reads the course-type code (for the
 * conditional Opfer-Rolle) and exposes save/delete mutations.
 *
 * Save/delete invalidate the same scope CourseEditSheet uses for
 * assignments, plus the `kpis` aggregate that depends on assignment
 * counts (cockpit "Aktive TLs", Today "Zuweisungen diese Woche").
 */

import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import {
  fetchCourseTypeCode,
  insertAssignmentRow,
  updateAssignmentRow,
  deleteAssignmentRow,
  type AssignmentSaveInput,
} from '@/lib/queries'

export function useCourseTypeCode(courseId: string | null | undefined) {
  return useQuery<string | null, Error>({
    queryKey: ['courseTypeCode', courseId],
    queryFn: () => fetchCourseTypeCode(courseId as string),
    enabled: Boolean(courseId),
    staleTime: 10 * 60_000,
  })
}

function invalidateAssignmentScope(qc: ReturnType<typeof useQueryClient>) {
  qc.invalidateQueries({ queryKey: ['assignments'] })
  qc.invalidateQueries({ queryKey: ['myAssignments'] })
  qc.invalidateQueries({ queryKey: ['kpis'] })
  qc.invalidateQueries({ queryKey: ['cockpit'] })
}

export interface SaveAssignmentVars {
  /** When set, updates this assignment; otherwise inserts a new row. */
  assignmentId?: string | null
  input: AssignmentSaveInput
}

export function useSaveAssignment() {
  const qc = useQueryClient()
  return useMutation<void, Error, SaveAssignmentVars>({
    mutationFn: async ({ assignmentId, input }) => {
      if (assignmentId) {
        const { course_id: _, ...patch } = input
        await updateAssignmentRow(assignmentId, patch)
      } else {
        await insertAssignmentRow(input)
      }
    },
    onSuccess: () => invalidateAssignmentScope(qc),
  })
}

export function useDeleteAssignment() {
  const qc = useQueryClient()
  return useMutation<void, Error, string>({
    mutationFn: (id) => deleteAssignmentRow(id),
    onSuccess: () => invalidateAssignmentScope(qc),
  })
}
