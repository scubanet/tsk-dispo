import clsx from 'clsx'
import { NavLink } from 'react-router-dom'
import { Icon, type IconName } from './Icon'
import type { Role } from '@/lib/auth'

interface SidebarProps {
  role: Role
  userName: string
  userEmail: string
  onLogout: () => void
}

interface NavItem {
  to: string
  icon: IconName
  label: string
  roles: Role[]
}

const ITEMS: NavItem[] = [
  { to: '/heute',     icon: 'house',    label: 'Heute',          roles: ['dispatcher', 'instructor'] },
  { to: '/kalender',  icon: 'calendar', label: 'Kalender',       roles: ['dispatcher', 'instructor'] },
  { to: '/kurse',     icon: 'book',     label: 'Kurse',          roles: ['dispatcher'] },
  { to: '/tldm',      icon: 'users',    label: 'TL/DM',          roles: ['dispatcher'] },
  { to: '/skills',    icon: 'grid',     label: 'Skill-Matrix',   roles: ['dispatcher'] },
  { to: '/pool',      icon: 'water',    label: 'Pool',           roles: ['dispatcher'] },
  { to: '/saldi',     icon: 'wallet',   label: 'Saldi',          roles: ['dispatcher'] },
  { to: '/einsaetze', icon: 'book',     label: 'Meine Einsätze', roles: ['instructor'] },
  { to: '/saldo',     icon: 'wallet',   label: 'Mein Saldo',     roles: ['instructor'] },
  { to: '/profil',    icon: 'tag',      label: 'Mein Profil',    roles: ['instructor'] },
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
            <div className="caption-2" style={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
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
