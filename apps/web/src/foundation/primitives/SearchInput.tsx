/**
 * SearchInput — text field with leading magnifier and optional clear button.
 *
 * Foundation rules:
 *   - Always 32px tall in md size (matches list-row height).
 *   - Uses inset focus-ring (foundation focus-ring on inputs).
 *   - aria-label required; placeholder is supplemental.
 */

import { useId, type ChangeEvent, type KeyboardEvent } from 'react'
import { Icon } from '../lib/icons'
import './SearchInput.css'

export type SearchInputSize = 'sm' | 'md'

export interface SearchInputProps {
  value: string
  onChange: (value: string) => void
  /** Triggered when user presses Escape with non-empty value, then again to blur. */
  onClear?: () => void
  placeholder?: string
  /** Required for a11y. */
  ariaLabel: string
  size?: SearchInputSize
  autoFocus?: boolean
  disabled?: boolean
}

export function SearchInput({
  value,
  onChange,
  onClear,
  placeholder,
  ariaLabel,
  size = 'md',
  autoFocus,
  disabled,
}: SearchInputProps) {
  const id = useId()

  function handleChange(e: ChangeEvent<HTMLInputElement>) {
    onChange(e.target.value)
  }

  function handleClear() {
    onChange('')
    onClear?.()
  }

  function handleKeyDown(e: KeyboardEvent<HTMLInputElement>) {
    if (e.key === 'Escape') {
      if (value) {
        e.preventDefault()
        handleClear()
      }
    }
  }

  return (
    <label
      htmlFor={id}
      className={`atoll-search atoll-search--${size}${disabled ? ' atoll-search--disabled' : ''}`}
    >
      <Icon.Search className="atoll-search__icon" size={14} aria-hidden />
      <input
        id={id}
        type="search"
        className="atoll-search__input"
        value={value}
        onChange={handleChange}
        onKeyDown={handleKeyDown}
        placeholder={placeholder}
        aria-label={ariaLabel}
        autoFocus={autoFocus}
        disabled={disabled}
        autoComplete="off"
        spellCheck={false}
      />
      {value && !disabled && (
        <button
          type="button"
          className="atoll-search__clear"
          onClick={handleClear}
          aria-label="Suche leeren"
        >
          <Icon.Close size={12} aria-hidden />
        </button>
      )}
    </label>
  )
}
