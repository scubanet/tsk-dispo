/**
 * PoolScreen — Foundation-based rewrite.
 *
 * Layout:
 *   PageHeader (Week navigator: ←  Heute  →)
 *   ┌─ Card ──────────────────────────────────────────────────┐
 *   │  Wochenplan-Tabelle (Pool-Location × Wochentag)         │
 *   │   Slot-Zelle: bestätigt = teal, offen = amber           │
 *   └─────────────────────────────────────────────────────────┘
 *   ┌─ Legend + Summary ──────────────────────────────────────┐
 */

import { useMemo, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { addDays, startOfWeek, addWeeks, subWeeks } from 'date-fns'
import { useTranslation } from 'react-i18next'
import {
  PageHeader,
  Icon,
  toISODate,
  weekday,
  dateShort,
} from '@/foundation'
import { POOL_LOCATIONS } from '@/lib/queries'
import { usePoolDatesInRange } from '@/hooks/usePoolDatesInRange'

export function PoolScreen() {
  const { t } = useTranslation()
  const navigate = useNavigate()
  const [weekStart, setWeekStart] = useState<Date>(() =>
    startOfWeek(new Date(), { weekStartsOn: 1 }),
  )

  const days = useMemo(
    () => Array.from({ length: 7 }, (_, i) => addDays(weekStart, i)),
    [weekStart],
  )

  const { data: rows = [] } = usePoolDatesInRange(
    toISODate(weekStart),
    toISODate(addDays(weekStart, 6)),
  )

  const reservedCount = rows.filter((r) => r.pool_reserved).length
  const openCount = rows.length - reservedCount

  return (
    <div className="atoll-screen">
      <PageHeader
        title={t('nav.pool')}
        subtitle={`KW ${weekNumber(weekStart)} · ${dateShort(weekStart)} – ${dateShort(addDays(weekStart, 6))}`}
        actions={
          <div className="atoll-pool__nav">
            <button
              type="button"
              className="atoll-iconbtn"
              onClick={() => setWeekStart((w) => subWeeks(w, 1))}
              aria-label={t('calendar.prev_week', 'Vorige Woche')}
            >
              <Icon.ChevronLeft size={14} />
            </button>
            <button
              type="button"
              className="atoll-btn"
              onClick={() => setWeekStart(startOfWeek(new Date(), { weekStartsOn: 1 }))}
            >
              {t('calendar.today')}
            </button>
            <button
              type="button"
              className="atoll-iconbtn"
              onClick={() => setWeekStart((w) => addWeeks(w, 1))}
              aria-label={t('calendar.next_week', 'Nächste Woche')}
            >
              <Icon.ChevronRight size={14} />
            </button>
          </div>
        }
      />

      <div className="atoll-screen__body">
        <section className="atoll-cockpit__card atoll-pool__card">
          <table className="atoll-pool__table">
            <thead>
              <tr>
                <th></th>
                {days.map((d) => (
                  <th key={d.toISOString()}>
                    <div className="atoll-pool__day-name">{weekday(d)}</div>
                    <div className="atoll-pool__day-date tabular-nums">{dateShort(d)}</div>
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {POOL_LOCATIONS.map((loc) => (
                <tr key={loc.value}>
                  <td className="atoll-pool__loc">{loc.label}</td>
                  {days.map((d) => {
                    const dateStr = toISODate(d)
                    const slots = rows.filter(
                      (r) => r.date === dateStr && r.pool_location === loc.value,
                    )
                    return (
                      <td key={d.toISOString()} className="atoll-pool__cell">
                        {slots.length === 0 ? (
                          <span className="atoll-pool__empty">—</span>
                        ) : (
                          <div className="atoll-pool__slots">
                            {slots.map((s) => (
                              <button
                                key={s.id}
                                type="button"
                                className={`atoll-pool__slot atoll-pool__slot--${s.pool_reserved ? 'reserved' : 'open'}`}
                                onClick={() => s.course && navigate(`/kurse/${s.course.id}`)}
                                title={`${s.course?.title ?? ''} — ${s.pool_reserved ? t('pool.reserved') : t('pool.open')}`}
                              >
                                <span className="atoll-pool__slot-code">
                                  {s.course?.course_type?.code ?? '—'}
                                </span>
                                <span className="atoll-pool__slot-title">
                                  {s.course?.title ?? ''}
                                </span>
                              </button>
                            ))}
                          </div>
                        )}
                      </td>
                    )
                  })}
                </tr>
              ))}
            </tbody>
          </table>
        </section>

        <div className="atoll-pool__legend">
          <span className="atoll-pool__summary">
            {t('pool.summary', {
              total: rows.length,
              reserved: reservedCount,
              open: openCount,
            })}
          </span>
          <span className="atoll-pool__legend-item">
            <span className="atoll-pool__chip atoll-pool__chip--reserved" />
            {t('pool.legend_reserved')}
          </span>
          <span className="atoll-pool__legend-item">
            <span className="atoll-pool__chip atoll-pool__chip--open" />
            {t('pool.legend_open')}
          </span>
        </div>
      </div>
    </div>
  )
}

/** ISO 8601 week number. */
function weekNumber(d: Date): number {
  const date = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()))
  const dayNum = date.getUTCDay() || 7
  date.setUTCDate(date.getUTCDate() + 4 - dayNum)
  const yearStart = new Date(Date.UTC(date.getUTCFullYear(), 0, 1))
  return Math.ceil(((date.getTime() - yearStart.getTime()) / 86400000 + 1) / 7)
}
