import { useEffect, useMemo, useState } from 'react'
import { Sheet } from '@/components/Sheet'
import { Icon } from '@/components/Icon'
import { Avatar } from '@/components/Avatar'
import { Chip } from '@/components/Chip'
import { supabase } from '@/lib/supabase'
import { initialsFromName } from '@/lib/format'

const PADI_LEVELS = ['Instructor', 'Staff Instructor', 'DM', 'Shop Staff', 'Andere Funktion'] as const
const ROLES = ['instructor', 'dispatcher', 'owner'] as const
const COLORS = [
  '#0A84FF', '#30B0C7', '#34C759', '#AF52DE', '#FF9500',
  '#FF3B30', '#5856D6', '#FF2D55', '#A2845E', '#5AC8FA',
]

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
  name: string
  padi_level: string
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
  instructorId: string
  open: boolean
  onClose: () => void
  onSaved: () => void
  currentUserAuthId: string | null  // to warn when editing own role
}

export function InstructorEditSheet({ instructorId, open, onClose, onSaved, currentUserAuthId }: Props) {
  const [form, setForm] = useState<Form | null>(null)
  const [authUserId, setAuthUserId] = useState<string | null>(null)
  const [allSkills, setAllSkills] = useState<Skill[]>([])
  const [skillSet, setSkillSet] = useState<Set<string>>(new Set())
  const [skillCategory, setSkillCategory] = useState<string>('all')
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    if (!open) return
    supabase
      .from('instructors')
      .select('name, padi_level, email, phone, color, initials, active, role, auth_user_id')
      .eq('id', instructorId)
      .single()
      .then(({ data }) => {
        if (!data) return
        setForm({
          name: data.name ?? '',
          padi_level: data.padi_level ?? 'Instructor',
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
      .from('skills')
      .select('id, code, label, category')
      .order('label')
      .then(({ data }) => setAllSkills((data ?? []) as Skill[]))

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
    setSaving(true)
    setError(null)
    const { error: updErr } = await supabase
      .from('instructors')
      .update({
        name: form.name.trim(),
        padi_level: form.padi_level,
        email: form.email.trim() || null,
        phone: form.phone.trim() || null,
        color: form.color,
        initials: form.initials.trim().toUpperCase() || initialsFromName(form.name),
        active: form.active,
        role: form.role,
      })
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
    <Sheet open={open} onClose={onClose} title="Person bearbeiten" width={560}>
      {!form ? (
        <div className="caption">Lade…</div>
      ) : (
        <div style={{ display: 'grid', gap: 14 }}>
          {/* Avatar preview */}
          <div style={{ display: 'flex', gap: 12, alignItems: 'center' }}>
            <Avatar initials={form.initials || initialsFromName(form.name)} color={form.color} size="lg" />
            <div className="caption">Vorschau Avatar</div>
          </div>

          <Field label="Name">
            <input
              value={form.name}
              onChange={(e) => set('name', e.target.value)}
              style={inputStyle}
            />
          </Field>

          <Field label="Initialen (1–4)">
            <input
              value={form.initials}
              onChange={(e) => set('initials', e.target.value.toUpperCase().slice(0, 4))}
              placeholder={initialsFromName(form.name)}
              style={inputStyle}
            />
          </Field>

          <Field label="PADI-Level">
            <select
              value={form.padi_level}
              onChange={(e) => set('padi_level', e.target.value)}
              style={inputStyle}
            >
              {PADI_LEVELS.map((l) => <option key={l} value={l}>{l}</option>)}
            </select>
          </Field>

          <Field label="Avatar-Farbe">
            <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
              {COLORS.map((c) => (
                <button
                  key={c}
                  onClick={() => set('color', c)}
                  type="button"
                  style={{
                    width: 28, height: 28, borderRadius: 999,
                    border: 0, background: c, cursor: 'pointer',
                    outline: form.color === c ? '2px solid var(--ink)' : 'none',
                    outlineOffset: 2,
                  }}
                />
              ))}
            </div>
          </Field>

          <Field label="Email">
            <input
              type="email"
              value={form.email}
              onChange={(e) => set('email', e.target.value)}
              placeholder="login@email.ch"
              style={inputStyle}
            />
          </Field>

          <Field label="Telefon / WhatsApp (optional)">
            <input
              value={form.phone}
              onChange={(e) => set('phone', e.target.value)}
              placeholder="+41 79 …"
              style={inputStyle}
            />
            <div className="caption-2" style={{ marginTop: 4 }}>
              Internationales Format. Aktiviert den "WhatsApp-Direkt"-Button im TL/DM-Detail.
            </div>
          </Field>

          <Field label="Rolle">
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
            <label htmlFor="active">Aktiv (erscheint in Dispo-Vorschlägen)</label>
          </div>

          <div style={{ marginTop: 6 }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 4 }}>
              <div className="caption-2">
                SKILLS ({skillSet.size}/{allSkills.length})
              </div>
              <select
                value={skillCategory}
                onChange={(e) => setSkillCategory(e.target.value)}
                style={{ ...inputStyle, width: 'auto', padding: '4px 8px' }}
              >
                {categories.map((c) => (
                  <option key={c} value={c}>{c === 'all' ? 'Alle' : c}</option>
                ))}
              </select>
            </div>
            <div className="caption-2" style={{ marginBottom: 8 }}>
              Klick zum An-/Abwählen. Speichert sofort, kein "Speichern"-Klick nötig.
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

          {willLockSelfOut && (
            <div
              className="chip-orange"
              style={{ padding: 12, borderRadius: 12, display: 'flex', gap: 10, alignItems: 'flex-start', fontSize: 13 }}
            >
              <Icon name="bell" size={16} />
              <div>
                <strong>Achtung:</strong> Du änderst gerade <em>deine eigene</em> Rolle weg von <code>dispatcher</code>.
                Wenn du speicherst, kommst du nach dem nächsten Login nicht mehr an die Admin-Bereiche heran.
              </div>
            </div>
          )}

          {error && <div className="chip chip-red">{error}</div>}

          <div style={{ display: 'flex', gap: 8, marginTop: 8 }}>
            <button className="btn-secondary btn" onClick={onClose}>Abbrechen</button>
            <button className="btn" onClick={save} disabled={saving || !form.name} style={{ flex: 1 }}>
              {saving ? 'Speichere…' : 'Speichern'}
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
