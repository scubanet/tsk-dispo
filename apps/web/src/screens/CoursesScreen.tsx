import { useEffect, useMemo, useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
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

export function CoursesScreen() {
  const { id } = useParams<{ id?: string }>()
  const navigate = useNavigate()
  const [courses, setCourses] = useState<CourseDetail[]>([])
  const [search, setSearch] = useState('')
  const [filter, setFilter] = useState<'all' | 'confirmed' | 'tentative' | 'cancelled'>('all')
  const [editOpen, setEditOpen] = useState(false)

  function refetch() {
    fetchAllCourses().then(setCourses)
  }

  useEffect(() => { refetch() }, [])

  const filtered = useMemo(() => {
    return courses.filter((c) => {
      if (filter !== 'all' && c.status !== filter) return false
      if (search) {
        const q = search.toLowerCase()
        return (
          c.title.toLowerCase().includes(q) ||
          c.course_type?.code.toLowerCase().includes(q) ||
          c.course_type?.label.toLowerCase().includes(q)
        )
      }
      return true
    })
  }, [courses, search, filter])

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
          <div style={{ padding: '12px 16px', borderBottom: '0.5px solid var(--separator)' }}>
            <div className="seg">
              <button
                className={clsx(filter === 'all' && 'active')}
                onClick={() => setFilter('all')}
              >Alle</button>
              <button
                className={clsx(filter === 'confirmed' && 'active')}
                onClick={() => setFilter('confirmed')}
              >Sicher</button>
              <button
                className={clsx(filter === 'tentative' && 'active')}
                onClick={() => setFilter('tentative')}
              >Evtl.</button>
              <button
                className={clsx(filter === 'cancelled' && 'active')}
                onClick={() => setFilter('cancelled')}
              >CXL</button>
            </div>
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
                <Chip tone={c.status === 'confirmed' ? 'green' : c.status === 'tentative' ? 'orange' : 'red'}>
                  {c.status === 'confirmed' ? 'sicher' : c.status === 'tentative' ? 'evtl.' : 'cxl'}
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
        onCreated={refetch}
      />
    </>
  )
}
