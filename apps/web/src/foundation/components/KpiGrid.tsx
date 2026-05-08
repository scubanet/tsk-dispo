/**
 * KpiGrid — responsive grid wrapper for KpiCards.
 *
 * Default: auto-fit minmax(200px, 1fr) — KpiCards expand to fill row.
 * The optional `columns` prop locks a fixed column count.
 */

import type { ReactNode } from 'react'
import './KpiGrid.css'

export interface KpiGridProps {
  children: ReactNode
  /** Lock to a specific column count instead of auto-fit. */
  columns?: 2 | 3 | 4
  /** Gap between cards. Default: var(--space-3) = 12px. */
  gap?: 'sm' | 'md' | 'lg'
}

export function KpiGrid({ children, columns, gap = 'md' }: KpiGridProps) {
  const cls = [
    'atoll-kpigrid',
    `atoll-kpigrid--gap-${gap}`,
    columns && `atoll-kpigrid--cols-${columns}`,
  ]
    .filter(Boolean)
    .join(' ')
  return <div className={cls}>{children}</div>
}
