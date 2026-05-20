/**
 * CreateContactSheet — slide-in drawer for creating a new contact (Phase F2).
 *
 * Props:
 *   open      — whether the drawer is visible
 *   onClose   — called on cancel / after successful save
 *   onCreated — called with the new contact's id after successful save
 */

import { useState, useEffect } from 'react'
import { useTranslation } from 'react-i18next'
import { Drawer } from '@/foundation/layouts/Drawer'
import { useCreateContact } from '@/hooks/useContactMutations'
import type { ContactKind, ContactRole } from '@/types/contacts'

interface Props {
  open: boolean
  onClose: () => void
  onCreated: (id: string) => void
}

interface RoleOption {
  role: ContactRole
  labelKey: string
}

const ROLE_OPTIONS: RoleOption[] = [
  { role: 'instructor', labelKey: 'contacts.role_instructor' },
  { role: 'student',    labelKey: 'contacts.role_student' },
  { role: 'candidate',  labelKey: 'contacts.role_candidate' },
  { role: 'newsletter', labelKey: 'contacts.role_newsletter' },
  { role: 'supplier',   labelKey: 'contacts.role_supplier' },
  { role: 'partner_rep', labelKey: 'contacts.role_partner_rep' },
]

function resetState() {
  return {
    kind: 'person' as ContactKind,
    firstName: '',
    lastName: '',
    legalName: '',
    email: '',
    phone: '',
    roles: [] as ContactRole[],
  }
}

