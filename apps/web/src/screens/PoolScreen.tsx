import { useEffect, useMemo, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { addDays, format, startOfWeek, addWeeks, subWeeks } from 'date-fns'
import { de } from 'date-fns/locale'
import { Topbar } from '@/components/Topbar'
import { Icon } from '@/components/Icon'
import { supabase } from '@/lib/supabase'
import { POOL_LOCATIONS, type PoolLocation } from '@/lib/queries'

interface PoolDateRow {
  id: string
  course_id: string
  date: string
  pool_location: PoolLocation
  pool_reserved: boolean
  time_from: string | null
  time_to: string | null
  course: {
    id: string
    title: string
    course_type: { code: string } | null
  } | null
}

export function PoolScreen() {
  const navigate = useNavigate()
  const [weekStart, setWeekStart] = useState<Date>(() => startOfWeek(new Date(), { weekStartsOn: 1 }))
  const [rows, setRows] = useState<PoolDateRow[]>([])

  const days = useMemo(
    () => Array.from({ length: 7 }, (_, i) => addDays(weekStart, i)),
    [weekStart],
  )

  useEffect(() => {
    const from = format(weekStart, 'yyyy-MM-dd')
    const to = format(addDays(weekStart, 6), 'yyyy-MM-dd')
    supabase
      .from('course_dates')
      .select(`
        id, course_id, date, pool_location, pool_reserved, time_from, time_to,
        course:courses(id, title, course_type:course_types(code))
      `)
      .eq('type', 'pool')
      .not('pool_location', 'is', null)
      .gte('date', from)
      .lte('date', to)
      .order('date')
      .then(({ data }) => setRows((data ?? []) as unknown as PoolDateRow[]))
  }, [weekStart])

  return (
    <>
      <Topbar
        title="Pool"
        subtitle={`KW ${format(weekStart, 'w')} · ${format(weekStart, 'd. MMM', { locale: de })} – ${format(addDays(weekStart, 6), 'd. MMM yyyy', { locale: de })}`}
      >
        <button className="btn-icon" onClick={() => setWeekStart((w) => subWeeks(w, 1))}>
          <Icon name="chevron-left" size={14} />
        </button>
        <button className="btn-secondary btn" onClick={() => setWeekStart(startOfWeek(new Date(), { weekStartsOn: 1 }))}>
          Heute
        </button>
        <button className="btn-icon" onClick={() => setWeekStart((w) => addWeeks(w, 1))}>
          <Icon name="chevron-right" size={14} />
        </button>
      </Topbar>

      <div className="scroll" style={{ flex: 1, padding: 16, overflow: 'auto' }}>
        <div className="glass card" style={{ padding: 0 }}>
          <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: 13 }}>
            <thead>
              <tr style={{ borderBottom: '0.5px solid var(--hairline)' }}>
                <th align="left" style={{ padding: '12px 16px', width: 110 }}></th>
                {days.map((d) => (
                  <th key={d.toISOString()} align="center" style={{ padding: '12px 8px' }}>
                    <div style={{ fontWeight: 600 }}>
                      {format(d, 'EEE', { locale: de })}
                    </div>
                    <div className="caption">{format(d, 'd. MMM', { locale: de })}</div>
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {POOL_LOCATIONS.map((loc) => (
                <tr key={loc.value} style={{ borderTop: '0.5px solid var(--separator)' }}>
                  <td style={{ padding: '12px 16px', verticalAlign: 'top', fontWeight: 500 }}>
                    {loc.label}
                  </td>
                  {days.map((d) => {
                    const dateStr = format(d, 'yyyy-MM-dd')
                    const slots = rows.filter(
                      (r) => r.date === dateStr && r.pool_location === loc.value,
                    )
                    return (
                      <td
                        key={d.toISOString()}
                        style={{
                          padding: 6,
                          verticalAlign: 'top',
                          minHeight: 90,
                          minWidth: 110,
                        }}
                      >
                        <div style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
                          {slots.length === 0 ? (
                            <div className="caption-2" style={{ color: 'var(--ink-4)' }}>—</div>
                          ) : (
                            slots.map((s) => (
                              <div
                                key={s.id}
                                onClick={() => s.course && navigate(`/kurse/${s.course.id}`)}
                                style={{
                                  cursor: 'pointer',
                                  // Grün wenn Pool reserviert, Orange wenn noch offen
                                  background: s.pool_reserved ? 'rgba(52,199,89,.22)' : 'rgba(255,149,0,.22)',
                                  color: s.pool_reserved ? '#1c8b3c' : '#a04e00',
                                  padding: '4px 6px',
                                  borderRadius: 6,
                                  fontSize: 11,
                                  fontWeight: 600,
                                  border: s.pool_reserved ? '0.5px solid rgba(52,199,89,.45)' : '0.5px dashed rgba(255,149,0,.55)',
                                }}
                                title={`${s.course?.title ?? ''} — ${s.pool_reserved ? 'Pool reserviert ✓' : 'Pool noch offen'}`}
                              >
                                <div style={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                                  {s.course?.course_type?.code ?? '—'}
                                </div>
                                <div className="caption-2" style={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap', opacity: 0.8 }}>
                                  {s.course?.title ?? ''}
                                </div>
                              </div>
                            ))
                          )}
                        </div>
                      </td>
                    )
                  })}
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        <div style={{ marginTop: 12, padding: '0 4px', display: 'flex', gap: 16, alignItems: 'center', flexWrap: 'wrap' }}>
          <span className="caption">
            {rows.length} Pool-Slots in dieser Woche · {rows.filter((r) => r.pool_reserved).length} reserviert · {rows.filter((r) => !r.pool_reserved).length} offen
          </span>
          <span className="caption-2" style={{ display: 'inline-flex', alignItems: 'center', gap: 4 }}>
            <span style={{ width: 10, height: 10, borderRadius: 3, background: 'rgba(52,199,89,.40)', border: '0.5px solid rgba(52,199,89,.6)' }} /> reserviert
          </span>
          <span className="caption-2" style={{ display: 'inline-flex', alignItems: 'center', gap: 4 }}>
            <span style={{ width: 10, height: 10, borderRadius: 3, background: 'rgba(255,149,0,.40)', border: '0.5px dashed rgba(255,149,0,.6)' }} /> offen
          </span>
        </div>
      </div>
    </>
  )
}
