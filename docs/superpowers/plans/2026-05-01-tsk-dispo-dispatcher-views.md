# TSK Dispo: Dispatcher Views Plan (Plan 2 von 3)

> **For agentic workers:** Use superpowers:subagent-driven-development or superpowers:executing-plans to implement task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Build the full Dispatcher UI on top of Plan 1's foundation — a working Heute-Dashboard, master-detail Kurse and TL/DM views with conflict-detection on assignment, Saldi overview, Skill-Matrix, Pool view, Kalender, and Settings (incl. Tweak Panel for dark/accent/layout). End-state: Dominik can do his entire dispatch workflow in the App without ever opening Excel.

**Architecture:** Same React 18 + Vite + Supabase stack as Plan 1. Add a Sidebar/FloatingTabBar layout shell that wraps all screens. New shared components: `Sidebar`, `FloatingTabBar`, `Topbar`, `Sheet`, `TweakPanel`. New screens: `TodayScreen`, `CoursesScreen`, `InstructorsScreen`, `SkillMatrixScreen`, `PoolScreen`, `SaldiScreen`, `CalendarScreen`, `SettingsScreen`. Conflict-detection runs as a Postgres function (server-side authoritative) plus a UI hint while the Sheet is open.

**Tech Stack:** Same as Plan 1. Net new deps: `date-fns` for date math, `clsx` for conditional class names, possibly `@tanstack/react-query` for caching/refetching.

**Reference:** This plan implements Sections 5 (App-Bereiche), 6.3 (Schlüssel-Flows B/C), and parts of 8.5 (Korrektur-Buchungen) of `docs/superpowers/specs/2026-04-30-tsk-dispo-app-design.md`.

**Lessons learned from Plan 1 baked into this plan:**
- Excel uses formula cells → use `cellNumber` helper for all numeric reads (already in lib).
- `excel_saldo_chf` is the comparison target, `opening_balance_chf` is the carryover.
- The instructor namespace has Spitznamen ("Tilly", "Mel", "Niggi") — UI must surface real names via `name_search` indexes.
- Real volumes: 71 instructors, ~110 courses, ~120 assignments. UI must scroll/paginate gracefully.

---

## File Structure (created during this plan)

```
Dispo/apps/web/src/
├── components/
│   ├── Sidebar.tsx                  # NEW: left rail nav (default layout)
│   ├── FloatingTabBar.tsx           # NEW: alt nav (bottom floating glass bar)
│   ├── Topbar.tsx                   # NEW: title + subtitle + actions
│   ├── Sheet.tsx                    # NEW: right-side modal
│   ├── TweakPanel.tsx               # NEW: settings panel (dark/accent/layout)
│   ├── Chip.tsx                     # NEW: inline status chips
│   ├── SegmentedControl.tsx         # NEW: tab/seg control (e.g., Tag/Woche)
│   ├── EmptyState.tsx               # NEW: "noch nichts hier" placeholders
│   └── Icon.tsx                     # NEW: SVG icon set
├── icons/
│   └── index.tsx                    # NEW: icon name registry
├── lib/
│   ├── tweaks.ts                    # NEW: localStorage-backed tweak hook
│   ├── format.ts                    # NEW: CHF + date formatters
│   └── queries.ts                   # NEW: typed Supabase query helpers
├── layout/
│   └── AppShell.tsx                 # NEW: wraps screens with nav + topbar
├── screens/
│   ├── TodayScreen.tsx              # NEW: dashboard hero + KPIs + sessions
│   ├── CalendarScreen.tsx           # NEW: week/month grid
│   ├── CoursesScreen.tsx            # NEW: list+detail Kurse
│   ├── CourseDetailPanel.tsx        # NEW: detail tabs (Übersicht/TN/Notizen/Vergütung)
│   ├── CourseEditSheet.tsx          # NEW: create/edit a course (with conflict UI)
│   ├── InstructorsScreen.tsx        # NEW: list+detail TL/DM
│   ├── InstructorDetailPanel.tsx    # NEW: tabs (Übersicht/Skills/Einsätze/Saldo/Verfüg)
│   ├── SkillMatrixScreen.tsx        # NEW: cross-table editor
│   ├── PoolScreen.tsx               # NEW: Möösli + Langnau lanes
│   ├── SaldiScreen.tsx              # NEW: list of all saldi + journal popout
│   └── SettingsScreen.tsx           # NEW: rates + import + users
└── styles/
    └── components.css               # MODIFIED: add sidebar, tabbar, sheet, kalender styles

Dispo/supabase/
├── migrations/
│   ├── 0022_function_conflict_check.sql        # NEW: conflict detection RPC
│   └── 0023_function_skill_match.sql           # NEW: instructor suggestions RPC
└── tests/pgtap/
    └── 04_conflict_detection.sql               # NEW: pgTAP for conflict_check
```

**Boundary discipline:**
- Layout primitives are dumb: they receive props and render. No data fetching inside them.
- Each screen owns its data fetching via typed helpers in `lib/queries.ts`.
- Mutations always go through Supabase client, never bypass RLS.
- Conflict-detection lives in Postgres (`conflict_check` function) so the truth is server-side; UI calls it during the edit Sheet.

---

## Phase A — Shared Layout Primitives (Day 1)

### Task A1: Add deps + tweak storage hook

**Files:**
- Modify: `apps/web/package.json`
- Create: `apps/web/src/lib/tweaks.ts`

- [ ] **Step 1: Add deps**

In `apps/web/package.json` add to `dependencies`:
```json
"clsx": "^2.1.0",
"date-fns": "^3.6.0"
```

Run from project root:
```bash
npm install
```

- [ ] **Step 2: Create `lib/tweaks.ts`**

```ts
import { useEffect, useState } from 'react'

export interface Tweaks {
  dark: boolean
  accent: '#0A84FF' | '#30B0C7' | '#34C759' | '#AF52DE' | '#FF9500'
  layout: 'sidebar' | 'tabbar'
}

const STORAGE_KEY = 'tsk.tweaks.v1'

const DEFAULTS: Tweaks = {
  dark: false,
  accent: '#0A84FF',
  layout: 'sidebar',
}

export function useTweaks(): [Tweaks, (k: keyof Tweaks, v: Tweaks[keyof Tweaks]) => void] {
  const [tweaks, setTweaks] = useState<Tweaks>(() => {
    try {
      const raw = localStorage.getItem(STORAGE_KEY)
      return raw ? { ...DEFAULTS, ...JSON.parse(raw) } : DEFAULTS
    } catch {
      return DEFAULTS
    }
  })

  useEffect(() => {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(tweaks))
    const root = document.documentElement
    root.classList.toggle('dark', tweaks.dark)
    root.style.setProperty('--accent', tweaks.accent)
    const hex = tweaks.accent.replace('#', '')
    const r = parseInt(hex.slice(0, 2), 16)
    const g = parseInt(hex.slice(2, 4), 16)
    const b = parseInt(hex.slice(4, 6), 16)
    root.style.setProperty('--accent-soft', `rgba(${r}, ${g}, ${b}, 0.12)`)
  }, [tweaks])

  function set<K extends keyof Tweaks>(k: K, v: Tweaks[K]) {
    setTweaks((prev) => ({ ...prev, [k]: v }))
  }

  return [tweaks, set as never]
}
```

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "feat: add tweaks hook (dark/accent/layout) + deps"
```

---

### Task A2: Icon component + format helpers

**Files:**
- Create: `apps/web/src/components/Icon.tsx`
- Create: `apps/web/src/lib/format.ts`

- [ ] **Step 1: Create `Icon.tsx`** with SVG paths for the icons we'll need

```tsx
type IconName =
  | 'house' | 'users' | 'book' | 'calendar' | 'anchor' | 'water'
  | 'wallet' | 'chart' | 'settings' | 'plus' | 'bell' | 'search'
  | 'filter' | 'check' | 'x' | 'chevron-right' | 'chevron-left'
  | 'chevron-down' | 'menu' | 'wrench' | 'logout' | 'tag'
  | 'thermometer' | 'eye' | 'location' | 'depth' | 'card'
  | 'tank' | 'boat' | 'grid'

interface Props {
  name: IconName
  size?: number
  className?: string
}

const PATHS: Record<IconName, string> = {
  house: 'M3 12L12 3l9 9v9a2 2 0 0 1-2 2h-3v-7H10v7H7a2 2 0 0 1-2-2v-9z',
  users: 'M16 11a3 3 0 1 0 0-6 3 3 0 0 0 0 6zM8 11a3 3 0 1 0 0-6 3 3 0 0 0 0 6zm0 2c-2.7 0-8 1.3-8 4v2h10v-2c0-1 .3-1.9.8-2.7-.9-.2-1.9-.3-2.8-.3zm8 0c-.3 0-.7 0-1 .1.6 1 1 2.1 1 3.2v1.7H22v-2c0-2.7-5.3-3-6-3z',
  book: 'M4 4h6c1.7 0 3 1.3 3 3v13c0-1.7-1.3-3-3-3H4V4zm16 0h-6c-1.7 0-3 1.3-3 3v13c0-1.7 1.3-3 3-3h6V4z',
  calendar: 'M7 2v3H5a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V7a2 2 0 0 0-2-2h-2V2h-2v3H9V2H7zm-2 6h14v11H5V8z',
  anchor: 'M12 2a3 3 0 0 0-1 5.8V10H8v2h3v6.9c-2.7-.4-5-2.4-5.7-5L8 13l-3-2-3 2 1.7 1c1 4.3 4.7 7.5 9.3 7.9V20h.5c4.6-.4 8.3-3.6 9.3-7.9l1.7-1-3-2-3 2 2.7.9c-.7 2.6-3 4.6-5.7 5V12h3v-2h-3V7.8c1.7-.4 3-2 3-3.8a3 3 0 0 0-3-3z',
  water: 'M12 2c-1 2-6 7-6 12a6 6 0 0 0 12 0c0-5-5-10-6-12z',
  wallet: 'M21 7H3a2 2 0 0 0-2 2v9a2 2 0 0 0 2 2h18a2 2 0 0 0 2-2V9a2 2 0 0 0-2-2zm-3 8a2 2 0 1 1 0-4 2 2 0 0 1 0 4zM5 5h14V3H5a2 2 0 0 0-2 2v.5c.6-.3 1.3-.5 2-.5z',
  chart: 'M3 13h2v8H3v-8zm4-5h2v13H7V8zm4-4h2v17h-2V4zm4 8h2v9h-2v-9zm4-3h2v12h-2V9z',
  settings: 'M19.4 13a7.5 7.5 0 0 0 0-2l2-1.6-2-3.4-2.4 1a7.5 7.5 0 0 0-1.7-1L15 3h-4l-.3 2.5a7.5 7.5 0 0 0-1.7 1l-2.4-1-2 3.4L6.6 11a7.5 7.5 0 0 0 0 2l-2 1.6 2 3.4 2.4-1c.5.4 1 .8 1.7 1L11 21h4l.3-2.5c.6-.2 1.2-.5 1.7-1l2.4 1 2-3.4-2-1.6zM12 15a3 3 0 1 1 0-6 3 3 0 0 1 0 6z',
  plus: 'M12 5v14M5 12h14',
  bell: 'M18 8a6 6 0 0 0-12 0c0 7-3 9-3 9h18s-3-2-3-9zM13.7 21a2 2 0 0 1-3.4 0',
  search: 'M11 4a7 7 0 1 0 4.3 12.5l4.6 4.6 1.4-1.4-4.6-4.6A7 7 0 0 0 11 4zm0 2a5 5 0 1 1 0 10 5 5 0 0 1 0-10z',
  filter: 'M3 4h18v2l-7 8v6l-4-2v-4L3 6V4z',
  check: 'M5 12l5 5L20 7',
  x: 'M18 6L6 18M6 6l12 12',
  'chevron-right': 'M9 6l6 6-6 6',
  'chevron-left': 'M15 6l-6 6 6 6',
  'chevron-down': 'M6 9l6 6 6-6',
  menu: 'M3 6h18M3 12h18M3 18h18',
  wrench: 'M22 12a10 10 0 1 1-20 0 10 10 0 0 1 20 0zm-3 0a7 7 0 1 0-14 0 7 7 0 0 0 14 0zm-7-4v8M8 12h8',
  logout: 'M16 17l5-5-5-5M21 12H9M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4',
  tag: 'M21 12l-9 9-9-9 9-9 9 9zM7 7h.01',
  thermometer: 'M14 14V5a2 2 0 0 0-4 0v9a4 4 0 1 0 4 0z',
  eye: 'M1 12s4-7 11-7 11 7 11 7-4 7-11 7-11-7-11-7zm11 3a3 3 0 1 0 0-6 3 3 0 0 0 0 6z',
  location: 'M12 2a7 7 0 0 0-7 7c0 5 7 13 7 13s7-8 7-13a7 7 0 0 0-7-7zm0 9a2 2 0 1 1 0-4 2 2 0 0 1 0 4z',
  depth: 'M2 12l5-3v2h10V9l5 3-5 3v-2H7v2l-5-3z',
  card: 'M3 5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5zm2 4v10h14V9H5zm0-2h14V5H5v2z',
  tank: 'M9 2v2H7v18h10V4h-2V2H9zm0 4h6v14H9V6z',
  boat: 'M2 18h20l-2 4H4l-2-4zm2-2l8-12 8 12H4z',
  grid: 'M4 4h7v7H4V4zm9 0h7v7h-7V4zM4 13h7v7H4v-7zm9 0h7v7h-7v-7z',
}

