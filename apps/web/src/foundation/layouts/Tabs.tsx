/**
 * Tabs — controlled tab strip + matching panel.
 *
 * Difference from FilterTabBar:
 *   - Tabs control which *content panel* is visible (not a list filter).
 *   - Includes the tab strip + the panel container; you pass `panels` keyed by id.
 *   - Selected panel uses role="tabpanel" with proper ARIA links.
 *
 * Foundation rules:
 *   - 36px tabstrip height.
 *   - Brand-blue underline on active tab.
 *   - Keyboard: ArrowLeft/Right to navigate; activates on focus.
 */

import { useId, useRef, type ReactNode } from 'react'
import './Tabs.css'

export interface TabDefinition<T extends string = string> {
  id: T
  label: ReactNode
  count?: number
}

export interface TabsProps<T extends string = string> {
  tabs: TabDefinition<T>[]
  active: T
  onChange: (id: T) => void
  ariaLabel: string
  /** Map of panel content keyed by tab id. */
  panels: Record<T, ReactNode>
}

export function Tabs<T extends string>({
  tabs,
  active,
  onChange,
  ariaLabel,
  panels,
}: TabsProps<T>) {
  const baseId = useId()
  const refs = useRef<Map<T, HTMLButtonElement>>(new Map())

  function handleKeyDown(e: React.KeyboardEvent<HTMLButtonElement>, id: T) {
    if (e.key !== 'ArrowLeft' && e.key !== 'ArrowRight') return
    e.preventDefault()
    const idx = tabs.findIndex((t) => t.id === id)
    if (idx < 0) return
    const next = e.key === 'ArrowLeft' ? (idx - 1 + tabs.length) % tabs.length : (idx + 1) % tabs.length
    const nextTab = tabs[next]
    onChange(nextTab.id)
    refs.current.get(nextTab.id)?.focus()
  }

  return (
    <div className="atoll-tabs">
      <div role="tablist" aria-label={ariaLabel} className="atoll-tabs__strip">
        {tabs.map((tab) => {
          const tabId = `${baseId}-tab-${tab.id}`
          const panelId = `${baseId}-panel-${tab.id}`
          const isActive = tab.id === active
          return (
            <button
              key={tab.id}
              ref={(el) => {
                if (el) refs.current.set(tab.id, el)
                else refs.current.delete(tab.id)
              }}
              id={tabId}
              type="button"
              role="tab"
              aria-selected={isActive}
              aria-controls={panelId}
              tabIndex={isActive ? 0 : -1}
              className={`atoll-tabs__tab${isActive ? ' atoll-tabs__tab--active' : ''}`}
              onClick={() => onChange(tab.id)}
              onKeyDown={(e) => handleKeyDown(e, tab.id)}
            >
              <span>{tab.label}</span>
              {typeof tab.count === 'number' && (
                <span className="atoll-tabs__count tabular-nums">{tab.count}</span>
              )}
            </button>
          )
        })}
      </div>
      {tabs.map((tab) => {
        const tabId = `${baseId}-tab-${tab.id}`
        const panelId = `${baseId}-panel-${tab.id}`
        const isActive = tab.id === active
        return (
          <div
            key={tab.id}
            id={panelId}
            role="tabpanel"
            aria-labelledby={tabId}
            hidden={!isActive}
            className="atoll-tabs__panel"
          >
            {isActive && panels[tab.id]}
          </div>
        )
      })}
    </div>
  )
}
