import { useEffect, useMemo, useState } from 'react'
import { useNavigate, useOutletContext, useParams } from 'react-router-dom'
import type { OutletCtx } from '@/layout/AppShell'
import clsx from 'clsx'
import { format } from 'date-fns'
import { de } from 'date-fns/locale'
import { Topbar } from '@/components/Topbar'
import { Icon } from '@/components/Icon'
import { Chip } from '@/components/Chip'
import { EmptyState } from '@/components/EmptyState'
import { fetchAllCourses, type CourseDetail } from '@/lib/queries'
import { CourseDetailPanel } from './CourseDetailPanel'
import { CourseEditSheet } from './CourseEditSheet'

type Filter = 'open' | 'confirmed' | 'tentative' | 'completed' | 'cancelled' | 'all'

const CD_COURSE_PREFIXES = ['DM', 'IDC', 'SPEI', 'EFRI']
function isCdCourse(code?: string | null) {
  if (!code) return false
  return CD_COURSE_PREFIXES.some((p) => code === p || code.startsWith(p + '_'))
}

export function CoursesScreen() {
  const { id } = useParams<{ id?: string }>()
  const navigate = useNavigate()
  const { user } = useOutletContext<OutletCtx>()
  const [courses, setCourses] = useState<CourseDetail[]>([])
  const [search, setSearch] = useState('')
  // Default 'open' = alles außer 'completed' (abgeschlossene Kurse standardmäßig ausblenden)
  const [filter, setFilter] = useState<Filter>('open')
  // CD: standardmäßig nur CD-Kurse; Dispatcher: aus
  const [cdOnly, setCdOnly] = useState(user.role === 'cd')
  const [editOpen, setEditOpen] = useState(false)

  function refetch() {
    fetchAllCourses().then(setCourses)
  }

  useEffect(() => { refetch() }, [])

  const filtered = useMemo(() => {
    let arr = courses.filter((c) => {
      switch (filter) {
        case 'all':       return true
        case 'open':      return c.status !== 'completed'
        case 'confirmed': return c.status === 'confirmed'
        case 'tentative': return c.status === 'tentative'
        case 'completed': return c.status === 'completed'
        case 'cancelled': return c.status === 'cancelled'
      }
    })
    if (cdOnly) {
      arr = arr.filter((c) => isCdCourse(c.course_type?.code))
    }
    if (search) {
      const q = search.toLowerCase()
      arr = arr.filter(
        (c) =>
          c.title.toLowerCase().includes(q) ||
          c.course_type?.code.toLowerCase().includes(q) ||
          c.course_type?.label.toLowerCase().includes(q),
      )
    }
    // Chronologisch nach Startdatum (frühester oben)
    arr = [...arr].sort((a, b) => a.start_date.localeCompare(b.start_date))
    return arr
  }, [courses, search, filter, cdOnly])

  const counts = useMemo(() => {
    const c = { confirmed: 0, tentative: 0, completed: 0, cancelled: 0 }
    for (const x of courses) c[x.status as keyof typeof c]++
    return c
  }, [courses])

  const selected = courses.find((c) => c.id === id) ?? null

  return (
    <>
      <Topbar title="Kurse" subtitle={`${courses.length} Kurse 2026`}>
        <div className="search" style={{ width: 220 }}>
          <Icon name="search" size={14} />
          <input
            placeholder="Suchen…"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
          />
        </div>
        <button className="btn" onClick={() => setEditOpen(true)}>
          <Icon name="plus" size={14} /> Neu
        </button>
      </Topbar>

      <div className="master-detail">
        <div className="master">
          <div style={{ padding: '12px 16px', borderBottom: '0.5px solid var(--separator)', display: 'flex', flexDirection: 'column', gap: 8 }}>
            <div className="seg">
              <button
                className={clsx(filter === 'open' && 'active')}
                onClick={() => setFilter('open')}
                title="alle außer abgeschlossen"
              >Aktiv</button>
              <button
                className={clsx(filter === 'confirmed' && 'active')}
                onClick={() => setFilter('confirmed')}
              >Sicher</button>
              <button
                className={clsx(filter === 'tentative' && 'active')}
                onClick={() => setFilter('tentative')}
              >Evtl.</button>
              <button
                className={clsx(filter === 'completed' && 'active')}
                onClick={() => setFilter('completed')}
              >Done</button>
              <button
                className={clsx(filter === 'cancelled' && 'active')}
                onClick={() => setFilter('cancelled')}
              >CXL</button>
              <button
                className={clsx(filter === 'all' && 'active')}
                onClick={() => setFilter('all')}
              >Alle</button>
            </div>
            <div className="caption-2">
              {filtered.length} sichtbar · {counts.confirmed} sicher · {counts.tentative} evtl. · {counts.completed} done · {counts.cancelled} cxl
            </div>

            {(user.role === 'cd' || user.role === 'dispatcher') && (
              <label
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: 6,
                  fontSize: 12,
                  cursor: 'pointer',
                  padding: '4px 8px',
                  borderRadius: 8,
                  background: cdOnly ? 'rgba(52,199,89,.18)' : 'transparent',
                  border: '0.5px solid var(--hairline)',
                  width: 'fit-content',
                }}
              >
                <input
                  type="checkbox"
                  checked={cdOnly}
                  onChange={(e) => setCdOnly(e.target.checked)}
                />
                Nur CD-Kurse <span className="caption-2">(DM/IDC/SPEI/EFRI)</span>
              </label>
            )}
          </div>

          {filtered.length === 0 ? (
            <EmptyState icon="book" title="Keine Treffer" />
          ) : (
            filtered.map((c) => (
              <div
                key={c.id}
                className={clsx('list-row', selected?.id === c.id && 'selected')}
                onClick={() => navigate(`/kurse/${c.id}`)}
                style={{ padding: '12px 16px' }}
              >
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ fontWeight: 500, fontSize: 14, marginBottom: 2, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                    {c.title}
                  </div>
                  <div className="caption">
                    {c.course_type?.code ?? '—'} ·{' '}
                    {format(new Date(c.start_date), 'dd. MMM', { locale: de })}
                  </div>
                </div>
                <Chip tone={
                  c.status === 'confirmed' ? 'green' :
                  c.status === 'tentative' ? 'orange' :
                  c.status === 'completed' ? 'purple' : 'red'
                }>
                  {c.status === 'confirmed' ? 'sicher' :
                   c.status === 'tentative' ? 'evtl.' :
                   c.status === 'completed' ? 'done' : 'cxl'}
                </Chip>
              </div>
            ))
          )}
        </div>

        <div className="detail">
          {selected ? (
            <CourseDetailPanel courseId={selected.id} key={selected.id} />
          ) : (
            <EmptyState
              icon="book"
              title="Wähle einen Kurs"
              description="Klick links auf einen Eintrag, um Details zu sehen."
            />
          )}
        </div>
      </div>

      <CourseEditSheet
        open={editOpen}
        onClose={() => setEditOpen(false)}
        onSaved={refetch}
        courseId={null}
      />
    </>
  )
}
