/**
 * CreateContactSheet — slide-in drawer for creating a new contact (Phase F2).
 *
 * Props:
 *   open      — whether the drawer is visible
 *   onClose   — called on cancel / after successful save
 *   onCreated — called with the new contact's id after successful save
 */

import { useState, useEffect } from 'react'
import { Drawer } from '@/foundation/layouts/Drawer'
import { createContact, findPotentialDuplicates } from '@/lib/contactQueries'
import type { ContactKind, ContactRole } from '@/types/contacts'

interface Props {
  open: boolean
  onClose: () => void
  onCreated: (id: string) => void
}

interface RoleOption {
  role: ContactRole
  label: string
}

const ROLE_OPTIONS: RoleOption[] = [
  { role: 'instructor', label: 'TL/DM' },
  { role: 'student',    label: 'Schüler' },
  { role: 'candidate',  label: 'Kandidat' },
  { role: 'newsletter', label: 'Newsletter' },
  { role: 'supplier',   label: 'Lieferant' },
  { role: 'partner_rep', label: 'Partner-Rep' },
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
  const [form, setForm] = useState(resetState())
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [dupWarning, setDupWarning] = useState<string | null>(null)

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
      setError('Vorname und Nachname sind erforderlich.')
      return
    }
    if (form.kind === 'organization' && !form.legalName.trim()) {
      setError('Firmenname ist erforderlich.')
      return
    }

    setSaving(true)
    try {
      const newId = await createContact({
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

      // Check for potential duplicates
      try {
        const dups = await findPotentialDuplicates(newId)
        if (dups.length > 0) {
          const first = dups[0]
          setDupWarning(
            `Möglicher Treffer: ${first.display_name} (${first.primary_email ?? first.kind})`
          )
          // Still proceed — warning is informational
        }
      } catch {
        // Dedup errors are non-fatal
      }

      onCreated(newId)
      onClose()
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Speichern fehlgeschlagen.')
    } finally {
      setSaving(false)
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
      title="Neuer Kontakt"
      width={Math.round(window.innerWidth * 0.4)}
      footer={
        <div style={{ display: 'flex', gap: 8, justifyContent: 'flex-end' }}>
          <button
            type="button"
            className="atoll-btn"
            onClick={onClose}
            disabled={saving}
          >
            Abbrechen
          </button>
          <button
            type="button"
            className="atoll-btn atoll-btn--primary"
            onClick={handleSave}
            disabled={saving}
          >
            {saving ? 'Speichern…' : 'Erstellen'}
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
              {k === 'person' ? 'Person' : 'Organisation'}
            </label>
          ))}
        </div>

        {/* Person fields */}
        {form.kind === 'person' && (
          <>
            <label style={labelStyle}>
              Vorname *
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
              Nachname *
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
            Firmenname *
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
          E-Mail
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
          Telefon
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
            Rollen
          </div>
          <div style={{ display: 'flex', flexWrap: 'wrap', gap: 10 }}>
            {ROLE_OPTIONS.map(({ role, label }) => (
              <label
                key={role}
                style={{ display: 'flex', alignItems: 'center', gap: 6, cursor: 'pointer', fontSize: 13 }}
              >
                <input
                  type="checkbox"
                  checked={form.roles.includes(role)}
                  onChange={() => toggleRole(role)}
                />
                {label}
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
