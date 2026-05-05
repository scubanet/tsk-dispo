import { useEffect, useState } from 'react'
import { Sheet } from '@/components/Sheet'
import { Icon } from '@/components/Icon'
import { supabase } from '@/lib/supabase'

interface Form {
  // Stamm
  first_name: string
  last_name: string
  email: string
  phone: string
  birthday: string
  padi_nr: string
  level: string
  notes: string
  active: boolean

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
  languages: string        // CSV
  organization_id: string  // '' = none
  organization_role: string
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

const STAGES = [
  { code: 'none',        label: 'Kein' },
  { code: 'lead',        label: 'Lead' },
  { code: 'qualified',   label: 'Qualifiziert' },
  { code: 'opportunity', label: 'Opportunity' },
  { code: 'candidate',   label: 'Kandidat' },
  { code: 'lost',        label: 'Verloren' },
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
  padi_nr: '',
  level: 'Anfänger',
  notes: '',
  active: true,

  address: '',
  postal_code: '',
  city: '',
  country: '',
  photo_url: '',

  pipeline_stage: 'none',
  lead_source: '',
  tags: '',
  languages: '',
  organization_id: '',
  organization_role: '',
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
  const isEdit = !!studentId
  const [form, setForm] = useState<Form>(EMPTY)
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [orgs, setOrgs] = useState<Org[]>([])

  useEffect(() => {
    if (!open) return
    setError(null)
    if (showCdFields) {
      supabase.from('organizations').select('id, name').order('name').then(({ data }) => {
        setOrgs((data ?? []) as Org[])
      })
    }
    if (studentId) {
      const cols = [
        'first_name','last_name','name','email','phone','birthday','padi_nr','level','notes','active',
        'address','postal_code','city','country','photo_url',
        'pipeline_stage','lead_source','tags','languages','organization_id','organization_role','is_candidate',
      ].join(',')
      supabase
        .from('students')
        .select(cols)
        .eq('id', studentId)
        .single()
        .then(({ data }) => {
          if (!data) return
          const d = data as any
          // Fallback: legacy Daten ohne first/last → aus name splitten
          const first = d.first_name?.trim() || (d.name ?? '').split(' ')[0] || ''
          const last  = d.last_name?.trim()  || (d.name ?? '').split(' ').slice(1).join(' ') || ''
          setForm({
            first_name: first,
            last_name: last,
            email: d.email ?? '',
            phone: d.phone ?? '',
            birthday: d.birthday ?? '',
            padi_nr: d.padi_nr ?? '',
            level: d.level ?? 'Anfänger',
            notes: d.notes ?? '',
            active: !!d.active,

            address: d.address ?? '',
            postal_code: d.postal_code ?? '',
            city: d.city ?? '',
            country: d.country ?? '',
            photo_url: d.photo_url ?? '',

            pipeline_stage: d.pipeline_stage ?? 'none',
            lead_source: d.lead_source ?? '',
            tags: Array.isArray(d.tags) ? d.tags.join(', ') : '',
            languages: Array.isArray(d.languages) ? d.languages.join(', ') : '',
            organization_id: d.organization_id ?? '',
            organization_role: d.organization_role ?? '',
            is_candidate: !!d.is_candidate,
          })
        })
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
    const base: Record<string, unknown> = {
      first_name: form.first_name.trim(),
      last_name: form.last_name.trim(),
      email: form.email.trim() || null,
      phone: form.phone.trim() || null,
      birthday: form.birthday || null,
      padi_nr: form.padi_nr.trim() || null,
      level: form.level || 'Anfänger',
      notes: form.notes.trim() || null,
      active: form.active,
    }
    // CD-Felder nur senden wenn UI sie geliefert hat — sonst werden sie nicht überschrieben
    if (showCdFields) {
      Object.assign(base, {
        address: form.address.trim(),
        postal_code: form.postal_code.trim(),
        city: form.city.trim(),
        country: form.country.trim(),
        photo_url: form.photo_url.trim() || null,
        pipeline_stage: form.pipeline_stage,
        lead_source: form.lead_source.trim(),
        tags: csvToArray(form.tags),
        languages: csvToArray(form.languages),
        organization_id: form.organization_id || null,
        organization_role: form.organization_role.trim(),
        is_candidate: form.is_candidate,
      })
    }
    if (isEdit) {
      const { error: updErr } = await supabase
        .from('students')
        .update(base)
        .eq('id', studentId!)
      if (updErr) { setError(updErr.message); setSaving(false); return }
      setSaving(false); onSaved(); onClose()
    } else {
      const { data: created, error: insErr } = await supabase
        .from('students')
        .insert(base)
        .select('id')
        .single()
      if (insErr) { setError(insErr.message); setSaving(false); return }
      setSaving(false); onSaved(created?.id); onClose()
    }
  }

  async function deleteStudent() {
    if (!isEdit) return
    if (!confirm('Schüler wirklich löschen? Falls er bereits Kursen zugewiesen ist, wird das Löschen blockiert — markier ihn dann lieber als inaktiv.')) return
    setSaving(true)
    const { error: delErr } = await supabase.from('students').delete().eq('id', studentId!)
    setSaving(false)
    if (delErr) { setError(delErr.message); return }
    onSaved()
    onClose()
  }

  return (
    <Sheet open={open} onClose={onClose} title={isEdit ? 'Schüler bearbeiten' : 'Neuer Schüler'} width={showCdFields ? 600 : 520}>
      <div style={{ display: 'grid', gap: 14 }}>
        <Section title="Stamm">
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
            <Field label="Vorname">
              <input value={form.first_name} onChange={(e) => set('first_name', e.target.value)} style={inputStyle} />
            </Field>
            <Field label="Nachname">
              <input value={form.last_name} onChange={(e) => set('last_name', e.target.value)} style={inputStyle} />
            </Field>
          </div>

          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
            <Field label="Email">
              <input type="email" value={form.email} onChange={(e) => set('email', e.target.value)} placeholder="name@example.ch" style={inputStyle} />
            </Field>
            <Field label="Telefon / WhatsApp">
              <input value={form.phone} onChange={(e) => set('phone', e.target.value)} placeholder="+41 …" style={inputStyle} />
            </Field>
          </div>

          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
            <Field label="Geburtstag">
              <input type="date" value={form.birthday} onChange={(e) => set('birthday', e.target.value)} style={inputStyle} />
            </Field>
            <Field label="PADI-Nr (falls vorhanden)">
              <input value={form.padi_nr} onChange={(e) => set('padi_nr', e.target.value)} placeholder="optional" style={inputStyle} />
            </Field>
          </div>

          <Field label="Aktueller Level">
            <select value={form.level} onChange={(e) => set('level', e.target.value)} style={inputStyle}>
              {LEVELS.map((l) => <option key={l} value={l}>{l}</option>)}
            </select>
            <div className="caption-2" style={{ marginTop: 4 }}>
              Der höchste bisher erreichte Tauchschein-Level. Updaten wenn ein neuer Schein erworben wird.
            </div>
          </Field>

          <Field label="Notizen (medizinisch, Allergien, etc.)">
            <textarea
              value={form.notes}
              onChange={(e) => set('notes', e.target.value)}
              rows={3}
              style={{ ...inputStyle, resize: 'vertical' }}
            />
          </Field>

          <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
            <input
              id="active"
              type="checkbox"
              checked={form.active}
              onChange={(e) => set('active', e.target.checked)}
            />
            <label htmlFor="active">Aktiv (erscheint in Anmelde-Vorschlägen)</label>
          </div>
        </Section>

        {showCdFields && (
          <>
            <Section title="Adresse">
              <Field label="Strasse">
                <input value={form.address} onChange={(e) => set('address', e.target.value)} style={inputStyle} />
              </Field>
              <div style={{ display: 'grid', gridTemplateColumns: '120px 1fr', gap: 12 }}>
                <Field label="PLZ">
                  <input value={form.postal_code} onChange={(e) => set('postal_code', e.target.value)} style={inputStyle} />
                </Field>
                <Field label="Ort">
                  <input value={form.city} onChange={(e) => set('city', e.target.value)} style={inputStyle} />
                </Field>
              </div>
              <Field label="Land">
                <input value={form.country} onChange={(e) => set('country', e.target.value)} style={inputStyle} />
              </Field>
              <Field label="Foto-URL (optional)">
                <input value={form.photo_url} onChange={(e) => set('photo_url', e.target.value)} placeholder="https://…" style={inputStyle} />
              </Field>
            </Section>

            <Section title="CRM">
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
                <Field label="Pipeline-Stage">
                  <select value={form.pipeline_stage} onChange={(e) => set('pipeline_stage', e.target.value)} style={inputStyle}>
                    {STAGES.map((s) => <option key={s.code} value={s.code}>{s.label}</option>)}
                  </select>
                </Field>
                <Field label="Lead-Quelle">
                  <input value={form.lead_source} onChange={(e) => set('lead_source', e.target.value)} placeholder="z.B. Empfehlung, Google, Messe" style={inputStyle} />
                </Field>
              </div>

              <Field label="Tags (Komma-getrennt)">
                <input value={form.tags} onChange={(e) => set('tags', e.target.value)} placeholder="z.B. vegan, photographer, club-member" style={inputStyle} />
              </Field>

              <Field label="Sprachen (Komma-getrennt)">
                <input value={form.languages} onChange={(e) => set('languages', e.target.value)} placeholder="z.B. de, en, it" style={inputStyle} />
              </Field>

              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
                <Field label="Organisation">
                  <select value={form.organization_id} onChange={(e) => set('organization_id', e.target.value)} style={inputStyle}>
                    <option value="">— keine —</option>
                    {orgs.map((o) => <option key={o.id} value={o.id}>{o.name}</option>)}
                  </select>
                </Field>
                <Field label="Rolle in Org">
                  <input value={form.organization_role} onChange={(e) => set('organization_role', e.target.value)} placeholder="z.B. Vorstand, Mitglied" style={inputStyle} />
                </Field>
              </div>

              <div style={{ display: 'flex', gap: 8, alignItems: 'center', padding: '8px 10px', borderRadius: 8, background: form.is_candidate ? 'rgba(52,199,89,.12)' : 'transparent', border: '0.5px solid var(--hairline)' }}>
                <input
                  id="is_candidate"
                  type="checkbox"
                  checked={form.is_candidate}
                  onChange={(e) => set('is_candidate', e.target.checked)}
                />
                <label htmlFor="is_candidate" style={{ fontWeight: 600 }}>Als Kandidat:in markieren</label>
                <span className="caption" style={{ marginLeft: 'auto' }}>
                  erscheint in der CD-Kandidatenliste
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
              <Icon name="x" size={12} /> Löschen
            </button>
          )}
          <button className="btn-secondary btn" onClick={onClose}>Abbrechen</button>
          <button
            className="btn"
            onClick={save}
            disabled={saving || !form.first_name.trim()}
            style={{ flex: 1 }}
          >
            {saving ? 'Speichere…' : isEdit ? 'Speichern' : 'Anlegen'}
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
