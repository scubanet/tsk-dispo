/**
 * InlineDateField — inline-edit for ISO date strings (YYYY-MM-DD).
 *
 * Display:  `dd.mm.yyyy` (Europäisches Format)
 * Edit:     native `<input type="date">` — Browser nutzt System-Locale,
 *           DB-Wert bleibt ISO.
 * Commit:   leerer String → null, sonst ISO-String.
 */

import { useState, useCallback } from 'react'
import { useTranslation } from 'react-i18next'
import { InlineField } from './InlineField'

export interface InlineDateFieldProps {
  label: string
  /** ISO date string (YYYY-MM-DD) or null/undefined. */
  value: string | null | undefined
  /** Called with new ISO string or null (when cleared). */
  onCommit: (value: string | null) => Promise<void>
  placeholder?: string
  disabled?: boolean
  /** Optional muted suffix next to the value in display mode (e.g. age). */
  displayExtra?: React.ReactNode
}

/** "YYYY-MM-DD" → "DD.MM.YYYY". Returns the input unchanged if not a valid ISO date. */
function toDisplay(iso: string | null | undefined): string | undefined {
  if (!iso) return undefined
  const m = iso.match(/^(\d{4})-(\d{2})-(\d{2})/)
  return m ? `${m[3]}.${m[2]}.${m[1]}` : iso
}

export function InlineDateField({
  label,
  value,
  onCommit,
  placeholder,
  disabled = false,
  displayExtra,
}: InlineDateFieldProps) {
  const { t } = useTranslation()
  const [editing, setEditing] = useState(false)
  const [draft, setDraft] = useState('')
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const startEdit = useCallback(() => {
    if (disabled) return
    setDraft(value ?? '')
    setError(null)
    setEditing(true)
  }, [disabled, value])

  const cancel = useCallback(() => {
    setEditing(false)
    setError(null)
  }, [])

  const commit = useCallback(async () => {
    const next = draft.trim() === '' ? null : draft
    if (next === (value ?? null)) {
      setEditing(false)
      return
    }
    setSaving(true)
    setError(null)
    try {
      await onCommit(next)
      setEditing(false)
    } catch (err) {
      setError(err instanceof Error ? err.message : t('contacts.rel_error_save'))
    } finally {
      setSaving(false)
    }
  }, [draft, value, onCommit, t])

  return (
    <InlineField
      label={label}
      displayValue={toDisplay(value)}
      displayExtra={displayExtra}
      editing={editing}
      saving={saving}
      error={error}
      disabled={disabled}
      onStartEdit={startEdit}
      onCancel={cancel}
      onEnter={commit}
    >
      <input
        type="date"
        value={draft}
        onChange={(e) => setDraft(e.target.value)}
        placeholder={placeholder}
        disabled={saving}
        onBlur={commit}
      />
    </InlineField>
  )
}
