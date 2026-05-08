/**
 * Master-Detail layout primitives — ListPane + DetailPane.
 *
 *   <MasterDetail>
 *     <ListPane>...</ListPane>
 *     <DetailPane>...</DetailPane>
 *   </MasterDetail>
 *
 * Foundation rules:
 *   - 320px list pane, 1fr detail pane on desktop.
 *   - On mobile, only one pane visible at a time (state managed by caller).
 *   - Both panes scroll independently.
 */

import type { ReactNode } from 'react'
import './MasterDetail.css'

export interface MasterDetailProps {
  children: ReactNode
}

export function MasterDetail({ children }: MasterDetailProps) {
  return <div className="atoll-md">{children}</div>
}

export interface ListPaneProps {
  children: ReactNode
  /** Sticky toolbar at the top (FilterTabBar, SearchInput, etc.). */
  toolbar?: ReactNode
}

export function ListPane({ children, toolbar }: ListPaneProps) {
  return (
    <aside className="atoll-md__list">
      {toolbar && <div className="atoll-md__list-toolbar">{toolbar}</div>}
      <div className="atoll-md__list-body" data-scroll>
        {children}
      </div>
    </aside>
  )
}

export interface DetailPaneProps {
  children: ReactNode
  /** Sticky header (PageHeader, Tabs). */
  header?: ReactNode
}

export function DetailPane({ children, header }: DetailPaneProps) {
  return (
    <section className="atoll-md__detail">
      {header && <div className="atoll-md__detail-header">{header}</div>}
      <div className="atoll-md__detail-body" data-scroll>
        {children}
      </div>
    </section>
  )
}
