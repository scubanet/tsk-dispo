/**
 * SkillsTab — read-only list of instructor skills.
 */

import { useState, useEffect } from 'react'
import { supabase } from '@/lib/supabase'

interface SkillRow {
  id: string
  code: string
  label: string
  category: string | null
}

interface Props {
  contactId: string
}

export function SkillsTab({ contactId }: Props) {
  const [skills, setSkills] = useState<SkillRow[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    let cancelled = false
    setLoading(true)
    void (async () => {
      const { data } = await supabase
        .from('instructor_skills')
        .select('id, code, label, category')
        .eq('instructor_id', contactId)
        .order('category')
        .order('label')
      if (!cancelled) {
        setSkills((data ?? []) as SkillRow[])
        setLoading(false)
      }
    })()
    return () => { cancelled = true }
  }, [contactId])

  if (loading) return <div className="contact-tab-body tab-stub">Lade Skills…</div>

  if (skills.length === 0) {
    return <div className="contact-tab-body tab-stub">Keine Skills erfasst.</div>
  }

  return (
    <div className="contact-tab-body">
      <ul className="skills-list">
        {skills.map((s) => (
          <li key={s.id} className="skills-list__item">
            {s.category && (
              <span className="skills-list__cat">{s.category}</span>
            )}
            <span className="skills-list__label">{s.label}</span>
            <span className="skills-list__code" style={{ color: 'var(--text-tertiary)', fontSize: 'var(--text-meta)' }}>
              {s.code}
            </span>
          </li>
        ))}
      </ul>
    </div>
  )
}
