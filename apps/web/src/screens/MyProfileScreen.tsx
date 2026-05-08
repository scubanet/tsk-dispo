/**
 * MyProfileScreen — Foundation-based rewrite (instructor view).
 *
 * Layout:
 *   PageHeader
 *   ┌─ Profile header card: Avatar + Name + level + email/phone + Edit ─┐
 *   ┌─ BrevetsView (cert-first, when present) ─────────────────────────┐
 *   ┌─ Skills card ─────────────────────────────────────────────────────┐
 *   ┌─ Availability card with add button ───────────────────────────────┐
 *
 * Edit/Add sheets stay as legacy `Sheet` components — they are local to
 * this screen and will get the Foundation Drawer treatment in a separate
 * pass alongside the other Edit Sheets.
 */

import { useEffect, useState } from 'react'
import { useOutletContext } from 'react-router-dom'
import { useTranslation } from 'react-i18next'
import {
  PageHeader,
  EmptyState,
  Avatar,
  Pill,
  Icon,
  padiLevelColor,
  dateMedium,
  BrevetsView,
} from '@/foundation'
import { Sheet } from '@/components/Sheet'
import { supabase } from '@/lib/supabase'
import {
  fetchMySkills,
  fetchMyAvailability,
  fetchCertifications,
  type MySkill,
  type AvailabilityRow,
} from '@/lib/queries'
import type { Certification } from '@/types/foundation'
import type { OutletCtx } from '@/layout/AppShell'

interface Profile {
  name: string
  initials: string
  color: string
  padi_level: string
  padi_nr: string | null
  email: string | null
  phone: string | null
}

const sheetInputStyle = {
  padding: '8px 10px',
  borderRadius: 8,
  border: '1px solid var(--border-tertiary)',
  background: 'var(--bg-card)',
  color: 'var(--text-primary)',
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
  const [brevets, setBrevets] = useState<Certification[]>([])
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
      .select('name, initials, color, padi_level, padi_nr, email, phone')
      .eq('id', user.instructorId)
      .single()
      .then(({ data }) => setProfile(data as Profile | null))
  }

  useEffect(() => {
    if (!user.instructorId) return
    refetchProfile()
    fetchMySkills(user.instructorId).then(setSkills)
    refetchAvail()
    fetchCertifications(user.instructorId).then(setBrevets)
  }, [user.instructorId])

  if (!user.instructorId) {
    return (
      <div className="atoll-screen">
        <PageHeader title={t('nav.my_profile')} />
        <div className="atoll-screen__body">
          <EmptyState
            icon={<Icon.User size={20} />}
            title={t('my_profile.no_link_title')}
            body={t('my_profile.no_link_desc')}
          />
        </div>
      </div>
    )
  }

  if (!profile) {
    return (
      <div className="atoll-screen">
        <PageHeader title={t('nav.my_profile')} />
        <div className="atoll-screen__body">
          <div className="atoll-cockpit__loading">{t('common.loading')}</div>
        </div>
      </div>
    )
  }

  return (
    <div className="atoll-screen">
      <PageHeader title={t('nav.my_profile')} />

      <div className="atoll-screen__body">
        {/* Profile header */}
        <section className="atoll-cockpit__card atoll-myprofile__head">
          <Avatar
            id={user.instructorId}
            name={profile.name}
            size="xl"
            color={padiLevelColor(profile.padi_level)}
          />
          <div className="atoll-myprofile__head-main">
            <div className="atoll-myprofile__name">{profile.name}</div>
            <div className="atoll-myprofile__head-meta">
              <Pill tone="pro" size="sm">{profile.padi_level}</Pill>
              {profile.padi_nr && (
                <span className="atoll-myprofile__padi-nr">PADI {profile.padi_nr}</span>
              )}
            </div>
            <div className="atoll-myprofile__contact">
              {[profile.email, profile.phone].filter(Boolean).join(' · ') || '—'}
            </div>
          </div>
          <button
            type="button"
            className="atoll-btn"
            onClick={() => setShowEditProfile(true)}
          >
            <Icon.Settings size={14} /> {t('common.edit')}
          </button>
        </section>

        {/* Cert-first brevets */}
        {brevets.length > 0 && (
          <section className="atoll-cockpit__card">
            <h2 className="atoll-cockpit__card-title">{t('student_detail.certifications')}</h2>
            <BrevetsView certifications={brevets} />
          </section>
        )}

        {/* Skills */}
        <section className="atoll-cockpit__card">
          <h2 className="atoll-cockpit__card-title">
            {t('my_profile.my_skills')}{' '}
            <span className="atoll-myprofile__count">({skills.length})</span>
          </h2>
          {skills.length === 0 ? (
            <p className="atoll-cockpit__card-sub">{t('my_profile.no_skills')}</p>
          ) : (
            <div className="atoll-myprofile__skills">
              {skills.map((s) => (
                <Pill key={s.code} tone="brand" size="sm">{s.label}</Pill>
              ))}
            </div>
          )}
        </section>

        {/* Availability */}
        <section className="atoll-cockpit__card">
          <div className="atoll-myprofile__avail-head">
            <h2 className="atoll-cockpit__card-title">{t('my_profile.availability')}</h2>
            <button
              type="button"
              className="atoll-btn atoll-btn--primary"
              onClick={() => setShowAddAvail(true)}
            >
              <Icon.Plus size={14} /> {t('my_profile.add_entry')}
            </button>
          </div>
          {availability.length === 0 ? (
            <p className="atoll-cockpit__card-sub">{t('my_profile.availability_hint')}</p>
          ) : (
            <div className="atoll-myprofile__avail-list">
              {availability.map((a) => (
                <AvailabilityRowView key={a.id} row={a} onDeleted={refetchAvail} />
              ))}
            </div>
          )}
        </section>
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
    </div>
  )
}

