/**
 * KpiCard — three variants:
 *   - hero  : large brand-deep background, white text (top-of-page anchor)
 *   - stat  : neutral white card with primary label + tabular value
 *   - alert : amber/red tint when count > 0, otherwise neutral
 *
 * Foundation rules:
 *   - All numeric values render with tabular-nums.
 *   - Card uses radius-md (10px). Hero uses radius-lg (14px).
 *   - Click handler upgrades the card to a button with focus-ring.
 */

import type { ReactNode } from 'react'
import './KpiCard.css'

export type KpiVariant = 'hero' | 'stat' | 'alert'

export interface KpiCardProps {
  label: string
  value: ReactNode
  /** Optional secondary text under the value. */
  sub?: ReactNode
  /** Optional leading icon (16px). */
  icon?: ReactNode
  variant?: KpiVariant
  /** Alert tone — only applied when variant='alert'. Default: 'warning'. */
  alertTone?: 'warning' | 'danger'
  /** Click handler — when set, renders as button. */
  onClick?: () => void
  ariaLabel?: string
}

export function KpiCard({
  label,
  value,
  sub,
  icon,
  variant = 'stat',
  alertTone = 'warning',
  onClick,
  ariaLabel,
}: KpiCardProps) {
  const cls = [
    'atoll-kpi',
    `atoll-kpi--${variant}`,
    variant === 'alert' && `atoll-kpi--alert-${alertTone}`,
    onClick && 'atoll-kpi--clickable',
  ]
    .filter(Boolean)
    .join(' ')

  const inner = (
    <>
      <div className="atoll-kpi__head">
        {icon && <span className="atoll-kpi__icon">{icon}</span>}
        <span className="atoll-kpi__label">{label}</span>
      </div>
      <span className="atoll-kpi__value tabular-nums">{value}</span>
      {sub && <span className="atoll-kpi__sub">{sub}</span>}
    </>
  )

  if (onClick) {
    return (
      <button
        type="button"
        className={cls}
        onClick={onClick}
        aria-label={ariaLabel ?? label}
      >
        {inner}
      </button>
    )
  }

  return <div className={cls}>{inner}</div>
}
