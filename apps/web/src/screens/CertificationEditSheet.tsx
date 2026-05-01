import { useEffect, useState } from 'react'
import { Sheet } from '@/components/Sheet'
import { Icon } from '@/components/Icon'
import { supabase } from '@/lib/supabase'
import type { StudentCertification } from '@/lib/queries'

interface Props {
  open: boolean
  onClose: () => void
  onSaved: () => void
  studentId: string
  existing?: StudentCertification | null
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

const COMMON_CERTS = [
  'Scuba Diver',
  'OWD — Open Water Diver',
  'AOWD — Advanced Open Water Diver',
  'Rescue Diver',
  'Master Scuba Diver',
  'Divemaster',
  'EFR — Emergency First Response',
  'Nitrox / EAN',
  'Deep Diver',
  'Wreck Diver',
  'Night Diver',
  'Dry Suit',
  'Sidemount',
  'Tec40',
  'Tec45',
  'Tec50',
]

const COMMON_AGENCIES = ['PADI', 'SSI', 'CMAS', 'NAUI', 'TDI', 'SDI', 'TSK ZRH']

export function CertificationEditSheet({ open, onClose, onSaved, studentId, existing }: Props) {
  const isEdit = !!existing
  const [certification, setCertification] = useState('')
  const [issuedDate, setIssuedDate] = useState('')
  const [issuedBy, setIssuedBy] = useState('PADI')
  const [certificateNr, setCertificateNr] = useState('')
  const [notes, setNotes] = useState('')
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    if (!open) return
    setError(null)
    if (existing) {
      setCertification(existing.certification)
      setIssuedDate(existing.issued_date ?? '')
      setIssuedBy(existing.issued_by ?? '')
      setCertificateNr(existing.certificate_nr ?? '')
      setNotes(existing.notes ?? '')
    } else {
      setCertification('')
      setIssuedDate('')
      setIssuedBy('PADI')
      setCertificateNr('')
      setNotes('')
    }
  }, [open, existing])

  async function save() {
    if (!certification.trim()) return
    setSaving(true)
    setError(null)
    const payload = {
      student_id: studentId,
      certification: certification.trim(),
      issued_date: issuedDate || null,
      issued_by: issuedBy.trim() || null,
      certificate_nr: certificateNr.trim() || null,
      notes: notes.trim() || null,
    }
    if (isEdit) {
      const { error: updErr } = await supabase
        .from('student_certifications')
        .update(payload)
        .eq('id', existing!.id)
      if (updErr) { setError(updErr.message); setSaving(false); return }
    } else {
      const { error: insErr } = await supabase
        .from('student_certifications')
        .insert(payload)
      if (insErr) { setError(insErr.message); setSaving(false); return }
    }
    setSaving(false)
    onSaved()
    onClose()
  }

  async function deleteCert() {
    if (!isEdit) return
    if (!confirm(`"${existing!.certification}" wirklich löschen?`)) return
    setSaving(true)
    const { error: delErr } = await supabase
      .from('student_certifications')
      .delete()
      .eq('id', existing!.id)
    setSaving(false)
    if (delErr) { setError(delErr.message); return }
    onSaved()
    onClose()
  }

  return (
    <Sheet open={open} onClose={onClose} title={isEdit ? 'Zertifikat bearbeiten' : 'Zertifikat erfassen'} width={520}>
      <div style={{ display: 'grid', gap: 14 }}>
        <div className="caption">
          Hier kannst du auch Zertifikate erfassen, die nicht bei TSK erworben wurden
          (z.B. OWD aus dem Urlaub vor 5 Jahren).
        </div>

        <div>
          <Label>Zertifikat</Label>
          <input
            value={certification}
            onChange={(e) => setCertification(e.target.value)}
            placeholder='z.B. "OWD — Open Water Diver"'
            list="common-certs"
            style={inputStyle}
          />
          <datalist id="common-certs">
            {COMMON_CERTS.map((c) => <option key={c} value={c} />)}
          </datalist>
        </div>

        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
          <div>
            <Label>Ausstelldatum</Label>
            <input
              type="date"
              value={issuedDate}
              onChange={(e) => setIssuedDate(e.target.value)}
              style={inputStyle}
            />
          </div>
          <div>
            <Label>Ausstellende Org</Label>
            <input
              value={issuedBy}
              onChange={(e) => setIssuedBy(e.target.value)}
              placeholder="PADI / SSI / …"
              list="common-agencies"
              style={inputStyle}
            />
            <datalist id="common-agencies">
              {COMMON_AGENCIES.map((a) => <option key={a} value={a} />)}
            </datalist>
          </div>
        </div>

        <div>
          <Label>Zertifikats-Nummer</Label>
          <input
            value={certificateNr}
            onChange={(e) => setCertificateNr(e.target.value)}
            placeholder="optional, z.B. 1234567890"
            style={inputStyle}
          />
        </div>

        <div>
          <Label>Notizen</Label>
          <input
            value={notes}
            onChange={(e) => setNotes(e.target.value)}
            placeholder="optional"
            style={inputStyle}
          />
        </div>

        {error && <div className="chip chip-red">{error}</div>}

        <div style={{ display: 'flex', gap: 8 }}>
          {isEdit && (
            <button
              className="btn-secondary btn"
              onClick={deleteCert}
              disabled={saving}
              style={{ color: '#FF3B30' }}
            >
              <Icon name="x" size={12} /> Löschen
            </button>
          )}
          <button className="btn-secondary btn" onClick={onClose}>Abbrechen</button>
          <button
            className="btn"
            onClick={save}
            disabled={saving || !certification.trim()}
            style={{ flex: 1 }}
          >
            {saving ? 'Speichere…' : isEdit ? 'Speichern' : 'Erfassen'}
          </button>
        </div>
      </div>
    </Sheet>
  )
}

function Label({ children }: { children: string }) {
  return <div className="caption-2" style={{ marginBottom: 4 }}>{children.toUpperCase()}</div>
}
