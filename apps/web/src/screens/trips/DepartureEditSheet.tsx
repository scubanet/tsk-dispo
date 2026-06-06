import { useEffect, useState, type CSSProperties, type ReactNode } from 'react'
import { useTranslation } from 'react-i18next'
import { Sheet } from '@/components/Sheet'
import { useSaveDeparture } from '@/hooks/useTrips'
import { useCurrentTenant } from '@/hooks/useRetail'
import type { Departure, DiveSite } from '@/lib/tripQueries'

interface Props {
  open: boolean
  onClose: () => void
  onSaved: () => void
  item: Departure | null
  sites: DiveSite[]
}

const inputStyle: CSSProperties = {
  padding: '8px 10px', borderRadius: 8, border: '0.5px solid var(--hairline)',
  background: 'var(--surface-strong)', color: 'var(--ink)', font: 'inherit', fontSize: 13.5, width: '100%',
}
function Field({ label, children }: { label: string; children: ReactNode }) {
  return <div><div className="caption-2" style={{ marginBottom: 4 }}>{label.toUpperCase()}</div>{children}</div>
}
// datetime-local → ISO; vorhandenes ISO → local input value
const toLocal = (iso: string) => { const d = new Date(iso); const off = d.getTimezoneOffset(); return new Date(d.getTime() - off * 60000).toISOString().slice(0, 16) }

export function DepartureEditSheet({ open, onClose, onSaved, item, sites }: Props) {
  const { t } = useTranslation()
  const { data: tenantId } = useCurrentTenant()
  const save = useSaveDeparture()
  const isEdit = !!item

  const [name, setName] = useState('')
  const [datetime, setDatetime] = useState('')
  const [capacity, setCapacity] = useState('8')
  const [meetingPoint, setMeetingPoint] = useState('')
  const [siteIds, setSiteIds] = useState<Set<string>>(new Set())
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    if (!open) return
    setError(null); setSiteIds(new Set())
    if (item) {
      setName(item.name); setDatetime(item.datetime ? toLocal(item.datetime) : ''); setCapacity(String(item.capacity)); setMeetingPoint(item.meeting_point ?? '')
    } else {
      setName(''); setDatetime(''); setCapacity('8'); setMeetingPoint('')
    }
  }, [open, item])

  function toggleSite(id: string) {
    setSiteIds((s) => { const next = new Set(s); if (next.has(id)) next.delete(id); else next.add(id); return next })
  }

  async function submit() {
    if (!name.trim()) { setError(t('trips.name_required')); return }
    if (!datetime) { setError(t('trips.datetime_required')); return }
    if (!tenantId) { setError(t('common.error')); return }
    setError(null)
    try {
      await save.mutateAsync({
        departureId: item?.departure_id,
        tenantId,
        name: name.trim(),
        datetimeIso: new Date(datetime).toISOString(),
        capacity: Number(capacity || 0),
        meetingPoint: meetingPoint.trim() || null,
        siteIds: [...siteIds],
      })
      onSaved(); onClose()
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : t('common.error'))
    }
  }

  return (
    <Sheet open={open} onClose={onClose} title={isEdit ? t('trips.edit_departure') : t('trips.new_departure')} width={540}>
      <div style={{ display: 'grid', gap: 12 }}>
        <Field label={t('trips.departure_name')}><input style={inputStyle} value={name} onChange={(e) => setName(e.target.value)} /></Field>
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 100px', gap: 8 }}>
          <Field label={t('trips.datetime')}><input style={inputStyle} type="datetime-local" value={datetime} onChange={(e) => setDatetime(e.target.value)} /></Field>
          <Field label={t('trips.capacity')}><input style={inputStyle} type="number" min="1" step="1" value={capacity} onChange={(e) => setCapacity(e.target.value)} /></Field>
        </div>
        <Field label={t('trips.meeting_point')}><input style={inputStyle} value={meetingPoint} onChange={(e) => setMeetingPoint(e.target.value)} /></Field>

        {!isEdit && (
          <div>
            <div className="caption-2" style={{ marginBottom: 4 }}>{t('trips.sites').toUpperCase()} ({siteIds.size})</div>
            <div style={{ display: 'grid', gap: 4, maxHeight: 180, overflow: 'auto' }}>
              {sites.length === 0 ? <div className="caption-2">{t('trips.no_sites')}</div> : sites.map((s) => (
                <label key={s.id} style={{ display: 'flex', gap: 8, alignItems: 'center', padding: '4px 2px' }}>
                  <input type="checkbox" checked={siteIds.has(s.id)} onChange={() => toggleSite(s.id)} />
                  <span>{s.name}</span>
                  <span className="caption-2">· {t(`trips.rank_${s.min_cert_rank}`, { defaultValue: String(s.min_cert_rank) })}</span>
                </label>
              ))}
            </div>
          </div>
        )}

        {error && <div className="chip chip-red">{error}</div>}

        <div style={{ display: 'flex', gap: 'var(--space-2)' }}>
          <button className="btn-secondary btn" onClick={onClose}>{t('common.cancel')}</button>
          <button className="btn" onClick={submit} disabled={save.isPending || !name.trim() || !datetime} style={{ flex: 1 }}>
            {save.isPending ? t('common.saving') : t('common.save')}
          </button>
        </div>
      </div>
    </Sheet>
  )
}
