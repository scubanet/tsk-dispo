/**
 * AvailabilityTab — Dispatcher-Sicht auf TL/DM-Verfügbarkeit im
 * Kontakt-Detail-Panel. Gruppiert nach Status (Aktuell / Zukünftig /
 * Vergangen). Dispatcher hat Vollrechte: anlegen + löschen.
 *
 * Sichtbarkeit (kontrolliert in ContactDetailPanel.tsx Zeile ~80):
 * nur bei contact.roles enthält 'instructor'.
 */

import { useEffect, useState, useMemo } from 'react'
import { useTranslation } from 'react-i18next'
import { Icon } from '@/foundation'
import {
  AvailabilityRow as AvailabilityRowView,
  AvailabilityAddSheet,
} from '@/components/availability'
import { fetchAvailability, type AvailabilityRow } from '@/lib/queries'

interface Props {
  contactId: string
}

interface Grouped {
  current: AvailabilityRow[]
  future: AvailabilityRow[]
  past: AvailabilityRow[]
}

function groupByStatus(rows: AvailabilityRow[]): Grouped {
  const today = new Date().toISOString().slice(0, 10)
  const current: AvailabilityRow[] = []
  const future: AvailabilityRow[] = []
  const past: AvailabilityRow[] = []
  for (const r of rows) {
    if (r.to_date < today) past.push(r)
    else if (r.from_date > today) future.push(r)
    else current.push(r)
  }
  // current + future: from_date ASC, past: from_date DESC
  current.sort((a, b) => a.from_date.localeCompare(b.from_date))
  future.sort((a, b) => a.from_date.localeCompare(b.from_date))
  past.sort((a, b) => b.from_date.localeCompare(a.from_date))
  return { current, future, past }
}

export function AvailabilityTab({ contactId }: Props) {
  const { t } = useTranslation()
  const [rows, setRows] = useState<AvailabilityRow[]>([])
  const [loading, setLoading] = useState(true)
  const [showAdd, setShowAdd] = useState(false)
  const [showPast, setShowPast] = useState(false)

  function load() {
    setLoading(true)
    fetchAvailability(contactId)
      .then((data) => setRows(data))
      .catch((err) => console.error('[availability-tab] load failed', err))
      .finally(() => setLoading(false))
  }

  useEffect(() => {
    load()
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [contactId])

  const grouped = useMemo(() => groupByStatus(rows), [rows])
  const totalCount = grouped.current.length + grouped.future.length + grouped.past.length

  if (loading) {
    return <div className="contact-tab-body tab-stub">{t('common.loading')}</div>
  }

  return (
    <div className="contact-tab-body">
      {/* Header: Plus-Button rechts */}
      <div
        style={{
          display: 'flex',
          justifyContent: 'flex-end',
          marginBottom: 12,
        }}
      >
        <button
          type="button"
          className="atoll-btn atoll-btn--primary"
          onClick={() => setShowAdd(true)}
        >
          <Icon.Plus size={14} /> {t('contacts.availability_add_button')}
        </button>
      </div>

      {totalCount === 0 ? (
        <div className="tab-stub" style={{ textAlign: 'center', padding: '24px 0' }}>
          {t('contacts.availability_empty_state')}
        </div>
      ) : (
        <>
          {grouped.current.length > 0 && (
            <section className="contact-section">
              <h2 className="contact-section__title">
                {t('contacts.availability_section_current')} ({grouped.current.length})
              </h2>
              <div className="atoll-myprofile__avail-list">
                {grouped.current.map((r) => (
                  <AvailabilityRowView key={r.id} row={r} onDeleted={load} />
                ))}
              </div>
            </section>
          )}

          {grouped.future.length > 0 && (
            <section className="contact-section">
              <h2 className="contact-section__title">
                {t('contacts.availability_section_future')} ({grouped.future.length})
              </h2>
              <div className="atoll-myprofile__avail-list">
                {grouped.future.map((r) => (
                  <AvailabilityRowView key={r.id} row={r} onDeleted={load} />
                ))}
              </div>
            </section>
          )}

          {grouped.past.length > 0 && (
            <section className="contact-section">
              <div
                style={{
                  display: 'flex',
                  justifyContent: 'space-between',
                  alignItems: 'center',
                }}
              >
                <h2 className="contact-section__title">
                  {t('contacts.availability_section_past')} ({grouped.past.length})
                </h2>
                <button
                  type="button"
                  className="atoll-btn"
                  onClick={() => setShowPast((v) => !v)}
                  style={{ fontSize: 12 }}
                >
                  {showPast
                    ? t('contacts.availability_hide_past')
                    : t('contacts.availability_show_past', { count: grouped.past.length })}
                </button>
              </div>
              {showPast && (
                <div className="atoll-myprofile__avail-list">
                  {grouped.past.map((r) => (
                    <AvailabilityRowView key={r.id} row={r} onDeleted={load} />
                  ))}
                </div>
              )}
            </section>
          )}
        </>
      )}

      <AvailabilityAddSheet
        open={showAdd}
        onClose={() => setShowAdd(false)}
        onCreated={load}
        instructorId={contactId}
      />
    </div>
  )
}
