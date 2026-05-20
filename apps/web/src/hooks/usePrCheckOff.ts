/**
 * Hook for PrCheckOffSheet. The read side reuses useCoursePrRecords —
 * the sheet just filters to the single `pr_code` it's editing. That means
 * opening this sheet from inside CourseDetailPanel's PR tab is a cache
 * hit, no extra roundtrip.
 *
 * The write side is a bulk upsert keyed on (student_id, course_id, pr_code).
 */

import { useMutation, useQueryClient } from '@tanstack/react-query'
import {
  upsertPerformanceRecords,
  type PerformanceRecordUpsert,
} from '@/lib/queries'

export function useUpsertPerformanceRecords() {
  const qc = useQueryClient()
  return useMutation<void, Error, PerformanceRecordUpsert[]>({
    mutationFn: (rows) => upsertPerformanceRecords(rows),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['prRecords'] })
    },
  })
}
