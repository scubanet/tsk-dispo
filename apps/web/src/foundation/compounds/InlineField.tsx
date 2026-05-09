/**
 * InlineField — generic inline-edit wrapper.
 *
 * Renders a label + a clickable display value. On click (or Enter) it
 * switches to edit mode. The caller renders the actual input as `children`.
 *
 * Keyboard: Enter commits, Escape cancels.
 * Disabled prop blocks all interaction.
 *
 * Usage pattern:
 *   <InlineField
 *     label="Vorname"
 *     displayValue={firstName || undefined}
 *     editing={editing}
 *     saving={saving}
 *     error={error}
 *     onStartEdit={() => setEditing(true)}
 *     onCancel={() => setEditing(false)}
 *   >
 *     <input … />
 *   </InlineField>
 */

import { useEffect, useRef } from 'react'
import '@/styles/tokens.css'

export interface InlineFieldProps {
  label: string
  /** Rendered when not in edit mode. Undefined → shows the empty dash. */
  displayValue?: string
  editing: boolean
  saving?: boolean
  error?: string | null
  disabled?: boolean
  onStartEdit: () => void
  onCancel: () => void
  /** Called when the wrapper detects Enter key on the edit area. */
  onEnter?: () => void
  children: React.ReactNode
}

export function InlineField({
  label,
  displayValue,
  editing,
  saving = false,
  error,
  disabled = false,
  onStartEdit,
  onCancel,
  onEnter,
  children,
}: InlineFieldProps) {
  const editRef = useRef<HTMLDivElement>(null)

  // Focus first focusable child when edit mode opens
  useEffect(() => {
    if (editing && editRef.current) {
      const focusable = editRef.current.querySelector<HTMLElement>(
        'input, textarea, select',
      )
      focusable?.focus()
    }
  }, [editing])

  const handleDisplayKeyDown = (e: React.KeyboardEvent) => {
    if (disabled) return
    if (e.key === 'Enter' || e.key === ' ') {
      e.preventDefault()
      onStartEdit()
    }
  }

  const handleEditKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Escape') {
      e.stopPropagation()
      onCancel()
    } else if (e.key === 'Enter' && onEnter) {
      e.preventDefault()
      onEnter()
    }
  }

  return (
    <div
      className="inline-field"
      data-saving={saving ? 'true' : undefined}
    >
      <span className="inline-field__label">{label}</span>

      {editing ? (
        <div
          ref={editRef}
          className="inline-field__edit"
          onKeyDown={handleEditKeyDown}
        >
          {children}
          {error && <span className="inline-field__error">{error}</span>}
        </div>
      ) : (
        <div
          className="inline-field__display"
          role={disabled ? undefined : 'button'}
          tabIndex={disabled ? undefined : 0}
          onClick={disabled ? undefined : onStartEdit}
          onKeyDown={handleDisplayKeyDown}
          aria-label={`${label} bearbeiten`}
        >
          {displayValue ? (
            displayValue
          ) : (
            <span className="inline-field__empty">—</span>
          )}
        </div>
      )}
    </div>
  )
}
