import { useEffect, useState, type CSSProperties, type ReactNode } from 'react'
import { useTranslation } from 'react-i18next'
import { Sheet } from '@/components/Sheet'
import { useServiceOpen } from '@/hooks/useRental'

interface Props {
  open: boolean
  onClose: () => void
  onSaved: () => void
  assetId: string | null
}

const SERVICE_TYPES = ['annual_service', 'repair', 'inspection', 'hydro', 'vip'] as const

const inputStyle: CSSProperties = {
  padding: '8px 10px', borderRadius: 8, border: '0.5px solid var(--hairline)',
  background: 'var(--surface-strong)', color: 'var(--ink)', font: 'inherit', fontSize: 13.5, width: '100%',
}
function Field({ label, children }: { label: string; children: ReactNode }) {
  return <div><div className="caption-2" style={{ marginBottom: 4 }}>{label.toUpperCase()}</div>{children}</div>
}

export function ServiceOpenSheet({ open, onClose, onSaved, assetId }: Props) {
  const { t } = useTranslation()
  const svc = useServiceOpen()
  const [type, setType] = useState<string>('annual_service')
  const [description, setDescription] = useState('')
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    if (!open) return
    setType('annual_service'); setDescription(''); setError(null)
  }, [open])

  async function submit() {
    setError(null)
    try {
      await svc.mutateAsync({ type, assetId: assetId ?? null, description: description.trim() || null })
      onSaved(); onClose()
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : t('common.error'))
    }
  }

  return (
    <Sheet open={open} onClose={onClose} title={t('rental.new_service')} width={480}>
      <div style={{ display: 'grid', gap: 12 }}>
        <Field label={t('rental.service_type')}>
          <select style={inputStyle} value={type} onChange={(e) => setType(e.target.value)}>
            {SERVICE_TYPES.map((s) => <option key={s} value={s}>{t(`rental.svc_${s}`, { defaultValue: s })}</option>)}
          </select>
        </Field>
        <Field label={t('rental.description')}>
          <textarea style={{ ...inputStyle, resize: 'vertical' }} rows={3} value={description} onChange={(e) => setDescription(e.target.value)} />
        </Field>

        {error && <div className="chip chip-red">{error}</div>}

        <div style={{ display: 'flex', gap: 'var(--space-2)' }}>
          <button className="btn-secondary btn" onClick={onClose}>{t('common.cancel')}</button>
          <button className="btn" onClick={submit} disabled={svc.isPending} style={{ flex: 1 }}>
            {svc.isPending ? t('common.saving') : t('rental.open_service')}
          </button>
        </div>
      </div>
    </Sheet>
  )
}
