import { useEffect, useMemo, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { Sheet } from '@/components/Sheet'
import { Icon } from '@/components/Icon'
import { Avatar, padiLevelColor } from '@/foundation'
import { supabase } from '@/lib/supabase'
import { initialsFromName } from '@/lib/format'

const PADI_LEVELS = ['DM', 'AI', 'OWSI', 'MSDT', 'IDC Staff', 'MI', 'CD', 'Shop Staff', 'Andere'] as const
const ROLES = ['instructor', 'dispatcher', 'owner'] as const
// Avatar color is derived from padi_level via Foundation `padiLevelColor()` —
// no manual color picker any more.

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

interface Form {
  first_name: string
  last_name: string
  padi_level: string
  padi_nr: string
  email: string
  phone: string
  color: string
  initials: string
  active: boolean
  role: string
}

interface Skill {
  id: string
  code: string
  label: string
  category: string | null
}

interface Props {
  instructorId?: string | null
  open: boolean
  onClose: () => void
  onSaved: (newId?: string) => void
  currentUserAuthId: string | null  // to warn when editing own role
}

const EMPTY_FORM: Form = {
  first_name: '',
  last_name: '',
  padi_level: 'OWSI',
  padi_nr: '',
  email: '',
  phone: '',
  color: '#0A84FF',
  initials: '',
  active: true,
  role: 'instructor',
}

export function InstructorEditSheet({ instructorId, open, onClose, onSaved, currentUserAuthId }: Props) {
  const { t } = useTranslation()
  const isEdit = !!instructorId
  const [form, setForm] = useState<Form | null>(null)
  const [authUserId, setAuthUserId] = useState<string | null>(null)
  const [allSkills, setAllSkills] = useState<Skill[]>([])
  const [skillSet, setSkillSet] = useState<Set<string>>(new Set())
  const [skillCategory, setSkillCategory] = useState<string>('all')
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    if (!open) return
    setError(null)

    // Load skill catalog (always)
    supabase
      .from('skills')
      .select('id, code, label, category')
      .order('label')
      .then(({ data }) => setAllSkills((data ?? []) as Skill[]))

    if (!instructorId) {
      // Create-Mode: leeres Formular, keine Skills
      setForm(EMPTY_FORM)
      setAuthUserId(null)
      setSkillSet(new Set())
      return
    }

    supabase
      .from('instructors')
      .select('first_name, last_name, name, padi_level, padi_nr, email, phone, color, initials, active, role, auth_user_id')
      .eq('id', instructorId)
      .single()
      .then(({ data }) => {
        if (!data) return
        // Fallback: falls first/last leer (legacy Daten vor Migration 0042), aus name splitten
        const first = data.first_name?.trim() || (data.name ?? '').split(' ')[0] || ''
        const last  = data.last_name?.trim()  || (data.name ?? '').split(' ').slice(1).join(' ') || ''
        setForm({
          first_name: first,
          last_name: last,
          padi_level: data.padi_level ?? 'OWSI',
          padi_nr: data.padi_nr ?? '',
          email: data.email ?? '',
          phone: data.phone ?? '',
          color: data.color ?? '#0A84FF',
          initials: data.initials ?? '',
          active: !!data.active,
          role: data.role ?? 'instructor',
        })
        setAuthUserId(data.auth_user_id)
      })

    supabase
      .from('instructor_skills')
      .select('skill_id')
      .eq('instructor_id', instructorId)
      .then(({ data }) =>
        setSkillSet(new Set((data ?? []).map((d: any) => d.skill_id))),
      )
  }, [open, instructorId])

  const categories = useMemo(() => {
    const set = new Set<string>()
    allSkills.forEach((s) => s.category && set.add(s.category))
    return ['all', ...Array.from(set).sort()]
  }, [allSkills])

  const filteredSkills = useMemo(() => {
    if (skillCategory === 'all') return allSkills
    return allSkills.filter((s) => s.category === skillCategory)
  }, [allSkills, skillCategory])

  async function toggleSkill(skillId: string) {
    if (!instructorId) return  // create-mode: skills erst nach dem Anlegen
    const next = new Set(skillSet)
    if (next.has(skillId)) {
      next.delete(skillId)
      await supabase
        .from('instructor_skills')
        .delete()
        .match({ instructor_id: instructorId, skill_id: skillId })
    } else {
      next.add(skillId)
      await supabase
        .from('instructor_skills')
        .insert({ instructor_id: instructorId, skill_id: skillId })
    }
    setSkillSet(next)
  }

  function set<K extends keyof Form>(k: K, v: Form[K]) {
    setForm((prev) => (prev ? { ...prev, [k]: v } : prev))
  }

  async function save() {
    if (!form) return
    if (!form.first_name.trim()) {
      setError(t('instructor_edit.error_first_name_required'))
      return
    }
    setSaving(true)
    setError(null)

    const fullName = `${form.first_name.trim()} ${form.last_name.trim()}`.trim()
    const payload = {
      first_name: form.first_name.trim(),
      last_name: form.last_name.trim(),
      padi_level: form.padi_level,
      padi_nr: form.padi_nr.trim() || null,
      email: form.email.trim() || null,
      phone: form.phone.trim() || null,
      color: form.color,
      initials: form.initials.trim().toUpperCase() || initialsFromName(fullName),
      active: form.active,
      role: form.role,
    }

    if (!isEdit) {
      // CREATE
      const { data: created, error: insErr } = await supabase
        .from('instructors')
        .insert(payload)
        .select('id')
        .single()
      if (insErr) {
        setError(insErr.message)
        setSaving(false)
        return
      }
      setSaving(false)
      onSaved(created?.id)
      onClose()
      return
    }

    // EDIT (existing)
    const { error: updErr } = await supabase
      .from('instructors')
      .update(payload)
      .eq('id', instructorId)
    if (updErr) {
      setError(updErr.message)
      setSaving(false)
      return
    }
    setSaving(false)
    onSaved()
    onClose()
  }

  const isEditingSelf = !!authUserId && authUserId === currentUserAuthId
  const willLockSelfOut = isEditingSelf && form?.role !== 'dispatcher'

  return (
    <Sheet open={open} onClose={onClose} title={isEdit ? t('instructor_edit.title_edit') : t('instructor_edit.title_new')} width={560}>
      {!form ? (
        <div className="caption">{t('common.loading')}</div>
      ) : (
        <div style={{ display: 'grid', gap: 14 }}>
          {/* Avatar preview — color follows padi_level automatically. */}
          <div style={{ display: 'flex', gap: 12, alignItems: 'center' }}>
            <Avatar
              id={instructorId ?? 'preview'}
              name={`${form.first_name} ${form.last_name}`.trim() || '—'}
              size="lg"
              color={padiLevelColor(form.padi_level)}
            />
            <div className="caption">{t('instructor_edit.avatar_preview')}</div>
          </div>

          <div style={{ display: 'flex', gap: 10 }}>
            <div style={{ flex: 1 }}>
              <Field label={t('student_edit.label_first_name')}>
                <input
                  value={form.first_name}
                  onChange={(e) => set('first_name', e.target.value)}
                  style={inputStyle}
                />
              </Field>
            </div>
            <div style={{ flex: 1 }}>
              <Field label={t('student_edit.label_last_name')}>
                <input
                  value={form.last_name}
                  onChange={(e) => set('last_name', e.target.value)}
                  style={inputStyle}
                />
              </Field>
            </div>
          </div>

          <Field label={t('instructor_edit.label_initials')}>
            <input
              value={form.initials}
              onChange={(e) => set('initials', e.target.value.toUpperCase().slice(0, 4))}
              placeholder={initialsFromName(`${form.first_name} ${form.last_name}`.trim())}
              style={inputStyle}
            />
          </Field>

          <Field label={t('instructor_edit.label_padi_level')}>
            <select
              value={form.padi_level}
              onChange={(e) => set('padi_level', e.target.value)}
              style={inputStyle}
            >
              {PADI_LEVELS.map((l) => <option key={l} value={l}>{l}</option>)}
            </select>
          </Field>

          <Field label={t('instructor_edit.label_padi_nr', 'PADI-Nummer')}>
            <input
              type="text"
              inputMode="numeric"
              value={form.padi_nr}
              onChange={(e) => set('padi_nr', e.target.value)}
              placeholder="123456"
              style={inputStyle}
            />
          </Field>

          <Field label={t('student_edit.label_email')}>
            <input
              type="email"
              value={form.email}
              onChange={(e) => set('email', e.target.value)}
              placeholder="login@email.ch"
              style={inputStyle}
            />
          </Field>

          <Field label={t('instructor_edit.label_phone')}>
            <input
              value={form.phone}
              onChange={(e) => set('phone', e.target.value)}
              placeholder="+41 79 …"
              style={inputStyle}
            />
            <div className="caption-2" style={{ marginTop: 4 }}>
              {t('instructor_edit.phone_hint')}
            </div>
          </Field>

          <Field label={t('instructor_edit.label_role')}>
            <select
              value={form.role}
              onChange={(e) => set('role', e.target.value)}
              style={inputStyle}
            >
              {ROLES.map((r) => <option key={r} value={r}>{r}</option>)}
            </select>
          </Field>

          <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
            <input
              id="active"
              type="checkbox"
              checked={form.active}
              onChange={(e) => set('active', e.target.checked)}
            />
            <label htmlFor="active">{t('instructor_edit.active_label')}</label>
          </div>

          {isEdit ? (
            <div style={{ marginTop: 6 }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 4 }}>
                <div className="caption-2">
                  {t('instructor_edit.skills_label', { selected: skillSet.size, total: allSkills.length })}
                </div>
                <select
                  value={skillCategory}
                  onChange={(e) => setSkillCategory(e.target.value)}
                  style={{ ...inputStyle, width: 'auto', padding: '4px 8px' }}
                >
                  {categories.map((c) => (
                    <option key={c} value={c}>{c === 'all' ? t('instructor_edit.all_categories_short') : c}</option>
                  ))}
                </select>
              </div>
              <div className="caption-2" style={{ marginBottom: 8 }}>
                {t('instructor_edit.skills_hint')}
              </div>
              <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6, maxHeight: 220, overflow: 'auto', padding: 4 }}>
                {filteredSkills.map((s) => {
                  const has = skillSet.has(s.id)
                  return (
                    <button
                      type="button"
                      key={s.id}
                      onClick={() => toggleSkill(s.id)}
                      style={{
                        padding: '5px 10px',
                        borderRadius: 999,
                        border: 0,
                        cursor: 'pointer',
                        fontSize: 11.5,
                        fontWeight: 500,
                        background: has ? 'var(--accent-soft)' : 'rgba(0,0,0,.05)',
                        color: has ? 'var(--accent)' : 'var(--ink-2)',
                      }}
                    >
                      {has ? '✓ ' : ''}{s.label}
                    </button>
                  )
                })}
              </div>
            </div>
          ) : (
            <div className="caption" style={{ padding: 12, background: 'rgba(120,120,128,.08)', borderRadius: 8 }}>
              {t('instructor_edit.skills_post_create_hint')}
            </div>
          )}

          {willLockSelfOut && (
            <div
              className="chip-orange"
              style={{ padding: 12, borderRadius: 12, display: 'flex', gap: 10, alignItems: 'flex-start', fontSize: 13 }}
            >
              <Icon name="bell" size={16} />
              <div>
                <strong>{t('instructor_edit.warning_label')}:</strong> {t('instructor_edit.lockout_warning')}
              </div>
            </div>
          )}

          {error && <div className="chip chip-red">{error}</div>}

          <div style={{ display: 'flex', gap: 8, marginTop: 8 }}>
            <button className="btn-secondary btn" onClick={onClose}>{t('common.cancel')}</button>
            <button className="btn" onClick={save} disabled={saving || !form.first_name.trim()} style={{ flex: 1 }}>
              {saving ? t('common.saving') : t('common.save')}
            </button>
          </div>
        </div>
      )}
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