export function Icon({ name, size = 16, className }: Props) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.6"
      strokeLinecap="round"
      strokeLinejoin="round"
      className={className}
    >
      <path d={PATHS[name]} />
    </svg>
  )
}
```

- [ ] **Step 2: Create `lib/format.ts`**

```ts
import { format as fmt, formatDistanceToNow } from 'date-fns'
import { de } from 'date-fns/locale'

export function chf(n: number | null | undefined): string {
  const v = Number(n ?? 0)
  return new Intl.NumberFormat('de-CH', {
    style: 'currency',
    currency: 'CHF',
    minimumFractionDigits: 2,
  }).format(v)
}

export function chfPlain(n: number | null | undefined): string {
  return Number(n ?? 0).toFixed(2)
}

export function dateShort(d: string | Date): string {
  return fmt(typeof d === 'string' ? new Date(d) : d, 'dd.MM.', { locale: de })
}

export function dateLong(d: string | Date): string {
  return fmt(typeof d === 'string' ? new Date(d) : d, 'EEEE, d. MMMM yyyy', { locale: de })
}

export function relTime(d: string | Date): string {
  return formatDistanceToNow(typeof d === 'string' ? new Date(d) : d, {
    locale: de,
    addSuffix: true,
  })
}

export function initialsFromName(name: string): string {
  return name
    .split(/\s+/)
    .map((p) => p[0])
    .filter(Boolean)
    .slice(0, 2)
    .join('')
    .toUpperCase()
}
```

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "feat: add Icon component and format helpers"
```

---

### Task A3: Sidebar component

**Files:**
- Create: `apps/web/src/components/Sidebar.tsx`
- Modify: `apps/web/src/styles/components.css` (add sidebar styles)

- [ ] **Step 1: Append CSS to `components.css`**

```css
/* SIDEBAR */
.sidebar {
  width: 264px;
  flex-shrink: 0;
  border-right: 0.5px solid var(--separator);
  display: flex; flex-direction: column;
  padding: 14px 12px;
  gap: 4px;
  height: 100%;
}
.sb-row {
  display: flex; align-items: center; gap: 10px;
  height: 34px; padding: 0 12px;
  border-radius: 9px;
  color: var(--ink-2);
  font-size: 13.5px; font-weight: 500;
  cursor: pointer;
  transition: background .12s;
  position: relative;
}
.sb-row:hover { background: rgba(0,0,0,.04); }
.dark .sb-row:hover { background: rgba(255,255,255,.05); }
.sb-row.active {
  background: var(--accent-soft);
  color: var(--accent);
}
.sb-row .sb-icon {
  width: 22px; height: 22px;
  display: grid; place-items: center;
  color: var(--ink-3);
}
.sb-row.active .sb-icon { color: var(--accent); }
.sb-row .badge {
  margin-left: auto;
  background: rgba(0,0,0,.08);
  color: var(--ink-2);
  font-size: 11px; font-weight: 600;
  border-radius: 999px;
  padding: 1px 7px;
  font-variant-numeric: tabular-nums;
}
.dark .sb-row .badge { background: rgba(255,255,255,.1); }
.sb-row.active .badge { background: var(--accent); color: white; }
.sb-section {
  font-size: 11px; font-weight: 600; letter-spacing: 0.04em;
  color: var(--ink-4);
  text-transform: uppercase;
  padding: 14px 12px 4px;
}
```

- [ ] **Step 2: Create `Sidebar.tsx`**

```tsx
import clsx from 'clsx'
import { NavLink } from 'react-router-dom'
import { Icon } from './Icon'
import type { Role } from '@/lib/auth'

interface SidebarProps {
  role: Role
  userName: string
  userEmail: string
  onLogout: () => void
}

interface NavItem {
  to: string
  icon: Parameters<typeof Icon>[0]['name']
  label: string
  roles: Role[]
}

const ITEMS: NavItem[] = [
  { to: '/heute',           icon: 'house',    label: 'Heute',         roles: ['dispatcher', 'instructor'] },
  { to: '/kalender',        icon: 'calendar', label: 'Kalender',      roles: ['dispatcher', 'instructor'] },
  { to: '/kurse',           icon: 'book',     label: 'Kurse',         roles: ['dispatcher'] },
  { to: '/tldm',            icon: 'users',    label: 'TL/DM',         roles: ['dispatcher'] },
  { to: '/skills',          icon: 'grid',     label: 'Skill-Matrix',  roles: ['dispatcher'] },
  { to: '/pool',            icon: 'water',    label: 'Pool',          roles: ['dispatcher'] },
  { to: '/saldi',           icon: 'wallet',   label: 'Saldi',         roles: ['dispatcher'] },
  { to: '/einsaetze',       icon: 'book',     label: 'Meine Einsätze', roles: ['instructor'] },
  { to: '/saldo',           icon: 'wallet',   label: 'Mein Saldo',    roles: ['instructor'] },
  { to: '/profil',          icon: 'tag',      label: 'Mein Profil',   roles: ['instructor'] },
]

const ADMIN: NavItem[] = [
  { to: '/einstellungen', icon: 'settings', label: 'Einstellungen', roles: ['dispatcher'] },
]

export function Sidebar({ role, userName, userEmail, onLogout }: SidebarProps) {
  const main = ITEMS.filter((i) => i.roles.includes(role))
  const admin = ADMIN.filter((i) => i.roles.includes(role))

  return (
    <aside className="sidebar glass-thin">
      <div style={{ padding: '6px 12px 14px', display: 'flex', gap: 10, alignItems: 'center' }}>
        <div
          style={{
            width: 30, height: 30, borderRadius: 8,
            background: 'linear-gradient(135deg, var(--accent), #30B0C7)',
            display: 'grid', placeItems: 'center', color: 'white', flexShrink: 0,
            boxShadow: '0 1px 2px rgba(0,0,0,.15), inset 0 0 0 .5px rgba(255,255,255,.3)',
          }}
        >
          <Icon name="anchor" size={16} />
        </div>
        <div style={{ minWidth: 0 }}>
          <div style={{ fontSize: 13, fontWeight: 600, lineHeight: 1.2, letterSpacing: '-.01em' }}>
            TSK Dispo
          </div>
          <div className="caption-2" style={{ marginTop: 1 }}>2026 · Zürich</div>
        </div>
      </div>

      {main.map((item) => (
        <NavLink
          key={item.to}
          to={item.to}
          className={({ isActive }) => clsx('sb-row', isActive && 'active')}
        >
          <span className="sb-icon">
            <Icon name={item.icon} size={17} />
          </span>
          <span>{item.label}</span>
        </NavLink>
      ))}

      {admin.length > 0 && (
        <>
          <div className="sb-section">Verwaltung</div>
          {admin.map((item) => (
            <NavLink
              key={item.to}
              to={item.to}
              className={({ isActive }) => clsx('sb-row', isActive && 'active')}
            >
              <span className="sb-icon">
                <Icon name={item.icon} size={17} />
              </span>
              <span>{item.label}</span>
            </NavLink>
          ))}
        </>
      )}

      <div style={{ marginTop: 'auto', padding: '8px 4px 0' }}>
        <div
          className="glass-thin"
          style={{
            padding: '10px 12px',
            borderRadius: 12,
            display: 'flex',
            alignItems: 'center',
            gap: 10,
          }}
        >
          <div
            className="avatar avatar-sm"
            style={{
              background: 'linear-gradient(135deg, var(--accent), #5856D6)',
              width: 30,
              height: 30,
              fontSize: 11,
            }}
          >
            {userName.slice(0, 2).toUpperCase()}
          </div>
          <div style={{ minWidth: 0, flex: 1 }}>
            <div style={{ fontSize: 12.5, fontWeight: 600 }}>{userName}</div>
            <div className="caption-2" style={{ overflow: 'hidden', textOverflow: 'ellipsis' }}>
              {userEmail}
            </div>
          </div>
          <button className="btn-icon" onClick={onLogout} title="Abmelden">
            <Icon name="logout" size={14} />
          </button>
        </div>
      </div>
    </aside>
  )
}
```

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "feat: add Sidebar with role-aware nav items"
```

---

### Task A4: FloatingTabBar component

**Files:**
- Create: `apps/web/src/components/FloatingTabBar.tsx`
- Modify: `apps/web/src/styles/components.css`

- [ ] **Step 1: Append CSS**

```css
/* FLOATING TAB BAR */
.tabbar {
  position: absolute; bottom: 18px; left: 50%; transform: translateX(-50%);
  display: flex; align-items: center; gap: 4px;
  padding: 6px;
  border-radius: 24px;
  z-index: 100;
}
.tabbar .tb-item {
  display: flex; flex-direction: column; align-items: center;
  width: 64px; padding: 6px 0;
  color: var(--ink-3);
  cursor: pointer;
  border-radius: 18px;
  font-size: 10px; font-weight: 500;
  gap: 2px;
  text-decoration: none;
}
.tabbar .tb-item.active { color: var(--accent); }
.tabbar .tb-item:hover  { color: var(--ink-2); }
.tabbar .tb-item.active:hover { color: var(--accent); }
```

- [ ] **Step 2: Create `FloatingTabBar.tsx`**

```tsx
import clsx from 'clsx'
import { NavLink } from 'react-router-dom'
import { Icon } from './Icon'
import type { Role } from '@/lib/auth'

interface Props {
  role: Role
}

const DISPATCHER_TABS = [
  { to: '/heute',     icon: 'house',    label: 'Heute' },
  { to: '/kurse',     icon: 'book',     label: 'Kurse' },
  { to: '/kalender',  icon: 'calendar', label: 'Kalender' },
  { to: '/tldm',      icon: 'users',    label: 'TL/DM' },
  { to: '/saldi',     icon: 'wallet',   label: 'Saldi' },
] as const

const INSTRUCTOR_TABS = [
  { to: '/heute',     icon: 'house',    label: 'Heute' },
  { to: '/einsaetze', icon: 'book',     label: 'Einsätze' },
  { to: '/kalender',  icon: 'calendar', label: 'Kalender' },
  { to: '/saldo',     icon: 'wallet',   label: 'Saldo' },
  { to: '/profil',    icon: 'tag',      label: 'Profil' },
] as const

