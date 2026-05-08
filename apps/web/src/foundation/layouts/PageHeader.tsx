/**
 * PageHeader — page title bar with optional breadcrumbs / actions.
 *
 * Foundation rules:
 *   - h1 = 22px medium, sentence-case (never UPPERCASE).
 *   - Subtitle in secondary color, 13px regular.
 *   - Right-side action slot (typically Buttons or Pills).
 */

import type { ReactNode } from 'react'
import './PageHeader.css'

export interface PageHeaderProps {
  title: ReactNode
  subtitle?: ReactNode
  /** Right-aligned actions (buttons, pills, etc.) */
  actions?: ReactNode
  /** Slot below title — typically FilterTabBar or breadcrumbs. */
  belowTitle?: ReactNode
}

export function PageHeader({ title, subtitle, actions, belowTitle }: PageHeaderProps) {
  return (
    <header className="atoll-pageheader">
      <div className="atoll-pageheader__row">
        <div className="atoll-pageheader__main">
          <h1 className="atoll-pageheader__title">{title}</h1>
          {subtitle && <div className="atoll-pageheader__subtitle">{subtitle}</div>}
        </div>
        {actions && <div className="atoll-pageheader__actions">{actions}</div>}
      </div>
      {belowTitle && <div className="atoll-pageheader__below">{belowTitle}</div>}
    </header>
  )
}
