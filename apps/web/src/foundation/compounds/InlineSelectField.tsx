/**
 * InlineSelectField — inline-edit for enum / option lists.
 *
 * Wraps InlineField with a <select>. Commits immediately on change.
 * Cancels on Escape.
 */

import { useState, useCallback } from 'react'
import { InlineField } from './InlineField'

export interface SelectOption {
  value: string
  label: string
}

export interface InlineSelectFieldProps {
  label: string
  value: string | null | undefined
  options: SelectOption[]
  onCommit: (value: string) => Promise<void>
  /** If true, an empty option ("—") is prepended to the list. */
  allowEmpty?: boolean
  disabled?: boolean
}

export function InlineSelectField({
  label,
  value,
  options,
  onCommit,
  allowEmpty = false,
  disabled = false,
}: InlineSelectFieldProps) {
  const [editing, setEditing] = useState(false)
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const startEdit = useCallback(() => {
    if (disabled) return
    setError(null)
    setEditing(true)
  }, [disabled])

  const cancel = useCallback(() => {
    setEditing(false)
    setError(null)
  }, [])

  const commit = useCallback(
    async (next: string) => {
      if (next === (value ?? '')) {
        setEditing(false)
        return
      }
      setSaving(true)
      setError(null)
      try {
        await onCommit(next)
        setEditing(false)
      } catch (err) {
        setError(err instanceof Error ? err.message : 'Fehler beim Speichern')
      } finally {
        setSaving(false)
      }
    },
    [value, onCommit],
  )

  const displayLabel =
    options.find((o) => o.value === value)?.label ?? value ?? undefined

  return (
    <InlineField
      label={label}
      displayValue={displayLabel}
      editing={editing}
      saving={saving}
      error={error}
      disabled={disabled}
      onStartEdit={startEdit}
      onCancel={cancel}
    >
      <select
        defaultValue={value ?? ''}
        disabled={saving}
        onChange={(e) => commit(e.target.value)}
        onBlur={cancel}
      >
        {allowEmpty && <option value="">—</option>}
        {options.map((o) => (
          <option key={o.value} value={o.value}>
            {o.label}
          </option>
        ))}
      </select>
    </InlineField>
  )
}
