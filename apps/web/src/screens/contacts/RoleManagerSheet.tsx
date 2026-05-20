/**
 * RoleManagerSheet — Drawer for managing a contact's roles[] array
 * and the corresponding sidecar rows (contact_instructor, contact_student).
 */

import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { Drawer } from '@/foundation/layouts/Drawer'
import { useSetContactRoles } from '@/hooks/useContactMutations'
import type { ContactRole } from '@/types/contacts'

// Role value → i18n key map
const ROLE_LABEL_KEYS: { value: ContactRole; labelKey: string; hasSidecar?: boolean }[] = [
  { value: 'instructor', labelKey: 'contacts.role_instructor', hasSidecar: true },
  { value: 'cd', labelKey: 'contacts.role_cd' },
  { value: 'owner', labelKey: 'contacts.role_owner' },
  { value: 'dispatcher', labelKey: 'contacts.role_dispatcher' },
  { value: 'student', labelKey: 'contacts.role_student', hasSidecar: true },
  { value: 'candidate', labelKey: 'contacts.role_candidate' },
  { value: 'newsletter', labelKey: 'contacts.role_newsletter' },
  { value: 'supplier', labelKey: 'contacts.role_supplier' },
  { value: 'partner_rep', labelKey: 'contacts.role_partner_rep' },
  { value: 'authority', labelKey: 'contacts.role_authority' },
]

interface Props {
  contactId: string
  currentRoles: ContactRole[]
  open: boolean
  onClose: () => void
  onSaved: () => void
}

export function RoleManagerSheet({ contactId, currentRoles, open, onClose, onSaved }: Props) {
  const { t } = useTranslation()
  const setRoles = useSetContactRoles()
  const [draft, setDraft] = useState<ContactRole[]>(currentRoles)
  const [error, setError] = useState<string | null>(null)
  const saving = setRoles.isPending

  function toggle(role: ContactRole, checked: boolean) {
    setDraft((prev) =>
      checked ? [...prev, role] : prev.filter((r) => r !== role)
    )
  }

  async function handleSave() {
    setError(null)
    try {
      await setRoles.mutateAsync({ contactId, currentRoles, newRoles: draft })
      onSaved()
      onClose()
    } catch (err) {
      setError(err instanceof Error ? err.message : t('common.error'))
    }
  }

  return (
    <Drawer
      open={open}
      onClose={onClose}
      title={t('contacts.manage_roles_title')}
      width={Math.round(window.innerWidth * 0.3)}
      ariaLabel={t('contacts.manage_roles_title')}
      footer={
        <div style={{ display: 'flex', gap: 'var(--space-3)', justifyContent: 'flex-end', padding: 'var(--space-4)' }}>
          <button type="button" className="contact-action-btn" onClick={onClose} disabled={saving}>
            {t('common.cancel')}
          </button>
          <button type="button" className="contact-action-btn contact-action-btn--primary" onClick={handleSave} disabled={saving}>
            {saving ? t('common.saving') : t('common.save')}
          </button>
        </div>
      }
    >
      <div style={{ padding: 'var(--space-5)' }}>
        {error && (
          <div style={{ color: 'var(--brand-red)', marginBottom: 'var(--space-4)', fontSize: 'var(--text-body)' }}>
            {error}
          </div>
        )}
        <ul style={{ listStyle: 'none', margin: 0, padding: 0, display: 'flex', flexDirection: 'column', gap: 'var(--space-2)' }}>
          {ROLE_LABEL_KEYS.map(({ value, labelKey }) => (
            <li key={value} style={{ display: 'flex', alignItems: 'center', gap: 'var(--space-3)', padding: 'var(--space-2) 0', borderBottom: '1px solid var(--border-tertiary)' }}>
              <input
                type="checkbox"
                id={`role-${value}`}
                checked={draft.includes(value)}
                onChange={(e) => toggle(value, e.target.checked)}
                style={{ width: 16, height: 16, cursor: 'pointer', flexShrink: 0 }}
              />
              <label
                htmlFor={`role-${value}`}
                style={{ fontSize: 'var(--text-body)', color: 'var(--text-primary)', cursor: 'pointer', flex: 1 }}
              >
                {t(labelKey)}
              </label>
            </li>
          ))}
        </ul>
      </div>
    </Drawer>
  )
}