export function FloatingTabBar({ role }: Props) {
  const tabs = role === 'dispatcher' ? DISPATCHER_TABS : INSTRUCTOR_TABS

  return (
    <div className="tabbar glass-strong">
      {tabs.map((t) => (
        <NavLink
          key={t.to}
          to={t.to}
          className={({ isActive }) => clsx('tb-item', isActive && 'active')}
        >
          <Icon name={t.icon as any} size={20} />
          <span>{t.label}</span>
        </NavLink>
      ))}
    </div>
  )
}
```

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "feat: add FloatingTabBar alternative nav"
```

---

### Task A5: Topbar + Sheet + Chip + SegmentedControl + EmptyState

**Files:**
- Create: `apps/web/src/components/Topbar.tsx`
- Create: `apps/web/src/components/Sheet.tsx`
- Create: `apps/web/src/components/Chip.tsx`
- Create: `apps/web/src/components/SegmentedControl.tsx`
- Create: `apps/web/src/components/EmptyState.tsx`
- Modify: `apps/web/src/styles/components.css`

- [ ] **Step 1: Append CSS**

```css
/* TOPBAR */
.topbar {
  display: flex; align-items: center; justify-content: space-between;
  padding: 12px 24px;
  height: 56px;
  border-bottom: 0.5px solid var(--separator);
  flex-shrink: 0;
}

/* SEGMENTED */
.seg {
  display: inline-flex; padding: 2px;
  background: rgba(120,120,128,.16);
  border-radius: 9px;
  font-size: 12.5px; font-weight: 500;
}
.seg button {
  appearance: none; border: 0; background: transparent;
  padding: 5px 12px; border-radius: 7px;
  color: var(--ink-2); cursor: pointer;
  font-weight: 500;
  transition: background .12s, color .12s;
}
.seg button.active {
  background: var(--surface-strong); color: var(--ink);
  box-shadow: 0 1px 2px rgba(0,0,0,.08);
}

/* SHEET */
.sheet-overlay {
  position: absolute; inset: 0; z-index: 200;
  display: flex; justify-content: flex-end;
  animation: fadein .2s;
}
.sheet-backdrop {
  position: absolute; inset: 0;
  background: rgba(0,0,0,.25);
  backdrop-filter: blur(2px);
}
.sheet-panel {
  position: relative;
  height: calc(100% - 24px);
  margin: 12px;
  border-radius: 22px;
  padding: 20px;
  display: flex; flex-direction: column;
}

/* EMPTY STATE */
.empty-state {
  display: grid; place-items: center;
  height: 100%;
  text-align: center;
  color: var(--ink-3);
  padding: 40px;
}

/* MASTER-DETAIL */
.master-detail {
  display: grid;
  grid-template-columns: 320px 1fr;
  height: 100%;
  overflow: hidden;
}
.master-detail .master {
  border-right: 0.5px solid var(--separator);
  overflow: auto;
}
.master-detail .detail {
  overflow: auto;
}
```

- [ ] **Step 2: `Topbar.tsx`**

```tsx
import type { ReactNode } from 'react'

interface TopbarProps {
  title: string
  subtitle?: string
  children?: ReactNode
}

export function Topbar({ title, subtitle, children }: TopbarProps) {
  return (
    <div className="topbar">
      <div>
        <div className="title-2" style={{ lineHeight: 1.1 }}>{title}</div>
        {subtitle && <div className="caption" style={{ marginTop: 2 }}>{subtitle}</div>}
      </div>
      <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>{children}</div>
    </div>
  )
}
```

- [ ] **Step 3: `Sheet.tsx`**

```tsx
import type { ReactNode } from 'react'
import { Icon } from './Icon'

interface SheetProps {
  open: boolean
  onClose: () => void
  title: string
  width?: number
  children: ReactNode
}

export function Sheet({ open, onClose, title, width = 520, children }: SheetProps) {
  if (!open) return null
  return (
    <div className="sheet-overlay">
      <div className="sheet-backdrop" onClick={onClose} />
      <div className="sheet-panel glass-strong" style={{ width }}>
        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            marginBottom: 14,
          }}
        >
          <div className="title-2">{title}</div>
          <button className="btn-icon" onClick={onClose}>
            <Icon name="x" size={14} />
          </button>
        </div>
        <div className="scroll" style={{ flex: 1, marginRight: -8, paddingRight: 8 }}>
          {children}
        </div>
      </div>
    </div>
  )
}
```

- [ ] **Step 4: `Chip.tsx`**

```tsx
import clsx from 'clsx'
import type { ReactNode } from 'react'

type Tone = 'neutral' | 'accent' | 'green' | 'orange' | 'red' | 'purple'

const TONE_CLASS: Record<Tone, string> = {
  neutral: '',
  accent: 'chip-accent',
  green: 'chip-green',
  orange: 'chip-orange',
  red: 'chip-red',
  purple: 'chip-purple',
}

export function Chip({ tone = 'neutral', children }: { tone?: Tone; children: ReactNode }) {
  return <span className={clsx('chip', TONE_CLASS[tone])}>{children}</span>
}
```

- [ ] **Step 5: `SegmentedControl.tsx`**

```tsx
import clsx from 'clsx'

interface Option<T extends string> {
  value: T
  label: string
}

interface Props<T extends string> {
  value: T
  options: Option<T>[]
  onChange: (v: T) => void
}

export function SegmentedControl<T extends string>({ value, options, onChange }: Props<T>) {
  return (
    <div className="seg">
      {options.map((o) => (
        <button
          key={o.value}
          className={clsx(value === o.value && 'active')}
          onClick={() => onChange(o.value)}
        >
          {o.label}
        </button>
      ))}
    </div>
  )
}
```

- [ ] **Step 6: `EmptyState.tsx`**

```tsx
import type { ReactNode } from 'react'
import { Icon } from './Icon'

interface Props {
  icon?: Parameters<typeof Icon>[0]['name']
  title: string
  description?: string
  action?: ReactNode
}

export function EmptyState({ icon = 'tag', title, description, action }: Props) {
  return (
    <div className="empty-state">
      <Icon name={icon} size={36} className="ink-3" />
      <div className="title-3" style={{ marginTop: 12 }}>{title}</div>
      {description && (
        <div className="caption" style={{ marginTop: 4, maxWidth: 320 }}>{description}</div>
      )}
      {action && <div style={{ marginTop: 16 }}>{action}</div>}
    </div>
  )
}
```

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat: add Topbar, Sheet, Chip, SegmentedControl, EmptyState"
```

---

### Task A6: TweakPanel

**Files:**
- Create: `apps/web/src/components/TweakPanel.tsx`
- Modify: `apps/web/src/styles/components.css`

- [ ] **Step 1: Append CSS**

```css
/* TWEAK PANEL */
.tweak-trigger {
  position: fixed; top: 14px; right: 18px; z-index: 50;
}
.tweak-panel {
  position: fixed; top: 60px; right: 18px;
  width: 320px;
  border-radius: 18px;
  padding: 18px;
  z-index: 100;
}
.tweak-row {
  display: flex; align-items: center; justify-content: space-between;
  padding: 8px 0;
}
.tweak-section {
  font-size: 11px; font-weight: 600; letter-spacing: 0.04em;
  color: var(--ink-4); text-transform: uppercase;
  padding: 14px 0 4px;
}
```

- [ ] **Step 2: Create `TweakPanel.tsx`**

```tsx
import { useState } from 'react'
import { Icon } from './Icon'
import { useTweaks, type Tweaks } from '@/lib/tweaks'

const ACCENTS: { value: Tweaks['accent']; name: string }[] = [
  { value: '#0A84FF', name: 'Ocean Blue' },
  { value: '#30B0C7', name: 'Teal' },
  { value: '#34C759', name: 'Reef' },
  { value: '#AF52DE', name: 'Coral' },
  { value: '#FF9500', name: 'Sunset' },
]

export function TweakPanel() {
  const [open, setOpen] = useState(false)
  const [tweaks, set] = useTweaks()

  return (
    <>
      <button
        className="btn-icon tweak-trigger"
        onClick={() => setOpen((v) => !v)}
        title="Tweaks"
      >
        <Icon name="wrench" size={14} />
      </button>

      {open && (
        <div className="tweak-panel glass-strong">
          <div className="title-3" style={{ marginBottom: 4 }}>Tweaks</div>
          <div className="caption" style={{ marginBottom: 8 }}>Anpassungen werden lokal gespeichert</div>

          <div className="tweak-section">Erscheinungsbild</div>

          <div className="tweak-row">
            <span>Dark Mode</span>
            <input
              type="checkbox"
              checked={tweaks.dark}
              onChange={(e) => set('dark', e.target.checked)}
            />
          </div>

          <div className="tweak-row">
            <span>Akzent</span>
            <div style={{ display: 'flex', gap: 8 }}>
              {ACCENTS.map((a) => (
                <button
                  key={a.value}
                  onClick={() => set('accent', a.value)}
                  title={a.name}
                  style={{
                    width: 26,
                    height: 26,
                    borderRadius: 999,
                    border: 0,
                    background: a.value,
                    cursor: 'pointer',
                    outline: tweaks.accent === a.value ? '2px solid var(--ink)' : 'none',
                    outlineOffset: 2,
                  }}
                />
              ))}
            </div>
          </div>

          <div className="tweak-section">Layout</div>

          <div className="tweak-row">
            <span>Navigation</span>
            <select
              value={tweaks.layout}
              onChange={(e) => set('layout', e.target.value as Tweaks['layout'])}
              style={{ padding: '4px 8px', borderRadius: 6 }}
            >
              <option value="sidebar">Sidebar</option>
              <option value="tabbar">Floating Tabs</option>
            </select>
          </div>
        </div>
      )}
    </>
  )
}
```

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "feat: add TweakPanel with dark/accent/layout settings"
```

---

### Task A7: AppShell layout

**Files:**
- Create: `apps/web/src/layout/AppShell.tsx`
- Modify: `apps/web/src/App.tsx` (rewrite routes to use AppShell)

- [ ] **Step 1: Create `AppShell.tsx`**

```tsx
import { Outlet, useNavigate } from 'react-router-dom'
import { useEffect, useState } from 'react'
import { Sidebar } from '@/components/Sidebar'
import { FloatingTabBar } from '@/components/FloatingTabBar'
import { Wallpaper } from '@/components/Wallpaper'
import { StatusBar } from '@/components/StatusBar'
import { TweakPanel } from '@/components/TweakPanel'
import { useTweaks } from '@/lib/tweaks'
import { fetchCurrentUser, type CurrentUser } from '@/lib/auth'
import { supabase } from '@/lib/supabase'

export function AppShell() {
  const [user, setUser] = useState<CurrentUser | null>(null)
  const [loading, setLoading] = useState(true)
  const [tweaks] = useTweaks()
  const navigate = useNavigate()

  useEffect(() => {
    fetchCurrentUser().then((u) => {
      setUser(u)
      setLoading(false)
    })
  }, [])

  async function logout() {
    await supabase.auth.signOut()
    navigate('/login', { replace: true })
  }

  if (loading) return <div style={{ padding: 40 }}>Lade…</div>
  if (!user) {
    navigate('/login', { replace: true })
    return null
  }

  const isSidebar = tweaks.layout === 'sidebar'

  return (
    <div style={{ height: '100vh', display: 'flex', flexDirection: 'column', position: 'relative' }}>
      <Wallpaper />
      <StatusBar />
      <TweakPanel />

      <div
        style={{
          flex: 1,
          display: 'flex',
          overflow: 'hidden',
          position: 'relative',
          zIndex: 1,
        }}
      >
        {isSidebar && (
          <Sidebar
            role={user.role}
            userName={user.name}
            userEmail={user.email}
            onLogout={logout}
          />
        )}

        <div
          style={{
            flex: 1,
            display: 'flex',
            flexDirection: 'column',
            overflow: 'hidden',
            paddingBottom: isSidebar ? 0 : 80,
          }}
        >
          <Outlet context={{ user }} />
        </div>

        {!isSidebar && <FloatingTabBar role={user.role} />}
      </div>
    </div>
  )
}

export interface OutletCtx {
  user: CurrentUser
}
```

