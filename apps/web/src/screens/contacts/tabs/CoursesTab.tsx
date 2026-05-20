/**
 * CoursesTab — courses as instructor and/or as participant.
 */

import { useTranslation } from 'react-i18next'
import type { ContactRole } from '@/types/contacts'
import { useInstructorCourses, useStudentParticipations } from '@/hooks/useContactTabs'

interface Props {
  contactId: string
  roles: ContactRole[]
}

export function CoursesTab({ contactId, roles }: Props) {
  const { t } = useTranslation()
  const isInstructor = roles.includes('instructor')
  const isStudent = roles.includes('student') || roles.includes('candidate')

  const { data: assignments = [] } = useInstructorCourses(contactId, isInstructor)
  const { data: participations = [] } = useStudentParticipations(contactId, isStudent)

  return (
    <div className="contact-tab-body">
      {isInstructor && (
        <section className="contact-section">
          <h2 className="contact-section__title">{t('contacts.section_as_instructor')}</h2>
          {assignments.length === 0 ? (
            <p className="tab-stub">{t('contacts.no_assignments')}</p>
          ) : (
            <ul className="courses-list">
              {assignments.map((a) => (
                <li key={a.id} className="courses-list__item">
                  <a href={`/kurse/${a.courses?.id}`} className="courses-list__title">
                    {a.courses?.title ?? '—'}
                  </a>
                  <span className="courses-list__meta">{a.role}</span>
                  {a.courses?.start_date && (
                    <span className="courses-list__meta">
                      {new Date(a.courses.start_date).toLocaleDateString('de-CH')}
                    </span>
                  )}
                  <span className="courses-list__status">{a.courses?.status}</span>
                </li>
              ))}
            </ul>
          )}
        </section>
      )}

      {isStudent && (
        <section className="contact-section">
          <h2 className="contact-section__title">{t('contacts.section_as_participant')}</h2>
          {participations.length === 0 ? (
            <p className="tab-stub">{t('contacts.no_participations')}</p>
          ) : (
            <ul className="courses-list">
              {participations.map((p) => (
                <li key={p.id} className="courses-list__item">
                  <a href={`/kurse/${p.courses?.id}`} className="courses-list__title">
                    {p.courses?.title ?? '—'}
                  </a>
                  {p.courses?.start_date && (
                    <span className="courses-list__meta">
                      {new Date(p.courses.start_date).toLocaleDateString('de-CH')}
                    </span>
                  )}
                  <span className="courses-list__status">{p.courses?.status}</span>
                </li>
              ))}
            </ul>
          )}
        </section>
      )}
    </div>
  )
}
