/**
 * PhoneList — edit list of PhoneEntry[].
 *
 * Features:
 * - Renders each phone with label badge, formatted number (tel: link), PRIMARY badge
 * - "Primär" button per row, "×" remove button
 * - Add-row with label dropdown + e164 input + "Hinzufügen" button
 * - Validates via parsePhoneNumberFromString(raw, 'CH')
 */

import { useState } from 'react'
import { parsePhoneNumberFromString } from 'libphonenumber-js'
import type { PhoneEntry } from '@/types/contacts'

const LABEL_OPTIONS = ['mobile', 'work', 'home', 'other']

export interface PhoneListProps {
  phones: PhoneEntry[]
  onChange: (next: PhoneEntry[]) => Promise<void>
  disabled?: boolean
}

export function PhoneList({ phones, onChange, disabled = false }: PhoneListProps) {
  const [addLabel, setAddLabel] = useState('mobile')
  const [addRaw, setAddRaw] = useState('')
  const [addError, setAddError] = useState<string | null>(null)
  const [saving, setSaving] = useState(false)

  async function save(next: PhoneEntry[]) {
    setSaving(true)
    try {
      await onChange(next)
    } finally {
      setSaving(false)
    }
  }

  async function makePrimary(idx: number) {
    const next = phones.map((p, i) => ({ ...p, primary: i === idx }))
    await save(next)
  }

  async function remove(idx: number) {
    const next = phones.filter((_, i) => i !== idx)
    // Auto-promote next if removed was primary
    if (phones[idx].primary && next.length > 0) {
      next[0] = { ...next[0], primary: true }
    }
    await save(next)
  }

  async function add() {
    setAddError(null)
    const parsed = parsePhoneNumberFromString(addRaw.trim(), 'CH')
    if (!parsed || !parsed.isValid()) {
      setAddError('Ungültige Telefonnummer (CH-Format erwartet, z. B. 079 123 45 67)')
      return
    }
    const e164 = parsed.format('E.164')
    const isPrimary = phones.length === 0
    const next: PhoneEntry[] = [
      ...phones,
      { label: addLabel, e164, primary: isPrimary },
    ]
    await save(next)
    setAddRaw('')
  }

  const isDisabled = disabled || saving

  return (
    <div className="phone-list">
      {phones.map((p, i) => (
        <div key={i} className="phone-list__row">
          <span className="contact-list-badge">{p.label}</span>
          <a
            href={`tel:${p.e164}`}
            style={{ flex: 1, fontSize: 'var(--text-body)', color: 'var(--text-primary)', textDecoration: 'none' }}
          >
            {p.e164}
          </a>
          {p.primary && (
            <span className="contact-list-badge contact-list-badge--primary">Primär</span>
          )}
          {!p.primary && !isDisabled && (
            <button
              type="button"
              style={{ fontSize: 'var(--text-meta)', color: 'var(--brand-blue)', background: 'none', border: 'none', cursor: 'pointer', padding: '0 var(--space-1)' }}
              onClick={() => makePrimary(i)}
            >
              Primär setzen
            </button>
          )}
          {!isDisabled && (
            <button
              type="button"
              aria-label="Entfernen"
              style={{ fontSize: 'var(--text-body)', color: 'var(--brand-red)', background: 'none', border: 'none', cursor: 'pointer', padding: '0 var(--space-1)' }}
              onClick={() => remove(i)}
            >
              ×
            </button>
          )}
        </div>
      ))}

      {!isDisabled && (
        <div className="phone-list__add">
          <select
            value={addLabel}
            onChange={(e) => setAddLabel(e.target.value)}
            style={{ fontSize: 'var(--text-label)', padding: 'var(--space-1) var(--space-2)', borderRadius: 'var(--radius-sm)', border: '1px solid var(--border-secondary)' }}
          >
            {LABEL_OPTIONS.map((l) => (
              <option key={l} value={l}>{l}</option>
            ))}
          </select>
          <input
            type="tel"
            placeholder="+41 79 123 45 67"
            value={addRaw}
            onChange={(e) => setAddRaw(e.target.value)}
            onKeyDown={(e) => { if (e.key === 'Enter') add() }}
            style={{ fontSize: 'var(--text-body)', padding: 'var(--space-1) var(--space-2)', borderRadius: 'var(--radius-sm)', border: '1px solid var(--border-secondary)', flex: 1, minWidth: '10rem' }}
          />
          <button
            type="button"
            onClick={add}
            style={{ fontSize: 'var(--text-label)', fontWeight: 'var(--weight-medium)', padding: 'var(--space-1) var(--space-3)', borderRadius: 'var(--radius-sm)', background: 'var(--brand-blue)', color: '#fff', border: 'none', cursor: 'pointer' }}
          >
            Hinzufügen
          </button>
          {addError && (
            <span style={{ fontSize: 'var(--text-meta)', color: 'var(--brand-red)', width: '100%' }}>
              {addError}
            </span>
          )}
        </div>
      )}
    </div>
  )
}
