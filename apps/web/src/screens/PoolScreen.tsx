import { useEffect, useMemo, useState } from 'react'
import { addDays, format, startOfWeek, addWeeks, subWeeks } from 'date-fns'
import { de } from 'date-fns/locale'
import { Topbar } from '@/components/Topbar'
import { Icon } from '@/components/Icon'
import { Chip } from '@/components/Chip'
import { supabase } from '@/lib/supabase'

interface Booking {
  id: string
  date: string
  time_from: string | null
  time_to: string | null
  location: 'mooesli' | 'langnau'
  course_id: string | null
  note: string | null
}

const LOCATIONS: { value: 'mooesli' | 'langnau'; label: string }[] = [
  { value: 'mooesli', label: 'Möösli' },
  { value: 'langnau', label: 'Langnau' },
]

export function PoolScreen() {
  const [weekStart, setWeekStart] = useState<Date>(() => startOfWeek(new Date(), { weekStartsOn: 1 }))
  const [bookings, setBookings] = useState<Booking[]>([])

  const days = useMemo(
    () => Array.from({ length: 7 }, (_, i) => addDays(weekStart, i)),
    [weekStart],
  )

  useEffect(() => {
    const from = format(weekStart, 'yyyy-MM-dd')
    const to = format(addDays(weekStart, 6), 'yyyy-MM-dd')
    supabase
      .from('pool_bookings')
      .select('id, date, time_from, time_to, location, course_id, note')
      .gte('date', from)
      .lte('date', to)
      .order('date')
      .then(({ data }) => setBookings((data ?? []) as Booking[]))
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
                <th align="left" style={{ padding: '12px 16px', width: 100 }}></th>
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
              {LOCATIONS.map((loc) => (
                <tr key={loc.value} style={{ borderTop: '0.5px solid var(--separator)' }}>
                  <td style={{ padding: '12px 16px', verticalAlign: 'top', fontWeight: 500 }}>
                    {loc.label}
                  </td>
                  {days.map((d) => {
                    const dateStr = format(d, 'yyyy-MM-dd')
                    const slots = bookings.filter(
                      (b) => b.date === dateStr && b.location === loc.value,
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
                              <Chip key={s.id} tone="accent">
                                {s.time_from?.slice(0, 5) ?? '—'}
                                {s.time_to ? `–${s.time_to.slice(0, 5)}` : ''}
                              </Chip>
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

        <div className="caption" style={{ marginTop: 12, padding: '0 4px' }}>
          {bookings.length} Slots in dieser Woche · Hinzufügen + Bearbeiten kommt in v1.5.
        </div>
      </div>
    </>
  )
}