// ──────────────────────── Availability Row ────────────────────────

function AvailabilityRowView({
  row,
  onDeleted,
}: {
  row: AvailabilityRow
  onDeleted: () => void
}) {
  const { t } = useTranslation()
  const tone =
    row.kind === 'urlaub' ? 'brand' :
    row.kind === 'abwesend' ? 'warning' :
    'success'

  async function del() {
    if (!confirm(t('my_profile.confirm_delete', { kind: t(`my_profile.kind_${row.kind}`) }))) return
    await supabase.from('availability').delete().eq('id', row.id)
    onDeleted()
  }

  return (
    <div className="atoll-myprofile__avail-row">
      <Pill tone={tone} size="sm">{t(`my_profile.kind_${row.kind}`)}</Pill>
      <div className="atoll-myprofile__avail-body">
        <div className="atoll-myprofile__avail-date tabular-nums">
          {dateMedium(row.from_date)}
          {row.from_date !== row.to_date && ` – ${dateMedium(row.to_date)}`}
        </div>
        {row.note && <div className="atoll-myprofile__avail-note">{row.note}</div>}
      </div>
      <button
        type="button"
        className="atoll-iconbtn"
        onClick={del}
        title={t('common.delete')}
        aria-label={t('common.delete')}
      >
        <Icon.Close size={14} />
      </button>
    </div>
  )
}

// ──────────────────────── Profile Edit Sheet ────────────────────────

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
        <div className="caption">{t('my_profile.edit_hint')}</div>

        <div>
          <div className="caption-2" style={{ marginBottom: 4 }}>{t('my_profile.label_email_fix')}</div>
          <input value={currentEmail ?? ''} disabled style={{ ...sheetInputStyle, opacity: 0.5 }} />
        </div>

        <div>
          <div className="caption-2" style={{ marginBottom: 4 }}>{t('my_profile.label_phone')}</div>
          <input
            value={phone}
            onChange={(e) => setPhone(e.target.value)}
            placeholder="+41 79 123 45 67"
            style={sheetInputStyle}
          />
          <div className="caption-2" style={{ marginTop: 4 }}>{t('my_profile.phone_hint')}</div>
        </div>

        {error && <div className="chip chip-red">{error}</div>}

        <div style={{ display: 'flex', gap: 8 }}>
          <button className="atoll-btn" onClick={onClose}>{t('common.cancel')}</button>
          <button
            className="atoll-btn atoll-btn--primary"
            onClick={save}
            disabled={saving}
            style={{ flex: 1 }}
          >
            {saving ? t('common.saving') : t('common.save')}
          </button>
        </div>
      </div>
    </Sheet>
  )
}

// ──────────────────────── Availability Add Sheet ────────────────────────

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
          <select
            value={kind}
            onChange={(e) => setKind(e.target.value as typeof kind)}
            style={sheetInputStyle}
          >
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
            style={sheetInputStyle}
          />
        </div>

        <div>
          <div className="caption-2" style={{ marginBottom: 4 }}>{t('my_profile.label_to')}</div>
          <input
            type="date"
            value={toDate}
            onChange={(e) => setToDate(e.target.value)}
            style={sheetInputStyle}
          />
        </div>

        <div>
          <div className="caption-2" style={{ marginBottom: 4 }}>{t('my_profile.label_note')}</div>
          <input
            value={note}
            onChange={(e) => setNote(e.target.value)}
            placeholder={t('my_profile.note_placeholder')}
            style={sheetInputStyle}
          />
        </div>

        <div style={{ display: 'flex', gap: 8 }}>
          <button className="atoll-btn" onClick={onClose}>{t('common.cancel')}</button>
          <button
            className="atoll-btn atoll-btn--primary"
            onClick={save}
            disabled={saving}
            style={{ flex: 1 }}
          >
            {saving ? t('common.saving') : t('my_profile.add_entry')}
          </button>
        </div>
      </div>
    </Sheet>
  )
}