export function CreateContactSheet({ open, onClose, onCreated }: Props) {
  const { t } = useTranslation()
  const createMutation = useCreateContact()
  const [form, setForm] = useState(resetState())
  const [error, setError] = useState<string | null>(null)
  const [dupWarning, setDupWarning] = useState<string | null>(null)
  const saving = createMutation.isPending

  // Reset form when drawer opens
  useEffect(() => {
    if (open) {
      setForm(resetState())
      setError(null)
      setDupWarning(null)
    }
  }, [open])

  function toggleRole(role: ContactRole) {
    setForm((prev) => ({
      ...prev,
      roles: prev.roles.includes(role)
        ? prev.roles.filter((r) => r !== role)
        : [...prev.roles, role],
    }))
  }

  async function handleSave() {
    setError(null)
    setDupWarning(null)

    // Validation
    if (form.kind === 'person' && (!form.firstName.trim() || !form.lastName.trim())) {
      setError(t('contacts.validation_person_name'))
      return
    }
    if (form.kind === 'organization' && !form.legalName.trim()) {
      setError(t('contacts.validation_company_name'))
      return
    }

    try {
      const { id: newId, duplicate } = await createMutation.mutateAsync({
        kind: form.kind,
        first_name: form.kind === 'person' ? form.firstName.trim() || undefined : undefined,
        last_name:  form.kind === 'person' ? form.lastName.trim()  || undefined : undefined,
        legal_name: form.kind === 'organization' ? form.legalName.trim() || undefined : undefined,
        primary_email: form.email.trim() || undefined,
        phones: form.phone.trim()
          ? [{ label: 'mobile', e164: form.phone.trim(), primary: true }]
          : undefined,
        roles: form.roles,
      })

      if (duplicate) {
        setDupWarning(
          t('contacts.dup_warning', {
            name: duplicate.display_name,
            info: duplicate.primary_email ?? duplicate.kind,
          }),
        )
      }

      onCreated(newId)
      onClose()
    } catch (err) {
      setError(err instanceof Error ? err.message : t('contacts.save_error'))
    }
  }

  const inputStyle: React.CSSProperties = {
    width: '100%',
    padding: '7px 10px',
    borderRadius: 8,
    border: '1px solid var(--border-primary)',
    background: 'var(--bg-tertiary)',
    color: 'var(--text-body)',
    fontSize: 14,
    boxSizing: 'border-box',
  }

  const labelStyle: React.CSSProperties = {
    display: 'flex',
    flexDirection: 'column',
    gap: 4,
    fontSize: 13,
    fontWeight: 500,
    color: 'var(--text-body)',
  }

  return (
    <Drawer
      open={open}
      onClose={onClose}
      title={t('contacts.create_title')}
      width={Math.round(window.innerWidth * 0.4)}
      footer={
        <div style={{ display: 'flex', gap: 8, justifyContent: 'flex-end' }}>
          <button
            type="button"
            className="atoll-btn"
            onClick={onClose}
            disabled={saving}
          >
            {t('common.cancel')}
          </button>
          <button
            type="button"
            className="atoll-btn atoll-btn--primary"
            onClick={handleSave}
            disabled={saving}
          >
            {saving ? t('contacts.saving_progress') : t('common.create')}
          </button>
        </div>
      }
    >
      <div style={{ display: 'flex', flexDirection: 'column', gap: 20, padding: '4px 0' }}>
        {/* Kind selector */}
        <div style={{ display: 'flex', gap: 16 }}>
          {(['person', 'organization'] as ContactKind[]).map((k) => (
            <label
              key={k}
              style={{ display: 'flex', alignItems: 'center', gap: 6, cursor: 'pointer', fontSize: 14 }}
            >
              <input
                type="radio"
                name="kind"
                value={k}
                checked={form.kind === k}
                onChange={() => setForm((prev) => ({ ...prev, kind: k }))}
              />
              {k === 'person' ? t('contacts.kind_person') : t('contacts.kind_organisation')}
            </label>
          ))}
        </div>

        {/* Person fields */}
        {form.kind === 'person' && (
          <>
            <label style={labelStyle}>
              {t('contacts.field_first_name_req')}
              <input
                type="text"
                value={form.firstName}
                onChange={(e) => setForm((prev) => ({ ...prev, firstName: e.target.value }))}
                placeholder="Max"
                style={inputStyle}
                autoComplete="given-name"
              />
            </label>
            <label style={labelStyle}>
              {t('contacts.field_last_name_req')}
              <input
                type="text"
                value={form.lastName}
                onChange={(e) => setForm((prev) => ({ ...prev, lastName: e.target.value }))}
                placeholder="Mustermann"
                style={inputStyle}
                autoComplete="family-name"
              />
            </label>
          </>
        )}

        {/* Organisation field */}
        {form.kind === 'organization' && (
          <label style={labelStyle}>
            {t('contacts.field_company_req')}
            <input
              type="text"
              value={form.legalName}
              onChange={(e) => setForm((prev) => ({ ...prev, legalName: e.target.value }))}
              placeholder="Musterfirma GmbH"
              style={inputStyle}
              autoComplete="organization"
            />
          </label>
        )}

        {/* Email */}
        <label style={labelStyle}>
          {t('contacts.field_email')}
          <input
            type="email"
            value={form.email}
            onChange={(e) => setForm((prev) => ({ ...prev, email: e.target.value }))}
            placeholder="max@example.com"
            style={inputStyle}
            autoComplete="email"
          />
        </label>

        {/* Phone */}
        <label style={labelStyle}>
          {t('contacts.field_phone')}
          <input
            type="tel"
            value={form.phone}
            onChange={(e) => setForm((prev) => ({ ...prev, phone: e.target.value }))}
            placeholder="+41 79 123 45 67"
            style={inputStyle}
            autoComplete="tel"
          />
        </label>

        {/* Roles */}
        <div>
          <div style={{ fontSize: 13, fontWeight: 500, color: 'var(--text-body)', marginBottom: 8 }}>
            {t('contacts.field_roles')}
          </div>
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: 10 }}>
            {ROLE_OPTIONS.map(({ role, labelKey }) => (
              <label
                key={role}
                style={{ display: 'flex', alignItems: 'center', gap: 6, cursor: 'pointer', fontSize: 13 }}
              >
                <input
                  type="checkbox"
                  checked={form.roles.includes(role)}
                  onChange={() => toggleRole(role)}
                />
                {t(labelKey)}
              </label>
            ))}
          </div>
        </div>

        {/* Error */}
        {error && (
          <div style={{ color: 'var(--brand-red)', fontSize: 13 }}>{error}</div>
        )}

        {/* Duplicate warning */}
        {dupWarning && (
          <div
            style={{
              padding: '8px 12px',
              borderRadius: 8,
              background: 'color-mix(in srgb, var(--brand-amber) 15%, transparent)',
              border: '1px solid var(--brand-amber)',
              color: 'var(--text-body)',
              fontSize: 13,
            }}
          >
            ⚠ {dupWarning}
          </div>
        )}
      </div>
    </Drawer>
  )
}
