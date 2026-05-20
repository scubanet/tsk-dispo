import { useMemo } from 'react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import {
  fetchInstructorSkillsMatrix,
  addInstructorSkill,
  removeInstructorSkill,
} from '@/lib/queries'

type MatrixRow = { instructor_id: string; skill_id: string }

/**
 * React-Query hook around `fetchInstructorSkillsMatrix`. Returns the raw
 * rows plus a derived `Set<"instructorId|skillId">` for O(1) `has()` checks
 * in the UI.
 */
export function useInstructorSkillsMatrix() {
  const q = useQuery<MatrixRow[], Error>({
    queryKey: ['instructorSkills', 'matrix'],
    queryFn: () => fetchInstructorSkillsMatrix(),
  })

  const matrix = useMemo(() => {
    const s = new Set<string>()
    for (const r of q.data ?? []) s.add(`${r.instructor_id}|${r.skill_id}`)
    return s
  }, [q.data])

  return { ...q, matrix }
}

/**
 * Toggle a single (instructor, skill) row with an **optimistic update**:
 * the UI flips immediately, the network call follows, and on error we roll
 * back to the previous matrix. Standard React-Query optimistic-update
 * cookbook.
 */
export function useToggleInstructorSkill() {
  const qc = useQueryClient()
  type Vars = { instructorId: string; skillId: string; currentlyHas: boolean }

  return useMutation({
    mutationFn: ({ instructorId, skillId, currentlyHas }: Vars) =>
      currentlyHas
        ? removeInstructorSkill(instructorId, skillId)
        : addInstructorSkill(instructorId, skillId),
    onMutate: async ({ instructorId, skillId, currentlyHas }) => {
      await qc.cancelQueries({ queryKey: ['instructorSkills', 'matrix'] })
      const previous = qc.getQueryData<MatrixRow[]>(['instructorSkills', 'matrix']) ?? []
      const next: MatrixRow[] = currentlyHas
        ? previous.filter((r) => !(r.instructor_id === instructorId && r.skill_id === skillId))
        : [...previous, { instructor_id: instructorId, skill_id: skillId }]
      qc.setQueryData(['instructorSkills', 'matrix'], next)
      return { previous }
    },
    onError: (_err, _vars, ctx) => {
      if (ctx?.previous) qc.setQueryData(['instructorSkills', 'matrix'], ctx.previous)
    },
    onSettled: () => {
      qc.invalidateQueries({ queryKey: ['instructorSkills'] })
    },
  })
}
