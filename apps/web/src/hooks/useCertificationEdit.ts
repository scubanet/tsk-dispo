/**
 * Hooks for CertificationEditSheet — save/delete mutations only.
 *
 * Mutations invalidate `['certifications', studentId]` (BrevetsView in
 * MyProfile + ContactDetailPanel) plus the per-student fetch under
 * `['studentCertifications']` (legacy callers).
 */

import { useMutation, useQueryClient } from '@tanstack/react-query'
import {
  insertStudentCertification,
  updateStudentCertification,
  deleteStudentCertification,
  type StudentCertificationInput,
} from '@/lib/queries'

function invalidateCertificationScope(
  qc: ReturnType<typeof useQueryClient>,
  studentId: string,
) {
  qc.invalidateQueries({ queryKey: ['certifications', studentId] })
  qc.invalidateQueries({ queryKey: ['studentCertifications', studentId] })
}

export interface SaveCertificationVars {
  certificationId?: string | null
  input: StudentCertificationInput
}

export function useSaveCertification() {
  const qc = useQueryClient()
  return useMutation<void, Error, SaveCertificationVars>({
    mutationFn: async ({ certificationId, input }) => {
      if (certificationId) {
        await updateStudentCertification(certificationId, input)
      } else {
        await insertStudentCertification(input)
      }
    },
    onSuccess: (_data, vars) => invalidateCertificationScope(qc, vars.input.student_id),
  })
}

export interface DeleteCertificationVars {
  certificationId: string
  studentId: string
}

export function useDeleteCertification() {
  const qc = useQueryClient()
  return useMutation<void, Error, DeleteCertificationVars>({
    mutationFn: ({ certificationId }) => deleteStudentCertification(certificationId),
    onSuccess: (_data, vars) => invalidateCertificationScope(qc, vars.studentId),
  })
}
