/**
 * AddressList — edit list of AddressEntry[].
 *
 * Features:
 * - Renders each address with label badge, formatted lines, PRIMARY badge
 * - Edit mode expands to multi-field form (street, postal, city, country)
 * - "Primär setzen" / "×" buttons per row
 * - Add-row with label dropdown + fields + "Hinzufügen" button
 * - No external validation — all fields optional
 */

import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import type { AddressEntry } from '@/types/contacts'

const LABEL_OPTIONS = ['home', 'work', 'billing', 'other']

function formatAddress(a: AddressEntry): string {
  return [a.street, [a.postal, a.city].filter(Boolean).join(' '), a.country]
    .filter(Boolean)
    .join(', ')
}

export interface AddressListProps {
  addresses: AddressEntry[]
  onChange: (next: AddressEntry[]) => Promise<void>
  disabled?: boolean
}

interface DraftAddress {
  label: string
  street: string
  postal: string
  city: string
  country: string
}

const EMPTY_DRAFT: DraftAddress = { label: 'home', street: '', postal: '', city: '', country: 'CH' }

export function AddressList({ addresses, onChange, disabled = false }: AddressListProps) {
  const { t } = useTranslation()
  const [editIdx, setEditIdx] = useState<number | null>(null)
  const [editDraft, setEditDraft] = useState<DraftAddress>(EMPTY_DRAFT)
  const [addOpen, setAddOpen] = useState(false)
  const [addDraft, setAddDraft] = useState<DraftAddress>(EMPTY_DRAFT)
  const [saving, setSaving] = useState(false)

  async function save(next: AddressEntry[]) {
    setSaving(true)
    try {
      await onChange(next)
    } finally {
      setSaving(false)
    }
  }

  async function makePrimary(idx: number) {
    const next = addresses.map((a, i) => ({ ...a, primary: i === idx }))
    await save(next)
  }

  async function remove(idx: number) {
    const next = addresses.filter((_, i) => i !== idx)
    if (addresses[idx].primary && next.length > 0) {
      next[0] = { ...next[0], primary: true }
    }
    await save(next)
  }

  function startEdit(idx: number) {
    const a = addresses[idx]
    setEditDraft({ label: a.label, street: a.street ?? '', postal: a.postal ?? '', city: a.city ?? '', country: a.country ?? '' })
    setEditIdx(idx)
  }

  async function commitEdit() {
    if (editIdx === null) return
    const next = addresses.map((a, i) =>
      i === editIdx
        ? { ...a, label: editDraft.label, street: editDraft.street || undefined, postal: editDraft.postal || undefined, city: editDraft.city || undefined, country: editDraft.country || undefined }
        : a,
    )
    await save(next)
    setEditIdx(null)
  }

  async function addAddress() {
    const isPrimary = addresses.length === 0
    const next: AddressEntry[] = [
      ...addresses,
      {
        label: addDraft.label,
        street: addDraft.street || undefined,
        postal: addDraft.postal || undefined,
        city: addDraft.city || undefined,
        country: addDraft.country || undefined,
        primary: isPrimary,
      },
    ]
    await save(next)
    setAddOpen(false)
    setAddDraft(EMPTY_DRAFT)
  }

  const isDisabled = disabled || saving

  return (
    <div className="address-list">
      {addresses.map((a, i) => (
        <div key={i} className="address-list__row" style={{ flexDirection: 'column', alignItems: 'flex-start', gap: 'var(--space-1)' }}>
          {editIdx === i ? (
            <AddressForm
              draft={editDraft}
              onChange={setEditDraft}
              onSubmit={commitEdit}
              onCancel={() => setEditIdx(null)}
              submitLabel={t('common.save')}
            />
          ) : (
            <div style={{ display: 'flex', alignItems: 'center', gap: 'var(--space-2)', width: '100%' }}>
              <span className="contact-list-badge">{a.label}</span>
              <span
                style={{ flex: 1, fontSize: 'var(--text-body)', cursor: isDisabled ? 'default' : 'pointer' }}
                onClick={isDisabled ? undefined : () => startEdit(i)}
              >
                {formatAddress(a) || <span style={{ color: 'var(--text-tertiary)', fontStyle: 'italic' }}>—</span>}
              </span>
              {a.primary && (
                <span className="contact-list-badge contact-list-badge--primary">{t('contacts.primary_badge')}</span>
              )}
              {!a.primary && !isDisabled && (
                <button
                  type="button"
                  style={{ fontSize: 'var(--text-meta)', color: 'var(--brand-blue)', background: 'none', border: 'none', cursor: 'pointer', padding: '0 var(--space-1)' }}
                  onClick={() => makePrimary(i)}
                >
                  {t('contacts.set_primary')}
                </button>
              )}
              {!isDisabled && (
                <button
                  type="button"
                  aria-label={t('contacts.remove_aria')}
                  style={{ fontSize: 'var(--text-body)', color: 'var(--brand-red)', background: 'none', border: 'none', cursor: 'pointer', padding: '0 var(--space-1)' }}
                  onClick={() => remove(i)}
                >
                  ×
                </button>
              )}
            </div>
          )}
        </div>
      ))}

      {!isDisabled && !addOpen && (
        <div style={{ paddingTop: 'var(--space-2)' }}>
          <button
            type="button"
            style={{ fontSize: 'var(--text-label)', color: 'var(--brand-blue)', background: 'none', border: 'none', cursor: 'pointer', padding: 0 }}
            onClick={() => setAddOpen(true)}
          >
            {t('contacts.add_address')}
          </button>
        </div>
      )}

      {!isDisabled && addOpen && (
        <div className="address-list__add" style={{ paddingTop: 'var(--space-2)', flexDirection: 'column', alignItems: 'flex-start' }}>
          <AddressForm
            draft={addDraft}
            onChange={setAddDraft}
            onSubmit={addAddress}
            onCancel={() => { setAddOpen(false); setAddDraft(EMPTY_DRAFT) }}
            submitLabel={t('contacts.add_item')}
          />
        </div>
      )}
    </div>
  )
}

