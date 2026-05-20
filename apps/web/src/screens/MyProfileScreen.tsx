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
import { useQueryClient } from '@tanstack/react-query'
import {
  PageHeader,
  EmptyState,
  Avatar,
  Pill,
  Icon,
  padiLevelColor,
  BrevetsView,
} from '@/foundation'
import { Sheet } from '@/components/Sheet'
import {
  fetchInstructorPhones,
  updateInstructorPhones,
} from '@/lib/queries'
import { useMyProfile, useMySkills, useCertifications } from '@/hooks/useMyProfile'
import { useContactAvailability } from '@/hooks/useContactTabs'
import type { OutletCtx } from '@/layout/AppShell'
import { AvailabilityRow, AvailabilityAddSheet } from '@/components/availability'

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
  const qc = useQueryClient()
  const { data: profile = null } = useMyProfile(user.instructorId)
  const { data: skills = [] } = useMySkills(user.instructorId)
  const { data: availability = [] } = useContactAvailability(user.instructorId)
  const { data: brevets = [] } = useCertifications(user.instructorId)
  const [showAddAvail, setShowAddAvail] = useState(false)
  const [showEditProfile, setShowEditProfile] = useState(false)

  function refetchAvail() {
    qc.invalidateQueries({ queryKey: ['contact', 'availability', user.instructorId] })
  }
  function refetchProfile() {
    qc.invalidateQueries({ queryKey: ['myProfile', user.instructorId] })
  }

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
                <AvailabilityRow key={a.id} row={a} onDeleted={refetchAvail} />
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
    // Phase J — Etappe 2d: Phone aus contacts.phones[] (JSONB Array).
    fetchInstructorPhones(instructorId).then((phonesArr) => {
      const primary = phonesArr.find((p) => p?.primary)?.e164 ?? phonesArr[0]?.e164 ?? ''
      setPhone(primary)
    })
  }, [open, instructorId])

  async function save() {
    setSaving(true)
    setError(null)
    const trimmed = phone.trim()
    // Build phones[] array: leerer Phone → leeres Array, sonst single mobile primary.
    const phonesArr = trimmed
      ? [{ label: 'mobile', e164: trimmed, primary: true }]
      : []
    try {
      await updateInstructorPhones(instructorId, phonesArr)
      setSaving(false)
      onSaved()
      onClose()
    } catch (err) {
      setSaving(false)
      setError(err instanceof Error ? err.message : String(err))
    }
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

