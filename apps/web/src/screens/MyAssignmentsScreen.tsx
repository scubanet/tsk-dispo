/**
 * MyAssignmentsScreen — Foundation-based rewrite (instructor view).
 *
 * Layout:
 *   PageHeader (search action)
 *     belowTitle: FilterTabBar (upcoming / past / all)
 *   ┌─ list of CourseRow-like cards ──────────────────────────┐
 *   │  course type color dot + title + status pill            │
 *   │  date · role · extra dates                              │
 *   │  optional info line                                     │
 *   └─────────────────────────────────────────────────────────┘
 */

import { useMemo, useState } from 'react'
import { useNavigate, useOutletContext } from 'react-router-dom'
import { isAfter, isBefore, startOfDay } from 'date-fns'
import { useTranslation } from 'react-i18next'
import {
  PageHeader,
  FilterTabBar,
  SearchInput,
  EmptyState,
  Pill,
  Icon,
  courseTypeColor,
  dateLong,
} from '@/foundation'
import type { CourseType } from '@/types/foundation'
import { useMyAssignments } from '@/hooks/useMyAssignments'
import type { OutletCtx } from '@/layout/AppShell'

type Filter = 'upcoming' | 'past' | 'all'

function asCourseType(code: string | undefined | null): CourseType {
  if (!code) return 'OWD'
  if (code.startsWith('SPEI_')) return { type: 'SPEI', specialty: code.slice(5) as never }
  if (code.startsWith('SP_')) return { type: 'SPECIALTY', specialty: code.slice(3) as never }
  return code as CourseType
}

export function MyAssignmentsScreen() {
  const { t } = useTranslation()
  const { user } = useOutletContext<OutletCtx>()
  const navigate = useNavigate()
  const { data: rows = [] } = useMyAssignments(user.instructorId)
  const [filter, setFilter] = useState<Filter>('upcoming')
  const [search, setSearch] = useState('')

  const counts = useMemo(() => {
    const today = startOfDay(new Date())
    const c = { upcoming: 0, past: 0, all: 0 }
    for (const r of rows) {
      if (!r.course) continue
      c.all++
      const d = new Date(r.course.start_date)
      if (isBefore(d, today)) c.past++
      else c.upcoming++
    }
    return c
  }, [rows])

  const filtered = useMemo(() => {
    const today = startOfDay(new Date())
    let arr = rows.filter((r) => {
      if (!r.course) return false
      if (filter === 'all') return true
      const d = new Date(r.course.start_date)
      return filter === 'upcoming' ? !isBefore(d, today) : isAfter(today, d)
    })
    if (search) {
      const q = search.toLowerCase()
      arr = arr.filter(
        (r) =>
          r.course?.title.toLowerCase().includes(q) ||
          r.course?.course_type?.code.toLowerCase().includes(q),
      )
    }
    return arr
  }, [rows, filter, search])

  if (!user.instructorId) {
    return (
      <div className="atoll-screen">
        <PageHeader title={t('nav.my_assignments')} />
        <div className="atoll-screen__body">
          <EmptyState
            icon={<Icon.Users size={20} />}
            title={t('my_assignments.no_link_title')}
            body={t('my_assignments.no_link_desc')}
          />
        </div>
      </div>
    )
  }

  const tabs = [
    { id: 'upcoming' as const, label: t('my_assignments.filter_upcoming'), count: counts.upcoming },
    { id: 'past' as const, label: t('my_assignments.filter_past'), count: counts.past },
    { id: 'all' as const, label: t('my_assignments.filter_all'), count: counts.all },
  ]

  return (
    <div className="atoll-screen">
      <PageHeader
        title={t('nav.my_assignments')}
        subtitle={t('my_assignments.subtitle', {
          total: rows.length,
          visible: filtered.length,
        })}
        actions={
          <SearchInput
            value={search}
            onChange={setSearch}
            ariaLabel={t('common.search')}
            placeholder={t('common.search') + '…'}
          />
        }
        belowTitle={
          <FilterTabBar<Filter>
            tabs={tabs}
            active={filter}
            onChange={setFilter}
            ariaLabel={t('nav.my_assignments')}
          />
        }
      />

      <div className="atoll-screen__body">
        {filtered.length === 0 ? (
          <EmptyState
            icon={<Icon.Calendar size={20} />}
            title={t('my_assignments.empty_title')}
            body={t('my_assignments.empty_desc')}
          />
        ) : (
          <div className="atoll-myasn__list">
            {filtered.map((a) => {
              if (!a.course) return null
              const c = a.course
              const dotColor = courseTypeColor(asCourseType(c.course_type?.code))
              return (
                <button
                  key={a.id}
                  type="button"
                  className={`atoll-myasn__card atoll-myasn__card--${c.status}`}
                  onClick={() => navigate(`/kurse/${c.id}`)}
                >
                  <span
                    className="atoll-myasn__accent"
                    style={{ background: dotColor }}
                    aria-hidden
                  />
                  <div className="atoll-myasn__main">
                    <div className="atoll-myasn__head">
                      <div>
                        <div className="atoll-myasn__title">{c.title}</div>
                        <div className="atoll-myasn__sub">
                          {c.course_type?.label ?? '—'}
                        </div>
                      </div>
                      <div className="atoll-myasn__pills">
                        <Pill tone={a.role === 'haupt' ? 'brand' : 'neutral'} size="sm">
                          {a.role}
                        </Pill>
                        {a.confirmed ? (
                          <Pill tone="success" size="sm">
                            ✓ {t('my_assignments.confirmed')}
                          </Pill>
                        ) : (
                          <Pill tone="warning" size="sm">
                            {t('my_assignments.open')}
                          </Pill>
                        )}
                      </div>
                    </div>
                    <div className="atoll-myasn__meta tabular-nums">
                      {dateLong(c.start_date)}
                      {c.additional_dates.length > 0 && (
                        <span>
                          {' · '}
                          {t('my_assignments.extra_dates', { count: c.additional_dates.length })}
                        </span>
                      )}
                    </div>
                    {c.info && <div className="atoll-myasn__info">{c.info}</div>}
                  </div>
                </button>
              )
            })}
          </div>
        )}
      </div>
    </div>
  )
}
