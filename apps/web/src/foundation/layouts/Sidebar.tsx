/**
 * Sidebar — vertical nav with logo header and grouped sections.
 *
 * Composition:
 *   <Sidebar>
 *     <Sidebar.Header>...</Sidebar.Header>
 *     <Sidebar.Section title="VERWALTUNG">
 *       <SidebarNavItem icon={<Icon.Home />} label="Heute" active />
 *       ...
 *     </Sidebar.Section>
 *     <Sidebar.Footer>...</Sidebar.Footer>
 *   </Sidebar>
 */

import type { ReactNode } from 'react'
import './Sidebar.css'

interface SidebarRootProps {
  children: ReactNode
}

function SidebarRoot({ children }: SidebarRootProps) {
  return <nav className="atoll-sidebar">{children}</nav>
}

function SidebarHeader({ children }: { children: ReactNode }) {
  return <div className="atoll-sidebar__header">{children}</div>
}

function SidebarSection({ title, children }: { title?: string; children: ReactNode }) {
  return (
    <section className="atoll-sidebar__section">
      {title && <div className="atoll-sidebar__section-title small-caps">{title}</div>}
      <div className="atoll-sidebar__section-items">{children}</div>
    </section>
  )
}

function SidebarFooter({ children }: { children: ReactNode }) {
  return <div className="atoll-sidebar__footer">{children}</div>
}

export const Sidebar = Object.assign(SidebarRoot, {
  Header: SidebarHeader,
  Section: SidebarSection,
  Footer: SidebarFooter,
})

export interface SidebarNavItemProps {
  icon?: ReactNode
  label: ReactNode
  active?: boolean
  /** Optional trailing badge / count. */
  trailing?: ReactNode
  onClick?: () => void
  href?: string
}

export function SidebarNavItem({
  icon,
  label,
  active = false,
  trailing,
  onClick,
  href,
}: SidebarNavItemProps) {
  const cls = `atoll-sidebar__item${active ? ' atoll-sidebar__item--active' : ''}`
  const content = (
    <>
      {icon && <span className="atoll-sidebar__item-icon">{icon}</span>}
      <span className="atoll-sidebar__item-label">{label}</span>
      {trailing && <span className="atoll-sidebar__item-trailing">{trailing}</span>}
    </>
  )

  if (href) {
    return (
      <a href={href} className={cls} aria-current={active ? 'page' : undefined}>
        {content}
      </a>
    )
  }

  return (
    <button
      type="button"
      className={cls}
      onClick={onClick}
      aria-current={active ? 'page' : undefined}
    >
      {content}
    </button>
  )
}
