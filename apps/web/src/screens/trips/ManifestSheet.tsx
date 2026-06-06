import { useEffect, useState, type CSSProperties } from 'react'
import { useTranslation } from 'react-i18next'
import { Sheet } from '@/components/Sheet'
import { Pill, EmptyState, Loader } from '@/foundation'
import { useManifest, useTripCancel, useTripCheckin } from '@/hooks/useTrips'
import { TripBookingForm } from '@/screens/trips/TripBookingForm'
import type { Departure } from '@/lib/tripQueries'

interface Props {
  open: boolean
  onClose: () => void
  departure: Departure | null
}

const rowStyle: CSSProperties = {
  display: 'grid', gridTemplateColumns: '1fr auto auto', alignItems: 'center',
  gap: 'var(--space-2)', padding: 'var(--space-2)', borderBottom: '0.5px solid var(--hairline)',
}
const BOOK_TONE: Record<string, 'neutral' | 'info' | 'success' | 'warning' | 'danger'> = {
  booked: 'success', waitlisted: 'warning', cancelled: 'neutral', no_show: 'danger', attended: 'info',
}

export function ManifestSheet({ open, onClose, departure }: Props) {
  const { t } = useTranslation()
  const depId = departure?.departure_id ?? null
  const { data: rows = [], isLoading } = useManifest(open ? depId : null)
  const cancel = useTripCancel(depId ?? '')
  const checkin = useTripCheckin(depId ?? '')
  const [booking, setBooking] = useState(false)

  useEffect(() => { if (!open) setBooking(false) }, [open])

  return (
    <Sheet open={open} onClose={onClose} title={departure ? departure.name : t('trips.manifest')} width={620}>
      <div style={{ display: 'grid', gap: 12 }}>
        {!booking && (
          <button className="btn" onClick={() => setBooking(true)}>{t('trips.new_booking')}</button>
        )}
        {booking && departure && (
          <TripBookingForm departureId={departure.departure_id} onBooked={() => setBooking(false)} onCancel={() => setBooking(false)} />
        )}

        {isLoading ? <Loader /> : rows.length === 0 ? <EmptyState title={t('trips.no_bookings')} /> : (
          <div>
            {rows.map((b) => (
              <div key={b.booking_id} style={rowStyle}>
                <div style={{ display: 'flex', flexDirection: 'column' }}>
                  <span style={{ fontWeight: 600 }}>{b.person_name}</span>
                  <span className="caption-2">
                    {b.cert_check !== 'ok' ? `${t(`trips.cert_${b.cert_check}`, { defaultValue: b.cert_check })} · ` : ''}
                    {b.needs_rental ? `${t('trips.needs_rental')} · ` : ''}
                    {b.needs_guide ? t('trips.needs_guide') : ''}
                  </span>
                </div>
                <Pill tone={BOOK_TONE[b.status] ?? 'neutral'} size="sm">{t(`trips.bstatus_${b.status}`, { defaultValue: b.status })}</Pill>
                <div style={{ display: 'flex', gap: 6, justifyContent: 'flex-end' }}>
                  {b.status === 'booked' && (
                    <>
                      <button className="btn-secondary btn" disabled={checkin.isPending} onClick={() => checkin.mutate({ bookingId: b.booking_id, attended: true })}>{t('trips.attended')}</button>
                      <button className="btn-ghost btn" disabled={checkin.isPending} onClick={() => checkin.mutate({ bookingId: b.booking_id, attended: false })}>{t('trips.no_show')}</button>
                    </>
                  )}
                  {(b.status === 'booked' || b.status === 'waitlisted') && (
                    <button className="btn-ghost btn" disabled={cancel.isPending} onClick={() => cancel.mutate(b.booking_id)}>{t('trips.cancel')}</button>
                  )}
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </Sheet>
  )
}
