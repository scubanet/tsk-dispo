/**
 * AppShell — top-level layout: Sidebar + main pane.
 *
 * Foundation rules:
 *   - 240px fixed sidebar on desktop, hidden on mobile.
 *   - Main pane scrolls; sidebar is fixed.
 *   - Sand background page-wide; cards introduce the white surface.
 */

import type { ReactNode } from 'react'
import './AppShell.css'

export interface AppShellProps {
  sidebar: ReactNode
  children: ReactNode
}

export function AppShell({ sidebar, children }: AppShellProps) {
  return (
    <div className="atoll-shell">
      <aside className="atoll-shell__sidebar">{sidebar}</aside>
      <main className="atoll-shell__main">{children}</main>
    </div>
  )
}
