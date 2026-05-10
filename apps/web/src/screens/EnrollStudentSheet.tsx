import { useEffect, useMemo, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { Sheet } from '@/components/Sheet'
import { Icon } from '@/components/Icon'
import { supabase } from '@/lib/supabase'
import { fetchStudents, type Student } from '@/lib/queries'
import { listActiveInstructors } from '@/lib/contactQueries'

type Status = 'enrolled' | 'certified' | 'dropped'

interface ExistingParticipation {
  id: string
  student_id: string
  status: Status
  certificate_nr: string | null
  notes: string | null
  certified_by_instructor_id?: string | null
  certified_on?: string | null
}

interface InstructorOption {
  id: string
  name: string
  active: boolean
}

interface Props {
  open: boolean
  onClose: () => void
  onSaved: () => void
  courseId: string
  /** When set: edit existing participation. Else: enroll new student. */
  existingParticipation?: ExistingParticipation | null
  /** Students already enrolled (so we can hide them in the picker) */
  alreadyEnrolledStudentIds?: string[]
  /** Open the new-student create flow inline */
  onNewStudent?: () => void
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

export function EnrollStudentSheet({
  open, onClose, onSaved, courseId, existingParticipation, alreadyEnrolledStudentIds = [],
  onNewStudent,
}: Props) {
  const { t } = useTranslation()
  const STATUSES: { value: Status; label: string }[] = [
    { value: 'enrolled',  label: t('course_detail.status_enrolled') },
    { value: 'certified', label: t('course_detail.status_certified') },
    { value: 'dropped',   label: t('course_detail.status_dropped') },
  ]
  const isEdit = !!existingParticipation

  const [students, setStudents] = useState<Student[]>([])
  const [instructors, setInstructors] = useState<InstructorOption[]>([])
  const [studentId, setStudentId] = useState('')
  const [status, setStatus] = useState<Status>('enrolled')
  const [certNr, setCertNr] = useState('')
  const [certifiedById, setCertifiedById] = useState('')
  const [certifiedOn, setCertifiedOn] = useState('')
  const [notes, setNotes] = useState('')
  const [search, setSearch] = useState('')
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    if (!open) return
    setError(null)
    fetchStudents().then(setStudents)
    listActiveInstructors()
      .then((rows) => setInstructors(rows.map(({ id, name, active }) => ({ id, name, active }))))
      .catch((err) => console.error('[enroll-student] load instructors failed', err))
    if (existingParticipation) {
      setStudentId(existingParticipation.student_id)
      setStatus(existingParticipation.status)
      setCertNr(existingParticipation.certificate_nr ?? '')
      setCertifiedById(existingParticipation.certified_by_instructor_id ?? '')
      setCertifiedOn(existingParticipation.certified_on ?? '')
      setNotes(existingParticipation.notes ?? '')
    } else {
      setStudentId('')
      setStatus('enrolled')
      setCertNr('')
      setCertifiedById('')
      setCertifiedOn('')
      setNotes('')
      setSearch('')
    }
  }, [open, existingParticipation])

  // Wenn Status auf 'certified' wechselt und kein Datum gesetzt → heute als Default
  useEffect(() => {
    if (status === 'certified' && !certifiedOn) {
      setCertifiedOn(new Date().toISOString().slice(0, 10))
    }
  }, [status, certifiedOn])

  const filteredStudents = useMemo(() => {
    const enrolled = new Set(alreadyEnrolledStudentIds)
    return students
      .filter((s) => s.active)
      .filter((s) => isEdit || !enrolled.has(s.id))
      .filter((s) => {
        if (!search) return true
        const q = search.toLowerCase()
        return s.name.toLowerCase().includes(q) ||
               s.email?.toLowerCase().includes(q) ||
               s.padi_nr?.toLowerCase().includes(q)
      })
      .slice(0, 50)
  }, [students, search, alreadyEnrolledStudentIds, isEdit])

  async function save() {
    if (!studentId) return
    setSaving(true)
    setError(null)
    const payload = {
      course_id: courseId,
      student_id: studentId,
      status,
      certificate_nr: certNr.trim() || null,
      notes: notes.trim() || null,
      // Bei 'certified': zertifizierender Instructor + Datum mitspeichern.
      // Bei anderen Status auf NULL setzen damit alte Einträge konsistent sind.
      certified_by_instructor_id: status === 'certified' ? (certifiedById || null) : null,
      certified_on: status === 'certified' ? (certifiedOn || null) : null,
    }
    if (isEdit) {
      const { error: updErr } = await supabase
        .from('course_participants')
        .update(payload)
        .eq('id', existingParticipation!.id)
      if (updErr) { setError(updErr.message); setSaving(false); return }
    } else {
      const { error: insErr } = await supabase
        .from('course_participants')
        .insert(payload)
      if (insErr) { setError(insErr.message); setSaving(false); return }
    }
    setSaving(false)
    onSaved()
    onClose()
  }

  async function unenroll() {
    if (!isEdit) return
    if (!confirm(t('enroll.confirm_unenroll'))) return
    setSaving(true)
    const { error: delErr } = await supabase
      .from('course_participants')
      .delete()
      .eq('id', existingParticipation!.id)
    setSaving(false)
    if (delErr) { setError(delErr.message); return }
    onSaved()
    onClose()
  }

  const selectedStudent = students.find((s) => s.id === studentId)

  return (
    <Sheet open={open} onClose={onClose} title={isEdit ? t('enroll.title_edit') : t('enroll.title_new')} width={520}>
      <div style={{ display: 'grid', gap: 14 }}>
        {!isEdit && (
          <>
            <div>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 4 }}>
                <Label>{t('enroll.search_student')}</Label>
                {onNewStudent && (
                  <button type="button" className="btn-ghost btn" onClick={onNewStudent} style={{ height: 24, padding: '0 8px' }}>
                    <Icon name="plus" size={12} /> {t('enroll.new_student')}
                  </button>
                )}
              </div>
              <input
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                placeholder={t('people.search_placeholder')}
                style={inputStyle}
              />
            </div>

            <div style={{ display: 'grid', gap: 4, maxHeight: 240, overflow: 'auto' }}>
              {filteredStudents.length === 0 ? (
                <div className="caption">{t('courses.no_matches')}.</div>
              ) : (
                filteredStudents.map((s) => (
                  <button
                    key={s.id}
                    type="button"
                    onClick={() => setStudentId(s.id)}
                    style={{
                      textAlign: 'left',
                      padding: '8px 10px',
                      borderRadius: 8,
                      border: 0,
                      cursor: 'pointer',
                      background: studentId === s.id ? 'var(--accent-soft)' : 'rgba(120,120,128,.08)',
                      color: studentId === s.id ? 'var(--accent)' : 'var(--ink)',
                      fontWeight: studentId === s.id ? 600 : 400,
                    }}
                  >
                    <div>{s.name}</div>
                    <div className="caption-2">
                      {[s.email, s.phone, s.padi_nr].filter(Boolean).join(' · ') || '—'}
                    </div>
                  </button>
                ))
              )}
            </div>
          </>
        )}

        {isEdit && selectedStudent && (
          <div className="glass-thin" style={{ padding: 12, borderRadius: 12 }}>
            <div style={{ fontWeight: 500 }}>{selectedStudent.name}</div>
            <div className="caption">
              {[selectedStudent.email, selectedStudent.phone, selectedStudent.padi_nr].filter(Boolean).join(' · ') || '—'}
            </div>
          </div>
        )}

        <div>
          <Label>{t('course_edit.label_status')}</Label>
          <div className="seg">
            {STATUSES.map((s) => (
              <button
                key={s.value}
                type="button"
                className={status === s.value ? 'active' : undefined}
                onClick={() => setStatus(s.value)}
              >
                {s.label}
              </button>
            ))}
          </div>
        </div>

        {status === 'certified' && (
          <>
            <div>
              <Label>{t('enroll.label_padi_cert_nr')}</Label>
              <input
                value={certNr}
                onChange={(e) => setCertNr(e.target.value)}
                placeholder="e.g. PADI 1234567890"
                style={inputStyle}
              />
            </div>

            <div style={{ display: 'grid', gridTemplateColumns: '1fr 160px', gap: 12 }}>
              <div>
                <Label>{t('enroll.label_certifying_instructor')}</Label>
                <select
                  value={certifiedById}
                  onChange={(e) => setCertifiedById(e.target.value)}
                  style={inputStyle}
                >
                  <option value="">— {t('enroll.please_choose')} —</option>
                  {instructors.map((i) => (
                    <option key={i.id} value={i.id}>{i.name}</option>
                  ))}
                </select>
              </div>
              <div>
                <Label>{t('enroll.label_certified_on')}</Label>
                <input
                  type="date"
                  value={certifiedOn}
                  onChange={(e) => setCertifiedOn(e.target.value)}
                  style={inputStyle}
                />
              </div>
            </div>
            <div className="caption-2" style={{ marginTop: -8 }}>
              {t('enroll.cert_stats_hint')}
            </div>
          </>
        )}

        <div>
          <Label>{t('enroll.label_notes')}</Label>
          <textarea
            value={notes}
            onChange={(e) => setNotes(e.target.value)}
            rows={2}
            style={{ ...inputStyle, resize: 'vertical' }}
          />
        </div>

        {error && <div className="chip chip-red">{error}</div>}

        <div style={{ display: 'flex', gap: 8, marginTop: 8 }}>
          {isEdit && (
            <button
              className="btn-secondary btn"
              onClick={unenroll}
              disabled={saving}
              style={{ color: '#FF3B30' }}
            >
              <Icon name="x" size={12} /> {t('assignment_edit.remove')}
            </button>
          )}
          <button className="btn-secondary btn" onClick={onClose}>{t('common.cancel')}</button>
          <button
            className="btn"
            onClick={save}
            disabled={saving || !studentId}
            style={{ flex: 1 }}
          >
            {saving ? t('common.saving') : isEdit ? t('common.save') : t('enroll.enroll')}
          </button>
        </div>
      </div>
    </Sheet>
  )
}

function Label({ children }: { children: string }) {
  return <div className="caption-2" style={{ marginBottom: 4 }}>{children.toUpperCase()}</div>
}
