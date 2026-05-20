/**
 * Hooks for CorrectionSheet — single-movement read for edit-mode, plus
 * insert/update/delete mutations.
 *
 * Mutations invalidate saldo / movement / cockpit caches because manual
 * corrections shift aggregate numbers immediately.
 */

import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import {
  fetchAccountMovement,
  insertCorrection,
  updateAccountMovement,
  deleteAccountMovement,
  type AccountMovementForEdit,
  type CorrectionInsertInput,
  type CorrectionUpdateInput,
} from '@/lib/queries'

export function useAccountMovement(movementId: string | null | undefined) {
  return useQuery<AccountMovementForEdit | null, Error>({
    queryKey: ['accountMovements', 'detail', movementId],
    queryFn: () => fetchAccountMovement(movementId as string),
    enabled: Boolean(movementId),
  })
}

function invalidateSaldoScope(qc: ReturnType<typeof useQueryClient>) {
  qc.invalidateQueries({ queryKey: ['saldi'] })
  qc.invalidateQueries({ queryKey: ['myMovements'] })
  qc.invalidateQueries({ queryKey: ['accountMovements'] })
  qc.invalidateQueries({ queryKey: ['cockpit'] })
}

export function useInsertCorrection() {
  const qc = useQueryClient()
  return useMutation<void, Error, CorrectionInsertInput>({
    mutationFn: (input) => insertCorrection(input),
    onSuccess: () => invalidateSaldoScope(qc),
  })
}

export interface UpdateMovementVars {
  movementId: string
  input: CorrectionUpdateInput
}

export function useUpdateAccountMovement() {
  const qc = useQueryClient()
  return useMutation<void, Error, UpdateMovementVars>({
    mutationFn: ({ movementId, input }) => updateAccountMovement(movementId, input),
    onSuccess: () => invalidateSaldoScope(qc),
  })
}

export function useDeleteAccountMovement() {
  const qc = useQueryClient()
  return useMutation<void, Error, string>({
    mutationFn: (movementId) => deleteAccountMovement(movementId),
    onSuccess: () => invalidateSaldoScope(qc),
  })
}