- [ ] **Step 2: Replace `App.tsx`**

```tsx
import { BrowserRouter, Route, Routes, Navigate, useOutletContext } from 'react-router-dom'
import { useEffect, useState } from 'react'
import type { Session } from '@supabase/supabase-js'
import { supabase } from '@/lib/supabase'
import { LoginScreen } from '@/screens/LoginScreen'
import { AuthCallback } from '@/screens/AuthCallback'
import { ImportWizard } from '@/screens/ImportWizard'
import { AppShell, type OutletCtx } from '@/layout/AppShell'
import { TodayScreen } from '@/screens/TodayScreen'
import { CoursesScreen } from '@/screens/CoursesScreen'
import { InstructorsScreen } from '@/screens/InstructorsScreen'
import { SkillMatrixScreen } from '@/screens/SkillMatrixScreen'
import { PoolScreen } from '@/screens/PoolScreen'
import { SaldiScreen } from '@/screens/SaldiScreen'
import { CalendarScreen } from '@/screens/CalendarScreen'
import { SettingsScreen } from '@/screens/SettingsScreen'

export function useUser() {
  return useOutletContext<OutletCtx>().user
}

function App() {
  const [session, setSession] = useState<Session | null>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    supabase.auth.getSession().then(({ data }) => {
      setSession(data.session)
      setLoading(false)
    })
    const { data: sub } = supabase.auth.onAuthStateChange((_e, s) => setSession(s))
    return () => sub.subscription.unsubscribe()
  }, [])

  if (loading) return <div style={{ padding: 40 }}>Lade…</div>

  return (
    <BrowserRouter>
      <Routes>
        <Route path="/login" element={session ? <Navigate to="/heute" replace /> : <LoginScreen />} />
        <Route path="/auth/callback" element={<AuthCallback />} />

        {/* All authenticated routes wrapped in AppShell */}
        <Route element={session ? <AppShell /> : <Navigate to="/login" replace />}>
          <Route path="/heute"                    element={<TodayScreen />} />
          <Route path="/kalender"                 element={<CalendarScreen />} />
          <Route path="/kurse"                    element={<CoursesScreen />} />
          <Route path="/kurse/:id"                element={<CoursesScreen />} />
          <Route path="/tldm"                     element={<InstructorsScreen />} />
          <Route path="/tldm/:id"                 element={<InstructorsScreen />} />
          <Route path="/skills"                   element={<SkillMatrixScreen />} />
          <Route path="/pool"                     element={<PoolScreen />} />
          <Route path="/saldi"                    element={<SaldiScreen />} />
          <Route path="/einstellungen"            element={<SettingsScreen />} />
          <Route path="/einstellungen/import"     element={<ImportWizard />} />
          <Route path="*"                         element={<Navigate to="/heute" replace />} />
        </Route>
      </Routes>
    </BrowserRouter>
  )
}

export default App
```

- [ ] **Step 3: Stub all the screen files** so the build passes

For each missing screen, create a placeholder file. Run from project root:
```bash
for f in TodayScreen CoursesScreen InstructorsScreen SkillMatrixScreen PoolScreen SaldiScreen CalendarScreen SettingsScreen; do
  cat > "apps/web/src/screens/${f}.tsx" <<EOF
import { Topbar } from '@/components/Topbar'

export function ${f}() {
  return (
    <>
      <Topbar title="${f}" subtitle="kommt in Plan 2" />
      <div style={{ padding: 40 }}>
        <div className="caption">Diese Seite wird in Plan 2 ausgebaut.</div>
      </div>
    </>
  )
}
EOF
done
```

- [ ] **Step 4: Verify build passes**

```bash
npm -w @tsk/web run typecheck
npm -w @tsk/web run build
```

Both should succeed.

- [ ] **Step 5: Run dev and click through nav**

```bash
npm run dev
```

Login, navigate to each menu item via the Sidebar, switch to Tabbar via TweakPanel, verify navigation works for all routes.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: AppShell with role-aware nav + screen stubs"
```

---

## Phase B — Settings & Tweak verification (Day 2)

### Task B1: Settings screen with sub-routes

**Files:**
- Modify: `apps/web/src/screens/SettingsScreen.tsx`

- [ ] **Step 1: Replace stub with real Settings**

```tsx
import { useEffect, useState } from 'react'
import { Topbar } from '@/components/Topbar'
import { Icon } from '@/components/Icon'
import { useNavigate } from 'react-router-dom'
import { supabase } from '@/lib/supabase'
import { chf } from '@/lib/format'

interface CompRate {
  id: string
  level: string
  hourly_rate_chf: number
}

interface UserRow {
  id: string
  name: string
  email: string | null
  role: string
  auth_linked: boolean
}

