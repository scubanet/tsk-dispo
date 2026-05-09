/**
 * OverviewTab — Stammdaten, Kontakt, Sprachen & Tags, Notizen, Footer.
 */

import { useState } from 'react'
import type { ContactWithSidecars } from '@/types/contacts'
import { InlineTextField } from '@/foundation/compounds/InlineTextField'
import { EmailList } from '@/foundation/compounds/EmailList'
import { PhoneList } from '@/foundation/compounds/PhoneList'
import { AddressList } from '@/foundation/compounds/AddressList'
import {
  updateContactField,
} from '@/lib/contactQueries'

const LANGUAGES = [
  { code: 'de',  label: 'De' },
  { code: 'en',  label: 'En' },
  { code: 'fr',  label: 'Fr' },
  { code: 'it',  label: 'It' },
  { code: 'sp',  label: 'Sp' },
  { code: 'tag', label: 'Tag' },
]

interface Props {
  contact: ContactWithSidecars
  onUpdated: () => void
}

export function OverviewTab({ contact, onUpdated }: Props) {
  const id = contact.id
  const isOrg = contact.kind === 'organization'
  const [savingLang, setSavingLang] = useState(false)

  async function save<K extends Parameters<typeof updateContactField>[1]>(
    field: K,
    value: Parameters<typeof updateContactField<K>>[2],
  ) {
    await updateContactField(id, field, value)
    onUpdated()
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
        <h2 className="contact-section__title">Stammdaten</h2>
        {isOrg ? (
          <>
            <InlineTextField
              label="Firmenname"
              value={contact.legal_name}
              onCommit={async (v) => save('legal_name', v)}
            />
            <InlineTextField
              label="Handelsname"
              value={contact.trading_name}
              onCommit={async (v) => save('trading_name', v)}
            />
          </>
        ) : (
          <>
            <InlineTextField
              label="Vorname"
              value={contact.first_name}
              onCommit={async (v) => save('first_name', v)}
            />
            <InlineTextField
              label="Nachname"
              value={contact.last_name}
              onCommit={async (v) => save('last_name', v)}
            />
            <InlineTextField
              label="Geburtsdatum"
              value={contact.birth_date}
              onCommit={async (v) => save('birth_date', v || null)}
              placeholder="JJJJ-MM-TT"
            />
          </>
        )}
      </section>

      {/* ── Kontakt ─────────────────────────────────── */}
      <section className="contact-section">
        <h2 className="contact-section__title">Kontakt</h2>
        <div className="contact-section__field-label">E-Mail</div>
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
        <div className="contact-section__field-label" style={{ marginTop: 'var(--space-4)' }}>Telefon</div>
        <PhoneList
          phones={contact.phones}
          onChange={async (next) => {
            await updateContactField(id, 'phones', next)
            onUpdated()
          }}
        />
        <div className="contact-section__field-label" style={{ marginTop: 'var(--space-4)' }}>Adresse</div>
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
        <h2 className="contact-section__title">Sprachen &amp; Tags</h2>
        <div className="contact-section__field-label">Sprachen</div>
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
          label="Tags"
          value={(contact.tags ?? []).join(', ')}
          onCommit={async (v) => {
            const arr = v.split(',').map((s) => s.trim()).filter(Boolean)
            await updateContactField(id, 'tags', arr)
            onUpdated()
          }}
          placeholder="vip, newsletter, …"
        />
      </section>

      {/* ── Notizen ─────────────────────────────────── */}
      <section className="contact-section">
        <h2 className="contact-section__title">Notizen</h2>
        <InlineTextField
          label="Notizen"
          value={contact.notes}
          onCommit={async (v) => save('notes', v || null)}
          multiline
          placeholder="Interne Notizen …"
        />
      </section>

      {/* ── Footer ──────────────────────────────────── */}
      <footer className="contact-tab-footer">
        <span>Erstellt: {new Date(contact.created_at).toLocaleDateString('de-CH')}</span>
        <span>Geändert: {new Date(contact.updated_at).toLocaleDateString('de-CH')}</span>
        {contact.source && <span>Quelle: {contact.source}</span>}
      </footer>
    </div>
  )
}
