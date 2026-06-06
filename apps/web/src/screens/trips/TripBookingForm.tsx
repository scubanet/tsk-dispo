import { useState, type CSSProperties } from 'react'
import { useTranslation } from 'react-i18next'
import { useTripBook } from '@/hooks/useTrips'
import { useSearchPersons } from '@/hooks/useRental'

interface Props {
  departureId: string
  onBooked: () => void
  onCancel: () => void
}

const RANKS = [0, 1, 2, 3, 4, 5] as const
const inputStyle: CSSProperties = {
  padding: '8px 10px', borderRadius: 8, border: '0.5px solid var(--hairline)',
  background: 'var(--surface-strong)', color: 'var(--ink)', font: 'inherit', fontSize: 13.5, width: '100%',
}

export function TripBookingForm({ departureId, onBooked, onCancel }: Props) {
  const { t } = useTranslation()
  const book = useTripBook(departureId)

  const [search, setSearch] = useState('')
  const { data: persons = [] } = useSearchPersons(search)
  const [personId, setPersonId] = useState('')
  const [personName, setPersonName] = useState('')
  const [rank, setRank] = useState('1')
  const [override, setOverride] = useState(false)
  const [needsRental, setNeedsRental] = useState(false)
  const [needsGuide, setNeedsGuide] = useState(false)
  const [error, setError] = useState<string | null>(null)

  async function submit() {
    if (!personId) { setError(t('trips.pick_person')); return }
    setError(null)
    try {
      await book.mutateAsync({ departureId, personId, certRank: Number(rank), override, needsRental, needsGuide })
      onBooked()
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : t('common.error'))
    }
  }

  return (
    <div className="glass-thin" style={{ padding: 'var(--space-3)', borderRadius: 12, display: 'grid', gap: 10 }}>
      <div className="caption-2">{t('trips.new_booking').toUpperCase()}</div>

      {personId ? (
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <span>{personName}</span>
          <button className="btn-ghost btn" onClick={() => { setPersonId(''); setPersonName('') }}>×</button>
        </div>
      ) : (
        <>
          <input style={inputStyle} placeholder={t('trips.search_person')} value={search} onChange={(e) => setSearch(e.target.value)} />
          <div style={{ display: 'grid', gap: 4, maxHeight: 140, overflow: 'auto' }}>
            {persons.map((p) => (
              <button key={p.id} type="button" className="btn-secondary btn" style={{ justifyContent: 'flex-start' }}
                onClick={() => { setPersonId(p.id); setPersonName(p.name) }}>{p.name}</button>
            ))}
          </div>
        </>
      )}

      <div style={{ display: 'grid', gridTemplateColumns: '1fr auto', gap: 8, alignItems: 'center' }}>
        <div>
          <div className="caption-2" style={{ marginBottom: 4 }}>{t('trips.diver_level').toUpperCase()}</div>
          <select style={inputStyle} value={rank} onChange={(e) => setRank(e.target.value)}>
            {RANKS.map((r) => <option key={r} value={r}>{t(`trips.rank_${r}`, { defaultValue: String(r) })}</option>)}
          </select>
        </div>
        <label style={{ display: 'flex', gap: 6, alignItems: 'center', paddingTop: 18 }}>
          <input type="checkbox" checked={override} onChange={(e) => setOverride(e.target.checked)} /> {t('trips.override')}
        </label>
      </div>

      <div style={{ display: 'flex', gap: 14 }}>
        <label style={{ display: 'flex', gap: 6, alignItems: 'center' }}><input type="checkbox" checked={needsRental} onChange={(e) => setNeedsRental(e.target.checked)} /> {t('trips.needs_rental')}</label>
        <label style={{ display: 'flex', gap: 6, alignItems: 'center' }}><input type="checkbox" checked={needsGuide} onChange={(e) => setNeedsGuide(e.target.checked)} /> {t('trips.needs_guide')}</label>
      </div>

      {error && <div className="chip chip-red">{error}</div>}

      <div style={{ display: 'flex', gap: 'var(--space-2)' }}>
        <button className="btn-secondary btn" onClick={onCancel}>{t('common.cancel')}</button>
        <button className="btn" onClick={submit} disabled={book.isPending || !personId} style={{ flex: 1 }}>
          {book.isPending ? t('common.saving') : t('trips.book_action')}
        </button>
      </div>
    </div>
  )
}
