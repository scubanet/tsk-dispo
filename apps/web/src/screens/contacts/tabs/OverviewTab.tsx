/**
 * OverviewTab — Stammdaten, Kontakt, Sprachen & Tags, Notizen, Footer.
 */

import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import type { ContactWithSidecars } from '@/types/contacts'
import { InlineTextField } from '@/foundation/compounds/InlineTextField'
import { InlineDateField } from '@/foundation/compounds/InlineDateField'
import { EmailList } from '@/foundation/compounds/EmailList'
import { PhoneList } from '@/foundation/compounds/PhoneList'
import { AddressList } from '@/foundation/compounds/AddressList'
import {
  updateContactField,
} from '@/lib/contactQueries'
import { generatePadiReferralPdf, downloadPdf } from '@/lib/padiReferralFill'
import type { PadiReferralData } from '@/lib/padiReferralFieldMap'

const LANGUAGES = [
  { code: 'de',  label: 'De' },
  { code: 'en',  label: 'En' },
  { code: 'fr',  label: 'Fr' },
  { code: 'it',  label: 'It' },
  { code: 'sp',  label: 'Sp' },
  { code: 'tag', label: 'Tag' },
]

/** Aktuelles Alter in Jahren aus einem ISO-Datum (YYYY-MM-DD). Null bei ungültigem Input. */
function calcAgeYears(isoDate: string | null | undefined): number | null {
  if (!isoDate) return null
  const birth = new Date(isoDate)
  if (Number.isNaN(birth.getTime())) return null
  const today = new Date()
  let age = today.getFullYear() - birth.getFullYear()
  const monthDiff = today.getMonth() - birth.getMonth()
  if (monthDiff < 0 || (monthDiff === 0 && today.getDate() < birth.getDate())) {
    age--
  }
  return age >= 0 && age < 150 ? age : null
}

interface Props {
  contact: ContactWithSidecars
  onUpdated: () => void
}

