/**
 * ContactMoreMenu — floating action menu for the contact header ⋯ button.
 *
 * Actions:
 *   - Rollen verwalten → RoleManagerSheet
 *   - Mit anderem Kontakt verschmelzen → MergeContactsSheet
 *   - Als vCard exportieren → Blob download
 *   - Archivieren → archiveContact() after confirm
 *   - GDPR-Löschung (PII entfernen) → gdprAnonymize() after confirm (danger)
 */

import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { archiveContact, gdprAnonymize } from '@/lib/contactQueries'
import type { ContactWithSidecars } from '@/types/contacts'
import { RoleManagerSheet } from './RoleManagerSheet'
import { MergeContactsSheet } from './MergeContactsSheet'

interface Props {
  contact: ContactWithSidecars
  onChanged: () => void
  /** GL-004 H5: jumps to the Activity panel (not in the tab strip). */
  onShowActivity?: () => void
  /** GL-004 H5: jumps to the Audit-History panel (not in the tab strip). */
  onShowAudit?: () => void
  onClosed: () => void
}

// ── vCard builder ─────────────────────────────────────────────────────────────

function buildVCard(contact: ContactWithSidecars): string {
  const lines: string[] = ['BEGIN:VCARD', 'VERSION:3.0']

  lines.push(`FN:${contact.display_name}`)

  if (contact.kind === 'person') {
    const last = contact.last_name ?? ''
    const first = contact.first_name ?? ''
    lines.push(`N:${last};${first};;;`)
  } else {
    const org = contact.legal_name ?? contact.display_name
    lines.push(`ORG:${org}`)
  }

  for (const e of contact.emails) {
    lines.push(`EMAIL;TYPE=${e.label}:${e.email}`)
  }

  for (const p of contact.phones) {
    lines.push(`TEL;TYPE=${p.label}:${p.e164}`)
  }

  lines.push('END:VCARD')
  return lines.join('\r\n')
}

function downloadVCard(contact: ContactWithSidecars) {
  const content = buildVCard(contact)
  const blob = new Blob([content], { type: 'text/vcard;charset=utf-8' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  const filename = contact.display_name.replace(/[^a-zA-Z0-9_\-]/g, '_') + '.vcf'
  a.href = url
  a.download = filename
  document.body.appendChild(a)
  a.click()
  document.body.removeChild(a)
  URL.revokeObjectURL(url)
}

// ── Component ─────────────────────────────────────────────────────────────────

type Sheet = 'roles' | 'merge' | null

export function ContactMoreMenu({ contact, onChanged, onShowActivity, onShowAudit, onClosed }: Props) {
  const { t } = useTranslation()
  const [activeSheet, setActiveSheet] = useState<Sheet>(null)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState<string | null>(null)

  async function handleArchive() {
    if (!window.confirm(t('contacts.confirm_archive', { name: contact.display_name }))) return
    setBusy(true)
    setError(null)
    try {
      await archiveContact(contact.id)
      onChanged()
      onClosed()
    } catch (err) {
      setError(err instanceof Error ? err.message : t('contacts.error_archive'))
      setBusy(false)
    }
  }

  async function handleGdpr() {
    if (!window.confirm(t('contacts.confirm_gdpr', { name: contact.display_name }))) return
    setBusy(true)
    setError(null)
    try {
      await gdprAnonymize(contact.id)
      onChanged()
      onClosed()
    } catch (err) {
      setError(err instanceof Error ? err.message : t('contacts.error_gdpr'))
      setBusy(false)
    }
  }

  return (
    <>
      <div className="more-menu" role="menu" aria-label={t('contacts.menu_aria')}>
        {error && (
          <div style={{ padding: 'var(--space-2) var(--space-4)', color: 'var(--brand-red)', fontSize: 'var(--text-label)' }}>
            {error}
          </div>
        )}
        <ul>
          <li>
            <button
              type="button"
              role="menuitem"
              onClick={() => setActiveSheet('roles')}
              disabled={busy}
            >
              {t('contacts.action_manage_roles')}
            </button>
          </li>
          <li>
            <button
              type="button"
              role="menuitem"
              onClick={() => setActiveSheet('merge')}
              disabled={busy}
            >
              {t('contacts.action_merge')}
            </button>
          </li>
          <li>
            <button
              type="button"
              role="menuitem"
              onClick={() => { downloadVCard(contact); onClosed() }}
              disabled={busy}
            >
              {t('contacts.action_export_vcard')}
            </button>
          </li>
          {onShowActivity && (
            <li>
              <button
                type="button"
                role="menuitem"
                onClick={onShowActivity}
                disabled={busy}
              >
                {t('contacts.tab_activity')}
              </button>
            </li>
          )}
          {onShowAudit && (
            <li>
              <button
                type="button"
                role="menuitem"
                onClick={onShowAudit}
                disabled={busy}
              >
                {t('contacts.tab_audit')}
              </button>
            </li>
          )}
          <li>
            <button
              type="button"
              role="menuitem"
              onClick={handleArchive}
              disabled={busy}
            >
              {t('contacts.action_archive')}
            </button>
          </li>
          <li>
            <button
              type="button"
              role="menuitem"
              className="danger"
              onClick={handleGdpr}
              disabled={busy}
            >
              {t('contacts.action_gdpr')}
            </button>
          </li>
          <li style={{ borderTop: '1px solid var(--border-secondary)', marginTop: 'var(--space-1)' }}>
            <button
              type="button"
              role="menuitem"
              onClick={onClosed}
              style={{ color: 'var(--text-tertiary)' }}
            >
              {t('contacts.action_close')}
            </button>
          </li>
        </ul>
      </div>

      <RoleManagerSheet
        contactId={contact.id}
        currentRoles={contact.roles}
        open={activeSheet === 'roles'}
        onClose={() => setActiveSheet(null)}
        onSaved={() => { setActiveSheet(null); onChanged(); onClosed() }}
      />

      <MergeContactsSheet
        winnerId={contact.id}
        open={activeSheet === 'merge'}
        onClose={() => setActiveSheet(null)}
        onMerged={() => { setActiveSheet(null); onChanged(); onClosed() }}
      />
    </>
  )
}
