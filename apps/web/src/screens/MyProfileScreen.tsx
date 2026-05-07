import { useEffect, useState } from 'react'
import { useOutletContext } from 'react-router-dom'
import { format } from 'date-fns'
import { de, enGB } from 'date-fns/locale'
import { useTranslation } from 'react-i18next'
import { Topbar } from '@/components/Topbar'
import { Icon } from '@/components/Icon'
import { Chip } from '@/components/Chip'
import { Avatar } from '@/components/Avatar'
import { EmptyState } from '@/components/EmptyState'
import { Sheet } from '@/components/Sheet'
import { supabase } from '@/lib/supabase'
import {
  fetchMySkills,
  fetchMyAvailability,
  type MySkill,
  type AvailabilityRow,
} from '@/lib/queries'
import type { OutletCtx } from '@/layout/AppShell'

interface Profile {
  name: string
  initials: string
  color: string
  padi_level: string
  email: string | null
  phone: string | null
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

export function MyProfileScreen() {
  const { t } = useTranslation()
  const { user } = useOutletContext<OutletCtx>()
  const [profile, setProfile] = useState<Profile | null>(null)
  const [skills, setSkills] = useState<MySkill[]>([])
  const [availability, setAvailability] = useState<AvailabilityRow[]>([])
  const [showAddAvail, setShowAddAvail] = useState(false)
  const [showEditProfile, setShowEditProfile] = useState(false)

  function refetchAvail() {
    if (!user.instructorId) return
    fetchMyAvailability(user.instructorId).then(setAvailability)
  }
  function refetchProfile() {
    if (!user.instructorId) return
    supabase
      .from('instructors')
      .select('name, initials, color, padi_level, email, phone')
      .eq('id', user.instructorId)
      .single()
      .then(({ data }) => setProfile(data as Profile | null))
  }

  useEffect(() => {
    if (!user.instructorId) return
    refetchProfile()
    fetchMySkills(user.instructorId).then(setSkills)
    refetchAvail()
  }, [user.instructorId])

  if (!user.instructorId) {
    return (
      <>
        <Topbar title={t('nav.my_profile')} />
        <EmptyState
          icon="tag"
          title={t('my_profile.no_link_title')}
          description={t('my_profile.no_link_desc')}
        />
      </>
    )
  }

  if (!profile) {
    return (
      <>
        <Topbar title={t('nav.my_profile')} />
        <div style={{ padding: 40 }} className="caption">{t('common.loading')}</div>
      </>
    )
  }

  return (
    <>
      <Topbar title={t('nav.my_profile')} />

      <div className="screen-fade scroll" style={{ flex: 1, padding: '20px 24px 40px' }}>
        <div className="glass card" style={{ marginBottom: 16, display: 'flex', gap: 16, alignItems: 'center' }}>
          <Avatar initials={profile.initials} color={profile.color} size="lg" />
          <div style={{ flex: 1 }}>
            <div className="title-2">{profile.name}</div>
            <div className="caption">{profile.padi_level}</div>
            <div className="caption" style={{ marginTop: 4 }}>
              {profile.email || '—'}{profile.phone ? ` · ${profile.phone}` : ''}
            </div>
          </div>
          <button className="btn-secondary btn" onClick={() => setShowEditProfile(true)}>
            <Icon name="settings" size={14} /> {t('common.edit')}
          </button>
        </div>

        <div className="glass card" style={{ marginBottom: 16 }}>
          <div className="title-3" style={{ marginBottom: 12 }}>
            {t('my_profile.my_skills')} <span className="caption">({skills.length})</span>
          </div>
          {skills.length === 0 ? (
            <div className="caption">{t('my_profile.no_skills')}</div>
          ) : (
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
              {skills.map((s) => <Chip key={s.code} tone="accent">{s.label}</Chip>)}
            </div>
          )}
        </div>

        <div className="glass card">
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 12 }}>
            <div className="title-3">{t('my_profile.availability')}</div>
            <button className="btn" onClick={() => setShowAddAvail(true)}>
              <Icon name="plus" size={14} /> {t('my_profile.add_entry')}
            </button>
          </div>

          {availability.length === 0 ? (
            <div className="caption">
              {t('my_profile.availability_hint')}
            </div>
          ) : (
            <div style={{ display: 'grid', gap: 6 }}>
              {availability.map((a) => (
                <AvailabilityRowView key={a.id} row={a} onDeleted={refetchAvail} />
              ))}
            </div>
          )}
        </div>
      </div>

      <AvailabilityAddSheet
        open={showAddAvail}
        onClose={() => setShowAddAvail(false)}
        onCreated={refetchAvail}
        instructorId={user.instructorId}
      />

      <ProfileEditSheet
        open={showEditProfile}
        onClose={() => setShowEditProfile(false)}
        onSaved={refetchProfile}
        instructorId={user.instructorId}
        currentEmail={profile.email}
      />
    </>
  )
}

