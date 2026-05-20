/**
 * ChecklistItem — single row in a checklist (intake, IDC prerequisites etc).
 *
 * States: pending (empty circle), done (filled check), warning (amber), n/a (greyed).
 *
 * Foundation rules:
 *   - Click toggles pending ↔ done unless onClick is provided (then external).
 *   - 36px row height — matches CourseRow.
 */

import type { ReactNode } from 'react'
import { Icon } from '../lib/icons'
import './ChecklistItem.css'

export type ChecklistState = 'pending' | 'done' | 'warning' | 'na'

export interface ChecklistItemProps {
  state: ChecklistState
  label: ReactNode
  /** Optional secondary line. */
  meta?: ReactNode
  /** Click handler — when set, row is interactive. */
  onClick?: () => void
  ariaLabel?: string
}

export function ChecklistItem({
  state,
  label,
  meta,
  onClick,
  ariaLabel,
}: ChecklistItemProps) {
  const cls = [
    'atoll-checklist',
    `atoll-checklist--${state}`,
    onClick && 'atoll-checklist--clickable',
  ]
    .filter(Boolean)
    .join(' ')

  const inner = (
    <>
      <span className="atoll-checklist__indicator" aria-hidden>
        {state === 'done' && <Icon.Check size={12} />}
        {state === 'warning' && <Icon.Warning size={12} />}
      </span>
      <span className="atoll-checklist__label">{label}</span>
      {meta && <span className="atoll-checklist__meta">{meta}</span>}
    </>
  )

  if (onClick) {
    return (
      <button
        type="button"
        className={cls}
        onClick={onClick}
        aria-label={ariaLabel ?? (typeof label === 'string' ? label : undefined)}
      >
        {inner}
      </button>
    )
  }

  return <div className={cls}>{inner}</div>
}
