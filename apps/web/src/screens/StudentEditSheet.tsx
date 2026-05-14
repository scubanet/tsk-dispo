import { useEffect, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { Sheet } from '@/components/Sheet'
import { Icon } from '@/components/Icon'
import { supabase } from '@/lib/supabase'
import { getContactWithSidecars, listRelationships } from '@/lib/contactQueries'

interface Form {
  // Stamm
  first_name: string
  last_name: string
  email: string
  phone: string
  birthday: string
  level: string
  notes: string

  // CD: Adresse
  address: string
  postal_code: string
  city: string
  country: string
  photo_url: string

  // CD: CRM
  pipeline_stage: string
  lead_source: string
  tags: string             // CSV
  languages: string[]      // selected codes
  organization_id: string  // '' = none
  organization_role: string
  is_student: boolean
  is_candidate: boolean
}

const LEVELS = [
  'Anfänger',
  'Scuba Diver',
  'OWD',
  'AOWD',
  'Rescue Diver',
  'Master Scuba Diver',
  'DM',
  'AI',
  'OWSI',
  'MSDT',
  'IDC Staff',
  'MI',
  'CD',
] as const

const STAGE_CODES = ['none', 'lead', 'qualified', 'opportunity', 'candidate', 'lost'] as const

const LANGUAGES = [
  { code: 'de',  label: 'De' },
  { code: 'en',  label: 'En' },
  { code: 'fr',  label: 'Fr' },
  { code: 'it',  label: 'It' },
  { code: 'sp',  label: 'Sp' },
  { code: 'tag', label: 'Tag' },
]

interface Org { id: string; name: string }

interface Props {
  open: boolean
  onClose: () => void
  onSaved: (newId?: string) => void
  /** When set, edits an existing student. Otherwise creates new. */
  studentId?: string | null
  /** Wenn true, werden CD-Felder (Adresse, CRM, Pipeline, Org, is_candidate) eingeblendet. */
  showCdFields?: boolean
  /** Beim Anlegen: is_candidate per default auf true setzen (z.B. wenn aus Kandidaten-View geöffnet). */
  defaultIsCandidate?: boolean
  /** Beim Anlegen: pipeline_stage per default. */
  defaultPipelineStage?: string
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

const EMPTY: Form = {
  first_name: '',
  last_name: '',
  email: '',
  phone: '',
  birthday: '',
  level: 'Anfänger',
  notes: '',

  address: '',
  postal_code: '',
  city: '',
  country: '',
  photo_url: '',

  pipeline_stage: 'none',
  lead_source: '',
  tags: '',
  languages: [],
  organization_id: '',
  organization_role: '',
  is_student: true,
  is_candidate: false,
}

export function StudentEditSheet({
  open,
  onClose,
  onSaved,
  studentId,
  showCdFields = false,
  defaultIsCandidate = false,
  defaultPipelineStage,
}: Props) {
  const { t } = useTranslation()
  const isEdit = !!studentId
  const STAGES = STAGE_CODES.map((code) => ({ code, label: t(`student_edit.stage_${code}`) }))
  const [form, setForm] = useState<Form>(EMPTY)
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [orgs, setOrgs] = useState<Org[]>([])

  useEffect(() => {
    if (!open) return
    setError(null)
    if (showCdFields) {
      supabase
        .from('contacts')
        .select('id, display_name, legal_name, trading_name')
        .eq('kind', 'organization')
        .is('archived_at', null)
        .order('display_name')
        .then(({ data }) => {
          const rows = (data ?? []).map((o: { id: string; display_name: string | null; legal_name: string | null; trading_name: string | null }) => ({
            id: o.id,
            name: o.display_name ?? o.trading_name ?? o.legal_name ?? '(unnamed)',
          }))
          setOrgs(rows)
        })
    }
    if (studentId) {
      void (async () => {
        const cws = await getContactWithSidecars(studentId)
        if (!cws) return
        const phones = (cws.phones as Array<{ e164?: string; primary?: boolean }> | null) ?? []
        const primaryPhone = phones.find((p) => p.primary)?.e164 ?? phones[0]?.e164 ?? ''
        const addresses = (cws.addresses as Array<{
          street?: string; postal_code?: string; city?: string; country?: string; primary?: boolean
        }> | null) ?? []
        const primaryAddr = addresses.find((a) => a.primary) ?? addresses[0]

        let orgId = ''
        if (showCdFields) {
          const rels = await listRelationships(studentId)
          const worksAt = rels.find(
            (r) => r.kind === 'works_at' && r.from_contact_id === studentId,
          )
          orgId = worksAt?.to_contact_id ?? ''
        }

        setForm({
          first_name: cws.first_name ?? '',
          last_name:  cws.last_name === '-' ? '' : (cws.last_name ?? ''),
          email:      cws.primary_email ?? '',
          phone:      primaryPhone,
          birthday:   cws.birth_date ?? '',
          level:      cws.student?.level ?? 'Anfänger',
          notes:      cws.notes ?? '',

          address:     primaryAddr?.street      ?? '',
          postal_code: primaryAddr?.postal_code ?? '',
          city:        primaryAddr?.city        ?? '',
          country:     primaryAddr?.country     ?? '',
          photo_url:   cws.student?.photo_url   ?? '',

          pipeline_stage:    cws.student?.pipeline_stage    ?? 'none',
          lead_source:       cws.student?.lead_source       ?? '',
          tags:              (cws.tags ?? []).join(', '),
          languages:         cws.languages ?? [],
          organization_id:   orgId,
          organization_role: cws.student?.organization_role ?? '',
          is_student:        (cws.roles ?? []).includes('student'),
          is_candidate:      cws.student?.is_candidate ?? false,
        })
      })()
    } else {
      setForm({
        ...EMPTY,
        is_candidate: defaultIsCandidate,
        pipeline_stage: defaultPipelineStage ?? EMPTY.pipeline_stage,
      })
    }
  }, [open, studentId, showCdFields, defaultIsCandidate, defaultPipelineStage])

  function set<K extends keyof Form>(k: K, v: Form[K]) {
    setForm((prev) => ({ ...prev, [k]: v }))
  }

  function csvToArray(s: string): string[] {
    return s.split(',').map((x) => x.trim()).filter(Boolean)
  }

  async function save() {
    if (!form.first_name.trim()) return
    setSaving(true)
    setError(null)

    const contactPayload: Record<string, unknown> = {
      first_name: form.first_name.trim(),
      last_name:  form.last_name.trim() || null,
      primary_email: form.email.trim() || null,
      phone:      form.phone.trim() || null,
      birthday:   form.birthday || null,
      notes:      form.notes.trim() || null,
      is_student: showCdFields ? form.is_student : true,
      is_candidate: showCdFields ? form.is_candidate : false,
    }

    if (showCdFields) {
      contactPayload.address = {
        street:      form.address.trim(),
        postal_code: form.postal_code.trim(),
        city:        form.city.trim(),
        country:     form.country.trim(),
      }
      contactPayload.tags = csvToArray(form.tags)
      contactPayload.languages = form.languages
    }

    const studentPayload: Record<string, unknown> = {
      pipeline_stage:    showCdFields ? form.pipeline_stage : 'none',
      lead_source:       showCdFields ? form.lead_source.trim() : '',
      is_candidate:      showCdFields ? form.is_candidate : false,
      level:             form.level || 'Anfänger',
      photo_url:         showCdFields ? (form.photo_url.trim() || null) : null,
      organization_role: showCdFields ? (form.organization_role.trim() || null) : null,
    }

    const { data, error: rpcErr } = await supabase.rpc('student_upsert', {
      p_contact_id: studentId ?? null,
      p_contact:    contactPayload,
      p_student:    studentPayload,
      p_org_id:     showCdFields && form.organization_id ? form.organization_id : null,
    })

    if (rpcErr) { setError(rpcErr.message); setSaving(false); return }
    setSaving(false)
    onSaved(data as string)
    onClose()
  }

  async function deleteStudent() {
    if (!isEdit) return
    if (!confirm(t('student_edit.confirm_delete'))) return
    setSaving(true)
    // CASCADE auf contacts.id räumt contact_student + contact_relationships
    // automatisch auf (definiert in 0079).
    const { error: delErr } = await supabase.from('contacts').delete().eq('id', studentId!)
    setSaving(false)
    if (delErr) { setError(delErr.message); return }
    onSaved()
    onClose()
  }

  return (
    <Sheet open={open} onClose={onClose} title={isEdit ? t('student_edit.title_edit') : t('student_edit.title_new')} width={showCdFields ? 600 : 520}>
      <div style={{ display: 'grid', gap: 14 }}>
        <Section title={t('student_edit.section_master')}>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
            <Field label={t('student_edit.label_first_name')}>
              <input value={form.first_name} onChange={(e) => set('first_name', e.target.value)} style={inputStyle} />
            </Field>
            <Field label={t('student_edit.label_last_name')}>
              <input value={form.last_name} onChange={(e) => set('last_name', e.target.value)} style={inputStyle} />
            </Field>
          </div>

          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
            <Field label={t('student_edit.label_email')}>
              <input type="email" value={form.email} onChange={(e) => set('email', e.target.value)} placeholder="name@example.ch" style={inputStyle} />
            </Field>
            <Field label={t('student_edit.label_phone')}>
              <input value={form.phone} onChange={(e) => set('phone', e.target.value)} placeholder="+41 …" style={inputStyle} />
            </Field>
          </div>

          <Field label={t('student_edit.label_birthday')}>
            <input type="date" value={form.birthday} onChange={(e) => set('birthday', e.target.value)} style={inputStyle} />
          </Field>

          <Field label={t('student_edit.label_level')}>
            <select value={form.level} onChange={(e) => set('level', e.target.value)} style={inputStyle}>
              {LEVELS.map((l) => <option key={l} value={l}>{l}</option>)}
            </select>
            <div className="caption-2" style={{ marginTop: 4 }}>
              {t('student_edit.level_hint')}
            </div>
          </Field>

          <Field label={t('student_edit.label_notes')}>
            <textarea
              value={form.notes}
              onChange={(e) => set('notes', e.target.value)}
              rows={3}
              style={{ ...inputStyle, resize: 'vertical' }}
            />
          </Field>

        </Section>

        {showCdFields && (
          <>
            <Section title={t('student_edit.section_address')}>
              <Field label={t('student_edit.label_street')}>
                <input value={form.address} onChange={(e) => set('address', e.target.value)} style={inputStyle} />
              </Field>
              <div style={{ display: 'grid', gridTemplateColumns: '120px 1fr', gap: 12 }}>
                <Field label={t('student_edit.label_zip')}>
                  <input value={form.postal_code} onChange={(e) => set('postal_code', e.target.value)} style={inputStyle} />
                </Field>
                <Field label={t('student_edit.label_city')}>
                  <input value={form.city} onChange={(e) => set('city', e.target.value)} style={inputStyle} />
                </Field>
              </div>
              <Field label={t('student_edit.label_country')}>
                <input value={form.country} onChange={(e) => set('country', e.target.value)} style={inputStyle} />
              </Field>
              <Field label={t('student_edit.label_photo_url')}>
                <input value={form.photo_url} onChange={(e) => set('photo_url', e.target.value)} placeholder="https://…" style={inputStyle} />
              </Field>
            </Section>

            <Section title={t('student_edit.section_crm')}>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
                <Field label={t('student_edit.label_pipeline_stage')}>
                  <select value={form.pipeline_stage} onChange={(e) => set('pipeline_stage', e.target.value)} style={inputStyle}>
                    {STAGES.map((s) => <option key={s.code} value={s.code}>{s.label}</option>)}
                  </select>
                </Field>
                <Field label={t('student_edit.label_lead_source')}>
                  <input value={form.lead_source} onChange={(e) => set('lead_source', e.target.value)} placeholder={t('student_edit.lead_source_placeholder')} style={inputStyle} />
                </Field>
              </div>

              <Field label={t('student_edit.label_tags')}>
                <input value={form.tags} onChange={(e) => set('tags', e.target.value)} placeholder={t('student_edit.tags_placeholder')} style={inputStyle} />
              </Field>

              <Field label={t('student_edit.label_languages')}>
                <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
                  {LANGUAGES.map((l) => {
                    const checked = form.languages.includes(l.code)
                    return (
                      <label
                        key={l.code}
                        style={{
                          display: 'inline-flex',
                          alignItems: 'center',
                          gap: 6,
                          padding: '6px 12px',
                          borderRadius: 999,
                          border: '0.5px solid var(--hairline)',
                          background: checked ? 'rgba(88,86,214,.20)' : 'transparent',
                          cursor: 'pointer',
                          userSelect: 'none',
                          fontSize: 12.5,
                          fontWeight: checked ? 600 : 400,
                        }}
                      >
                        <input
                          type="checkbox"
                          checked={checked}
                          onChange={(e) => {
                            const next = e.target.checked
                              ? [...form.languages, l.code]
                              : form.languages.filter((x) => x !== l.code)
                            set('languages', next)
                          }}
                          style={{ cursor: 'pointer' }}
                        />
                        {l.label}
                      </label>
                    )
                  })}
                </div>
              </Field>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
                <Field label={t('student_edit.label_organization')}>
                  <select value={form.organization_id} onChange={(e) => set('organization_id', e.target.value)} style={inputStyle}>
                    <option value="">— {t('student_edit.org_none')} —</option>
                    {orgs.map((o) => <option key={o.id} value={o.id}>{o.name}</option>)}
                  </select>
                </Field>
                <Field label={t('student_edit.label_org_role')}>
                  <input value={form.organization_role} onChange={(e) => set('organization_role', e.target.value)} placeholder={t('student_edit.org_role_placeholder')} style={inputStyle} />
                </Field>
              </div>

              <div style={{ display: 'flex', gap: 8, alignItems: 'center', padding: '8px 10px', borderRadius: 8, background: form.is_student ? 'rgba(0,122,255,.12)' : 'transparent', border: '0.5px solid var(--hairline)' }}>
                <input
                  id="is_student"
                  type="checkbox"
                  checked={form.is_student}
                  onChange={(e) => set('is_student', e.target.checked)}
                />
                <label htmlFor="is_student" style={{ fontWeight: 600 }}>{t('student_edit.is_student')}</label>
                <span className="caption" style={{ marginLeft: 'auto' }}>{t('student_edit.is_student_hint')}</span>
              </div>

              <div style={{ display: 'flex', gap: 8, alignItems: 'center', padding: '8px 10px', borderRadius: 8, background: form.is_candidate ? 'rgba(52,199,89,.12)' : 'transparent', border: '0.5px solid var(--hairline)' }}>
                <input
                  id="is_candidate"
                  type="checkbox"
                  checked={form.is_candidate}
                  onChange={(e) => set('is_candidate', e.target.checked)}
                />
                <label htmlFor="is_candidate" style={{ fontWeight: 600 }}>{t('student_edit.is_candidate')}</label>
                <span className="caption" style={{ marginLeft: 'auto' }}>
                  {t('student_edit.is_candidate_hint')}
                </span>
              </div>
            </Section>
          </>
        )}

        {error && <div className="chip chip-red">{error}</div>}

        <div style={{ display: 'flex', gap: 8, marginTop: 8 }}>
          {isEdit && (
            <button
              className="btn-secondary btn"
              onClick={deleteStudent}
              disabled={saving}
              style={{ color: '#FF3B30' }}
            >
              <Icon name="x" size={12} /> {t('common.delete')}
            </button>
          )}
          <button className="btn-secondary btn" onClick={onClose}>{t('common.cancel')}</button>
          <button
            className="btn"
            onClick={save}
            disabled={saving || !form.first_name.trim()}
            style={{ flex: 1 }}
          >
            {saving ? t('common.saving') : isEdit ? t('common.save') : t('course_edit.create')}
          </button>
        </div>
      </div>
    </Sheet>
  )
}

function Section({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div style={{ display: 'grid', gap: 12 }}>
      <div className="caption-2" style={{ marginTop: 4, fontSize: 11, opacity: 0.6, letterSpacing: '.08em' }}>
        {title.toUpperCase()}
      </div>
      {children}
    </div>
  )
}

function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div>
      <Label>{label}</Label>
      {children}
    </div>
  )
}

function Label({ children }: { children: string }) {
  return <div className="caption-2" style={{ marginBottom: 4 }}>{children.toUpperCase()}</div>
}
