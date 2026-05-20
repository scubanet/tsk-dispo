/**
 * CoursesScreen — Foundation-based rewrite (Tag 5 cutover).
 *
 * Layout:
 *   PageHeader (search + "+New" action)
 *   ┌─ MasterDetail ─────────────────────────────────────────┐
 *   │  ListPane (320px)            │  DetailPane              │
 *   │   FilterTabBar (6 status)    │   CourseDetailPanel      │
 *   │   CD-only toggle (cd/disp)   │     (legacy, stays)      │
 *   │   CourseRow × N              │                          │
 *   └────────────────────────────────────────────────────────┘
 *
 * Default filter: 'open' = everything except 'completed' (matches legacy).
 */

import { useMemo, useState } from 'react'
import { useNavigate, useOutletContext, useParams } from 'react-router-dom'
import { useTranslation } from 'react-i18next'
import {
  PageHeader,
  MasterDetail,
  ListPane,
  DetailPane,
  FilterTabBar,
  SearchInput,
  EmptyState,
  CourseRow,
  Pill,
  Icon,
  dateShort,
} from '@/foundation'
import type { OutletCtx } from '@/layout/AppShell'
import type { CourseType } from '@/types/foundation'
import { type CourseDetail } from '@/lib/queries'
import { useAllCourses } from '@/hooks/useAllCourses'
import { CourseDetailPanel } from './CourseDetailPanel'
import { CourseEditSheet } from './CourseEditSheet'

type Filter = 'open' | 'confirmed' | 'tentative' | 'completed' | 'cancelled' | 'all'

const CD_COURSE_PREFIXES = ['DM', 'IDC', 'SPEI', 'EFRI']
function isCdCourse(code?: string | null): boolean {
  if (!code) return false
  return CD_COURSE_PREFIXES.some((p) => code === p || code.startsWith(p + '_'))
}

/** Map legacy course-type code → foundation `CourseType` for color dot. */
function asCourseType(code: string | undefined | null): CourseType {
  if (!code) return 'OWD'
  if (code.startsWith('SPEI_')) return { type: 'SPEI', specialty: code.slice(5) as never }
  if (code.startsWith('SP_')) return { type: 'SPECIALTY', specialty: code.slice(3) as never }
  return code as CourseType
}

