import { useEffect, useMemo, useState } from 'react'
import { useNavigate, useOutletContext } from 'react-router-dom'
import clsx from 'clsx'
import { format, isAfter, isBefore, startOfDay } from 'date-fns'
import { de } from 'date-fns/locale'
import { Topbar } from '@/components/Topbar'
import { Icon } from '@/components/Icon'
import { Chip } from '@/components/Chip'
import { EmptyState } from '@/components/EmptyState'
import { fetchMyAssignments, type MyAssignment } from '@/lib/queries'
import type { OutletCtx } from '@/layout/AppShell'

type Filter = 'upcoming' | 'past' | 'all'

export function MyAssignmentsScreen() {
  const { user } = useOutletContext<OutletCtx>()
  const navigate = useNavigate()
  const [rows, setRows] = useState<MyAssignment[]>([])
  const [filter, setFilter] = useState<Filter>('upcoming')
  const [search, setSearch] = useState('')

  useEffect(() => {
    if (!user.instructorId) return
    fetchMyAssignments(user.instructorId).then(setRows)
  }, [user.instructorId])

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
      <>
        <Topbar title="Meine Einsätze" />
        <EmptyState
          icon="users"
          title="Kein Instructor verknüpft"
          description="Dein Login ist noch keinem TL/DM-Datensatz zugeordnet. Bitte den Dispatcher um die Verknüpfung."
        />
      </>
    )
  }

  return (
    <>
      <Topbar
        title="Meine Einsätze"
        subtitle={`${rows.length} insgesamt · ${filtered.length} sichtbar`}
      >
        <div className="search" style={{ width: 200 }}>
          <Icon name="search" size={14} />
          <input
            placeholder="Suchen…"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
          />
        </div>
      </Topbar>

      <div className="screen-fade scroll" style={{ flex: 1, padding: '20px 24px 40px' }}>
        <div className="seg" style={{ marginBottom: 16 }}>
          <button className={clsx(filter === 'upcoming' && 'active')} onClick={() => setFilter('upcoming')}>
            Kommend
          </button>
          <button className={clsx(filter === 'past' && 'active')} onClick={() => setFilter('past')}>
            Vergangen
          </button>
          <button className={clsx(filter === 'all' && 'active')} onClick={() => setFilter('all')}>
            Alle
          </button>
        </div>

        {filtered.length === 0 ? (
          <EmptyState icon="book" title="Keine Einsätze" description="Hier ist gerade nichts." />
        ) : (
          <div style={{ display: 'grid', gap: 8 }}>
            {filtered.map((a) => {
              if (!a.course) return null
              const dateColor =
                a.course.status === 'cancelled' ? '#FF3B30' :
                a.course.status === 'tentative' ? '#FF9500' : 'var(--accent)'
              return (
                <div
                  key={a.id}
                  className="glass card"
                  style={{
                    padding: 16,
                    cursor: 'pointer',
                    borderLeft: `3px solid ${dateColor}`,
                  }}
                  onClick={() => navigate(`/kurse/${a.course?.id}`)}
                >
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: 6 }}>
                    <div>
                      <div className="title-3">{a.course.title}</div>
                      <div className="caption" style={{ marginTop: 2 }}>
                        {a.course.course_type?.label ?? '—'}
                      </div>
                    </div>
                    <div style={{ display: 'flex', gap: 6, flexDirection: 'column', alignItems: 'flex-end' }}>
                      <Chip tone={a.role === 'haupt' ? 'accent' : 'neutral'}>{a.role}</Chip>
                      {a.confirmed ? (
                        <Chip tone="green">bestätigt</Chip>
                      ) : (
                        <Chip tone="orange">offen</Chip>
                      )}
                    </div>
                  </div>
                  <div className="caption mono" style={{ marginTop: 8 }}>
                    {format(new Date(a.course.start_date), 'EEE, d. MMM yyyy', { locale: de })}
                    {a.course.additional_dates.length > 0 && (
                      <span> · +{a.course.additional_dates.length} Zusatzdaten</span>
                    )}
                  </div>
                  {a.course.info && (
                    <div className="caption" style={{ marginTop: 6, fontStyle: 'italic' }}>
                      {a.course.info}
                    </div>
                  )}
                </div>
              )
            })}
          </div>
        )}
      </div>
    </>
  )
}
