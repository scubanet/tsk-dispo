import { useEffect, useState, type CSSProperties } from 'react'
import { useTranslation } from 'react-i18next'
import { Sheet } from '@/components/Sheet'
import { useRentalCheckout, useSearchPersons } from '@/hooks/useRental'
import type { RentalAsset } from '@/lib/rentalQueries'

interface Props {
  open: boolean
  onClose: () => void
  onSaved: () => void
  assets: RentalAsset[]
}

const inputStyle: CSSProperties = {
  padding: '8px 10px', borderRadius: 8, border: '0.5px solid var(--hairline)',
  background: 'var(--surface-strong)', color: 'var(--ink)', font: 'inherit', fontSize: 13.5, width: '100%',
}

export function RentalCheckoutSheet({ open, onClose, onSaved, assets }: Props) {
  const { t } = useTranslation()
  const checkout = useRentalCheckout()

  const [search, setSearch] = useState('')
  const { data: persons = [] } = useSearchPersons(search)
  const [personId, setPersonId] = useState('')
  const [personName, setPersonName] = useState('')
  const [selected, setSelected] = useState<Set<string>>(new Set())
  const [dueAt, setDueAt] = useState('')
  const [deposit, setDeposit] = useState('')
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    if (!open) return
    setSearch(''); setPersonId(''); setPersonName(''); setSelected(new Set()); setDueAt(''); setDeposit(''); setError(null)
  }, [open])

  // Nur ausgebbare Geräte: verfügbar und nicht überfällig.
  const available = assets.filter((a) => a.status === 'available' && !a.service_overdue && !a.cert_overdue)

  function toggle(id: string) {
    setSelected((s) => {
      const next = new Set(s)
      if (next.has(id)) next.delete(id); else next.add(id)
      return next
    })
  }

  async function submit() {
    if (!personId) { setError(t('rental.pick_person')); return }
    if (selected.size === 0) { setError(t('rental.pick_assets')); return }
    setError(null)
    try {
      await checkout.mutateAsync({
        personId,
        assetIds: [...selected],
        dueAt: dueAt ? new Date(dueAt).toISOString() : null,
        deposit: Number(deposit || 0),
      })
      onSaved(); onClose()
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : t('common.error'))
    }
  }

  return (
    <Sheet open={open} onClose={onClose} title={t('rental.new_checkout')} width={560}>
      <div style={{ display: 'grid', gap: 12 }}>
        <div>
          <div className="caption-2" style={{ marginBottom: 4 }}>{t('rental.person').toUpperCase()}</div>
          {personId ? (
            <div className="glass-thin" style={{ padding: '8px 10px', borderRadius: 8, display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <span>{personName}</span>
              <button className="btn-ghost btn" onClick={() => { setPersonId(''); setPersonName('') }}>×</button>
            </div>
          ) : (
            <>
              <input style={inputStyle} placeholder={t('rental.search_person')} value={search} onChange={(e) => setSearch(e.target.value)} />
              <div style={{ display: 'grid', gap: 4, maxHeight: 160, overflow: 'auto', marginTop: 6 }}>
                {persons.map((p) => (
                  <button key={p.id} type="button" className="btn-secondary btn" style={{ justifyContent: 'flex-start' }}
                    onClick={() => { setPersonId(p.id); setPersonName(p.name) }}>{p.name}</button>
                ))}
              </div>
            </>
          )}
        </div>

        <div>
          <div className="caption-2" style={{ marginBottom: 4 }}>{t('rental.assets').toUpperCase()} ({selected.size})</div>
          <div style={{ display: 'grid', gap: 4, maxHeight: 200, overflow: 'auto' }}>
            {available.length === 0 ? (
              <div className="caption-2">{t('rental.no_available')}</div>
            ) : available.map((a) => (
              <label key={a.asset_id} style={{ display: 'flex', gap: 8, alignItems: 'center', padding: '4px 2px' }}>
                <input type="checkbox" checked={selected.has(a.asset_id)} onChange={() => toggle(a.asset_id)} />
                <span>{a.label}</span>
                <span className="caption-2">· {t(`rental.type_${a.asset_type}`, { defaultValue: a.asset_type })}</span>
              </label>
            ))}
          </div>
        </div>

        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8 }}>
          <div><div className="caption-2" style={{ marginBottom: 4 }}>{t('rental.due_at').toUpperCase()}</div><input style={inputStyle} type="date" value={dueAt} onChange={(e) => setDueAt(e.target.value)} /></div>
          <div><div className="caption-2" style={{ marginBottom: 4 }}>{t('rental.deposit').toUpperCase()}</div><input style={inputStyle} type="number" min="0" step="1" value={deposit} onChange={(e) => setDeposit(e.target.value)} /></div>
        </div>

        {error && <div className="chip chip-red">{error}</div>}

        <div style={{ display: 'flex', gap: 'var(--space-2)' }}>
          <button className="btn-secondary btn" onClick={onClose}>{t('common.cancel')}</button>
          <button className="btn" onClick={submit} disabled={checkout.isPending || !personId || selected.size === 0} style={{ flex: 1 }}>
            {checkout.isPending ? t('common.saving') : t('rental.checkout_action')}
          </button>
        </div>
      </div>
    </Sheet>
  )
}
