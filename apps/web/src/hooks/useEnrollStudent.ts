/**
 * Hooks for EnrollStudentSheet — picker lists (students vs. candidates,
 * gated by course type) plus participation save/delete mutations.
 *
 * Save/delete invalidate per-course participants + the parent course list
 * (for the participants-count badge on CoursesScreen) + KPIs.
 */

import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { fetchStudents, type Student } from '@/lib/queries'
import { listCandidates, type StudentRow } from '@/lib/contactQueries'
import {
  insertParticipation,
  updateParticipation,
  deleteParticipation,
  type ParticipationInput,
} from '@/lib/queries'

export function useStudents(enabled: boolean = true) {
  return useQuery<Student[], Error>({
    queryKey: ['students', 'list'],
    queryFn: () => fetchStudents(),
    enabled,
    staleTime: 60_000,
  })
}

export function useCandidates(enabled: boolean = true) {
  return useQuery<StudentRow[], Error>({
    queryKey: ['candidates', 'list'],
    queryFn: () => listCandidates(),
    enabled,
    staleTime: 60_000,
  })
}

function invalidateParticipationScope(qc: ReturnType<typeof useQueryClient>) {
  qc.invalidateQueries({ queryKey: ['participants'] })
  qc.invalidateQueries({ queryKey: ['courses'] })
  qc.invalidateQueries({ queryKey: ['kpis'] })
}

export interface SaveParticipationVars {
  participationId?: string | null
  input: ParticipationInput
}

export function useSaveParticipation() {
  const qc = useQueryClient()
  return useMutation<void, Error, SaveParticipationVars>({
    mutationFn: async ({ participationId, input }) => {
      if (participationId) {
        await updateParticipation(participationId, input)
      } else {
        await insertParticipation(input)
      }
    },
    onSuccess: () => invalidateParticipationScope(qc),
  })
}

export function useDeleteParticipation() {
  const qc = useQueryClient()
  return useMutation<void, Error, string>({
    mutationFn: (participationId) => deleteParticipation(participationId),
    onSuccess: () => invalidateParticipationScope(qc),
  })
}