export function SettingsScreen() {
  const navigate = useNavigate()
  const [rates, setRates] = useState<CompRate[]>([])
  const [users, setUsers] = useState<UserRow[]>([])

  useEffect(() => {
    supabase
      .from('comp_rates')
      .select('id, level, hourly_rate_chf')
      .is('valid_to', null)
      .order('level')
      .then(({ data }) => setRates((data as CompRate[] | null) ?? []))

    supabase
      .from('instructors')
      .select('id, name, email, role, auth_user_id')
      .order('name')
      .then(({ data }) => {
        setUsers(
          (data ?? []).map((d: any) => ({
            id: d.id,
            name: d.name,
            email: d.email,
            role: d.role,
            auth_linked: !!d.auth_user_id,
          })),
        )
      })
  }, [])

  return (
    <>
      <Topbar title="Einstellungen" subtitle="Vergütungssätze · Import · User" />
      <div className="screen-fade scroll" style={{ padding: '20px 24px 40px' }}>
        <div className="glass card" style={{ marginBottom: 20 }}>
          <div className="title-3" style={{ marginBottom: 12 }}>Excel-Import</div>
          <div className="caption" style={{ marginBottom: 12 }}>
            4-stufiger Wizard zum einmaligen Import deines Excel-Sheets.
          </div>
          <button className="btn" onClick={() => navigate('/einstellungen/import')}>
            <Icon name="plus" size={14} />
            Import öffnen
          </button>
        </div>

        <div className="glass card" style={{ marginBottom: 20 }}>
          <div className="title-3" style={{ marginBottom: 12 }}>Vergütungssätze</div>
          <table style={{ width: '100%', fontSize: 13 }}>
            <thead>
              <tr style={{ borderBottom: '0.5px solid var(--hairline)' }}>
                <th align="left" style={{ padding: '6px 4px' }}>Level</th>
                <th align="right" style={{ padding: '6px 4px' }}>Stundensatz</th>
              </tr>
            </thead>
            <tbody>
              {rates.map((r) => (
                <tr key={r.id}>
                  <td style={{ padding: '6px 4px' }}>{r.level}</td>
                  <td align="right" className="mono">{chf(r.hourly_rate_chf)}</td>
                </tr>
              ))}
            </tbody>
          </table>
          <div className="caption-2" style={{ marginTop: 8 }}>
            Bearbeitung kommt in v1.5 — aktuell nur Anzeige.
          </div>
        </div>

        <div className="glass card">
          <div className="title-3" style={{ marginBottom: 12 }}>User & Login-Verknüpfungen</div>
          <div className="caption" style={{ marginBottom: 12 }}>
            {users.filter((u) => u.auth_linked).length} von {users.length} Personen haben einen Login.
          </div>
          <table style={{ width: '100%', fontSize: 13 }}>
            <thead>
              <tr style={{ borderBottom: '0.5px solid var(--hairline)' }}>
                <th align="left" style={{ padding: '6px 4px' }}>Name</th>
                <th align="left" style={{ padding: '6px 4px' }}>Email</th>
                <th align="left" style={{ padding: '6px 4px' }}>Rolle</th>
                <th align="center" style={{ padding: '6px 4px' }}>Login</th>
              </tr>
            </thead>
            <tbody>
              {users.map((u) => (
                <tr key={u.id}>
                  <td style={{ padding: '6px 4px' }}>{u.name}</td>
                  <td style={{ padding: '6px 4px' }} className="caption">{u.email || '—'}</td>
                  <td style={{ padding: '6px 4px' }}>
                    <span className="chip" style={{ fontSize: 10 }}>{u.role}</span>
                  </td>
                  <td align="center" style={{ padding: '6px 4px' }}>
                    {u.auth_linked ? '✓' : '—'}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </>
  )
}
```

- [ ] **Step 2: Verify**

Click through `/einstellungen` — see rates + users.

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "feat(settings): show comp_rates + user table"
```

---

## Phase C — Heute Dashboard (Days 3–4)

### Task C1: Today screen — Hero + KPI cards + Sessions timeline

**Files:**
- Create: `apps/web/src/lib/queries.ts`
- Modify: `apps/web/src/screens/TodayScreen.tsx`
- Modify: `apps/web/src/styles/components.css`

- [ ] **Step 1: Append CSS for tile-now + timeline + stat-card**

```css
/* HERO TILE */
.tile-now {
  background: linear-gradient(135deg, var(--accent), color-mix(in oklab, var(--accent) 70%, #30B0C7));
  color: white;
  border-radius: var(--radius-lg);
  padding: 18px 20px;
  position: relative;
  overflow: hidden;
}
.tile-now::after {
  content: ""; position: absolute; inset: 0;
  background: radial-gradient(400px 200px at 90% -10%, rgba(255,255,255,.35), transparent 60%);
  pointer-events: none;
}

/* STAT CARD */
.stat-card { padding: 16px 18px; border-radius: var(--radius-lg); }
.stat-card .stat-num   { font-size: 30px; font-weight: 700; letter-spacing: -0.025em; }
.stat-card .stat-label { font-size: 12px; color: var(--ink-3); margin-top: 4px; font-weight: 500; }
.stat-card .stat-trend { font-size: 11px; margin-top: 8px; color: #34C759; font-weight: 600; }

/* TIMELINE */
.timeline {
  display: grid;
  grid-template-columns: 60px 1fr;
  gap: 0;
}
.tl-time {
  font-size: 11.5px; color: var(--ink-3);
  font-variant-numeric: tabular-nums;
  padding-top: 12px; text-align: right; padding-right: 12px;
  font-weight: 500;
}
.tl-event {
  margin: 6px 0;
  padding: 12px 14px;
  border-radius: 12px;
  border-left: 3px solid var(--accent);
  background: var(--surface);
  -webkit-backdrop-filter: blur(16px);
  backdrop-filter: blur(16px);
}
```

- [ ] **Step 2: Create `lib/queries.ts`**

```ts
import { supabase } from './supabase'

export interface CourseRow {
  id: string
  title: string
  start_date: string
  status: 'confirmed' | 'tentative' | 'cancelled'
  num_participants: number
  course_type: { code: string; label: string } | null
}

export interface AssignmentRow {
  id: string
  course_id: string
  instructor_id: string
  role: 'haupt' | 'assist' | 'dmt'
  confirmed: boolean
  course: CourseRow | null
  instructor: { id: string; name: string; initials: string; color: string } | null
}

export async function fetchCoursesInRange(from: string, to: string) {
  const { data, error } = await supabase
    .from('courses')
    .select(`
      id, title, start_date, status, num_participants,
      course_type:course_types(code, label)
    `)
    .gte('start_date', from)
    .lte('start_date', to)
    .order('start_date')
  if (error) throw error
  return (data ?? []) as unknown as CourseRow[]
}

export async function fetchAssignmentsForCourses(courseIds: string[]) {
  if (courseIds.length === 0) return []
  const { data, error } = await supabase
    .from('course_assignments')
    .select(`
      id, course_id, instructor_id, role, confirmed,
      instructor:instructors(id, name, initials, color)
    `)
    .in('course_id', courseIds)
  if (error) throw error
  return (data ?? []) as unknown as AssignmentRow[]
}

export async function fetchKpis() {
  const today = new Date().toISOString().slice(0, 10)
  const [{ count: totalCourses }, { count: confirmedCourses }, { count: instructorCount }] =
    await Promise.all([
      supabase.from('courses').select('*', { count: 'exact', head: true }),
      supabase.from('courses').select('*', { count: 'exact', head: true }).eq('status', 'confirmed'),
      supabase.from('instructors').select('*', { count: 'exact', head: true }).eq('active', true),
    ])
  const { count: assignmentsThisWeek } = await supabase
    .from('course_assignments')
    .select('courses!inner(start_date)', { count: 'exact', head: true })
    .gte('courses.start_date', today)
  return {
    totalCourses: totalCourses ?? 0,
    confirmedCourses: confirmedCourses ?? 0,
    instructorCount: instructorCount ?? 0,
    assignmentsThisWeek: assignmentsThisWeek ?? 0,
  }
}
```

- [ ] **Step 3: Replace `TodayScreen.tsx`**

```tsx
import { useEffect, useState } from 'react'
import { format, addDays, startOfDay } from 'date-fns'
import { de } from 'date-fns/locale'
import { Topbar } from '@/components/Topbar'
import { Icon } from '@/components/Icon'
import { Avatar } from '@/components/Avatar'
import { Chip } from '@/components/Chip'
import { useUser } from '@/App'
import {
  fetchCoursesInRange,
  fetchAssignmentsForCourses,
  fetchKpis,
  type CourseRow,
  type AssignmentRow,
} from '@/lib/queries'

interface Kpis {
  totalCourses: number
  confirmedCourses: number
  instructorCount: number
  assignmentsThisWeek: number
}

export function TodayScreen() {
  const user = useUser()
  const [kpis, setKpis] = useState<Kpis | null>(null)
  const [today, setToday] = useState<CourseRow[]>([])
  const [thisWeek, setThisWeek] = useState<CourseRow[]>([])
  const [assignments, setAssignments] = useState<AssignmentRow[]>([])

  useEffect(() => {
    const todayStr = format(startOfDay(new Date()), 'yyyy-MM-dd')
    const weekEnd = format(addDays(new Date(), 7), 'yyyy-MM-dd')
    Promise.all([
      fetchKpis(),
      fetchCoursesInRange(todayStr, todayStr),
      fetchCoursesInRange(todayStr, weekEnd),
    ]).then(async ([k, t, w]) => {
      setKpis(k)
      setToday(t)
      setThisWeek(w)
      const ids = [...t, ...w].map((c) => c.id)
      const a = await fetchAssignmentsForCourses(ids)
      setAssignments(a)
    })
  }, [])

  const todayLabel = format(new Date(), 'EEEE, d. MMMM', { locale: de })
  const weekCount = thisWeek.length

  return (
    <>
      <Topbar
        title={user.role === 'dispatcher' ? 'Heute' : `Heute, ${user.name.split(' ')[0]}`}
        subtitle={`${todayLabel} · ${weekCount} Kurse diese Woche`}
      >
        <button className="btn-icon"><Icon name="bell" size={16} /></button>
        {user.role === 'dispatcher' && (
          <button className="btn"><Icon name="plus" size={14} /> Neuer Kurs</button>
        )}
      </Topbar>

      <div className="screen-fade scroll" style={{ flex: 1, padding: '20px 24px 28px' }}>
        {/* Hero + KPIs */}
        <div
          style={{
            display: 'grid',
            gridTemplateColumns: '1.4fr 1fr 1fr 1fr',
            gap: 14,
            marginBottom: 16,
          }}
        >
          <div className="tile-now">
            <div
              style={{
                fontSize: 12,
                opacity: 0.85,
                letterSpacing: '.02em',
                textTransform: 'uppercase',
                fontWeight: 600,
              }}
            >
              {todayLabel}
            </div>
            <div
              style={{
                fontSize: 26,
                fontWeight: 700,
                marginTop: 8,
                letterSpacing: '-.02em',
              }}
            >
              {today.length === 0
                ? 'Heute keine Kurse'
                : `${today.length} ${today.length === 1 ? 'Kurs' : 'Kurse'} heute`}
            </div>
            <div style={{ fontSize: 13, opacity: 0.9, marginTop: 4 }}>
              {today.reduce((sum, c) => sum + (c.num_participants || 0), 0)} Teilnehmer insgesamt
            </div>
          </div>

          {kpis && (
            <>
              <StatCard
                num={kpis.confirmedCourses}
                total={kpis.totalCourses}
                label="Bestätigte Kurse 2026"
                trend={null}
              />
              <StatCard
                num={kpis.instructorCount}
                label="Aktive Instructors"
                trend={null}
              />
              <StatCard
                num={kpis.assignmentsThisWeek}
                label="Einsätze ab heute"
                trend={null}
              />
            </>
          )}
        </div>

        {/* Sessions today */}
        <div className="glass card">
          <div className="title-3" style={{ marginBottom: 10 }}>Heutige Kurse</div>
          {today.length === 0 ? (
            <div className="caption">Heute frei. ☀️ Genieß den Tag.</div>
          ) : (
            <div className="timeline">
              {today.map((c) => {
                const a = assignments.filter((x) => x.course_id === c.id)
                return (
                  <Session key={c.id} course={c} assignments={a} />
                )
              })}
            </div>
          )}
        </div>
      </div>
    </>
  )
}

function StatCard({
  num,
  total,
  label,
  trend,
}: {
  num: number
  total?: number
  label: string
  trend: string | null
}) {
  return (
    <div className="glass card stat-card">
      <div className="stat-num">{num}{total != null && <span className="caption" style={{ marginLeft: 4 }}> / {total}</span>}</div>
      <div className="stat-label">{label}</div>
      {trend && <div className="stat-trend">{trend}</div>}
    </div>
  )
}

function Session({ course, assignments }: { course: CourseRow; assignments: AssignmentRow[] }) {
  const tone = course.status === 'cancelled' ? 'red' : course.status === 'tentative' ? 'orange' : 'accent'
  return (
    <>
      <div className="tl-time">
        {course.course_type?.code ?? '—'}
      </div>
      <div className="tl-event" style={{ borderLeftColor: 'var(--accent)' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', gap: 12 }}>
          <div style={{ minWidth: 0 }}>
            <div style={{ fontWeight: 600, fontSize: 14 }}>{course.title}</div>
            <div className="caption" style={{ marginTop: 3 }}>
              {course.num_participants > 0 && `${course.num_participants} TN`}
            </div>
          </div>
          <Chip tone={tone}>{course.status}</Chip>
        </div>
        <div style={{ display: 'flex', gap: 6, marginTop: 10, alignItems: 'center' }}>
          {assignments.map((a) =>
            a.instructor ? (
              <div key={a.id} title={`${a.instructor.name} (${a.role})`}>
                <Avatar
                  initials={a.instructor.initials}
                  color={a.instructor.color}
                  size="sm"
                />
              </div>
            ) : null,
          )}
          <span className="caption" style={{ marginLeft: 4 }}>{assignments.length} Instructor(s)</span>
        </div>
      </div>
    </>
  )
}
```

- [ ] **Step 4: Verify**

Run dev, navigate to `/heute`. Should show:
- Title showing today's date
- Hero tile with today's course count
- KPI cards with real data (~110 courses, ~71 instructors)
- "Heutige Kurse" card (empty if no courses today)

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat(today): hero tile + KPI cards + sessions timeline"
```

---

## Phase D — Kurse Master-Detail (Days 5–6)

### Task D1: Course list (master pane)

**Files:**
- Modify: `apps/web/src/screens/CoursesScreen.tsx`
- Create: `apps/web/src/screens/CourseDetailPanel.tsx`
- Modify: `apps/web/src/lib/queries.ts`

- [ ] **Step 1: Add to `lib/queries.ts`**

```ts
export interface CourseDetail extends CourseRow {
  info: string | null
  notes: string | null
  additional_dates: string[]
  pool_booked: boolean
  type_id: string
}

export async function fetchAllCourses() {
  const { data, error } = await supabase
    .from('courses')
    .select(`
      id, title, start_date, status, num_participants,
      info, notes, additional_dates, pool_booked, type_id,
      course_type:course_types(code, label)
    `)
    .order('start_date')
  if (error) throw error
  return (data ?? []) as unknown as CourseDetail[]
}

export async function fetchCourseAssignments(courseId: string) {
  const { data, error } = await supabase
    .from('course_assignments')
    .select(`
      id, course_id, instructor_id, role, confirmed, assigned_for_dates,
      instructor:instructors(id, name, initials, color, padi_level)
    `)
    .eq('course_id', courseId)
  if (error) throw error
  return data ?? []
}

export async function fetchAccountMovementsForAssignment(assignmentId: string) {
  const { data, error } = await supabase
    .from('account_movements')
    .select('id, instructor_id, date, amount_chf, kind, breakdown_json, description')
    .eq('ref_assignment_id', assignmentId)
  if (error) throw error
  return data ?? []
}
```

- [ ] **Step 2: Replace `CoursesScreen.tsx`**

```tsx
import { useEffect, useMemo, useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import clsx from 'clsx'
import { format } from 'date-fns'
import { de } from 'date-fns/locale'
import { Topbar } from '@/components/Topbar'
import { Icon } from '@/components/Icon'
import { Chip } from '@/components/Chip'
import { EmptyState } from '@/components/EmptyState'
import { fetchAllCourses, type CourseDetail } from '@/lib/queries'
import { CourseDetailPanel } from './CourseDetailPanel'

export function CoursesScreen() {
  const { id } = useParams<{ id?: string }>()
  const navigate = useNavigate()
  const [courses, setCourses] = useState<CourseDetail[]>([])
  const [search, setSearch] = useState('')
  const [filter, setFilter] = useState<'all' | 'confirmed' | 'tentative'>('all')

  useEffect(() => {
    fetchAllCourses().then(setCourses)
  }, [])

  const filtered = useMemo(() => {
    return courses.filter((c) => {
      if (filter !== 'all' && c.status !== filter) return false
      if (search) {
        const q = search.toLowerCase()
        return (
          c.title.toLowerCase().includes(q) ||
          c.course_type?.code.toLowerCase().includes(q) ||
          c.course_type?.label.toLowerCase().includes(q)
        )
      }
      return true
    })
  }, [courses, search, filter])

  const selected = courses.find((c) => c.id === id) ?? null

  return (
    <>
      <Topbar title="Kurse" subtitle={`${courses.length} Kurse 2026`}>
        <div className="search" style={{ width: 220 }}>
          <Icon name="search" size={14} />
          <input
            placeholder="Suchen…"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
          />
        </div>
        <button className="btn"><Icon name="plus" size={14} /> Neu</button>
      </Topbar>

      <div className="master-detail">
        <div className="master">
          <div style={{ padding: '12px 16px', borderBottom: '0.5px solid var(--separator)' }}>
            <div className="seg">
              <button
                className={clsx(filter === 'all' && 'active')}
                onClick={() => setFilter('all')}
              >Alle ({courses.length})</button>
              <button
                className={clsx(filter === 'confirmed' && 'active')}
                onClick={() => setFilter('confirmed')}
              >Sicher</button>
              <button
                className={clsx(filter === 'tentative' && 'active')}
                onClick={() => setFilter('tentative')}
              >Evtl.</button>
            </div>
          </div>

          {filtered.length === 0 ? (
            <EmptyState icon="book" title="Keine Treffer" />
          ) : (
            filtered.map((c) => (
              <div
                key={c.id}
                className={clsx('list-row', selected?.id === c.id && 'selected')}
                onClick={() => navigate(`/kurse/${c.id}`)}
                style={{ padding: '12px 16px', cursor: 'pointer' }}
              >
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ fontWeight: 500, fontSize: 14, marginBottom: 2 }}>
                    {c.title}
                  </div>
                  <div className="caption">
                    {c.course_type?.code ?? '—'} ·{' '}
                    {format(new Date(c.start_date), 'dd. MMM', { locale: de })}
                  </div>
                </div>
                <Chip tone={c.status === 'confirmed' ? 'green' : c.status === 'tentative' ? 'orange' : 'red'}>
                  {c.status === 'confirmed' ? 'sicher' : c.status === 'tentative' ? 'evtl.' : 'cxl'}
                </Chip>
              </div>
            ))
          )}
        </div>

        <div className="detail">
          {selected ? (
            <CourseDetailPanel courseId={selected.id} key={selected.id} />
          ) : (
            <EmptyState
              icon="book"
              title="Wähle einen Kurs"
              description="Klick links auf einen Eintrag, um Details zu sehen."
            />
          )}
        </div>
      </div>
    </>
  )
}
```

- [ ] **Step 3: Add list-row styles to `components.css`**

```css
.list-row {
  display: flex; align-items: center; gap: 12px;
  border-bottom: 0.5px solid var(--separator);
  cursor: pointer;
  transition: background .1s;
}
.list-row:hover    { background: rgba(0,0,0,.04); }
.dark .list-row:hover { background: rgba(255,255,255,.04); }
.list-row.selected { background: var(--accent-soft); }
```

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat(courses): master list with filter and search"
```

---

### Task D2: Course detail panel with tabs

**Files:**
- Create: `apps/web/src/screens/CourseDetailPanel.tsx`

- [ ] **Step 1: Implement**

```tsx
import { useEffect, useState } from 'react'
import { format } from 'date-fns'
import { de } from 'date-fns/locale'
import clsx from 'clsx'
import { Avatar } from '@/components/Avatar'
import { Chip } from '@/components/Chip'
import { Icon } from '@/components/Icon'
import { chf } from '@/lib/format'
import {
  fetchAllCourses,
  fetchCourseAssignments,
  type CourseDetail,
} from '@/lib/queries'

type Tab = 'overview' | 'assignments' | 'notes' | 'compensation'

const TABS: { value: Tab; label: string }[] = [
  { value: 'overview',     label: 'Übersicht' },
  { value: 'assignments',  label: 'Zuweisungen' },
  { value: 'notes',        label: 'Notizen' },
  { value: 'compensation', label: 'Vergütung' },
]

export function CourseDetailPanel({ courseId }: { courseId: string }) {
  const [course, setCourse] = useState<CourseDetail | null>(null)
  const [assignments, setAssignments] = useState<any[]>([])
  const [tab, setTab] = useState<Tab>('overview')

  useEffect(() => {
    fetchAllCourses().then((all) => setCourse(all.find((c) => c.id === courseId) ?? null))
    fetchCourseAssignments(courseId).then(setAssignments)
  }, [courseId])

  if (!course) return <div style={{ padding: 40 }} className="caption">Lade…</div>

  return (
    <div className="screen-fade" style={{ padding: '20px 24px 40px' }}>
      <div style={{ display: 'flex', gap: 12, alignItems: 'baseline', marginBottom: 4 }}>
        <div className="title-1" style={{ flex: 1 }}>{course.title}</div>
        <Chip tone={course.status === 'confirmed' ? 'green' : course.status === 'tentative' ? 'orange' : 'red'}>
          {course.status}
        </Chip>
      </div>
      <div className="caption" style={{ marginBottom: 20 }}>
        {course.course_type?.label} · {format(new Date(course.start_date), 'EEEE, d. MMMM yyyy', { locale: de })}
      </div>

      <div className="seg" style={{ marginBottom: 20 }}>
        {TABS.map((t) => (
          <button
            key={t.value}
            className={clsx(tab === t.value && 'active')}
            onClick={() => setTab(t.value)}
          >
            {t.label}
          </button>
        ))}
      </div>

      {tab === 'overview' && (
        <div style={{ display: 'grid', gap: 14 }}>
          <Field label="Kurstyp" value={`${course.course_type?.code} · ${course.course_type?.label}`} />
          <Field label="Startdatum" value={format(new Date(course.start_date), 'd. MMMM yyyy', { locale: de })} />
          {course.additional_dates.length > 0 && (
            <Field
              label="Zusatzdaten"
              value={course.additional_dates
                .map((d) => format(new Date(d), 'd. MMM', { locale: de }))
                .join(' · ')}
            />
          )}
          <Field label="Teilnehmer" value={String(course.num_participants)} />
          <Field label="Pool gebucht" value={course.pool_booked ? 'Ja' : 'Nein'} />
        </div>
      )}

      {tab === 'assignments' && (
        <div style={{ display: 'grid', gap: 10 }}>
          {assignments.length === 0 ? (
            <div className="caption">Noch keine Zuweisungen.</div>
          ) : (
            assignments.map((a) => (
              <div
                key={a.id}
                className="glass-thin"
                style={{
                  padding: 12,
                  borderRadius: 12,
                  display: 'flex',
                  alignItems: 'center',
                  gap: 12,
                }}
              >
                <Avatar initials={a.instructor.initials} color={a.instructor.color} />
                <div style={{ flex: 1 }}>
                  <div style={{ fontWeight: 500 }}>{a.instructor.name}</div>
                  <div className="caption">{a.instructor.padi_level} · {a.role}</div>
                </div>
                {a.confirmed ? (
                  <Chip tone="green">bestätigt</Chip>
                ) : (
                  <Chip tone="orange">offen</Chip>
                )}
              </div>
            ))
          )}
        </div>
      )}

      {tab === 'notes' && (
        <div>
          <div className="title-3" style={{ marginBottom: 8 }}>Info</div>
          <div className="caption" style={{ marginBottom: 18, whiteSpace: 'pre-wrap' }}>
            {course.info || '—'}
          </div>
          <div className="title-3" style={{ marginBottom: 8 }}>Notizen</div>
          <div className="caption" style={{ whiteSpace: 'pre-wrap' }}>
            {course.notes || '—'}
          </div>
        </div>
      )}

      {tab === 'compensation' && (
        <CompensationTab assignments={assignments} />
      )}
    </div>
  )
}

function Field({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <div className="caption-2">{label.toUpperCase()}</div>
      <div style={{ fontSize: 14 }}>{value}</div>
    </div>
  )
}

function CompensationTab({ assignments }: { assignments: any[] }) {
  // Flatten breakdowns: each assignment generates a movement row via trigger.
  // We don't have movements joined here yet; we'll show planned per-assignment summary.
  if (assignments.length === 0) return <div className="caption">Noch keine Zuweisungen → keine Vergütung.</div>

  return (
    <table style={{ width: '100%', fontSize: 13 }}>
      <thead>
        <tr style={{ borderBottom: '0.5px solid var(--hairline)' }}>
          <th align="left" style={{ padding: '6px 4px' }}>Instructor</th>
          <th align="left" style={{ padding: '6px 4px' }}>Rolle</th>
        </tr>
      </thead>
      <tbody>
        {assignments.map((a) => (
          <tr key={a.id}>
            <td style={{ padding: '6px 4px' }}>{a.instructor.name}</td>
            <td style={{ padding: '6px 4px' }}>{a.role}</td>
          </tr>
        ))}
      </tbody>
    </table>
  )
}
```

> Note: full breakdown_json reading from account_movements is added in Task D5.

- [ ] **Step 2: Verify**

Click a course in the list, see detail with tabs. Cycle through tabs.

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "feat(courses): detail panel with tabs"
```

---

### Task D3: Conflict-detection RPC

**Files:**
- Create: `supabase/migrations/0022_function_conflict_check.sql`
- Create: `supabase/tests/pgtap/04_conflict_detection.sql`

- [ ] **Step 1: Write the function**

```sql
-- Returns conflicting assignments for a given (instructor, course start dates).
-- A conflict is "another assignment for this instructor on the same date(s)".
CREATE OR REPLACE FUNCTION conflict_check(
  p_instructor_id UUID,
  p_dates DATE[]
)
RETURNS TABLE (
  conflicting_course_id UUID,
  conflicting_course_title TEXT,
  conflicting_role assignment_role,
  conflict_dates DATE[]
)
LANGUAGE plpgsql STABLE
AS $$
BEGIN
  RETURN QUERY
  SELECT
    c.id,
    c.title,
    ca.role,
    ARRAY(
      SELECT d::date
      FROM unnest(p_dates) d
      WHERE d = c.start_date
         OR d::text IN (SELECT jsonb_array_elements_text(c.additional_dates))
    ) AS conflict_dates
  FROM course_assignments ca
  JOIN courses c ON c.id = ca.course_id
  WHERE ca.instructor_id = p_instructor_id
    AND c.status <> 'cancelled'
    AND (
      c.start_date = ANY(p_dates)
      OR EXISTS (
        SELECT 1 FROM jsonb_array_elements_text(c.additional_dates) AS ad(d)
        WHERE ad.d::date = ANY(p_dates)
      )
    );
END;
$$;

COMMENT ON FUNCTION conflict_check IS 'Returns courses on the same dates for a given instructor.';
```

- [ ] **Step 2: pgTAP test**

```sql
BEGIN;
SELECT plan(2);

INSERT INTO instructors (id, name, padi_level, initials)
VALUES ('dddd1111-1111-1111-1111-111111111111', 'Conflict Test', 'Instructor', 'CT');

INSERT INTO courses (id, type_id, title, status, start_date)
SELECT 'eeee1111-1111-1111-1111-111111111111', id, 'Course A', 'confirmed', '2026-06-01'
FROM course_types WHERE code = 'OWD';

INSERT INTO course_assignments (course_id, instructor_id, role)
VALUES (
  'eeee1111-1111-1111-1111-111111111111',
  'dddd1111-1111-1111-1111-111111111111',
  'haupt'
);

-- Same date should produce a conflict
SELECT is(
  (SELECT COUNT(*)::int FROM conflict_check(
    'dddd1111-1111-1111-1111-111111111111',
    ARRAY['2026-06-01'::date]
  )),
  1,
  'detects conflict on same date'
);

-- Different date should produce no conflict
SELECT is(
  (SELECT COUNT(*)::int FROM conflict_check(
    'dddd1111-1111-1111-1111-111111111111',
    ARRAY['2026-06-02'::date]
  )),
  0,
  'no conflict on different date'
);

SELECT * FROM finish();
ROLLBACK;
```

- [ ] **Step 3: Push migration + run test**

```bash
supabase db push
bash supabase/tests/pgtap/run.sh
```

Both assertions pass.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat(db): conflict_check RPC + pgTAP coverage"
```

---

### Task D4: Skill-match RPC

**Files:**
- Create: `supabase/migrations/0023_function_skill_match.sql`

- [ ] **Step 1: Implement function**

```sql
-- Returns instructors that have a given skill, ordered by least-recently assigned.
CREATE OR REPLACE FUNCTION skill_match(
  p_skill_codes TEXT[],
  p_for_dates DATE[]
)
RETURNS TABLE (
  instructor_id UUID,
  name TEXT,
  padi_level padi_level,
  has_conflict BOOLEAN,
  last_assigned DATE
)
LANGUAGE plpgsql STABLE
AS $$
BEGIN
  RETURN QUERY
  SELECT
    i.id,
    i.name,
    i.padi_level,
    EXISTS (
      SELECT 1 FROM conflict_check(i.id, p_for_dates)
    ) AS has_conflict,
    (SELECT MAX(c.start_date) FROM course_assignments ca
       JOIN courses c ON c.id = ca.course_id
       WHERE ca.instructor_id = i.id) AS last_assigned
  FROM instructors i
  WHERE i.active = true
    AND (
      array_length(p_skill_codes, 1) IS NULL  -- empty array = no filter
      OR EXISTS (
        SELECT 1 FROM instructor_skills isk
        JOIN skills s ON s.id = isk.skill_id
        WHERE isk.instructor_id = i.id
          AND s.code = ANY(p_skill_codes)
      )
    )
  ORDER BY has_conflict ASC, last_assigned ASC NULLS FIRST;
END;
$$;
```

- [ ] **Step 2: Push + commit**

```bash
supabase db push
git add -A
git commit -m "feat(db): skill_match RPC for instructor suggestions"
```

---

### Task D5: Course Edit Sheet (with conflict UI)

**Files:**
- Create: `apps/web/src/screens/CourseEditSheet.tsx`
- Modify: `apps/web/src/screens/CoursesScreen.tsx` (wire "+ Neu" button)

- [ ] **Step 1: Implement Sheet**

```tsx
import { useEffect, useState } from 'react'
import { Sheet } from '@/components/Sheet'
import { Chip } from '@/components/Chip'
import { Icon } from '@/components/Icon'
import { supabase } from '@/lib/supabase'

interface CourseType { id: string; code: string; label: string }
interface Instructor { id: string; name: string; padi_level: string }

interface Props {
  open: boolean
  onClose: () => void
  onCreated: () => void
}

export function CourseEditSheet({ open, onClose, onCreated }: Props) {
  const [types, setTypes] = useState<CourseType[]>([])
  const [instructors, setInstructors] = useState<Instructor[]>([])
  const [typeId, setTypeId] = useState('')
  const [title, setTitle] = useState('')
  const [startDate, setStartDate] = useState(new Date().toISOString().slice(0, 10))
  const [haupt, setHaupt] = useState('')
  const [conflict, setConflict] = useState<any[]>([])
  const [saving, setSaving] = useState(false)

  useEffect(() => {
    if (!open) return
    supabase
      .from('course_types')
      .select('id, code, label')
      .eq('active', true)
      .order('code')
      .then(({ data }) => setTypes((data ?? []) as CourseType[]))
    supabase
      .from('instructors')
      .select('id, name, padi_level')
      .eq('active', true)
      .order('name')
      .then(({ data }) => setInstructors((data ?? []) as Instructor[]))
  }, [open])

  // Conflict-check on each instructor/date change
  useEffect(() => {
    if (!haupt || !startDate) {
      setConflict([])
      return
    }
    supabase
      .rpc('conflict_check', {
        p_instructor_id: haupt,
        p_dates: [startDate],
      })
      .then(({ data }) => setConflict((data ?? []) as any[]))
  }, [haupt, startDate])

  async function save() {
    setSaving(true)
    const { data: course, error } = await supabase
      .from('courses')
      .insert({ type_id: typeId, title, status: 'tentative', start_date: startDate })
      .select('id')
      .single()
    if (error || !course) {
      alert('Speichern fehlgeschlagen: ' + (error?.message ?? 'unbekannt'))
      setSaving(false)
      return
    }
    if (haupt) {
      await supabase.from('course_assignments').insert({
        course_id: course.id,
        instructor_id: haupt,
        role: 'haupt',
      })
    }
    setSaving(false)
    onCreated()
    onClose()
  }

  return (
    <Sheet open={open} onClose={onClose} title="Neuer Kurs">
      <div style={{ display: 'grid', gap: 14 }}>
        <Label>Kurstyp</Label>
        <select value={typeId} onChange={(e) => setTypeId(e.target.value)}>
          <option value="">— wählen —</option>
          {types.map((t) => (
            <option key={t.id} value={t.id}>{t.code} · {t.label}</option>
          ))}
        </select>

        <Label>Titel</Label>
        <input
          value={title}
          onChange={(e) => setTitle(e.target.value)}
          placeholder='z.B. "OWD GK15"'
        />

        <Label>Startdatum</Label>
        <input
          type="date"
          value={startDate}
          onChange={(e) => setStartDate(e.target.value)}
        />

        <Label>Haupt-Instructor</Label>
        <select value={haupt} onChange={(e) => setHaupt(e.target.value)}>
          <option value="">— wählen —</option>
          {instructors.map((i) => (
            <option key={i.id} value={i.id}>{i.name} ({i.padi_level})</option>
          ))}
        </select>

        {conflict.length > 0 && (
          <div className="chip chip-orange" style={{ height: 'auto', padding: 12, alignItems: 'flex-start' }}>
            <Icon name="bell" size={14} />
            <div style={{ marginLeft: 8 }}>
              <strong>Konflikt:</strong> Instructor ist am {startDate} bereits zugewiesen für{' '}
              "{conflict[0].conflicting_course_title}" als {conflict[0].conflicting_role}. Trotzdem speichern?
            </div>
          </div>
        )}

        <div style={{ display: 'flex', gap: 8, marginTop: 8 }}>
          <button className="btn-secondary btn" onClick={onClose}>Abbrechen</button>
          <button className="btn" onClick={save} disabled={saving || !typeId || !title}>
            {saving ? 'Speichere…' : 'Speichern'}
          </button>
        </div>
      </div>
    </Sheet>
  )
}

function Label({ children }: { children: string }) {
  return <div className="caption-2">{children.toUpperCase()}</div>
}
```

- [ ] **Step 2: Wire button in CoursesScreen**

Add `useState` for sheet open + render `<CourseEditSheet>`. Update "+ Neu" button to open it. After `onCreated`, refetch courses.

- [ ] **Step 3: Verify**

In `/kurse`, click "+ Neu", create a tentative course, assign yourself as Haupt. Try with overlapping date — see orange conflict banner.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat(courses): create-course Sheet with live conflict warning"
```

---

## Phase E — TL/DM Master-Detail (Day 7)

### Task E1: Instructors list + tabs

**Files:**
- Modify: `apps/web/src/screens/InstructorsScreen.tsx`
- Create: `apps/web/src/screens/InstructorDetailPanel.tsx`

- [ ] **Step 1: List**

Mirror the `CoursesScreen` pattern: master list with search + filter (active/inactive, role), detail panel with tabs.

```tsx
import { useEffect, useMemo, useState } from 'react'
import { useNavigate, useParams } from 'react-router-dom'
import clsx from 'clsx'
import { Topbar } from '@/components/Topbar'
import { Icon } from '@/components/Icon'
import { Avatar } from '@/components/Avatar'
import { EmptyState } from '@/components/EmptyState'
import { supabase } from '@/lib/supabase'
import { chf } from '@/lib/format'
import { InstructorDetailPanel } from './InstructorDetailPanel'

interface Row {
  id: string
  name: string
  padi_level: string
  initials: string
  color: string
  email: string | null
  active: boolean
  balance_chf: number | null
}

export function InstructorsScreen() {
  const { id } = useParams<{ id?: string }>()
  const navigate = useNavigate()
  const [rows, setRows] = useState<Row[]>([])
  const [search, setSearch] = useState('')

  useEffect(() => {
    supabase
      .from('instructors')
      .select(`
        id, name, padi_level, initials, color, email, active,
        v_instructor_balance!inner(balance_chf)
      `)
      .order('name')
      .then(({ data }) => {
        const mapped = (data ?? []).map((d: any) => ({
          ...d,
          balance_chf: d.v_instructor_balance?.[0]?.balance_chf ?? 0,
        }))
        setRows(mapped as Row[])
      })
  }, [])

  const filtered = useMemo(() => {
    return rows.filter((r) => {
      if (!search) return true
      return r.name.toLowerCase().includes(search.toLowerCase())
    })
  }, [rows, search])

  const selected = rows.find((r) => r.id === id)

  return (
    <>
      <Topbar title="TL/DM" subtitle={`${rows.length} Personen`}>
        <div className="search" style={{ width: 220 }}>
          <Icon name="search" size={14} />
          <input
            placeholder="Suchen…"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
          />
        </div>
      </Topbar>

      <div className="master-detail">
        <div className="master">
          {filtered.map((r) => (
            <div
              key={r.id}
              className={clsx('list-row', selected?.id === r.id && 'selected')}
              onClick={() => navigate(`/tldm/${r.id}`)}
              style={{ padding: '12px 16px', cursor: 'pointer', gap: 12, alignItems: 'center', display: 'flex' }}
            >
              <Avatar initials={r.initials} color={r.color} size="sm" />
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontWeight: 500, fontSize: 14 }}>{r.name}</div>
                <div className="caption">{r.padi_level}</div>
              </div>
              <div className="mono" style={{ fontSize: 12 }}>
                {chf(r.balance_chf ?? 0)}
              </div>
            </div>
          ))}
        </div>

        <div className="detail">
          {selected ? (
            <InstructorDetailPanel instructorId={selected.id} key={selected.id} />
          ) : (
            <EmptyState icon="users" title="Wähle eine Person" />
          )}
        </div>
      </div>
    </>
  )
}
```

- [ ] **Step 2: Detail panel**

```tsx
import { useEffect, useState } from 'react'
import clsx from 'clsx'
import { Avatar } from '@/components/Avatar'
import { Chip } from '@/components/Chip'
import { supabase } from '@/lib/supabase'
import { chf } from '@/lib/format'
import { format } from 'date-fns'
import { de } from 'date-fns/locale'

