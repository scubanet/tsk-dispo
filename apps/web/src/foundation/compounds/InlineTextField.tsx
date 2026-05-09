/**
 * InlineTextField — inline-edit for plain text (single or multi-line).
 *
 * Wraps InlineField with an <input type="text"> or <textarea>.
 * Commits on Enter (single-line) or explicit onCommit. Cancels on Escape.
 */

import { useState, useCallback } from 'react'
import { InlineField } from './InlineField'

export interface InlineTextFieldProps {
  label: string
  value: string | null | undefined
  onCommit: (value: string) => Promise<void>
  placeholder?: string
  multiline?: boolean
  disabled?: boolean
}

export function InlineTextField({
  label,
  value,
  onCommit,
  placeholder,
  multiline = false,
  disabled = false,
}: InlineTextFieldProps) {
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
    if (draft === (value ?? '')) {
      setEditing(false)
      return
    }
    setSaving(true)
    setError(null)
    try {
      await onCommit(draft)
      setEditing(false)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Fehler beim Speichern')
    } finally {
      setSaving(false)
    }
  }, [draft, value, onCommit])

  return (
    <InlineField
      label={label}
      displayValue={value ?? undefined}
      editing={editing}
      saving={saving}
      error={error}
      disabled={disabled}
      onStartEdit={startEdit}
      onCancel={cancel}
      onEnter={multiline ? undefined : commit}
    >
      {multiline ? (
        <textarea
          value={draft}
          onChange={(e) => setDraft(e.target.value)}
          placeholder={placeholder}
          rows={3}
          disabled={saving}
          onBlur={commit}
        />
      ) : (
        <input
          type="text"
          value={draft}
          onChange={(e) => setDraft(e.target.value)}
          placeholder={placeholder}
          disabled={saving}
          onBlur={commit}
        />
      )}
    </InlineField>
  )
}
