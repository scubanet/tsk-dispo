import { useEffect, useState } from 'react'
import { Sheet } from '@/components/Sheet'
import { Icon } from '@/components/Icon'
import { supabase } from '@/lib/supabase'
import { chf } from '@/lib/format'

interface Instructor { id: string; name: string; padi_level: string }

type Kind = 'korrektur' | 'übertrag'

interface Props {
  open: boolean
  onClose: () => void
  onSaved: () => void
  /** Pre-select an instructor when opening from their detail panel */
  defaultInstructorId?: string
  /** If set: edit-mode for an existing movement. Only 'korrektur' or 'übertrag' allowed. */
  movementId?: string | null
}

const inputStyle = {
  padding: '8px 10px',
  borderRadius: 8,
  border: '0.5px solid var(--hairline)',
  background: 'var(--surface-strong)',
  color: 'var(--ink)',
  font: 'inherit',
  fontSize: 13.5,
  width: '100%',
}

export function CorrectionSheet({ open, onClose, onSaved, defaultInstructorId, movementId }: Props) {
  const isEdit = !!movementId
  const [instructors, setInstructors] = useState<Instructor[]>([])
  const [instructorId, setInstructorId] = useState(defaultInstructorId ?? '')
  const [date, setDate] = useState(new Date().toISOString().slice(0, 10))
  const [amount, setAmount] = useState('')
  const [description, setDescription] = useState('')
  const [kind, setKind] = useState<Kind>('korrektur')
  const [saving, setSaving] = useState(false)
  const [deleting, setDeleting] = useState(false)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    if (!open) return
    setError(null)

    // Load instructors list (always)
    supabase
      .from('instructors')
      .select('id, name, padi_level')
      .eq('active', true)
      .order('last_name')
      .order('first_name')
      .then(({ data }) => setInstructors((data ?? []) as Instructor[]))

    if (!movementId) {
      // CREATE mode: reset to defaults
      setInstructorId(defaultInstructorId ?? '')
      setDate(new Date().toISOString().slice(0, 10))
      setAmount('')
      setDescription('')
      setKind('korrektur')
      return
    }

    // EDIT mode: load movement
    supabase
      .from('account_movements')
      .select('id, instructor_id, date, amount_chf, kind, description')
      .eq('id', movementId)
      .single()
      .then(({ data, error: loadErr }) => {
        if (loadErr || !data) {
          setError(loadErr?.message ?? 'Bewegung nicht gefunden.')
          return
        }
        if (data.kind !== 'korrektur' && data.kind !== 'übertrag') {
          setError('Nur Korrektur und Übertrag können bearbeitet werden.')
          return
        }
        setInstructorId(data.instructor_id)
        setDate(data.date)
        setAmount(String(data.amount_chf))
        setDescription(data.description ?? '')
        setKind(data.kind as Kind)
      })
  }, [open, movementId, defaultInstructorId])

  async function save() {
    setSaving(true)
    setError(null)
    const num = Number(amount.replace(',', '.'))
    if (isNaN(num) || num === 0) {
      setError('Betrag muss eine Zahl ungleich 0 sein.')
      setSaving(false)
      return
    }
    if (!description.trim()) {
      setError('Begründung ist Pflicht (für die Audit-Spur).')
      setSaving(false)
      return
    }

    if (isEdit) {
      // UPDATE
      const { error: updErr } = await supabase
        .from('account_movements')
        .update({
          instructor_id: instructorId,
          date,
          amount_chf: num,
          description: description.trim(),
        })
        .eq('id', movementId)
      if (updErr) {
        setError(updErr.message)
        setSaving(false)
        return
      }
    } else {
      // INSERT
      const { error: insErr } = await supabase.from('account_movements').insert({
        instructor_id: instructorId,
        date,
        amount_chf: num,
        kind: 'korrektur',
        description: description.trim(),
      })
      if (insErr) {
        setError(insErr.message)
        setSaving(false)
        return
      }
    }

    setSaving(false)
    onSaved()
    onClose()
  }

  async function remove() {
    if (!movementId) return
    if (!confirm('Diese Buchung wirklich löschen? Diese Aktion ist nicht umkehrbar.')) return
    setDeleting(true)
    setError(null)
    const { error: delErr } = await supabase
      .from('account_movements')
      .delete()
      .eq('id', movementId)
    if (delErr) {
      setError(delErr.message)
      setDeleting(false)
      return
    }
    setDeleting(false)
    onSaved()
    onClose()
  }

  const previewAmount = Number(amount.replace(',', '.'))
  const title = isEdit
    ? (kind === 'übertrag' ? 'Übertrag bearbeiten' : 'Korrektur bearbeiten')
    : 'Saldo-Korrektur'

  return (
    <Sheet open={open} onClose={onClose} title={title}>
      <div style={{ display: 'grid', gap: 14 }}>
        <div className="caption">
          {isEdit ? (
            <>Bearbeitet eine bestehende <code>{kind}</code>-Buchung. Audit-Spur bleibt über das Datum erhalten.</>
          ) : (
            <>Manuelle Buchung außerhalb der Kurs-Vergütung — z.B. Spesen, Guru-Bezug, Bonus.
            Wird im Bewegungs-Journal als <code>korrektur</code> sichtbar.</>
          )}
        </div>

        <div>
          <Label>Person</Label>
          <select
            value={instructorId}
            onChange={(e) => setInstructorId(e.target.value)}
            style={inputStyle}
            disabled={isEdit}
          >
            <option value="">— wählen —</option>
            {instructors.map((i) => (
              <option key={i.id} value={i.id}>{i.name} ({i.padi_level})</option>
            ))}
          </select>
        </div>

        <div>
          <Label>Datum</Label>
          <input
            type="date"
            value={date}
            onChange={(e) => setDate(e.target.value)}
            style={inputStyle}
          />
        </div>

        <div>
          <Label>Betrag CHF (negativ für Abzüge, z.B. Guru-Bezug)</Label>
          <input
            value={amount}
            onChange={(e) => setAmount(e.target.value)}
            placeholder="z.B. 50.00 oder -120.50"
            style={{ ...inputStyle, fontFamily: 'ui-monospace, "SF Mono", Menlo, monospace' }}
          />
          {!isNaN(previewAmount) && previewAmount !== 0 && (
            <div className="caption-2" style={{ marginTop: 4 }}>
              Vorschau: <strong style={{ color: previewAmount < 0 ? '#FF3B30' : 'inherit' }}>{chf(previewAmount)}</strong>
            </div>
          )}
        </div>

        <div>
          <Label>Begründung</Label>
          <input
            value={description}
            onChange={(e) => setDescription(e.target.value)}
            placeholder='z.B. "Guru-Bezug VK-0146302" oder "Reisekosten Tessin"'
            style={inputStyle}
          />
        </div>

        {error && (
          <div className="chip-orange" style={{ padding: 12, borderRadius: 12, display: 'flex', gap: 8, alignItems: 'flex-start', fontSize: 13 }}>
            <Icon name="bell" size={16} /> {error}
          </div>
        )}

        <div style={{ display: 'flex', gap: 8 }}>
          {isEdit && (
            <button
              type="button"
              className="btn-secondary btn"
              onClick={remove}
              disabled={saving || deleting}
              style={{ color: '#FF3B30' }}
            >
              <Icon name="x" size={14} /> {deleting ? 'Lösche…' : 'Löschen'}
            </button>
          )}
          <button className="btn-secondary btn" onClick={onClose}>Abbrechen</button>
          <button
            className="btn"
            onClick={save}
            disabled={saving || deleting || !instructorId || !amount || !description.trim()}
            style={{ flex: 1 }}
          >
            {saving ? 'Speichere…' : (isEdit ? 'Speichern' : 'Korrektur buchen')}
          </button>
        </div>
      </div>
    </Sheet>
  )
}

function Label({ children }: { children: string }) {
  return <div className="caption-2" style={{ marginBottom: 4 }}>{children.toUpperCase()}</div>
}
