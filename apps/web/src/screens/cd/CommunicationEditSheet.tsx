import { useEffect, useMemo, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { Sheet } from '@/components/Sheet'
import { Icon } from '@/components/Icon'
import { useActiveInstructors } from '@/hooks/useActiveInstructors'
import {
  useContactPickerList,
  useContactBasics,
  useCommunicationEntry,
  useSaveCommunicationEntry,
  useDeleteCommunicationEntry,
} from '@/hooks/useCommunicationEdit'
import { waDirectUrl } from '@/lib/whatsapp'
import i18n from '@/i18n'

/**
 * Communication-Channels.
 *
 * Important: many other screens import `CHANNELS` and read the `.label`
 * field (e.g. `CommunicationHubScreen`, `StudentDetailPanel`). To keep
 * those callers working without forcing them to be hooks, we resolve the
 * label via the i18n singleton at access time using a getter.
 */
export const CHANNELS = [
  { code: 'email',    icon: 'tag'      as const, get label() { return i18n.t('comm_edit.channel_email')    } },
  { code: 'phone',    icon: 'users'    as const, get label() { return i18n.t('comm_edit.channel_phone')    } },
  { code: 'whatsapp', icon: 'tag'      as const, get label() { return i18n.t('comm_edit.channel_whatsapp') } },
  { code: 'meeting',  icon: 'calendar' as const, get label() { return i18n.t('comm_edit.channel_meeting')  } },
  { code: 'note',     icon: 'tag'      as const, get label() { return i18n.t('comm_edit.channel_note')     } },
  { code: 'other',    icon: 'tag'      as const, get label() { return i18n.t('comm_edit.channel_other')    } },
]

export const DIRECTIONS = [
  { code: 'outbound', get label() { return i18n.t('comm_hub.outbound') } },
  { code: 'inbound',  get label() { return i18n.t('comm_hub.inbound')  } },
]

interface Form {
  channel: string
  direction: string
  occurred_on: string  // ISO datetime-local
  subject: string
  body: string
  duration_minutes: string
  outcome: string
  created_by: string  // instructor_id; '' = nicht erfasst
}

interface InstructorOption {
  id: string
  name: string
  active: boolean
}

const EMPTY: Form = {
  channel: 'note',
  direction: 'outbound',
  occurred_on: '',
  subject: '',
  body: '',
  duration_minutes: '',
  outcome: '',
  created_by: '',
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

interface Props {
  open: boolean
  onClose: () => void
  onSaved: () => void
  /** Wenn gesetzt: Touchpoint hängt direkt an dieser Person. Sonst Person-Picker im Sheet. */
  contactId?: string | null
  /** When set, edits an existing entry. */
  entryId?: string | null
  /** Default-Assessor (instructor_id) zum Setzen von created_by */
  createdById?: string | null
}

export function CommunicationEditSheet({ open, onClose, onSaved, contactId, entryId, createdById }: Props) {
  const { t } = useTranslation()
  const showPicker = !contactId
  const isEdit = !!entryId
  const [pickedContactId, setPickedContactId] = useState<string>('')
  const [pickerSearch, setPickerSearch] = useState('')
  const [form, setForm] = useState<Form>(EMPTY)
  const [error, setError] = useState<string | null>(null)

  // Data via hooks.
  const { data: people = [] } = useContactPickerList(showPicker && open)
  const { data: instructorRows = [] } = useActiveInstructors()
  const instructors = useMemo<InstructorOption[]>(
    () => instructorRows.map(({ id, name, active }) => ({ id, name, active })),
    [instructorRows],
  )
  const activeContactId = contactId ?? pickedContactId
  const { data: contactInfo = null } = useContactBasics(activeContactId || null)
  const { data: existingEntry } = useCommunicationEntry(open ? entryId : null)
  const saveMutation = useSaveCommunicationEntry()
  const deleteMutation = useDeleteCommunicationEntry()
  const saving = saveMutation.isPending || deleteMutation.isPending

  // Hydrate the form when entering edit-mode / opening sheet. Separate from
  // contact-picker selection so picking a person never resets the form.
  useEffect(() => {
    if (!open) return
    setError(null)
    setPickedContactId('')
    if (!entryId) {
      setForm({ ...EMPTY, occurred_on: nowLocal(), created_by: createdById ?? '' })
      return
    }
    if (!existingEntry) return
    if (showPicker && existingEntry.contact_id) setPickedContactId(existingEntry.contact_id)
    setForm({
      channel: existingEntry.channel ?? 'note',
      direction: existingEntry.direction ?? 'outbound',
      occurred_on: existingEntry.occurred_on ? toLocal(existingEntry.occurred_on) : '',
      subject: existingEntry.subject ?? '',
      body: existingEntry.body ?? '',
      duration_minutes:
        existingEntry.duration_minutes != null ? String(existingEntry.duration_minutes) : '',
      outcome: existingEntry.outcome ?? '',
      created_by: existingEntry.created_by ?? '',
    })
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [open, entryId, contactId, existingEntry])

  function set<K extends keyof Form>(k: K, v: Form[K]) {
    setForm((prev) => ({ ...prev, [k]: v }))
  }

  async function save() {
    const finalContactId = contactId ?? pickedContactId
    if (!finalContactId) {
      setError(t('comm_edit.error_pick_person'))
      return
    }
    setError(null)
    const payload = {
      contact_id: finalContactId,
      channel: form.channel,
      direction: form.direction,
      occurred_on: form.occurred_on ? new Date(form.occurred_on).toISOString() : new Date().toISOString(),
      subject: form.subject.trim() || null,
      body: form.body.trim() || null,
      duration_minutes: form.duration_minutes ? Number(form.duration_minutes) : null,
      outcome: form.outcome.trim() || null,
      created_by: form.created_by || createdById || null,
    }
    try {
      await saveMutation.mutateAsync({ entryId: entryId ?? null, input: payload })
      onSaved()
      onClose()
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : t('common.error'))
    }
  }

  async function deleteEntry() {
    if (!entryId) return
    const finalContactId = contactId ?? pickedContactId
    if (!finalContactId) return
    if (!confirm(t('comm_edit.confirm_delete'))) return
    setError(null)
    try {
      await deleteMutation.mutateAsync({ entryId, contactId: finalContactId })
      onSaved()
      onClose()
    } catch (e: unknown) {
      setError(e instanceof Error ? e.message : t('common.error'))
    }
  }

  const showDuration = form.channel === 'phone' || form.channel === 'meeting'

  // Send-Helpers — öffnen native Apps mit pre-filled Subject/Body und setzen Direction auf outbound
  function sendViaMail() {
    if (!contactInfo?.email) return
    const subject = encodeURIComponent(form.subject || '')
    const body = encodeURIComponent(form.body || '')
    set('direction', 'outbound')
    set('channel', 'email')
    window.location.href = `mailto:${contactInfo.email}?subject=${subject}&body=${body}`
  }
  function sendViaWhatsApp() {
    if (!contactInfo?.phone) return
    const text = [form.subject, form.body].filter(Boolean).join('\n\n')
    set('direction', 'outbound')
    set('channel', 'whatsapp')
    window.open(waDirectUrl(contactInfo.phone, text), '_blank')
  }
  function sendViaIMessage() {
    if (!contactInfo?.phone) return
    const cleanPhone = contactInfo.phone.replace(/[^\d+]/g, '')
    const text = [form.subject, form.body].filter(Boolean).join('\n\n')
    set('direction', 'outbound')
    set('channel', 'phone') // sms fällt unter "Phone"
    // Apple-Format: sms:NUMBER&body=TEXT
    window.location.href = `sms:${cleanPhone}&body=${encodeURIComponent(text)}`
  }

  return (
    <Sheet open={open} onClose={onClose} title={isEdit ? t('comm_edit.title_edit') : t('comm_edit.title_new')} width={520}>
      <div style={{ display: 'grid', gap: 14 }}>
        {showPicker && (
          <Field label={t('assignment_edit.label_person')}>
            <input
              value={pickerSearch}
              onChange={(e) => setPickerSearch(e.target.value)}
              placeholder={t('comm_edit.search_name')}
              style={inputStyle}
            />
            <div style={{ marginTop: 6, maxHeight: 180, overflow: 'auto', display: 'grid', gap: 4 }}>
              {people
                .filter((p) => !pickerSearch || p.name.toLowerCase().includes(pickerSearch.toLowerCase()))
                .slice(0, 30)
                .map((p) => (
                  <button
                    key={p.id}
                    type="button"
                    onClick={() => setPickedContactId(p.id)}
                    style={{
                      textAlign: 'left',
                      padding: '6px 10px',
                      borderRadius: 6,
                      border: 0,
                      cursor: 'pointer',
                      background: pickedContactId === p.id ? 'var(--accent-soft)' : 'rgba(120,120,128,.08)',
                      color: pickedContactId === p.id ? 'var(--accent)' : 'var(--ink)',
                      fontWeight: pickedContactId === p.id ? 600 : 400,
                      fontSize: 13,
                    }}
                  >
                    {p.name}
                    {p.is_candidate && <span style={{ marginLeft: 8, opacity: 0.6, fontSize: 11 }}>· {t('student_edit.stage_candidate')}</span>}
                    {p.is_student && !p.is_candidate && <span style={{ marginLeft: 8, opacity: 0.6, fontSize: 11 }}>· {t('comm_hub.student_badge')}</span>}
                  </button>
                ))}
            </div>
          </Field>
        )}

        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
          <Field label={t('comm_edit.label_channel')}>
            <select value={form.channel} onChange={(e) => set('channel', e.target.value)} style={inputStyle}>
              {CHANNELS.map((c) => <option key={c.code} value={c.code}>{c.label}</option>)}
            </select>
          </Field>
          <Field label={t('comm_edit.label_direction')}>
            <select value={form.direction} onChange={(e) => set('direction', e.target.value)} style={inputStyle}>
              {DIRECTIONS.map((d) => <option key={d.code} value={d.code}>{d.label}</option>)}
            </select>
          </Field>
        </div>

        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
          <Field label={t('comm_edit.label_datetime')}>
            <input
              type="datetime-local"
              value={form.occurred_on}
              onChange={(e) => set('occurred_on', e.target.value)}
              style={inputStyle}
            />
          </Field>
          <Field label={t('comm_edit.label_handler')}>
            <select value={form.created_by} onChange={(e) => set('created_by', e.target.value)} style={inputStyle}>
              <option value="">— {t('course_edit.choose')} —</option>
              {instructors.map((i) => <option key={i.id} value={i.id}>{i.name}</option>)}
            </select>
          </Field>
        </div>

        <Field label={t('comm_edit.label_subject')}>
          <input
            value={form.subject}
            onChange={(e) => set('subject', e.target.value)}
            placeholder={form.channel === 'meeting' ? t('comm_edit.subject_meeting_placeholder') : t('comm_edit.subject_placeholder')}
            style={inputStyle}
          />
        </Field>

        <Field label={t('comm_edit.label_body')}>
          <textarea
            value={form.body}
            onChange={(e) => set('body', e.target.value)}
            rows={4}
            style={{ ...inputStyle, resize: 'vertical' }}
          />
        </Field>

        {showDuration && (
          <Field label={t('comm_edit.label_duration')}>
            <input
              type="number"
              min={0}
              value={form.duration_minutes}
              onChange={(e) => set('duration_minutes', e.target.value)}
              placeholder={t('comm_edit.duration_placeholder')}
              style={{ ...inputStyle, width: 120 }}
            />
          </Field>
        )}

        <Field label={t('comm_edit.label_outcome')}>
          <input
            value={form.outcome}
            onChange={(e) => set('outcome', e.target.value)}
            placeholder={t('comm_edit.outcome_placeholder')}
            style={inputStyle}
          />
        </Field>

        {/* Direkt-Senden über Mail / WhatsApp / iMessage */}
        {contactInfo && (contactInfo.email || contactInfo.phone) && (
          <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', alignItems: 'center', padding: '8px 10px', borderRadius: 10, background: 'rgba(0,122,255,.08)' }}>
            <span className="caption-2" style={{ marginRight: 4 }}>{t('comm_edit.send_label')}:</span>
            {contactInfo.email && (
              <button
                type="button"
                onClick={sendViaMail}
                className="btn-secondary btn"
                style={{ height: 28, padding: '0 12px', fontSize: 12 }}
              >
                ✉ {t('comm_edit.channel_email')}
              </button>
            )}
            {contactInfo.phone && (
              <>
                <button
                  type="button"
                  onClick={sendViaWhatsApp}
                  className="btn-secondary btn"
                  style={{ height: 28, padding: '0 12px', fontSize: 12, background: 'rgba(37,211,102,.18)' }}
                >
                  💬 WhatsApp
                </button>
                <button
                  type="button"
                  onClick={sendViaIMessage}
                  className="btn-secondary btn"
                  style={{ height: 28, padding: '0 12px', fontSize: 12 }}
                >
                  💬 iMessage / SMS
                </button>
              </>
            )}
            <span className="caption-2" style={{ marginLeft: 'auto', opacity: 0.6 }}>
              {t('comm_edit.sets_outbound')}
            </span>
          </div>
        )}

        {error && <div className="chip chip-red">{error}</div>}

        <div style={{ display: 'flex', gap: 8, marginTop: 8 }}>
          {isEdit && (
            <button
              className="btn-secondary btn"
              onClick={deleteEntry}
              disabled={saving}
              style={{ color: '#FF3B30' }}
            >
              <Icon name="x" size={12} /> {t('common.delete')}
            </button>
          )}
          <button className="btn-secondary btn" onClick={onClose}>{t('common.cancel')}</button>
          <button className="btn" onClick={save} disabled={saving} style={{ flex: 1 }}>
            {saving ? t('common.saving') : isEdit ? t('common.save') : t('course_edit.create')}
          </button>
        </div>
      </div>
    </Sheet>
  )
}

function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div>
      <div className="caption-2" style={{ marginBottom: 4 }}>{label.toUpperCase()}</div>
      {children}
    </div>
  )
}

// Helper: ISO → datetime-local Format (yyyy-MM-ddTHH:mm)
function toLocal(iso: string): string {
  const d = new Date(iso)
  const pad = (n: number) => String(n).padStart(2, '0')
  return `${d.getFullYear()}-${pad(d.getMonth()+1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`
}
function nowLocal(): string {
  return toLocal(new Date().toISOString())
}