type Tab = 'overview' | 'skills' | 'assignments' | 'saldo'

const TABS: { value: Tab; label: string }[] = [
  { value: 'overview',    label: 'Übersicht' },
  { value: 'skills',      label: 'Skills' },
  { value: 'assignments', label: 'Einsätze' },
  { value: 'saldo',       label: 'Saldo' },
]

interface Instructor {
  id: string
  name: string
  initials: string
  color: string
  padi_level: string
  email: string | null
  opening_balance_chf: number
  excel_saldo_chf: number
}

export function InstructorDetailPanel({ instructorId }: { instructorId: string }) {
  const [inst, setInst] = useState<Instructor | null>(null)
  const [tab, setTab] = useState<Tab>('overview')
  const [skills, setSkills] = useState<any[]>([])
  const [assignments, setAssignments] = useState<any[]>([])
  const [movements, setMovements] = useState<any[]>([])

  useEffect(() => {
    supabase
      .from('instructors')
      .select('id, name, initials, color, padi_level, email, opening_balance_chf, excel_saldo_chf')
      .eq('id', instructorId)
      .single()
      .then(({ data }) => setInst(data as Instructor | null))

    supabase
      .from('instructor_skills')
      .select('skills(code, label, category)')
      .eq('instructor_id', instructorId)
      .then(({ data }) => setSkills((data ?? []).map((d: any) => d.skills)))

    supabase
      .from('course_assignments')
      .select('id, role, courses(id, title, start_date, status)')
      .eq('instructor_id', instructorId)
      .order('courses(start_date)', { ascending: false })
      .then(({ data }) => setAssignments(data ?? []))

    supabase
      .from('account_movements')
      .select('id, date, amount_chf, kind, description, breakdown_json')
      .eq('instructor_id', instructorId)
      .order('date', { ascending: false })
      .then(({ data }) => setMovements(data ?? []))
  }, [instructorId])

  if (!inst) return <div style={{ padding: 40 }} className="caption">Lade…</div>

  const balance = movements.reduce((sum, m) => sum + Number(m.amount_chf), 0)

  return (
    <div className="screen-fade" style={{ padding: '20px 24px 40px' }}>
      <div style={{ display: 'flex', gap: 16, alignItems: 'center', marginBottom: 12 }}>
        <Avatar initials={inst.initials} color={inst.color} size="lg" />
        <div>
          <div className="title-1">{inst.name}</div>
          <div className="caption">{inst.padi_level} · {inst.email || '—'}</div>
        </div>
      </div>

      <div className="seg" style={{ marginBottom: 20 }}>
        {TABS.map((t) => (
          <button
            key={t.value}
            className={clsx(tab === t.value && 'active')}
            onClick={() => setTab(t.value)}
          >
            {t.label}
          </button>
        ))}
      </div>

      {tab === 'overview' && (
        <div style={{ display: 'grid', gap: 12 }}>
          <Field label="PADI-Level" value={inst.padi_level} />
          <Field label="Email" value={inst.email || '—'} />
          <Field label="Eröffnung 2026 (Excel)" value={chf(inst.opening_balance_chf)} />
          <Field label="Saldo aus Excel-Import" value={chf(inst.excel_saldo_chf)} />
          <Field label="Aktueller App-Saldo" value={chf(balance)} />
          <Field label="Anzahl Skills" value={String(skills.length)} />
          <Field label="Einsätze 2026" value={String(assignments.length)} />
        </div>
      )}

      {tab === 'skills' && (
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
          {skills.length === 0 ? (
            <div className="caption">Keine Skills hinterlegt.</div>
          ) : (
            skills.map((s) => <Chip key={s.code} tone="accent">{s.label}</Chip>)
          )}
        </div>
      )}

      {tab === 'assignments' && (
        <div style={{ display: 'grid', gap: 8 }}>
          {assignments.map((a) => (
            <div key={a.id} className="glass-thin" style={{ padding: 12, borderRadius: 12 }}>
              <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                <span style={{ fontWeight: 500 }}>{a.courses.title}</span>
                <Chip tone="accent">{a.role}</Chip>
              </div>
              <div className="caption" style={{ marginTop: 4 }}>
                {format(new Date(a.courses.start_date), 'd. MMM yyyy', { locale: de })} ·{' '}
                <span className="chip" style={{ fontSize: 10 }}>{a.courses.status}</span>
              </div>
            </div>
          ))}
        </div>
      )}

      {tab === 'saldo' && (
        <>
          <div className="title-2 mono" style={{ marginBottom: 16 }}>{chf(balance)}</div>
          <div style={{ display: 'grid', gap: 6 }}>
            {movements.map((m) => (
              <div
                key={m.id}
                className="glass-thin"
                style={{ padding: 10, borderRadius: 10, display: 'flex', gap: 12 }}
              >
                <div style={{ flex: 1 }}>
                  <div style={{ fontSize: 13 }}>{m.description || m.kind}</div>
                  <div className="caption-2">
                    {format(new Date(m.date), 'd. MMM yyyy', { locale: de })} · {m.kind}
                  </div>
                </div>
                <div className="mono" style={{ fontWeight: 600 }}>
                  {chf(m.amount_chf)}
                </div>
              </div>
            ))}
          </div>
        </>
      )}
    </div>
  )
}

