/**
 * AvailabilityAddSheet — Sheet zum Anlegen eines neuen Verfügbarkeits-Eintrags.
 * Identisch genutzt vom MyProfileScreen (TL/DM trägt sich selbst ein) und
 * AvailabilityTab (Dispatcher trägt stellvertretend ein).
 */

import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { Sheet } from '@/components/Sheet'
import { supabase } from '@/lib/supabase'

const sheetInputStyle = {
  padding: '8px 10px',
  borderRadius: 8,
  border: '1px solid var(--border-tertiary)',
  background: 'var(--bg-card)',
  color: 'var(--text-primary)',
  font: 'inherit',
  fontSize: 13.5,
  width: '100%',
}

interface Props {
  open: boolean
  onClose: () => void
  onCreated: () => void
  instructorId: string
}

export function AvailabilityAddSheet({ open, onClose, onCreated, instructorId }: Props) {
  const { t } = useTranslation()
  const [kind, setKind] = useState<'urlaub' | 'abwesend' | 'verfügbar'>('urlaub')
  const [fromDate, setFromDate] = useState(new Date().toISOString().slice(0, 10))
  const [toDate, setToDate] = useState(new Date().toISOString().slice(0, 10))
  const [note, setNote] = useState('')
  const [saving, setSaving] = useState(false)

  async function save() {
    setSaving(true)
    const { error } = await supabase.from('availability').insert({
      instructor_id: instructorId,
      from_date: fromDate,
      to_date: toDate,
      kind,
      note: note.trim() || null,
    })
    setSaving(false)
    if (error) {
      alert(t('settings.recalc.error_prefix') + error.message)
      return
    }
    onCreated()
    onClose()
    setKind('urlaub')
    setNote('')
  }

  return (
    <Sheet open={open} onClose={onClose} title={t('my_profile.add_availability')}>
      <div style={{ display: 'grid', gap: 14 }}>
        <div>
          <div className="caption-2" style={{ marginBottom: 4 }}>{t('my_profile.label_kind')}</div>
          <select
            value={kind}
            onChange={(e) => setKind(e.target.value as typeof kind)}
            style={sheetInputStyle}
          >
            <option value="urlaub">{t('my_profile.kind_urlaub')}</option>
            <option value="abwesend">{t('my_profile.kind_abwesend')}</option>
            <option value="verfügbar">{t('my_profile.kind_verfügbar_long')}</option>
          </select>
        </div>

        <div>
          <div className="caption-2" style={{ marginBottom: 4 }}>{t('my_profile.label_from')}</div>
          <input
            type="date"
            value={fromDate}
            onChange={(e) => setFromDate(e.target.value)}
            style={sheetInputStyle}
          />
        </div>

        <div>
          <div className="caption-2" style={{ marginBottom: 4 }}>{t('my_profile.label_to')}</div>
          <input
            type="date"
            value={toDate}
            onChange={(e) => setToDate(e.target.value)}
            style={sheetInputStyle}
          />
        </div>

        <div>
          <div className="caption-2" style={{ marginBottom: 4 }}>{t('my_profile.label_note')}</div>
          <input
            value={note}
            onChange={(e) => setNote(e.target.value)}
            placeholder={t('my_profile.note_placeholder')}
            style={sheetInputStyle}
          />
        </div>

        <div style={{ display: 'flex', gap: 8 }}>
          <button className="atoll-btn" onClick={onClose}>{t('common.cancel')}</button>
          <button
            className="atoll-btn atoll-btn--primary"
            onClick={save}
            disabled={saving}
            style={{ flex: 1 }}
          >
            {saving ? t('common.saving') : t('my_profile.add_entry')}
          </button>
        </div>
      </div>
    </Sheet>
  )
}
