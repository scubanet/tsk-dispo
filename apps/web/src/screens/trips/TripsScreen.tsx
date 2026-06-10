import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { PageHeader, KpiCard, KpiGrid, Pill, EmptyState, Loader, dateMedium } from '@/foundation'
import { useDepartures, useDiveSites } from '@/hooks/useTrips'
import { useCurrentUser } from '@/hooks/useCurrentUser'
import { canEditOps } from '@/lib/auth'
import { DepartureEditSheet } from '@/screens/trips/DepartureEditSheet'
import { SiteEditSheet } from '@/screens/trips/SiteEditSheet'
import { ManifestSheet } from '@/screens/trips/ManifestSheet'
import type { Departure, DiveSite } from '@/lib/tripQueries'

type Tab = 'departures' | 'sites'

const STATUS_TONE: Record<string, 'neutral' | 'info' | 'success' | 'warning'> = {
  scheduled: 'info', confirmed: 'success', running: 'warning', done: 'neutral', cancelled: 'neutral',
}

export function TripsScreen() {
  const { t } = useTranslation()
  const { data: user } = useCurrentUser()
  const mayEdit = user ? canEditOps(user.role) : false

  const { data: departures = [], isLoading: ld } = useDepartures()
  const { data: sites = [], isLoading: ls } = useDiveSites()

  const [tab, setTab] = useState<Tab>('departures')
  const [depSheet, setDepSheet] = useState<{ open: boolean; item: Departure | null }>({ open: false, item: null })
  const [siteSheet, setSiteSheet] = useState<{ open: boolean; item: DiveSite | null }>({ open: false, item: null })
  const [manifest, setManifest] = useState<Departure | null>(null)

  if (ld || ls) return <div style={{ padding: 'var(--space-4)' }}><Loader /></div>

  const totalBooked = departures.reduce((s, d) => s + d.booked, 0)

  const newAction = tab === 'departures'
    ? { label: t('trips.new_departure'), onClick: () => setDepSheet({ open: true, item: null }) }
    : { label: t('trips.new_site'), onClick: () => setSiteSheet({ open: true, item: null }) }

  return (
    <div className="atoll-screen">
      <PageHeader title={t('trips.title')} subtitle={t('trips.subtitle')} />

      <div className="atoll-screen__body">
        <KpiGrid columns={3} gap="md">
          <KpiCard variant="stat" label={t('trips.kpi_departures')} value={departures.length} />
          <KpiCard variant="stat" label={t('trips.kpi_booked')} value={totalBooked} />
          <KpiCard variant="stat" label={t('trips.kpi_sites')} value={sites.length} />
        </KpiGrid>

        <div className="atoll-panel">
          <div className="atoll-panel__toolbar">
            <div className="seg">
              <button className={tab === 'departures' ? 'active' : undefined} onClick={() => setTab('departures')}>{t('trips.tab_departures')}</button>
              <button className={tab === 'sites' ? 'active' : undefined} onClick={() => setTab('sites')}>{t('trips.tab_sites')}</button>
            </div>
            <span className="atoll-panel__spacer" />
            {mayEdit && <button className="btn" onClick={newAction.onClick}>{newAction.label}</button>}
          </div>

          {tab === 'departures' && (
            departures.length === 0 ? (
              <div className="atoll-panel__empty"><EmptyState title={t('trips.no_departures')} /></div>
            ) : (
              <div>
                {departures.map((d) => (
                  <div key={d.departure_id} className="atoll-listrow atoll-listrow--clickable" onClick={() => setManifest(d)}>
                    <div className="atoll-listrow__main">
                      <span className="atoll-listrow__title">{d.name}</span>
                      <span className="caption-2">{dateMedium(d.datetime)}{d.meeting_point ? ` · ${d.meeting_point}` : ''}</span>
                    </div>
                    <Pill tone={STATUS_TONE[d.status] ?? 'neutral'} size="sm">{t(`trips.status_${d.status}`, { defaultValue: d.status })}</Pill>
                    <div className="atoll-listrow__pills">
                      <span className="tabular-nums">{d.booked}/{d.capacity}</span>
                      {d.waitlisted > 0 && <Pill tone="warning" size="sm">{t('trips.waitlist_n', { count: d.waitlisted })}</Pill>}
                    </div>
                  </div>
                ))}
              </div>
            )
          )}

          {tab === 'sites' && (
            sites.length === 0 ? (
              <div className="atoll-panel__empty"><EmptyState title={t('trips.no_sites')} /></div>
            ) : (
              <div>
                {sites.map((s) => (
                  <div
                    key={s.id}
                    className={`atoll-listrow${mayEdit ? ' atoll-listrow--clickable' : ''}`}
                    onClick={() => mayEdit && setSiteSheet({ open: true, item: s })}
                  >
                    <div className="atoll-listrow__main">
                      <span className="atoll-listrow__title">{s.name}</span>
                      <span className="caption-2">{[s.region, s.max_depth_m ? `${s.max_depth_m} m` : null].filter(Boolean).join(' · ') || '—'}</span>
                    </div>
                    {s.difficulty ? <Pill tone="info" size="sm">{t(`trips.diff_${s.difficulty}`, { defaultValue: s.difficulty })}</Pill> : <span />}
                    <Pill tone="neutral" size="sm">{t(`trips.rank_${s.min_cert_rank}`, { defaultValue: String(s.min_cert_rank) })}</Pill>
                  </div>
                ))}
              </div>
            )
          )}
        </div>
      </div>

      <DepartureEditSheet open={depSheet.open} onClose={() => setDepSheet({ open: false, item: null })} onSaved={() => setDepSheet({ open: false, item: null })} item={depSheet.item} sites={sites} />
      <SiteEditSheet open={siteSheet.open} onClose={() => setSiteSheet({ open: false, item: null })} onSaved={() => setSiteSheet({ open: false, item: null })} item={siteSheet.item} />
      <ManifestSheet open={!!manifest} onClose={() => setManifest(null)} departure={manifest} />
    </div>
  )
}
