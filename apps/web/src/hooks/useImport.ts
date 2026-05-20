/**
 * Hooks for the Excel-Import wizard. The edge function has three actions
 * (preview / dryrun / apply); preview + dryrun are read-shaped (queryKey
 * with inputs → idempotent given the same storage object) while apply is
 * a one-time mutation that rewrites the world.
 */

import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import {
  uploadImportFile,
  importExcelPreview,
  importExcelDryRun,
  importExcelApply,
  type ImportPreview,
  type ImportDryRunSummary,
} from '@/lib/queries'

/**
 * Stage 1: file -> storage upload -> preview. Single mutation because the
 * upload generates a new path each call (timestamp prefix), so caching is
 * not meaningful.
 */
export function useImportPreview() {
  return useMutation<
    { storagePath: string; preview: ImportPreview },
    Error,
    File
  >({
    mutationFn: async (file: File) => {
      const storagePath = await uploadImportFile(file)
      const preview = await importExcelPreview(storagePath)
      return { storagePath, preview }
    },
  })
}

/**
 * Stage 3 read: dry-run. `enabled` lets the caller hold off until both
 * inputs are present. Cache key includes mappings so going back to
 * Stage 2 + changing a mapping triggers a fresh dry-run.
 */
export function useImportDryRun(
  storagePath: string | null,
  mappings: Record<string, string> | null,
) {
  return useQuery<ImportDryRunSummary, Error>({
    queryKey: ['import', 'dryRun', storagePath, mappings],
    queryFn: () => importExcelDryRun(storagePath as string, mappings as Record<string, string>),
    enabled: Boolean(storagePath) && Boolean(mappings),
    staleTime: Infinity, // dry-run is idempotent for given inputs
  })
}

/**
 * Stage 3 write: apply. After success we blow away every aggregate cache
 * we know about — the import rewrites courses, assignments, movements,
 * KPIs, and the saldo view.
 */
export function useImportApply() {
  const qc = useQueryClient()
  return useMutation<
    unknown,
    Error,
    { storagePath: string; mappings: Record<string, string> }
  >({
    mutationFn: ({ storagePath, mappings }) => importExcelApply(storagePath, mappings),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['courses'] })
      qc.invalidateQueries({ queryKey: ['assignments'] })
      qc.invalidateQueries({ queryKey: ['participants'] })
      qc.invalidateQueries({ queryKey: ['saldi'] })
      qc.invalidateQueries({ queryKey: ['myMovements'] })
      qc.invalidateQueries({ queryKey: ['kpis'] })
      qc.invalidateQueries({ queryKey: ['cockpit'] })
      qc.invalidateQueries({ queryKey: ['instructors'] })
      qc.invalidateQueries({ queryKey: ['settings'] })
    },
  })
}
