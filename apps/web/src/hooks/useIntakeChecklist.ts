/**
 * Hooks for IntakeChecklistSheet — single-row read keyed by course-
 * participant-id OR student-id, plus a save mutation that internally
 * decides between insert and update based on `hasRow`.
 */

import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import {
  fetchIntakeChecklist,
  saveIntakeChecklist,
  type IntakeChecklistKey,
  type IntakeChecklistRow,
} from '@/lib/queries'

export function useIntakeChecklist(key: IntakeChecklistKey, enabled: boolean = true) {
  const hasKey = Boolean(key.courseParticipantId) || Boolean(key.studentId)
  return useQuery<IntakeChecklistRow | null, Error>({
    queryKey: ['intakeChecklist', key.courseParticipantId ?? null, key.studentId ?? null],
    queryFn: () => fetchIntakeChecklist(key),
    enabled: enabled && hasKey,
  })
}

export interface SaveIntakeVars {
  key: IntakeChecklistKey
  payload: Omit<IntakeChecklistRow, 'course_participant_id' | 'student_id'>
  hasRow: boolean
}

export function useSaveIntakeChecklist() {
  const qc = useQueryClient()
  return useMutation<void, Error, SaveIntakeVars>({
    mutationFn: ({ key, payload, hasRow }) => saveIntakeChecklist(key, payload, hasRow),
    onSuccess: (_data, vars) => {
      qc.invalidateQueries({
        queryKey: [
          'intakeChecklist',
          vars.key.courseParticipantId ?? null,
          vars.key.studentId ?? null,
        ],
      })
      // Course-detail view shows a "Intake done?" badge per participant.
      qc.invalidateQueries({ queryKey: ['participants'] })
    },
  })
}
