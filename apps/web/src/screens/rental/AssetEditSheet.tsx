import { useEffect, useState, type CSSProperties, type ReactNode } from 'react'
import { useTranslation } from 'react-i18next'
import { CHDateField } from '@/components/CHFields'
import { Sheet } from '@/components/Sheet'
import { useSaveAsset } from '@/hooks/useRental'
import { useCurrentTenant } from '@/hooks/useRetail'
import type { RentalAsset } from '@/lib/rentalQueries'

interface Props {
  open: boolean
  onClose: () => void
  onSaved: () => void
  item: RentalAsset | null
}

const ASSET_TYPES = ['regulator', 'bcd', 'tank', 'computer', 'wetsuit', 'weight', 'fins', 'mask', 'torch', 'other'] as const

const inputStyle: CSSProperties = {
  padding: '8px 10px', borderRadius: 8, border: '0.5px solid var(--hairline)',
  background: 'var(--surface-strong)', color: 'var(--ink)', font: 'inherit', fontSize: 13.5, width: '100%',
}
function Field({ label, children }: { label: string; children: ReactNode }) {
  return <div><div className="caption-2" style={{ marginBottom: 4 }}>{label.toUpperCase()}</div>{children}</div>
}

export function AssetEditSheet({ open, onClose, onSaved, item }: Props) {
  const { t } = useTranslation()
  const { data: tenantId } = useCurrentTenant()
  const save = useSaveAsset()
  const isEdit = !!item

  const [assetType, setAssetType] = useState<string>('regulator')
  const [label, setLabel] = useState('')
  const [nextServiceDue, setNextServiceDue] = useState('')
  const [certDue, setCertDue] = useState('')
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    if (!open) return
    setError(null)
    if (item) {
      setAssetType(item.asset_type)
      setLabel(item.label)
      setNextServiceDue(item.next_service_due ?? '')
      setCertDue(item.cert_due ?? '')
    } else {
      setAssetType('regulator'); setLabel(''); setNextServiceDue(''); setCertDue('')
    }
  }, [open, item])

  async function submit() {
    if (!label.trim()) { setError(t('rental.label_required')); return }
    if (!tenantId) { setError(t('common.error')); return }
    setError(null)
    try {
      await save.mutateAsync({
        assetId: item?.asset_id,
        tenantId,
        assetType,
        label: label.trim(),
        nextServiceDue: nextServiceDue || null,
        certDue: certDue || null,
      })
      onSaved(); onClose()
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : t('common.error'))
    }
  }

  return (
    <Sheet open={open} onClose={onClose} title={isEdit ? t('rental.edit_asset') : t('rental.new_asset')} width={500}>
      <div style={{ display: 'grid', gap: 12 }}>
        <Field label={t('rental.asset_label')}>
          <input style={inputStyle} value={label} onChange={(e) => setLabel(e.target.value)} />
        </Field>
        <Field label={t('rental.asset_type')}>
          <select style={inputStyle} value={assetType} onChange={(e) => setAssetType(e.target.value)}>
            {ASSET_TYPES.map((tp) => <option key={tp} value={tp}>{t(`rental.type_${tp}`, { defaultValue: tp })}</option>)}
          </select>
        </Field>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8 }}>
          <Field label={t('rental.next_service')}><CHDateField style={inputStyle} value={nextServiceDue} onChange={setNextServiceDue} /></Field>
          <Field label={t('rental.cert_due')}><CHDateField style={inputStyle} value={certDue} onChange={setCertDue} /></Field>
        </div>

        {error && <div className="chip chip-red">{error}</div>}

        <div style={{ display: 'flex', gap: 'var(--space-2)' }}>
          <button className="btn-secondary btn" onClick={onClose}>{t('common.cancel')}</button>
          <button className="btn" onClick={submit} disabled={save.isPending || !label.trim()} style={{ flex: 1 }}>
            {save.isPending ? t('common.saving') : t('common.save')}
          </button>
        </div>
      </div>
    </Sheet>
  )
}
