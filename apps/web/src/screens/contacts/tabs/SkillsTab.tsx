/**
 * SkillsTab — read-only list of instructor skills, grouped by category.
 */

import { useTranslation } from 'react-i18next'
import { useContactSkills } from '@/hooks/useContactTabs'
import type { ContactSkillRow } from '@/lib/contactQueries'

interface Props {
  contactId: string
}

export function SkillsTab({ contactId }: Props) {
  const { t } = useTranslation()
  const { data: skills = [], isLoading } = useContactSkills(contactId)

  if (isLoading) return <div className="contact-tab-body tab-stub">{t('contacts.loading_skills')}</div>

  if (skills.length === 0) {
    return <div className="contact-tab-body tab-stub">{t('contacts.no_skills')}</div>
  }

  // Group by category for nicer presentation
  const byCategory = skills.reduce<Record<string, ContactSkillRow[]>>((acc, s) => {
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
