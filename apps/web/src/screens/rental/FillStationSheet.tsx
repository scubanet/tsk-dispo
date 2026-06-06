import { useEffect, useState, type CSSProperties, type ReactNode } from 'react'
import { useTranslation } from 'react-i18next'
import { Sheet } from '@/components/Sheet'
import { useFillLogCreate } from '@/hooks/useRental'
import type { RentalAsset } from '@/lib/rentalQueries'

interface Props {
  open: boolean
  onClose: () => void
  onSaved: () => void
  assets: RentalAsset[]
}

const GASES = ['air', 'nitrox', 'trimix'] as const

const inputStyle: CSSProperties = {
  padding: '8px 10px', borderRadius: 8, border: '0.5px solid var(--hairline)',
  background: 'var(--surface-strong)', color: 'var(--ink)', font: 'inherit', fontSize: 13.5, width: '100%',
}
function Field({ label, children }: { label: string; children: ReactNode }) {
  return <div><div className="caption-2" style={{ marginBottom: 4 }}>{label.toUpperCase()}</div>{children}</div>
}

export function FillStationSheet({ open, onClose, onSaved, assets }: Props) {
  const { t } = useTranslation()
  const fill = useFillLogCreate()

  const [assetId, setAssetId] = useState('')
  const [cylinderRef, setCylinderRef] = useState('')
  const [gas, setGas] = useState<string>('air')
  const [o2, setO2] = useState('')
  const [he, setHe] = useState('')
  const [pressure, setPressure] = useState('200')
  const [certPassed, setCertPassed] = useState(true)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    if (!open) return
    setAssetId(''); setCylinderRef(''); setGas('air'); setO2(''); setHe(''); setPressure('200'); setCertPassed(true); setError(null)
  }, [open])

  const tanks = assets.filter((a) => a.asset_type === 'tank')

  async function submit() {
    if (!certPassed) { setError(t('rental.cert_required')); return }
    setError(null)
    try {
      await fill.mutateAsync({
        gas,
        pressureBar: Number(pressure || 0),
        certCheckPassed: certPassed,
        assetId: assetId || null,
        cylinderRef: assetId ? null : (cylinderRef.trim() || null),
        mixO2: gas === 'air' ? null : (o2 ? Number(o2) : null),
        mixHe: gas === 'trimix' ? (he ? Number(he) : null) : null,
      })
      onSaved(); onClose()
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : t('common.error'))
    }
  }

  return (
    <Sheet open={open} onClose={onClose} title={t('rental.new_fill')} width={500}>
      <div style={{ display: 'grid', gap: 12 }}>
        <Field label={t('rental.cylinder')}>
          <select style={inputStyle} value={assetId} onChange={(e) => setAssetId(e.target.value)}>
            <option value="">{t('rental.customer_cylinder')}</option>
            {tanks.map((a) => <option key={a.asset_id} value={a.asset_id}>{a.label}</option>)}
          </select>
        </Field>
        {!assetId && (
          <Field label={t('rental.cylinder_ref')}>
            <input style={inputStyle} value={cylinderRef} onChange={(e) => setCylinderRef(e.target.value)} />
          </Field>
        )}
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8 }}>
          <Field label={t('rental.gas')}>
            <select style={inputStyle} value={gas} onChange={(e) => setGas(e.target.value)}>
              {GASES.map((g) => <option key={g} value={g}>{t(`rental.gas_${g}`, { defaultValue: g })}</option>)}
            </select>
          </Field>
          <Field label={t('rental.pressure')}>
            <input style={inputStyle} type="number" min="0" step="10" value={pressure} onChange={(e) => setPressure(e.target.value)} />
          </Field>
        </div>
        {gas !== 'air' && (
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8 }}>
            <Field label="O₂ %"><input style={inputStyle} type="number" min="0" max="100" value={o2} onChange={(e) => setO2(e.target.value)} /></Field>
            {gas === 'trimix' && <Field label="He %"><input style={inputStyle} type="number" min="0" max="100" value={he} onChange={(e) => setHe(e.target.value)} /></Field>}
          </div>
        )}
        <label style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
          <input type="checkbox" checked={certPassed} onChange={(e) => setCertPassed(e.target.checked)} />
          {t('rental.cert_check_passed')}
        </label>

        {error && <div className="chip chip-red">{error}</div>}

        <div style={{ display: 'flex', gap: 'var(--space-2)' }}>
          <button className="btn-secondary btn" onClick={onClose}>{t('common.cancel')}</button>
          <button className="btn" onClick={submit} disabled={fill.isPending} style={{ flex: 1 }}>
            {fill.isPending ? t('common.saving') : t('rental.fill_action')}
          </button>
        </div>
      </div>
    </Sheet>
  )
}
