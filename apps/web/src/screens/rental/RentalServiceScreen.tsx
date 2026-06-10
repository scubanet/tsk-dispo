import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { PageHeader, KpiCard, KpiGrid, Pill, EmptyState, Loader, dateMedium } from '@/foundation'
import {
  useRentalAssets, useOpenRentals, useOpenServiceJobs, useRecentFills,
  useRentalCheckin, useServiceComplete,
} from '@/hooks/useRental'
import { useCurrentUser } from '@/hooks/useCurrentUser'
import { canEditOps } from '@/lib/auth'
import { AssetEditSheet } from '@/screens/rental/AssetEditSheet'
import { RentalCheckoutSheet } from '@/screens/rental/RentalCheckoutSheet'
import { ServiceOpenSheet } from '@/screens/rental/ServiceOpenSheet'
import { FillStationSheet } from '@/screens/rental/FillStationSheet'
import type { RentalAsset } from '@/lib/rentalQueries'

type Tab = 'assets' | 'rentals' | 'service' | 'fill'

const STATUS_TONE: Record<string, 'neutral' | 'info' | 'success' | 'warning' | 'danger'> = {
  available: 'success', reserved: 'info', out: 'warning', service: 'warning', retired: 'neutral',
}

export function RentalServiceScreen() {
  const { t } = useTranslation()
  const { data: user } = useCurrentUser()
  const mayEdit = user ? canEditOps(user.role) : false

  const { data: assets = [], isLoading: la } = useRentalAssets()
  const { data: rentals = [], isLoading: lr } = useOpenRentals()
  const { data: jobs = [], isLoading: lj } = useOpenServiceJobs()
  const { data: fills = [] } = useRecentFills()
  const checkin = useRentalCheckin()
  const complete = useServiceComplete()

  const [tab, setTab] = useState<Tab>('assets')
  const [assetSheet, setAssetSheet] = useState<{ open: boolean; item: RentalAsset | null }>({ open: false, item: null })
  const [checkoutOpen, setCheckoutOpen] = useState(false)
  const [serviceSheet, setServiceSheet] = useState<{ open: boolean; assetId: string | null }>({ open: false, assetId: null })
  const [fillOpen, setFillOpen] = useState(false)

  if (la || lr || lj) return <div style={{ padding: 'var(--space-4)' }}><Loader /></div>

  const dueCount = assets.filter((a) => a.service_overdue || a.cert_overdue).length
  const assetLabel = (id: string | null) => assets.find((a) => a.asset_id === id)?.label ?? '—'

  const tabs: Tab[] = ['assets', 'rentals', 'service', 'fill']

  const NEW_ACTIONS: Record<Tab, { label: string; onClick: () => void }> = {
    assets: { label: t('rental.new_asset'), onClick: () => setAssetSheet({ open: true, item: null }) },
    rentals: { label: t('rental.new_checkout'), onClick: () => setCheckoutOpen(true) },
    service: { label: t('rental.new_service'), onClick: () => setServiceSheet({ open: true, assetId: null }) },
    fill: { label: t('rental.new_fill'), onClick: () => setFillOpen(true) },
  }

  return (
    <div className="atoll-screen">
      <PageHeader title={t('rental.title')} subtitle={t('rental.subtitle')} />

      <div className="atoll-screen__body">
        <KpiGrid columns={3} gap="md">
          <KpiCard variant="stat" label={t('rental.kpi_assets')} value={assets.length} />
          <KpiCard variant={dueCount > 0 ? 'alert' : 'stat'} alertTone="warning" label={t('rental.kpi_due')} value={dueCount} />
          <KpiCard variant="stat" label={t('rental.kpi_open_rentals')} value={rentals.length} />
        </KpiGrid>

        <div className="atoll-panel">
          <div className="atoll-panel__toolbar">
            <div className="seg">
              {tabs.map((tk) => (
                <button key={tk} className={tab === tk ? 'active' : undefined} onClick={() => setTab(tk)}>{t(`rental.tab_${tk}`)}</button>
              ))}
            </div>
            <span className="atoll-panel__spacer" />
            {mayEdit && <button className="btn" onClick={NEW_ACTIONS[tab].onClick}>{NEW_ACTIONS[tab].label}</button>}
          </div>

          {/* GERÄTE */}
          {tab === 'assets' && (
            assets.length === 0 ? (
              <div className="atoll-panel__empty"><EmptyState title={t('rental.no_assets')} /></div>
            ) : (
              <div>
                {assets.map((a) => (
                  <div key={a.asset_id} className="atoll-listrow">
                    <div
                      className="atoll-listrow__main"
                      style={{ cursor: mayEdit ? 'pointer' : 'default' }}
                      onClick={() => mayEdit && setAssetSheet({ open: true, item: a })}
                    >
                      <span className="atoll-listrow__title">{a.label}</span>
                      <span className="caption-2">{t(`rental.type_${a.asset_type}`, { defaultValue: a.asset_type })}</span>
                    </div>
                    <div className="atoll-listrow__pills">
                      <Pill tone={STATUS_TONE[a.status] ?? 'neutral'} size="sm">{t(`rental.status_${a.status}`, { defaultValue: a.status })}</Pill>
                      {a.service_overdue && <Pill tone="warning" size="sm">{t('rental.service_due')}</Pill>}
                      {a.cert_overdue && <Pill tone="danger" size="sm">{t('rental.cert_overdue')}</Pill>}
                    </div>
                    {mayEdit
                      ? <button className="btn-secondary btn" onClick={() => setServiceSheet({ open: true, assetId: a.asset_id })}>{t('rental.to_service')}</button>
                      : <span />}
                  </div>
                ))}
              </div>
            )
          )}

          {/* VERLEIH */}
          {tab === 'rentals' && (
            rentals.length === 0 ? (
              <div className="atoll-panel__empty"><EmptyState title={t('rental.no_rentals')} /></div>
            ) : (
              <div>
                {rentals.map((r) => (
                  <div key={r.agreement_id} className="atoll-listrow">
                    <div className="atoll-listrow__main">
                      <span className="atoll-listrow__title">{r.person_name}</span>
                      <span className="caption-2">{t('rental.assets_n', { count: r.asset_count })} · {dateMedium(r.out_at)}</span>
                    </div>
                    {r.overdue ? <Pill tone="danger" size="sm">{t('rental.overdue')}</Pill> : <span />}
                    {mayEdit
                      ? <button className="btn-secondary btn" disabled={checkin.isPending} onClick={() => checkin.mutate(r.agreement_id)}>{t('rental.return')}</button>
                      : <span />}
                  </div>
                ))}
              </div>
            )
          )}

          {/* SERVICE */}
          {tab === 'service' && (
            jobs.length === 0 ? (
              <div className="atoll-panel__empty"><EmptyState title={t('rental.no_jobs')} /></div>
            ) : (
              <div>
                {jobs.map((j) => (
                  <div key={j.id} className="atoll-listrow">
                    <div className="atoll-listrow__main">
                      <span className="atoll-listrow__title">{t(`rental.svc_${j.type}`, { defaultValue: j.type })}{j.asset_id ? ` · ${assetLabel(j.asset_id)}` : ''}</span>
                      <span className="caption-2">{j.description || '—'}</span>
                    </div>
                    <Pill tone="info" size="sm">{t(`rental.jobstatus_${j.status}`, { defaultValue: j.status })}</Pill>
                    {mayEdit
                      ? <button className="btn-secondary btn" disabled={complete.isPending} onClick={() => complete.mutate({ jobId: j.id })}>{t('rental.complete')}</button>
                      : <span />}
                  </div>
                ))}
              </div>
            )
          )}

          {/* FÜLLEN */}
          {tab === 'fill' && (
            fills.length === 0 ? (
              <div className="atoll-panel__empty"><EmptyState title={t('rental.no_fills')} /></div>
            ) : (
              <div>
                {fills.map((f) => (
                  <div key={f.id} className="atoll-listrow">
                    <div className="atoll-listrow__main">
                      <span className="atoll-listrow__title">{t(`rental.gas_${f.gas}`, { defaultValue: f.gas })}{f.mix_o2 != null ? ` · O₂ ${f.mix_o2}%` : ''}{f.mix_he != null ? ` · He ${f.mix_he}%` : ''}</span>
                      <span className="caption-2">{f.asset_id ? assetLabel(f.asset_id) : (f.cylinder_ref || '—')} · {dateMedium(f.filled_at)}</span>
                    </div>
                    <span className="tabular-nums">{f.pressure_bar != null ? `${f.pressure_bar} bar` : ''}</span>
                    {f.cert_check_passed ? <Pill tone="success" size="sm">✓</Pill> : <Pill tone="danger" size="sm">✗</Pill>}
                  </div>
                ))}
              </div>
            )
          )}
        </div>
      </div>

      <AssetEditSheet open={assetSheet.open} onClose={() => setAssetSheet({ open: false, item: null })} onSaved={() => setAssetSheet({ open: false, item: null })} item={assetSheet.item} />
      <RentalCheckoutSheet open={checkoutOpen} onClose={() => setCheckoutOpen(false)} onSaved={() => setCheckoutOpen(false)} assets={assets} />
      <ServiceOpenSheet open={serviceSheet.open} onClose={() => setServiceSheet({ open: false, assetId: null })} onSaved={() => setServiceSheet({ open: false, assetId: null })} assetId={serviceSheet.assetId} />
      <FillStationSheet open={fillOpen} onClose={() => setFillOpen(false)} onSaved={() => setFillOpen(false)} assets={assets} />
    </div>
  )
}
