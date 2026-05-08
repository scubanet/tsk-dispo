/**
 * SkillMatrixScreen — Foundation-based rewrite.
 *
 * Layout:
 *   PageHeader (search + category dropdown as actions)
 *   ┌─ Foundation card ───────────────────────────────────────┐
 *   │  Sticky-header matrix:                                  │
 *   │   first column: instructor name + padi_level            │
 *   │   skill columns: rotated label headers                  │
 *   │   cells: tap to toggle (filled = teal check, else dot)  │
 *   └─────────────────────────────────────────────────────────┘
 */

import { useEffect, useMemo, useState } from 'react'
import { useTranslation } from 'react-i18next'
import {
  PageHeader,
  SearchInput,
  SortDropdown,
  EmptyState,
  Icon,
} from '@/foundation'
import { supabase } from '@/lib/supabase'

interface Skill {
  id: string
  code: string
  label: string
  category: string | null
}

interface Inst {
  id: string
  name: string
  padi_level: string
}

export function SkillMatrixScreen() {
  const { t } = useTranslation()
  const [skills, setSkills] = useState<Skill[]>([])
  const [instructors, setInstructors] = useState<Inst[]>([])
  const [matrix, setMatrix] = useState<Set<string>>(new Set())
  const [search, setSearch] = useState('')
  const [category, setCategory] = useState<string>('all')

  useEffect(() => {
    Promise.all([
      supabase.from('skills').select('id, code, label, category').order('label'),
      supabase
        .from('instructors')
        .select('id, name, padi_level')
        .eq('active', true)
        .order('last_name')
        .order('first_name'),
      supabase.from('instructor_skills').select('instructor_id, skill_id'),
    ]).then(([s, i, m]) => {
      setSkills((s.data ?? []) as Skill[])
      setInstructors((i.data ?? []) as Inst[])
      setMatrix(
        new Set(
          ((m.data ?? []) as { instructor_id: string; skill_id: string }[]).map(
            (r) => `${r.instructor_id}|${r.skill_id}`,
          ),
        ),
      )
    })
  }, [])

  const categories = useMemo(() => {
    const set = new Set<string>()
    skills.forEach((s) => s.category && set.add(s.category))
    return ['all', ...Array.from(set).sort()]
  }, [skills])

  const filteredSkills = useMemo(() => {
    if (category === 'all') return skills
    return skills.filter((s) => s.category === category)
  }, [skills, category])

  const filteredInstructors = useMemo(() => {
    if (!search) return instructors
    const q = search.toLowerCase()
    return instructors.filter(
      (i) => i.name.toLowerCase().includes(q) || i.padi_level.toLowerCase().includes(q),
    )
  }, [instructors, search])

  async function toggle(instId: string, skillId: string) {
    const key = `${instId}|${skillId}`
    if (matrix.has(key)) {
      await supabase
        .from('instructor_skills')
        .delete()
        .match({ instructor_id: instId, skill_id: skillId })
      const next = new Set(matrix)
      next.delete(key)
      setMatrix(next)
    } else {
      await supabase
        .from('instructor_skills')
        .insert({ instructor_id: instId, skill_id: skillId })
      const next = new Set(matrix)
      next.add(key)
      setMatrix(next)
    }
  }

  const categoryOptions = categories.map((c) => ({
    id: c,
    label: c === 'all' ? t('skill_matrix.all_categories') : c,
  }))

  return (
    <div className="atoll-screen">
      <PageHeader
        title={t('nav.skills')}
        subtitle={t('skill_matrix.subtitle', {
          people: instructors.length,
          skills: skills.length,
        })}
        actions={
          <>
            <SearchInput
              value={search}
              onChange={setSearch}
              ariaLabel={t('skill_matrix.search_placeholder')}
              placeholder={t('skill_matrix.search_placeholder')}
            />
            <SortDropdown
              options={categoryOptions}
              value={category}
              onChange={setCategory}
              ariaLabel={t('skill_matrix.all_categories')}
            />
          </>
        }
      />

      <div className="atoll-screen__body">
        <section className="atoll-cockpit__card atoll-skillmatrix__card">
          {filteredInstructors.length === 0 || filteredSkills.length === 0 ? (
            <EmptyState
              icon={<Icon.Users size={20} />}
              title={t('courses.no_matches')}
            />
          ) : (
            <div className="atoll-skillmatrix__scroll">
              <table className="atoll-skillmatrix__table">
                <thead>
                  <tr>
                    <th className="atoll-skillmatrix__corner">
                      {t('skill_matrix.col_person')}
                    </th>
                    {filteredSkills.map((s) => (
                      <th key={s.id} className="atoll-skillmatrix__skill-head">
                        <span>{s.label}</span>
                      </th>
                    ))}
                  </tr>
                </thead>
                <tbody>
                  {filteredInstructors.map((i) => (
                    <tr key={i.id}>
                      <td className="atoll-skillmatrix__name">
                        <div className="atoll-skillmatrix__name-text">{i.name}</div>
                        <div className="atoll-skillmatrix__name-sub">{i.padi_level}</div>
                      </td>
                      {filteredSkills.map((s) => {
                        const has = matrix.has(`${i.id}|${s.id}`)
                        return (
                          <td
                            key={s.id}
                            className={`atoll-skillmatrix__cell${has ? ' atoll-skillmatrix__cell--has' : ''}`}
                            onClick={() => toggle(i.id, s.id)}
                          >
                            {has ? <Icon.Check size={12} /> : <span aria-hidden>·</span>}
                          </td>
                        )
                      })}
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </section>
      </div>
    </div>
  )
}