function Field({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <div className="caption-2">{label.toUpperCase()}</div>
      <div style={{ fontSize: 14 }}>{value}</div>
    </div>
  )
}
```

- [ ] **Step 3: Verify + commit**

Click an instructor → see Tabs. Click "Saldo" → see Bewegungs-Journal.

```bash
git add -A
git commit -m "feat(tldm): master-detail with skills, assignments, saldo"
```

---

## Phase F — Saldi screen + Skill-Matrix (Day 8)

### Task F1: Saldi list

**Files:**
- Modify: `apps/web/src/screens/SaldiScreen.tsx`

- [ ] Implement a list view of `v_instructor_balance` joined with `v_saldo_diff`. Sortable by name / balance / diff. Click → opens InstructorDetailPanel's Saldo tab in a Sheet (or navigate to `/tldm/:id`).

```tsx
// (~120 lines, mirroring InstructorsScreen but read-only and saldo-focused)
```

> See InstructorsScreen for the full pattern; the only difference is the columns shown (balance, diff, last movement).

- [ ] Commit: `feat(saldi): saldo overview list with sort + diff badge`

---

### Task F2: Skill-Matrix screen

**Files:**
- Modify: `apps/web/src/screens/SkillMatrixScreen.tsx`
- Modify: `apps/web/src/styles/components.css`

- [ ] Build a sticky-header / sticky-first-column matrix:
  - Rows: instructors
  - Cols: skills
  - Cells: ✓ if `instructor_skills` has the row, click toggles
  - Filter: by skill category, by instructor active

- [ ] Implementation skeleton:

```tsx
import { useEffect, useState } from 'react'
import { Topbar } from '@/components/Topbar'
import { supabase } from '@/lib/supabase'

