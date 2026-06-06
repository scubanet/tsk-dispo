import { useState, type CSSProperties } from 'react'
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

const rowStyle: CSSProperties = {
  display: 'grid', gridTemplateColumns: '1fr auto auto', alignItems: 'center',
  gap: 'var(--space-3)', padding: 'var(--space-2)', borderBottom: '0.5px solid var(--hairline)',
}
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

  return (
    <div className="screen" style={{ padding: 'var(--space-4)', display: 'grid', gap: 'var(--space-3)' }}>
      <PageHeader title={t('rental.title')} subtitle={t('rental.subtitle')} />

      <KpiGrid columns={3} gap="md">
        <KpiCard variant="stat" label={t('rental.kpi_assets')} value={assets.length} />
        <KpiCard variant={dueCount > 0 ? 'alert' : 'stat'} alertTone="warning" label={t('rental.kpi_due')} value={dueCount} />
        <KpiCard variant="stat" label={t('rental.kpi_open_rentals')} value={rentals.length} />
      </KpiGrid>

      <div className="seg">
        {tabs.map((tk) => (
          <button key={tk} className={tab === tk ? 'active' : undefined} onClick={() => setTab(tk)}>{t(`rental.tab_${tk}`)}</button>
        ))}
      </div>

      {/* GERÄTE */}
      {tab === 'assets' && (
        <div>
          {mayEdit && (
            <div style={{ marginBottom: 'var(--space-2)' }}>
              <button className="btn" onClick={() => setAssetSheet({ open: true, item: null })}>{t('rental.new_asset')}</button>
            </div>
          )}
          {assets.length === 0 ? <EmptyState title={t('rental.no_assets')} /> : assets.map((a) => (
            <div key={a.asset_id} style={rowStyle}>
              <div style={{ display: 'flex', flexDirection: 'column', cursor: mayEdit ? 'pointer' : 'default' }} onClick={() => mayEdit && setAssetSheet({ open: true, item: a })}>
                <span style={{ fontWeight: 600 }}>{a.label}</span>
                <span className="caption-2">{t(`rental.type_${a.asset_type}`, { defaultValue: a.asset_type })}</span>
              </div>
              <div style={{ display: 'flex', gap: 6, alignItems: 'center', flexWrap: 'wrap', justifyContent: 'flex-end' }}>
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
      )}

      {/* VERLEIH */}
      {tab === 'rentals' && (
        <div>
          {mayEdit && (
            <div style={{ marginBottom: 'var(--space-2)' }}>
              <button className="btn" onClick={() => setCheckoutOpen(true)}>{t('rental.new_checkout')}</button>
            </div>
          )}
          {rentals.length === 0 ? <EmptyState title={t('rental.no_rentals')} /> : rentals.map((r) => (
            <div key={r.agreement_id} style={rowStyle}>
              <div style={{ display: 'flex', flexDirection: 'column' }}>
                <span style={{ fontWeight: 600 }}>{r.person_name}</span>
                <span className="caption-2">{t('rental.assets_n', { count: r.asset_count })} · {dateMedium(r.out_at)}</span>
              </div>
              {r.overdue ? <Pill tone="danger" size="sm">{t('rental.overdue')}</Pill> : <span />}
              {mayEdit
                ? <button className="btn-secondary btn" disabled={checkin.isPending} onClick={() => checkin.mutate(r.agreement_id)}>{t('rental.return')}</button>
                : <span />}
            </div>
          ))}
        </div>
      )}

      {/* SERVICE */}
      {tab === 'service' && (
        <div>
          {mayEdit && (
            <div style={{ marginBottom: 'var(--space-2)' }}>
              <button className="btn" onClick={() => setServiceSheet({ open: true, assetId: null })}>{t('rental.new_service')}</button>
            </div>
          )}
          {jobs.length === 0 ? <EmptyState title={t('rental.no_jobs')} /> : jobs.map((j) => (
            <div key={j.id} style={rowStyle}>
              <div style={{ display: 'flex', flexDirection: 'column' }}>
                <span style={{ fontWeight: 600 }}>{t(`rental.svc_${j.type}`, { defaultValue: j.type })}{j.asset_id ? ` · ${assetLabel(j.asset_id)}` : ''}</span>
                <span className="caption-2">{j.description || '—'}</span>
              </div>
              <Pill tone="info" size="sm">{t(`rental.jobstatus_${j.status}`, { defaultValue: j.status })}</Pill>
              {mayEdit
                ? <button className="btn-secondary btn" disabled={complete.isPending} onClick={() => complete.mutate({ jobId: j.id })}>{t('rental.complete')}</button>
                : <span />}
            </div>
          ))}
        </div>
      )}

      {/* FÜLLEN */}
      {tab === 'fill' && (
        <div>
          {mayEdit && (
            <div style={{ marginBottom: 'var(--space-2)' }}>
              <button className="btn" onClick={() => setFillOpen(true)}>{t('rental.new_fill')}</button>
            </div>
          )}
          {fills.length === 0 ? <EmptyState title={t('rental.no_fills')} /> : fills.map((f) => (
            <div key={f.id} style={rowStyle}>
              <div style={{ display: 'flex', flexDirection: 'column' }}>
                <span style={{ fontWeight: 600 }}>{t(`rental.gas_${f.gas}`, { defaultValue: f.gas })}{f.mix_o2 != null ? ` · O₂ ${f.mix_o2}%` : ''}{f.mix_he != null ? ` · He ${f.mix_he}%` : ''}</span>
                <span className="caption-2">{f.asset_id ? assetLabel(f.asset_id) : (f.cylinder_ref || '—')} · {dateMedium(f.filled_at)}</span>
              </div>
              <span className="tabular-nums">{f.pressure_bar != null ? `${f.pressure_bar} bar` : ''}</span>
              {f.cert_check_passed ? <Pill tone="success" size="sm">✓</Pill> : <Pill tone="danger" size="sm">✗</Pill>}
            </div>
          ))}
        </div>
      )}

      <AssetEditSheet open={assetSheet.open} onClose={() => setAssetSheet({ open: false, item: null })} onSaved={() => setAssetSheet({ open: false, item: null })} item={assetSheet.item} />
      <RentalCheckoutSheet open={checkoutOpen} onClose={() => setCheckoutOpen(false)} onSaved={() => setCheckoutOpen(false)} assets={assets} />
      <ServiceOpenSheet open={serviceSheet.open} onClose={() => setServiceSheet({ open: false, assetId: null })} onSaved={() => setServiceSheet({ open: false, assetId: null })} assetId={serviceSheet.assetId} />
      <FillStationSheet open={fillOpen} onClose={() => setFillOpen(false)} onSaved={() => setFillOpen(false)} assets={assets} />
    </div>
  )
}
