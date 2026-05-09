/**
 * EmailList — edit list of EmailEntry[].
 *
 * Features:
 * - Renders each email with label badge, mailto: link, PRIMARY badge
 * - "Primär setzen" / "×" buttons per row
 * - Add-row with label dropdown + email input + "Hinzufügen" button
 * - Validates via regex
 */

import { useState } from 'react'
import type { EmailEntry } from '@/types/contacts'

const LABEL_OPTIONS = ['work', 'personal', 'other']
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/

export interface EmailListProps {
  emails: EmailEntry[]
  onChange: (next: EmailEntry[]) => Promise<void>
  disabled?: boolean
}

export function EmailList({ emails, onChange, disabled = false }: EmailListProps) {
  const [addLabel, setAddLabel] = useState('work')
  const [addEmail, setAddEmail] = useState('')
  const [addError, setAddError] = useState<string | null>(null)
  const [saving, setSaving] = useState(false)

  async function save(next: EmailEntry[]) {
    setSaving(true)
    try {
      await onChange(next)
    } finally {
      setSaving(false)
    }
  }

  async function makePrimary(idx: number) {
    const next = emails.map((e, i) => ({ ...e, primary: i === idx }))
    await save(next)
  }

  async function remove(idx: number) {
    const next = emails.filter((_, i) => i !== idx)
    if (emails[idx].primary && next.length > 0) {
      next[0] = { ...next[0], primary: true }
    }
    await save(next)
  }

  async function add() {
    setAddError(null)
    if (!EMAIL_RE.test(addEmail.trim())) {
      setAddError('Ungültige E-Mail-Adresse')
      return
    }
    const isPrimary = emails.length === 0
    const next: EmailEntry[] = [
      ...emails,
      { label: addLabel, email: addEmail.trim(), primary: isPrimary },
    ]
    await save(next)
    setAddEmail('')
  }

  const isDisabled = disabled || saving

  return (
    <div className="email-list">
      {emails.map((e, i) => (
        <div key={i} className="email-list__row">
          <span className="contact-list-badge">{e.label}</span>
          <a
            href={`mailto:${e.email}`}
            style={{ flex: 1, fontSize: 'var(--text-body)', color: 'var(--text-primary)', textDecoration: 'none' }}
          >
            {e.email}
          </a>
          {e.primary && (
            <span className="contact-list-badge contact-list-badge--primary">Primär</span>
          )}
          {!e.primary && !isDisabled && (
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
        <div className="email-list__add">
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
            type="email"
            placeholder="name@beispiel.ch"
            value={addEmail}
            onChange={(e) => setAddEmail(e.target.value)}
            onKeyDown={(e) => { if (e.key === 'Enter') add() }}
            style={{ fontSize: 'var(--text-body)', padding: 'var(--space-1) var(--space-2)', borderRadius: 'var(--radius-sm)', border: '1px solid var(--border-secondary)', flex: 1, minWidth: '12rem' }}
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