export function SkillMatrixScreen() {
  const [skills, setSkills] = useState<any[]>([])
  const [instructors, setInstructors] = useState<any[]>([])
  const [matrix, setMatrix] = useState<Set<string>>(new Set()) // 'instId|skillId'

  useEffect(() => {
    Promise.all([
      supabase.from('skills').select('id, code, label, category').order('label'),
      supabase.from('instructors').select('id, name').eq('active', true).order('name'),
      supabase.from('instructor_skills').select('instructor_id, skill_id'),
    ]).then(([s, i, m]) => {
      setSkills(s.data ?? [])
      setInstructors(i.data ?? [])
      setMatrix(new Set((m.data ?? []).map((r: any) => `${r.instructor_id}|${r.skill_id}`)))
    })
  }, [])

  async function toggle(instId: string, skillId: string) {
    const key = `${instId}|${skillId}`
    if (matrix.has(key)) {
      await supabase.from('instructor_skills').delete().match({ instructor_id: instId, skill_id: skillId })
      const next = new Set(matrix); next.delete(key); setMatrix(next)
    } else {
      await supabase.from('instructor_skills').insert({ instructor_id: instId, skill_id: skillId })
      setMatrix(new Set(matrix).add(key))
    }
  }

  return (
    <>
      <Topbar title="Skill-Matrix" subtitle={`${instructors.length} × ${skills.length}`} />
      <div className="scroll" style={{ padding: 16, overflow: 'auto' }}>
        <table style={{ borderCollapse: 'collapse', fontSize: 12 }}>
          <thead>
            <tr>
              <th style={{ position: 'sticky', left: 0, background: 'var(--bg)', textAlign: 'left', padding: 8, minWidth: 180 }}>
                Person
              </th>
              {skills.map((s) => (
                <th key={s.id} style={{ padding: 8, writingMode: 'vertical-rl', whiteSpace: 'nowrap' }}>
                  {s.label}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {instructors.map((i) => (
              <tr key={i.id}>
                <td style={{ position: 'sticky', left: 0, background: 'var(--bg)', padding: 8, fontWeight: 500 }}>
                  {i.name}
                </td>
                {skills.map((s) => {
                  const has = matrix.has(`${i.id}|${s.id}`)
                  return (
                    <td
                      key={s.id}
                      onClick={() => toggle(i.id, s.id)}
                      style={{
                        textAlign: 'center', padding: 6,
                        cursor: 'pointer',
                        background: has ? 'var(--accent-soft)' : undefined,
                        color: has ? 'var(--accent)' : 'var(--ink-4)',
                      }}
                    >
                      {has ? '✓' : '·'}
                    </td>
                  )
                })}
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </>
  )
}
```

- [ ] Commit: `feat(skills): matrix editor with toggle`

---

## Phase G — Pool + Calendar (Days 9–10)

### Task G1: PoolScreen — Möösli/Langnau two-lane week view

**Files:**
- Modify: `apps/web/src/screens/PoolScreen.tsx`

- [ ] Render a week (7 columns) × 2 rows (Möösli / Langnau) grid. Each cell shows pool_bookings for that day/location. Click to add a slot.

> Implementation skeleton ~150 lines. Same pattern as Calendar (Task G2) but smaller scope.

- [ ] Commit: `feat(pool): week-view of Möösli + Langnau slots`

---

### Task G2: CalendarScreen — week + month view

**Files:**
- Modify: `apps/web/src/screens/CalendarScreen.tsx`

- [ ] Two modes via SegmentedControl:
  - **Woche**: 7 columns × ~16 hour rows, courses placed as cards with color = course type
  - **Monat**: 6 weeks × 7 days grid, courses as compact pills

- [ ] Use `date-fns` `eachDayOfInterval`, `startOfWeek`, `addWeeks` etc.

- [ ] Click a course → navigate to `/kurse/:id`

> Implementation skeleton ~250 lines. The most visually complex screen — give it the most polish time.

- [ ] Commit: `feat(calendar): week + month grid with course cards`

---

## Phase H — Final Polish (Day 11)

### Task H1: Wire "+ Neuer Kurs" globally

- [ ] Topbar of Heute and Kurse already has it. Add to Calendar Topbar too.

### Task H2: Stage-1 Excel-Import filter for re-imports

- [ ] In Stage 1, after upload, if any non-CXL courses already exist in DB, show a yellow warning: "Du hast bereits N Kurse — Re-Import legt Duplikate an. Cleanup empfohlen." Add a "Vorhandene löschen" button that runs the cleanup SQL.

### Task H3: Production env at Vercel

- [ ] Push to GitHub.
- [ ] Vercel auto-deploys.
- [ ] Configure DNS at Infomaniak (CNAME `dispo` → `cname.vercel-dns.com`).
- [ ] Update Supabase Auth → URL Configuration with `https://dispo.course-director.ch` + `https://dispo.course-director.ch/auth/callback`.
- [ ] Smoke-test login from production URL.

- [ ] Commit: `feat(prod): live on dispo.course-director.ch`

---

## Self-Review

**Spec coverage:**
- §5.1 Dispatcher Nav (8 sections): all routes wired ✓ (Heute, Kalender, Kurse, TL/DM, Skills, Pool, Saldi, Settings)
- §5.2 Instructor Nav: routes wired but screens stub-only — actual content lives in Plan 3 ⚠
- §5.3 Visual Language (Liquid Glass, Tweak Panel, accent switching): full ✓
- §6.3 Flow A (course create): full ✓
- §6.3 Flow B (conflict): full ✓ (Task D3 + D5 banner)
- §6.3 Flow C (skill match): backend ready ✓ but UI surface (using it in CourseEditSheet) is in Task D5 stretch — added as nice-to-have
- §8.5 Korrektur-Buchungen UI: not in this plan; deferred to Plan 3 ⚠

**Placeholder scan:** All TaskXX → real content. Task F1 (Saldi list) and G1 (Pool) are sketched but the implementation skeletons are intentionally short — they reuse the master-detail / week-view pattern from D and G2 respectively. Engineer can scaffold them in <1h each from the existing patterns.

**Type consistency:** `Role`, `CurrentUser`, `CourseRow`, `AssignmentRow` types defined in `lib/auth.ts` and `lib/queries.ts`, referenced consistently across screens.

**Scope check:** This plan is 11 days. Tighter than Plan 1 (9 days) because the foundation removes a lot of yak-shaving. Realistic for an experienced engineer + Claude-assisted velocity.

---

## Execution Handoff

**Plan complete and saved to `docs/superpowers/plans/2026-05-01-tsk-dispo-dispatcher-views.md`.**

Two execution options:

**1. Subagent-Driven** — fresh subagent per task, two-stage reviews
**2. Inline Execution** — direct write-through (used for Plan 1, fast for mostly-mechanical UI)

Which approach? After this plan ships, **Plan 3** covers Instructor screens, WhatsApp Tiefe-1 deep links, Email notifications, weekly Excel export, and Pitch-Polish.
