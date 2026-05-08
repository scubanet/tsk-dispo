/**
 * FilterTabBar — segmented filter tabs with optional counts.
 *
 * Foundation rules:
 *   - Active tab uses brand-blue underline + medium weight.
 *   - Counts render as small subtle pills (tabular-nums).
 *   - Keyboard: ArrowLeft / ArrowRight cycles tabs.
 */

import { useRef } from 'react'
import './FilterTabBar.css'

export interface FilterTab<T extends string = string> {
  id: T
  label: string
  count?: number
}

export interface FilterTabBarProps<T extends string = string> {
  tabs: FilterTab<T>[]
  active: T
  onChange: (id: T) => void
  ariaLabel: string
}

export function FilterTabBar<T extends string>({
  tabs,
  active,
  onChange,
  ariaLabel,
}: FilterTabBarProps<T>) {
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
    <div className="atoll-filter-tabbar" role="tablist" aria-label={ariaLabel}>
      {tabs.map((tab) => {
        const isActive = tab.id === active
        return (
          <button
            key={tab.id}
            ref={(el) => {
              if (el) refs.current.set(tab.id, el)
              else refs.current.delete(tab.id)
            }}
            type="button"
            role="tab"
            aria-selected={isActive}
            tabIndex={isActive ? 0 : -1}
            className={`atoll-filter-tabbar__tab${isActive ? ' atoll-filter-tabbar__tab--active' : ''}`}
            onClick={() => onChange(tab.id)}
            onKeyDown={(e) => handleKeyDown(e, tab.id)}
          >
            <span className="atoll-filter-tabbar__label">{tab.label}</span>
            {typeof tab.count === 'number' && (
              <span className="atoll-filter-tabbar__count tabular-nums">{tab.count}</span>
            )}
          </button>
        )
      })}
    </div>
  )
}
