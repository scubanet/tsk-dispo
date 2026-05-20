/**
 * SortDropdown — native <select> styled to match foundation inputs.
 *
 * Foundation rules:
 *   - Uses real <select> for accessibility + native keyboard support.
 *   - Custom chevron via background-image (SVG data URL).
 *   - 32px height to match SearchInput.
 */

import { useId } from 'react'
import './SortDropdown.css'

export interface SortOption<T extends string = string> {
  id: T
  label: string
}

export interface SortDropdownProps<T extends string = string> {
  options: SortOption<T>[]
  value: T
  onChange: (id: T) => void
  ariaLabel: string
  /** Optional leading label rendered as small-caps. */
  labelText?: string
}

export function SortDropdown<T extends string>({
  options,
  value,
  onChange,
  ariaLabel,
  labelText,
}: SortDropdownProps<T>) {
  const id = useId()

  return (
    <div className="atoll-sort">
      {labelText && (
        <label htmlFor={id} className="atoll-sort__label small-caps">
          {labelText}
        </label>
      )}
      <select
        id={id}
        className="atoll-sort__select"
        value={value}
        onChange={(e) => onChange(e.target.value as T)}
        aria-label={ariaLabel}
      >
        {options.map((opt) => (
          <option key={opt.id} value={opt.id}>
            {opt.label}
          </option>
        ))}
      </select>
    </div>
  )
}
