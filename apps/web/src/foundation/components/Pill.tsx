/**
 * Pill — semantic badge / status indicator.
 *
 * Foundation rules:
 *   - Five tones: neutral, brand, success, warning, danger.
 *   - Three sizes: sm (badge), md (default), lg (hero kpi).
 *   - radius-sm only — pills never use radius-md/lg.
 *   - Uppercase reserved for `tone="muted"` small-caps usage.
 */

import type { ReactNode } from 'react'
import './Pill.css'

export type PillTone = 'neutral' | 'brand' | 'success' | 'warning' | 'danger' | 'info' | 'pro'
export type PillSize = 'sm' | 'md' | 'lg'

export interface PillProps {
  children: ReactNode
  tone?: PillTone
  size?: PillSize
  /** Render as small-caps section divider style. */
  smallCaps?: boolean
  /** Optional leading icon. */
  icon?: ReactNode
  /** Click handler — when set, renders as button. */
  onClick?: () => void
  className?: string
}

export function Pill({
  children,
  tone = 'neutral',
  size = 'md',
  smallCaps = false,
  icon,
  onClick,
  className,
}: PillProps) {
  const cls = [
    'atoll-pill',
    `atoll-pill--${tone}`,
    `atoll-pill--${size}`,
    smallCaps && 'atoll-pill--smallcaps',
    onClick && 'atoll-pill--clickable',
    className,
  ]
    .filter(Boolean)
    .join(' ')

  if (onClick) {
    return (
      <button type="button" className={cls} onClick={onClick}>
        {icon && <span className="atoll-pill__icon">{icon}</span>}
        <span className="atoll-pill__label">{children}</span>
      </button>
    )
  }

  return (
    <span className={cls}>
      {icon && <span className="atoll-pill__icon">{icon}</span>}
      <span className="atoll-pill__label">{children}</span>
    </span>
  )
}
