import { useEffect, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { Sheet } from '@/components/Sheet'
import { Icon } from '@/components/Icon'
import { supabase } from '@/lib/supabase'

interface Form {
  name: string
  kind: string
  address: string
  postal_code: string
  city: string
  country: string
  email: string
  phone: string
  website: string
  notes: string
  active: boolean
}

const KIND_CODES = ['dive_school', 'partner', 'association', 'company', 'school', 'agency', 'resort', 'other'] as const

const EMPTY: Form = {
  name: '',
  kind: '',
  address: '',
  postal_code: '',
  city: '',
  country: '',
  email: '',
  phone: '',
  website: '',
  notes: '',
  active: true,
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
  onSaved: (newId?: string) => void
  orgId?: string | null
}

export function OrganizationEditSheet({ open, onClose, onSaved, orgId }: Props) {
  const { t } = useTranslation()
  const isEdit = !!orgId
  const KINDS = [
    { code: '', label: `— ${t('enroll.please_choose')} —` },
    ...KIND_CODES.map((code) => ({ code, label: t(`org_edit.kind_${code}`) })),
  ]
  const [form, setForm] = useState<Form>(EMPTY)
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    if (!open) return
    setError(null)
    if (orgId) {
      supabase
        .from('organizations')
        .select('name, kind, address, postal_code, city, country, email, phone, website, notes, active')
        .eq('id', orgId)
        .single()
        .then(({ data }) => {
          if (!data) return
          const d = data as any
          setForm({
            name: d.name ?? '',
            kind: d.kind ?? '',
            address: d.address ?? '',
            postal_code: d.postal_code ?? '',
            city: d.city ?? '',
            country: d.country ?? '',
            email: d.email ?? '',
            phone: d.phone ?? '',
            website: d.website ?? '',
            notes: d.notes ?? '',
            active: !!d.active,
          })
        })
    } else {
      setForm(EMPTY)
    }
  }, [open, orgId])

  function set<K extends keyof Form>(k: K, v: Form[K]) {
    setForm((prev) => ({ ...prev, [k]: v }))
  }

  async function save() {
    if (!form.name.trim()) return
    setSaving(true)
    setError(null)
    const payload = {
      name: form.name.trim(),
      kind: form.kind || null,
      address: form.address.trim() || null,
      postal_code: form.postal_code.trim() || null,
      city: form.city.trim() || null,
      country: form.country.trim() || null,
      email: form.email.trim() || null,
      phone: form.phone.trim() || null,
      website: form.website.trim() || null,
      notes: form.notes.trim() || null,
      active: form.active,
    }
    if (isEdit) {
      const { error: updErr } = await supabase.from('organizations').update(payload).eq('id', orgId!)
      if (updErr) { setError(updErr.message); setSaving(false); return }
      setSaving(false); onSaved(); onClose()
    } else {
      const { data: created, error: insErr } = await supabase
        .from('organizations')
        .insert(payload)
        .select('id')
        .single()
      if (insErr) { setError(insErr.message); setSaving(false); return }
      setSaving(false); onSaved(created?.id); onClose()
    }
  }

  async function deleteOrg() {
    if (!isEdit) return
    if (!confirm(t('org_edit.confirm_delete'))) return
    setSaving(true)
    const { error: delErr } = await supabase.from('organizations').delete().eq('id', orgId!)
    setSaving(false)
    if (delErr) { setError(delErr.message); return }
    onSaved()
    onClose()
  }

  return (
    <Sheet open={open} onClose={onClose} title={isEdit ? t('org_edit.title_edit') : t('org_edit.title_new')} width={520}>
      <div style={{ display: 'grid', gap: 14 }}>
        <Field label={t('org_edit.label_name_required')}>
          <input value={form.name} onChange={(e) => set('name', e.target.value)} style={inputStyle} placeholder={t('org_edit.name_placeholder')} />
        </Field>

        <Field label={t('org_edit.label_kind')}>
          <select value={form.kind} onChange={(e) => set('kind', e.target.value)} style={inputStyle}>
            {KINDS.map((k) => <option key={k.code} value={k.code}>{k.label}</option>)}
          </select>
        </Field>

        <div className="caption-2" style={{ marginTop: 6, opacity: 0.6, letterSpacing: '.08em' }}>
          {t('student_edit.section_address').toUpperCase()}
        </div>

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

        <div className="caption-2" style={{ marginTop: 6, opacity: 0.6, letterSpacing: '.08em' }}>
          {t('org_edit.section_contact').toUpperCase()}
        </div>

        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
          <Field label={t('student_edit.label_email')}>
            <input type="email" value={form.email} onChange={(e) => set('email', e.target.value)} style={inputStyle} placeholder="info@…" />
          </Field>
          <Field label={t('student_detail.field_phone')}>
            <input value={form.phone} onChange={(e) => set('phone', e.target.value)} style={inputStyle} placeholder="+41 …" />
          </Field>
        </div>

        <Field label={t('org_edit.label_website')}>
          <input value={form.website} onChange={(e) => set('website', e.target.value)} style={inputStyle} placeholder="https://…" />
        </Field>

        <Field label={t('student_edit.label_notes').replace(/ \(.*\)/, '')}>
          <textarea
            value={form.notes}
            onChange={(e) => set('notes', e.target.value)}
            rows={3}
            style={{ ...inputStyle, resize: 'vertical' }}
          />
        </Field>

        <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
          <input
            id="org_active"
            type="checkbox"
            checked={form.active}
            onChange={(e) => set('active', e.target.checked)}
          />
          <label htmlFor="org_active">{t('org_edit.active')}</label>
        </div>

        {error && <div className="chip chip-red">{error}</div>}

        <div style={{ display: 'flex', gap: 8, marginTop: 8 }}>
          {isEdit && (
            <button
              className="btn-secondary btn"
              onClick={deleteOrg}
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
            disabled={saving || !form.name.trim()}
            style={{ flex: 1 }}
          >
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
