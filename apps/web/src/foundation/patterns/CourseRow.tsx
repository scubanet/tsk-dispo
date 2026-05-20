/**
 * CourseRow — list row for a single course.
 *
 * Layout:
 *   [color dot] | Course Title         |  Date · Status |  >
 *               | sub: students/staff  |
 *
 * Foundation rules:
 *   - Color dot uses `courseTypeColor()` from /lib/colors.
 *   - 56px row height.
 *   - Click handler upgrades the row to a button with focus-ring.
 *   - Active state highlights with brand-blue-50 background.
 */

import type { ReactNode } from 'react'
import type { CourseType } from '@/types/foundation'
import { courseTypeColor } from '../lib/colors'
import { Icon } from '../lib/icons'
import './CourseRow.css'

export interface CourseRowProps {
  courseType: CourseType
  title: string
  /** Right-aligned label — typically a date or status. */
  meta?: ReactNode
  /** Sub-line under title. */
  sub?: ReactNode
  active?: boolean
  onClick?: () => void
  /** Trailing pill or icon (after meta). */
  trailing?: ReactNode
  ariaLabel?: string
}

export function CourseRow({
  courseType,
  title,
  meta,
  sub,
  active = false,
  onClick,
  trailing,
  ariaLabel,
}: CourseRowProps) {
  const cls = [
    'atoll-courserow',
    active && 'atoll-courserow--active',
    onClick && 'atoll-courserow--clickable',
  ]
    .filter(Boolean)
    .join(' ')

  const content = (
    <>
      <span
        className="atoll-courserow__dot"
        style={{ background: courseTypeColor(courseType) }}
        aria-hidden
      />
      <span className="atoll-courserow__main">
        <span className="atoll-courserow__title">{title}</span>
        {sub && <span className="atoll-courserow__sub">{sub}</span>}
      </span>
      {meta && <span className="atoll-courserow__meta tabular-nums">{meta}</span>}
      {trailing && <span className="atoll-courserow__trailing">{trailing}</span>}
      {onClick && <Icon.ChevronRight size={16} className="atoll-courserow__chevron" aria-hidden />}
    </>
  )

  if (onClick) {
    return (
      <button
        type="button"
        className={cls}
        onClick={onClick}
        aria-label={ariaLabel ?? title}
        aria-current={active ? 'true' : undefined}
      >
        {content}
      </button>
    )
  }

  return <div className={cls}>{content}</div>
}