export function CoursesScreen() {
  const { t } = useTranslation()
  const { id } = useParams<{ id?: string }>()
  const navigate = useNavigate()
  const { user } = useOutletContext<OutletCtx>()

  const { data: courses = [], refetch } = useAllCourses()
  const [search, setSearch] = useState('')
  const [filter, setFilter] = useState<Filter>('open')
  // Always default to "all courses". CD users can toggle the filter manually
  // when they want to focus on Pro-Level courses only.
  const [cdOnly, setCdOnly] = useState(false)
  const [editOpen, setEditOpen] = useState(false)

  const counts = useMemo(() => {
    const c = { confirmed: 0, tentative: 0, completed: 0, cancelled: 0, open: 0 }
    for (const x of courses) {
      c[x.status as keyof typeof c]++
      if (x.status !== 'completed') c.open++
    }
    return c
  }, [courses])

  const filtered = useMemo(() => {
    let arr = courses.filter((c) => {
      switch (filter) {
        case 'all': return true
        case 'open': return c.status !== 'completed'
        case 'confirmed': return c.status === 'confirmed'
        case 'tentative': return c.status === 'tentative'
        case 'completed': return c.status === 'completed'
        case 'cancelled': return c.status === 'cancelled'
      }
    })
    if (cdOnly) arr = arr.filter((c) => isCdCourse(c.course_type?.code))
    if (search) {
      const q = search.toLowerCase()
      arr = arr.filter(
        (c) =>
          c.title.toLowerCase().includes(q) ||
          c.course_type?.code.toLowerCase().includes(q) ||
          c.course_type?.label.toLowerCase().includes(q),
      )
    }
    arr = [...arr].sort((a, b) => a.start_date.localeCompare(b.start_date))
    return arr
  }, [courses, search, filter, cdOnly])

  const tabs = [
    { id: 'open' as const, label: t('courses.filter_active'), count: counts.open },
    { id: 'confirmed' as const, label: t('courses.filter_certain'), count: counts.confirmed },
    { id: 'tentative' as const, label: t('courses.filter_tentative'), count: counts.tentative },
    { id: 'completed' as const, label: t('courses.filter_done'), count: counts.completed },
    { id: 'cancelled' as const, label: t('courses.filter_cxl'), count: counts.cancelled },
    { id: 'all' as const, label: t('courses.filter_all'), count: courses.length },
  ]

  const showCdToggle = user.role === 'cd' || user.role === 'dispatcher' || user.role === 'owner'

  return (
    <div className="atoll-screen">
      <PageHeader
        title={t('nav.courses')}
        subtitle={t('courses.count_year', { count: courses.length, year: new Date().getFullYear() })}
        actions={
          <>
            <SearchInput
              value={search}
              onChange={setSearch}
              ariaLabel={t('common.search')}
              placeholder={t('common.search') + '…'}
            />
            <button
              type="button"
              className="atoll-btn atoll-btn--primary"
              onClick={() => setEditOpen(true)}
            >
              <Icon.Plus size={14} /> {t('courses.new')}
            </button>
          </>
        }
      />

      <div className="atoll-screen__body atoll-screen__body--full">
        <MasterDetail>
          <ListPane
            toolbar={
              <div className="atoll-courses__toolbar">
                <FilterTabBar<Filter>
                  tabs={tabs}
                  active={filter}
                  onChange={setFilter}
                  ariaLabel={t('nav.courses')}
                />
                {showCdToggle && (
                  <Pill
                    tone={cdOnly ? 'success' : 'neutral'}
                    size="sm"
                    onClick={() => setCdOnly((v) => !v)}
                  >
                    {cdOnly ? '✓ ' : ''}{t('courses.pro_only')}
                  </Pill>
                )}
              </div>
            }
          >
            {filtered.length === 0 ? (
              <EmptyState
                icon={<Icon.Calendar size={20} />}
                title={t('courses.no_matches')}
              />
            ) : (
              <div className="atoll-courses__list">
                {filtered.map((c) => (
                  <CourseRow
                    key={c.id}
                    courseType={asCourseType(c.course_type?.code)}
                    title={c.title}
                    sub={
                      <>
                        {c.course_type?.code ?? '—'} · {dateShort(c.start_date)}
                      </>
                    }
                    trailing={statusPill(c.status, t)}
                    active={id === c.id}
                    onClick={() => navigate(`/kurse/${c.id}`)}
                  />
                ))}
              </div>
            )}
          </ListPane>

          <DetailPane>
            {id ? (
              <CourseDetailPanel courseId={id} key={id} />
            ) : (
              <EmptyState
                icon={<Icon.Calendar size={20} />}
                title={t('courses.pick_one_title')}
                body={t('courses.pick_one_desc')}
              />
            )}
          </DetailPane>
        </MasterDetail>
      </div>

      <CourseEditSheet
        open={editOpen}
        onClose={() => setEditOpen(false)}
        onSaved={() => { refetch() }}
        courseId={null}
      />
    </div>
  )
}

function statusPill(status: CourseDetail['status'], t: ReturnType<typeof useTranslation>['t']) {
  const tone =
    status === 'cancelled' ? 'danger' :
    status === 'tentative' ? 'warning' :
    status === 'completed' ? 'pro' : 'success'
  const label =
    status === 'confirmed' ? t('courses.status_certain') :
    status === 'tentative' ? t('courses.status_tentative') :
    status === 'completed' ? t('courses.status_done') :
    t('courses.status_cxl')
  return <Pill tone={tone} size="sm">{label}</Pill>
}