function ProfileEditSheet({
  open, onClose, onSaved, instructorId, currentEmail,
}: {
  open: boolean
  onClose: () => void
  onSaved: () => void
  instructorId: string
  currentEmail: string | null
}) {
  const { t } = useTranslation()
  const [phone, setPhone] = useState('')
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    if (!open) return
    setError(null)
    supabase
      .from('instructors')
      .select('phone')
      .eq('id', instructorId)
      .single()
      .then(({ data }) => setPhone(data?.phone ?? ''))
  }, [open, instructorId])

  async function save() {
    setSaving(true)
    setError(null)
    const { error: updErr } = await supabase
      .from('instructors')
      .update({ phone: phone.trim() || null })
      .eq('id', instructorId)
    setSaving(false)
    if (updErr) { setError(updErr.message); return }
    onSaved()
    onClose()
  }

  return (
    <Sheet open={open} onClose={onClose} title={t('my_profile.edit_title')}>
      <div style={{ display: 'grid', gap: 14 }}>
        <div className="caption">
          {t('my_profile.edit_hint')}
        </div>

        <div>
          <div className="caption-2" style={{ marginBottom: 4 }}>{t('my_profile.label_email_fix')}</div>
          <input
            value={currentEmail ?? ''}
            disabled
            style={{ ...inputStyle, opacity: 0.5 }}
          />
        </div>

        <div>
          <div className="caption-2" style={{ marginBottom: 4 }}>{t('my_profile.label_phone')}</div>
          <input
            value={phone}
            onChange={(e) => setPhone(e.target.value)}
            placeholder="+41 79 123 45 67"
            style={inputStyle}
          />
          <div className="caption-2" style={{ marginTop: 4 }}>
            {t('my_profile.phone_hint')}
          </div>
        </div>

        {error && <div className="chip chip-red">{error}</div>}

        <div style={{ display: 'flex', gap: 8 }}>
          <button className="btn-secondary btn" onClick={onClose}>{t('common.cancel')}</button>
          <button className="btn" onClick={save} disabled={saving} style={{ flex: 1 }}>
            {saving ? t('common.saving') : t('common.save')}
          </button>
        </div>
      </div>
    </Sheet>
  )
}

function AvailabilityRowView({ row, onDeleted }: { row: AvailabilityRow; onDeleted: () => void }) {
  const { t, i18n } = useTranslation()
  const dfLocale = i18n.resolvedLanguage === 'en' ? enGB : de
  const tone =
    row.kind === 'urlaub'    ? 'accent' :
    row.kind === 'abwesend'  ? 'orange' : 'green'
  async function del() {
    if (!confirm(t('my_profile.confirm_delete', { kind: t(`my_profile.kind_${row.kind}`) }))) return
    await supabase.from('availability').delete().eq('id', row.id)
    onDeleted()
  }
  return (
    <div className="glass-thin" style={{ padding: 10, borderRadius: 10, display: 'flex', gap: 10, alignItems: 'center' }}>
      <Chip tone={tone}>{t(`my_profile.kind_${row.kind}`)}</Chip>
      <div style={{ flex: 1 }}>
        <div style={{ fontSize: 13 }}>
          {format(new Date(row.from_date), 'd. MMM', { locale: dfLocale })}
          {row.from_date !== row.to_date && ` – ${format(new Date(row.to_date), 'd. MMM yyyy', { locale: dfLocale })}`}
        </div>
        {row.note && <div className="caption-2" style={{ marginTop: 2 }}>{row.note}</div>}
      </div>
      <button className="btn-icon" onClick={del} title={t('common.delete')}>
        <Icon name="x" size={14} />
      </button>
    </div>
  )
}

function AvailabilityAddSheet({
  open, onClose, onCreated, instructorId,
}: {
  open: boolean
  onClose: () => void
  onCreated: () => void
  instructorId: string
}) {
  const { t } = useTranslation()
  const [kind, setKind] = useState<'urlaub' | 'abwesend' | 'verfügbar'>('urlaub')
  const [fromDate, setFromDate] = useState(new Date().toISOString().slice(0, 10))
  const [toDate, setToDate] = useState(new Date().toISOString().slice(0, 10))
  const [note, setNote] = useState('')
  const [saving, setSaving] = useState(false)

  async function save() {
    setSaving(true)
    const { error } = await supabase.from('availability').insert({
      instructor_id: instructorId,
      from_date: fromDate,
      to_date: toDate,
      kind,
      note: note.trim() || null,
    })
    setSaving(false)
    if (error) {
      alert(t('settings.recalc.error_prefix') + error.message)
      return
    }
    onCreated()
    onClose()
    setKind('urlaub')
    setNote('')
  }

  return (
    <Sheet open={open} onClose={onClose} title={t('my_profile.add_availability')}>
      <div style={{ display: 'grid', gap: 14 }}>
        <div>
          <div className="caption-2" style={{ marginBottom: 4 }}>{t('my_profile.label_kind')}</div>
          <select value={kind} onChange={(e) => setKind(e.target.value as typeof kind)} style={inputStyle}>
            <option value="urlaub">{t('my_profile.kind_urlaub')}</option>
            <option value="abwesend">{t('my_profile.kind_abwesend')}</option>
            <option value="verfügbar">{t('my_profile.kind_verfügbar_long')}</option>
          </select>
        </div>

        <div>
          <div className="caption-2" style={{ marginBottom: 4 }}>{t('my_profile.label_from')}</div>
          <input
            type="date"
            value={fromDate}
            onChange={(e) => setFromDate(e.target.value)}
            style={inputStyle}
          />
        </div>

        <div>
          <div className="caption-2" style={{ marginBottom: 4 }}>{t('my_profile.label_to')}</div>
          <input
            type="date"
            value={toDate}
            onChange={(e) => setToDate(e.target.value)}
            style={inputStyle}
          />
        </div>

        <div>
          <div className="caption-2" style={{ marginBottom: 4 }}>{t('my_profile.label_note')}</div>
          <input
            value={note}
            onChange={(e) => setNote(e.target.value)}
            placeholder={t('my_profile.note_placeholder')}
            style={inputStyle}
          />
        </div>

        <div style={{ display: 'flex', gap: 8 }}>
          <button className="btn-secondary btn" onClick={onClose}>{t('common.cancel')}</button>
          <button className="btn" onClick={save} disabled={saving} style={{ flex: 1 }}>
            {saving ? t('common.saving') : t('my_profile.add_entry')}
          </button>
        </div>
      </div>
    </Sheet>
  )
}
