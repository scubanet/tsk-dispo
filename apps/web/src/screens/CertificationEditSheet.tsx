import { useEffect, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { CHDateField } from '@/components/CHFields'
import { Sheet } from '@/components/Sheet'
import { Icon } from '@/components/Icon'
import type { StudentCertification } from '@/lib/queries'
import { useSaveCertification, useDeleteCertification } from '@/hooks/useCertificationEdit'

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
  const { t } = useTranslation()
  const isEdit = !!existing
  const saveMutation = useSaveCertification()
  const deleteMutation = useDeleteCertification()
  const saving = saveMutation.isPending || deleteMutation.isPending

  const [certification, setCertification] = useState('')
  const [issuedDate, setIssuedDate] = useState('')
  const [issuedBy, setIssuedBy] = useState('PADI')
  const [certificateNr, setCertificateNr] = useState('')
  const [notes, setNotes] = useState('')
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
    setError(null)
    const input = {
      student_id: studentId,
      certification: certification.trim(),
      issued_date: issuedDate || null,
      issued_by: issuedBy.trim() || null,
      certificate_nr: certificateNr.trim() || null,
      notes: notes.trim() || null,
    }
    try {
      await saveMutation.mutateAsync({
        certificationId: existing?.id ?? null,
        input,
      })
      onSaved()
      onClose()
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : t('common.error'))
    }
  }

  async function deleteCert() {
    if (!existing) return
    if (!confirm(t('cert_edit.confirm_delete', { name: existing.certification }))) return
    setError(null)
    try {
      await deleteMutation.mutateAsync({ certificationId: existing.id, studentId })
      onSaved()
      onClose()
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : t('common.error'))
    }
  }

  return (
    <Sheet open={open} onClose={onClose} title={isEdit ? t('cert_edit.title_edit') : t('cert_edit.title_new')} width={520}>
      <div style={{ display: 'grid', gap: 14 }}>
        <div className="caption">
          {t('cert_edit.intro')}
        </div>

        <div>
          <Label>{t('cert_edit.label_certification')}</Label>
          <input
            value={certification}
            onChange={(e) => setCertification(e.target.value)}
            placeholder={t('cert_edit.cert_placeholder')}
            list="common-certs"
            style={inputStyle}
          />
          <datalist id="common-certs">
            {COMMON_CERTS.map((c) => <option key={c} value={c} />)}
          </datalist>
        </div>

        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 'var(--space-3)' }}>
          <div>
            <Label>{t('cert_edit.label_issued_date')}</Label>
            <CHDateField
              value={issuedDate}
              onChange={setIssuedDate}
              style={inputStyle}
            />
          </div>
          <div>
            <Label>{t('cert_edit.label_issued_by')}</Label>
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
          <Label>{t('cert_edit.label_cert_nr')}</Label>
          <input
            value={certificateNr}
            onChange={(e) => setCertificateNr(e.target.value)}
            placeholder={t('cert_edit.cert_nr_placeholder')}
            style={inputStyle}
          />
        </div>

        <div>
          <Label>{t('cert_edit.label_notes')}</Label>
          <input
            value={notes}
            onChange={(e) => setNotes(e.target.value)}
            placeholder={t('student_edit.placeholder_optional')}
            style={inputStyle}
          />
        </div>

        {error && <div className="chip chip-red">{error}</div>}

        <div style={{ display: 'flex', gap: 'var(--space-2)' }}>
          {isEdit && (
            <button
              className="btn-danger btn"
              onClick={deleteCert}
              disabled={saving}
            >
              <Icon name="x" size={12} /> {t('common.delete')}
            </button>
          )}
          <button className="btn-secondary btn" onClick={onClose}>{t('common.cancel')}</button>
          <button
            className="btn"
            onClick={save}
            disabled={saving || !certification.trim()}
            style={{ flex: 1 }}
          >
            {saving ? t('common.saving') : isEdit ? t('common.save') : t('cert_edit.capture')}
          </button>
        </div>
      </div>
    </Sheet>
  )
}

function Label({ children }: { children: string }) {
  return <div className="caption-2" style={{ marginBottom: 'var(--space-1)' }}>{children.toUpperCase()}</div>
}