export function OverviewTab({ contact, onUpdated }: Props) {
  const { t } = useTranslation()
  const id = contact.id
  const isOrg = contact.kind === 'organization'
  const [savingLang, setSavingLang] = useState(false)
  const [padiGenerating, setPadiGenerating] = useState(false)
  const [padiError, setPadiError] = useState<string | null>(null)

  const isStudent = contact.roles.includes('student')

  async function save<K extends Parameters<typeof updateContactField>[1]>(
    field: K,
    value: Parameters<typeof updateContactField<K>>[2],
  ) {
    await updateContactField(id, field, value)
    onUpdated()
  }

  async function handlePadiReferral() {
    setPadiGenerating(true)
    setPadiError(null)
    try {
      const diveCenterNr = localStorage.getItem('atoll.padi_dive_center_nr') ?? ''

      // Parse birth date
      let studentBirthTag: string | undefined
      let studentBirthMonat: string | undefined
      let studentBirthJahr: string | undefined
      if (contact.birth_date) {
        const parts = contact.birth_date.split('-')
        if (parts.length === 3) {
          studentBirthJahr  = parts[0]
          studentBirthMonat = parts[1]
          studentBirthTag   = parts[2]
        }
      }

      // Map gender
      let studentGender: 'M' | 'W' | undefined
      const g = (contact.gender ?? '').toLowerCase()
      if (g === 'm' || g === 'male' || g === 'männlich') studentGender = 'M'
      else if (g === 'f' || g === 'w' || g === 'female' || g === 'weiblich') studentGender = 'W'

      // Address (prefer primary, else first)
      const addr =
        contact.addresses.find((a) => a.primary) ?? contact.addresses[0]
      const studentStreet     = addr?.street
      const studentCityPostal = addr ? [addr.postal, addr.city].filter(Boolean).join(' ') || undefined : undefined
      const studentCountry    = addr?.country

      // Phones
      const privatePhone = contact.phones.find(
        (p) => p.label === 'home' || p.label === 'mobile' || p.label === 'privat',
      )
      const workPhone = contact.phones.find(
        (p) => p.label === 'work' || p.label === 'beruflich',
      )

      // Today for the filename
      const today = new Date().toISOString().slice(0, 10)

      const data: PadiReferralData = {
        studentName: [contact.first_name, contact.last_name].filter(Boolean).join(' '),
        studentBirthTag,
        studentBirthMonat,
        studentBirthJahr,
        studentGender,
        studentStreet,
        studentCityPostal,
        studentCountry,
        studentEmail: contact.primary_email ?? undefined,
        studentPhonePrivat:    privatePhone?.e164,
        studentPhoneBeruflich: workPhone?.e164,
        inst1DiveCenterNr: diveCenterNr || undefined,
      }

      const bytes = await generatePadiReferralPdf(data)
      const lastName = (contact.last_name ?? 'Referral').replace(/\s+/g, '-')
      downloadPdf(bytes, `PADI-Referral-${lastName}-${today}.pdf`)
    } catch (err) {
      console.error('PADI referral generation failed', err)
      setPadiError(t('contacts.padi_referral_error'))
    } finally {
      setPadiGenerating(false)
    }
  }

  async function toggleLanguage(code: string) {
    if (savingLang) return
    const current = contact.languages ?? []
    const next = current.includes(code)
      ? current.filter((c) => c !== code)
      : [...current, code]
    setSavingLang(true)
    try {
      await updateContactField(id, 'languages', next)
      onUpdated()
    } finally {
      setSavingLang(false)
    }
  }

  return (
    <div className="contact-tab-body">
      {/* ── Stammdaten ──────────────────────────────── */}
      <section className="contact-section">
        <h2 className="contact-section__title">{t('contacts.section_master')}</h2>
        {isOrg ? (
          <>
            <InlineTextField
              label={t('contacts.field_company_name')}
              value={contact.legal_name}
              onCommit={async (v) => save('legal_name', v)}
            />
            <InlineTextField
              label={t('contacts.field_trading_name')}
              value={contact.trading_name}
              onCommit={async (v) => save('trading_name', v)}
            />
          </>
        ) : (
          <>
            <InlineTextField
              label={t('contacts.field_first_name')}
              value={contact.first_name}
              onCommit={async (v) => save('first_name', v)}
            />
            <InlineTextField
              label={t('contacts.field_last_name')}
              value={contact.last_name}
              onCommit={async (v) => save('last_name', v)}
            />
            <InlineDateField
              label={t('contacts.field_birth_date')}
              value={contact.birth_date}
              onCommit={async (v) => save('birth_date', v)}
              placeholder={t('contacts.birth_date_placeholder')}
              displayExtra={
                (() => {
                  const age = calcAgeYears(contact.birth_date)
                  return age != null ? t('contacts.age_years', { count: age }) : undefined
                })()
              }
            />
          </>
        )}
      </section>

      {/* ── Kontakt ─────────────────────────────────── */}
      <section className="contact-section">
        <h2 className="contact-section__title">{t('contacts.section_contact_info')}</h2>
        <div className="contact-section__field-label">{t('contacts.field_email_label')}</div>
        <EmailList
          emails={contact.emails}
          onChange={async (next) => {
            await updateContactField(id, 'emails', next)
            // Also sync primary_email
            const primary = next.find((e) => e.primary)?.email ?? next[0]?.email ?? null
            await updateContactField(id, 'primary_email', primary)
            onUpdated()
          }}
        />
        <div className="contact-section__field-label" style={{ marginTop: 'var(--space-4)' }}>{t('contacts.field_phone_label')}</div>
        <PhoneList
          phones={contact.phones}
          onChange={async (next) => {
            await updateContactField(id, 'phones', next)
            onUpdated()
          }}
        />
        <div className="contact-section__field-label" style={{ marginTop: 'var(--space-4)' }}>{t('contacts.field_address_label')}</div>
        <AddressList
          addresses={contact.addresses}
          onChange={async (next) => {
            await updateContactField(id, 'addresses', next)
            onUpdated()
          }}
        />
      </section>

      {/* ── Sprachen & Tags ─────────────────────────── */}
      <section className="contact-section">
        <h2 className="contact-section__title">{t('contacts.section_languages_tags')}</h2>
        <div className="contact-section__field-label">{t('contacts.field_languages')}</div>
        <div className="languages-checkbox-group" data-saving={savingLang}>
          {LANGUAGES.map((l) => {
            const checked = (contact.languages ?? []).includes(l.code)
            return (
              <label
                key={l.code}
                className="language-chip"
                data-checked={checked}
              >
                <input
                  type="checkbox"
                  checked={checked}
                  disabled={savingLang}
                  onChange={() => toggleLanguage(l.code)}
                />
                <span>{l.label}</span>
              </label>
            )
          })}
        </div>
        <InlineTextField
          label={t('contacts.field_tags')}
          value={(contact.tags ?? []).join(', ')}
          onCommit={async (v) => {
            const arr = v.split(',').map((s) => s.trim()).filter(Boolean)
            await updateContactField(id, 'tags', arr)
            onUpdated()
          }}
          placeholder={t('contacts.tags_placeholder')}
        />
      </section>

      {/* ── Notizen ─────────────────────────────────── */}
      <section className="contact-section">
        <h2 className="contact-section__title">{t('contacts.section_notes')}</h2>
        <InlineTextField
          label={t('contacts.section_notes')}
          value={contact.notes}
          onCommit={async (v) => save('notes', v || null)}
          multiline
          placeholder={t('contacts.notes_placeholder')}
        />
      </section>

      {/* ── PADI Referral PDF ────────────────────────── */}
      {isStudent && (
        <section className="contact-section">
          <h2 className="contact-section__title">{t('contacts.section_padi_forms')}</h2>
          <div style={{ display: 'flex', alignItems: 'center', gap: 'var(--space-3)' }}>
            <button
              type="button"
              className="atoll-btn atoll-btn--secondary"
              onClick={handlePadiReferral}
              disabled={padiGenerating}
            >
              {padiGenerating
                ? t('contacts.padi_referral_generating')
                : t('contacts.padi_referral_button')}
            </button>
            {padiError && (
              <span style={{ color: 'var(--danger)', fontSize: 'var(--text-sm)' }}>
                {padiError}
              </span>
            )}
          </div>
        </section>
      )}

      {/* ── Footer ──────────────────────────────────── */}
      <footer className="contact-tab-footer">
        <span>{t('contacts.footer_created', { date: new Date(contact.created_at).toLocaleDateString('de-CH') })}</span>
        <span>{t('contacts.footer_updated', { date: new Date(contact.updated_at).toLocaleDateString('de-CH') })}</span>
        {contact.source && <span>{t('contacts.footer_source', { source: contact.source })}</span>}
      </footer>
    </div>
  )
}
