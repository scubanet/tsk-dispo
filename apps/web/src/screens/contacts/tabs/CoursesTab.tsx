/**
 * CoursesTab — courses as instructor and/or as participant.
 */

import { useState, useEffect } from 'react'
import { useTranslation } from 'react-i18next'
import { supabase } from '@/lib/supabase'
import type { ContactRole } from '@/types/contacts'

interface CourseRef {
  id: string
  title: string
  start_date: string | null
  status: string
}

interface AssignmentRow {
  id: string
  role: string
  courses: CourseRef | null
}

interface ParticipantRow {
  id: string
  courses: CourseRef | null
}

interface Props {
  contactId: string
  roles: ContactRole[]
}

export function CoursesTab({ contactId, roles }: Props) {
  const { t } = useTranslation()
  const isInstructor = roles.includes('instructor')
  const isStudent = roles.includes('student') || roles.includes('candidate')

  const [assignments, setAssignments] = useState<AssignmentRow[]>([])
  const [participations, setParticipations] = useState<ParticipantRow[]>([])

  useEffect(() => {
    if (isInstructor) {
      supabase
        .from('course_assignments')
        .select('id, role, courses(id, title, start_date, status)')
        .eq('instructor_id', contactId)
        .order('id', { ascending: false })
        .limit(50)
        .then(({ data }) => setAssignments((data ?? []) as unknown as AssignmentRow[]))
    }
  }, [contactId, isInstructor])

  useEffect(() => {
    if (isStudent) {
      supabase
        .from('course_participants')
        .select('id, courses(id, title, start_date, status)')
        .eq('student_id', contactId)
        .order('id', { ascending: false })
        .limit(50)
        .then(({ data }) => setParticipations((data ?? []) as unknown as ParticipantRow[]))
    }
  }, [contactId, isStudent])

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
