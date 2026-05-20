/**
 * Hooks for the CourseEditSheet — type options, edit-mode data load,
 * conflict checks (read), plus save/delete mutations.
 *
 * The mutation hooks fan out invalidations across every cache namespace
 * a course write can affect:
 *   - 'courses' (all course lists)
 *   - 'assignments' (per-course and cross-course)
 *   - 'participants' (per-course)
 *   - 'courseDates' (per-course)
 *   - 'kpis' (cockpit/today aggregates)
 *   - 'cockpit'
 *   - 'saldi' / 'myMovements' (only on delete, because it removes movements)
 */

import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import {
  fetchCourseTypeOptions,
  fetchCourseForEdit,
  fetchCourseDatesForEdit,
  checkScheduleConflicts,
  insertCourse,
  updateCourseRow,
  replaceCourseDates,
  insertCourseAssignment,
  deleteCourseWithCleanup,
  type CourseTypeOption,
  type CourseForEdit,
  type CourseDateForEdit,
  type ScheduleConflict,
  type CourseSaveInput,
  type CourseDateInsert,
} from '@/lib/queries'

/** Active course types for the edit form's type dropdown. */
export function useCourseTypeOptions() {
  return useQuery<CourseTypeOption[], Error>({
    queryKey: ['courseTypes', 'options'],
    queryFn: () => fetchCourseTypeOptions(),
    staleTime: 10 * 60_000,
  })
}

/** Single course row for the edit form. */
export function useCourseForEdit(courseId: string | null | undefined) {
  return useQuery<CourseForEdit | null, Error>({
    queryKey: ['courseEdit', 'course', courseId],
    queryFn: () => fetchCourseForEdit(courseId as string),
    enabled: Boolean(courseId),
  })
}

/** Per-date breakdown for the edit form. */
export function useCourseDatesForEdit(courseId: string | null | undefined) {
  return useQuery<CourseDateForEdit[], Error>({
    queryKey: ['courseEdit', 'dates', courseId],
    queryFn: () => fetchCourseDatesForEdit(courseId as string),
    enabled: Boolean(courseId),
  })
}

/**
 * Live conflict check when picking a haupt-instructor in create mode.
 * Disabled when there's no instructor selected or no dates yet.
 */
export function useScheduleConflicts(
  instructorId: string | null | undefined,
  dates: string[],
) {
  return useQuery<ScheduleConflict[], Error>({
    queryKey: ['scheduleConflicts', instructorId, dates],
    queryFn: () => checkScheduleConflicts(instructorId as string, dates),
    enabled: Boolean(instructorId) && dates.length > 0,
  })
}

/**
 * Invalidates every cache namespace a course mutation can affect. Shared
 * helper so create / update / delete all sweep the same scope.
 */
function invalidateCourseScope(
  qc: ReturnType<typeof useQueryClient>,
  opts: { withMovements?: boolean } = {},
) {
  qc.invalidateQueries({ queryKey: ['courses'] })
  qc.invalidateQueries({ queryKey: ['assignments'] })
  qc.invalidateQueries({ queryKey: ['participants'] })
  qc.invalidateQueries({ queryKey: ['courseDates'] })
  qc.invalidateQueries({ queryKey: ['kpis'] })
  qc.invalidateQueries({ queryKey: ['cockpit'] })
  qc.invalidateQueries({ queryKey: ['courseEdit'] })
  if (opts.withMovements) {
    qc.invalidateQueries({ queryKey: ['saldi'] })
    qc.invalidateQueries({ queryKey: ['myMovements'] })
  }
}

export interface CreateCourseVars {
  course: CourseSaveInput
  dateRows: CourseDateInsert[]
  /** Optional haupt-instructor to assign immediately. */
  hauptInstructorId?: string | null
}

/** Creates a new course (+ dates + optional haupt). Returns the new course id. */
export function useCreateCourse() {
  const qc = useQueryClient()
  return useMutation<string, Error, CreateCourseVars>({
    mutationFn: async ({ course, dateRows, hauptInstructorId }) => {
      const id = await insertCourse(course)
      await replaceCourseDates(id, dateRows)
      if (hauptInstructorId) {
        await insertCourseAssignment(id, hauptInstructorId, 'haupt')
      }
      return id
    },
    onSuccess: () => invalidateCourseScope(qc),
  })
}

export interface UpdateCourseVars {
  courseId: string
  course: CourseSaveInput
  dateRows: CourseDateInsert[]
}

/** Updates an existing course and rebuilds its dates. */
export function useUpdateCourse() {
  const qc = useQueryClient()
  return useMutation<void, Error, UpdateCourseVars>({
    mutationFn: async ({ courseId, course, dateRows }) => {
      await updateCourseRow(courseId, course)
      await replaceCourseDates(courseId, dateRows)
    },
    onSuccess: () => invalidateCourseScope(qc),
  })
}

/** Deletes a course and cleans up its payment movements. */
export function useDeleteCourse() {
  const qc = useQueryClient()
  return useMutation<void, Error, string>({
    mutationFn: (courseId) => deleteCourseWithCleanup(courseId),
    onSuccess: () => invalidateCourseScope(qc, { withMovements: true }),
  })
}