// ── Internal form component ──────────────────────────────────────────

interface AddressFormProps {
  draft: DraftAddress
  onChange: (d: DraftAddress) => void
  onSubmit: () => void
  onCancel: () => void
  submitLabel: string
}

function AddressForm({ draft, onChange, onSubmit, onCancel, submitLabel }: AddressFormProps) {
  const { t } = useTranslation()
  const fieldStyle: React.CSSProperties = {
    fontSize: 'var(--text-body)',
    padding: 'var(--space-1) var(--space-2)',
    borderRadius: 'var(--radius-sm)',
    border: '1px solid var(--border-secondary)',
    width: '100%',
  }

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--space-2)', width: '100%' }}>
      <select
        value={draft.label}
        onChange={(e) => onChange({ ...draft, label: e.target.value })}
        style={{ ...fieldStyle, width: 'auto' }}
      >
        {LABEL_OPTIONS.map((l) => (
          <option key={l} value={l}>{l}</option>
        ))}
      </select>
      <input type="text" placeholder="Strasse, Nr." value={draft.street} onChange={(e) => onChange({ ...draft, street: e.target.value })} style={fieldStyle} />
      <div style={{ display: 'flex', gap: 'var(--space-2)' }}>
        <input type="text" placeholder="PLZ" value={draft.postal} onChange={(e) => onChange({ ...draft, postal: e.target.value })} style={{ ...fieldStyle, width: '5rem' }} />
        <input type="text" placeholder="Ort" value={draft.city} onChange={(e) => onChange({ ...draft, city: e.target.value })} style={{ ...fieldStyle, flex: 1 }} />
      </div>
      <input type="text" placeholder="Land" value={draft.country} onChange={(e) => onChange({ ...draft, country: e.target.value })} style={fieldStyle} />
      <div style={{ display: 'flex', gap: 'var(--space-2)' }}>
        <button
          type="button"
          onClick={onSubmit}
          style={{ fontSize: 'var(--text-label)', fontWeight: 'var(--weight-medium)', padding: 'var(--space-1) var(--space-3)', borderRadius: 'var(--radius-sm)', background: 'var(--brand-blue)', color: '#fff', border: 'none', cursor: 'pointer' }}
        >
          {submitLabel}
        </button>
        <button
          type="button"
          onClick={onCancel}
          style={{ fontSize: 'var(--text-label)', padding: 'var(--space-1) var(--space-3)', borderRadius: 'var(--radius-sm)', background: 'var(--bg-tertiary)', color: 'var(--text-secondary)', border: 'none', cursor: 'pointer' }}
        >
          {t('common.cancel')}
        </button>
      </div>
    </div>
  )
}
