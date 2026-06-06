import { useEffect, useState, type CSSProperties, type ReactNode } from 'react'
import { useTranslation } from 'react-i18next'
import { Sheet } from '@/components/Sheet'
import { useSaveSite } from '@/hooks/useTrips'
import { useCurrentTenant } from '@/hooks/useRetail'
import type { DiveSite } from '@/lib/tripQueries'

interface Props { open: boolean; onClose: () => void; onSaved: () => void; item: DiveSite | null }

const RANKS = [0, 1, 2, 3, 4, 5] as const
const DIFFICULTIES = ['', 'easy', 'medium', 'hard'] as const

const inputStyle: CSSProperties = {
  padding: '8px 10px', borderRadius: 8, border: '0.5px solid var(--hairline)',
  background: 'var(--surface-strong)', color: 'var(--ink)', font: 'inherit', fontSize: 13.5, width: '100%',
}
function Field({ label, children }: { label: string; children: ReactNode }) {
  return <div><div className="caption-2" style={{ marginBottom: 4 }}>{label.toUpperCase()}</div>{children}</div>
}

export function SiteEditSheet({ open, onClose, onSaved, item }: Props) {
  const { t } = useTranslation()
  const { data: tenantId } = useCurrentTenant()
  const save = useSaveSite()
  const isEdit = !!item

  const [name, setName] = useState('')
  const [region, setRegion] = useState('')
  const [rank, setRank] = useState('0')
  const [difficulty, setDifficulty] = useState('')
  const [maxDepth, setMaxDepth] = useState('')
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    if (!open) return
    setError(null)
    if (item) {
      setName(item.name); setRegion(item.region ?? ''); setRank(String(item.min_cert_rank))
      setDifficulty(item.difficulty ?? ''); setMaxDepth(item.max_depth_m != null ? String(item.max_depth_m) : '')
    } else {
      setName(''); setRegion(''); setRank('0'); setDifficulty(''); setMaxDepth('')
    }
  }, [open, item])

  async function submit() {
    if (!name.trim()) { setError(t('trips.name_required')); return }
    if (!tenantId) { setError(t('common.error')); return }
    setError(null)
    try {
      await save.mutateAsync({
        siteId: item?.id,
        tenantId,
        name: name.trim(),
        region: region.trim() || null,
        minCertRank: Number(rank || 0),
        difficulty: difficulty || null,
        maxDepth: maxDepth ? Number(maxDepth) : null,
      })
      onSaved(); onClose()
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : t('common.error'))
    }
  }

  return (
    <Sheet open={open} onClose={onClose} title={isEdit ? t('trips.edit_site') : t('trips.new_site')} width={500}>
      <div style={{ display: 'grid', gap: 12 }}>
        <Field label={t('trips.site_name')}><input style={inputStyle} value={name} onChange={(e) => setName(e.target.value)} /></Field>
        <Field label={t('trips.region')}><input style={inputStyle} value={region} onChange={(e) => setRegion(e.target.value)} /></Field>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 8 }}>
          <Field label={t('trips.min_level')}>
            <select style={inputStyle} value={rank} onChange={(e) => setRank(e.target.value)}>
              {RANKS.map((r) => <option key={r} value={r}>{t(`trips.rank_${r}`, { defaultValue: String(r) })}</option>)}
            </select>
          </Field>
          <Field label={t('trips.difficulty')}>
            <select style={inputStyle} value={difficulty} onChange={(e) => setDifficulty(e.target.value)}>
              {DIFFICULTIES.map((d) => <option key={d} value={d}>{d ? t(`trips.diff_${d}`, { defaultValue: d }) : '—'}</option>)}
            </select>
          </Field>
          <Field label={t('trips.max_depth')}><input style={inputStyle} type="number" min="0" step="1" value={maxDepth} onChange={(e) => setMaxDepth(e.target.value)} /></Field>
        </div>

        {error && <div className="chip chip-red">{error}</div>}

        <div style={{ display: 'flex', gap: 'var(--space-2)' }}>
          <button className="btn-secondary btn" onClick={onClose}>{t('common.cancel')}</button>
          <button className="btn" onClick={submit} disabled={save.isPending || !name.trim()} style={{ flex: 1 }}>
            {save.isPending ? t('common.saving') : t('common.save')}
          </button>
        </div>
      </div>
    </Sheet>
  )
}
