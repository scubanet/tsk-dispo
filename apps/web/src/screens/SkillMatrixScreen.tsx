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

import { useMemo, useState } from 'react'
import { useTranslation } from 'react-i18next'
import {
  PageHeader,
  SearchInput,
  SortDropdown,
  EmptyState,
  Icon,
} from '@/foundation'
import { useSkills } from '@/hooks/useSkills'
import { useActiveInstructors } from '@/hooks/useActiveInstructors'
import {
  useInstructorSkillsMatrix,
  useToggleInstructorSkill,
} from '@/hooks/useInstructorSkillsMatrix'
import { ContactDetailPanel } from './contacts/ContactDetailPanel'

export function SkillMatrixScreen() {
  const { t } = useTranslation()
  const { data: skills = [] } = useSkills()
  const { data: instructorRows = [] } = useActiveInstructors()
  const { matrix } = useInstructorSkillsMatrix()
  const toggleSkill = useToggleInstructorSkill()
  const [search, setSearch] = useState('')
  const [category, setCategory] = useState<string>('all')
  const [selectedId, setSelectedId] = useState<string | null>(null)

  // Drop the `active` flag — the matrix already filters by active=true.
  const instructors = useMemo(
    () => instructorRows.map(({ id, name, padi_level }) => ({ id, name, padi_level })),
    [instructorRows],
  )

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

  function toggle(instId: string, skillId: string) {
    const currentlyHas = matrix.has(`${instId}|${skillId}`)
    toggleSkill.mutate({ instructorId: instId, skillId, currentlyHas })
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
                        <button
                          type="button"
                          className="atoll-skillmatrix__name-text atoll-skillmatrix__name-text--link"
                          onClick={() => setSelectedId(i.id)}
                        >
                          {i.name}
                        </button>
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
      <ContactDetailPanel
        contactId={selectedId}
        open={!!selectedId}
        initialTab="skills"
        onClose={() => setSelectedId(null)}
      />
    </div>
  )
}
