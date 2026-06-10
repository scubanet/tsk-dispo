/**
 * Stepper — compact −/+ numeric control for quantities.
 *
 * Foundation rules:
 *   - Pill container (radius-pill), 0.5px hairline, accent affordances.
 *   - Value stays a real <input> so direct typing keeps working; the
 *     buttons are the fast path. Tabular-nums (global utility) for stable width.
 *   - While the field is being edited it holds a local draft string, so the
 *     user can clear it and type a multi-digit number without it snapping to
 *     min mid-keystroke. On blur the draft is committed + clamped.
 *   - Clamps to [min, max]; buttons disable at the bounds.
 *
 * Reusable anywhere a small integer needs in-place adjustment
 * (cart quantities, seat counts, participant numbers, …).
 */

import { useState } from 'react'
import './Stepper.css'

export interface StepperProps {
  value: number
  onChange: (value: number) => void
  min?: number
  max?: number
  step?: number
  /** Accessible label for the group (e.g. "Menge"). */
  ariaLabel?: string
}

export function Stepper({ value, onChange, min = 1, max = 9999, step = 1, ariaLabel }: StepperProps) {
  const clamp = (n: number) => Math.min(max, Math.max(min, n))
  const [draft, setDraft] = useState<string | null>(null)
  const dec = () => { setDraft(null); onChange(clamp(value - step)) }
  const inc = () => { setDraft(null); onChange(clamp(value + step)) }

  return (
    <div className="atoll-stepper" role="group" aria-label={ariaLabel}>
      <button type="button" className="atoll-stepper__btn" onClick={dec} disabled={value <= min} aria-label="−">
        −
      </button>
      <input
        className="atoll-stepper__val tabular-nums"
        type="number"
        inputMode="numeric"
        value={draft ?? String(value)}
        min={min}
        max={max}
        step={step}
        onChange={(e) => {
          const raw = e.target.value
          setDraft(raw)
          const n = Number(raw)
          if (raw !== '' && !Number.isNaN(n)) onChange(clamp(n))
        }}
        onBlur={() => {
          const n = Number(draft)
          if (draft === '' || Number.isNaN(n)) onChange(min)
          setDraft(null)
        }}
      />
      <button type="button" className="atoll-stepper__btn" onClick={inc} disabled={value >= max} aria-label="+">
        +
      </button>
    </div>
  )
}
