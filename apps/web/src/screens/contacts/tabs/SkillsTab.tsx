/**
 * SkillsTab — read-only list of instructor skills.
 *
 * `instructor_skills` is a pure M:N junction (instructor_id, skill_id).
 * We embed-join `skills` to get code/label/category in one query.
 */

import { useState, useEffect } from 'react'
import { useTranslation } from 'react-i18next'
import { supabase } from '@/lib/supabase'

interface SkillRow {
  id: string
  code: string
  label: string
  category: string | null
}

interface JoinedRow {
  skill: SkillRow | null
}

interface Props {
  contactId: string
}

export function SkillsTab({ contactId }: Props) {
  const { t } = useTranslation()
  const [skills, setSkills] = useState<SkillRow[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    let cancelled = false
    setLoading(true)
    void (async () => {
      const { data, error } = await supabase
        .from('instructor_skills')
        .select('skill:skills(id, code, label, category)')
        .eq('instructor_id', contactId)
      if (cancelled) return
      if (error) console.error('[skills-tab] load failed', error)
      const rows = ((data ?? []) as unknown as JoinedRow[])
        .map((r) => r.skill)
        .filter((s): s is SkillRow => s !== null)
        .sort((a, b) => {
          const ca = a.category ?? ''
          const cb = b.category ?? ''
          if (ca !== cb) return ca.localeCompare(cb)
          return a.label.localeCompare(b.label)
        })
      setSkills(rows)
      setLoading(false)
    })()
    return () => { cancelled = true }
  }, [contactId])

  if (loading) return <div className="contact-tab-body tab-stub">{t('contacts.loading_skills')}</div>

  if (skills.length === 0) {
    return <div className="contact-tab-body tab-stub">{t('contacts.no_skills')}</div>
  }

  // Group by category for nicer presentation
  const byCategory = skills.reduce<Record<string, SkillRow[]>>((acc, s) => {
    const key = s.category ?? '—'
    if (!acc[key]) acc[key] = []
    acc[key].push(s)
    return acc
  }, {})

  return (
    <div className="contact-tab-body">
      {Object.entries(byCategory).map(([cat, list]) => (
        <section key={cat} className="contact-section">
          <h2 className="contact-section__title">{cat}</h2>
          <ul className="skills-list">
            {list.map((s) => (
              <li key={s.id} className="skills-list__item">
                <span className="skills-list__label">{s.label}</span>
                <span
                  className="skills-list__code"
                  style={{ color: 'var(--text-tertiary)', fontSize: 'var(--text-meta)' }}
                >
                  {s.code}
                </span>
              </li>
            ))}
          </ul>
        </section>
      ))}
    </div>
  )
}
