import clsx from 'clsx'
import { NavLink } from 'react-router-dom'
import { Icon, type IconName } from './Icon'
import type { Role } from '@/lib/auth'

interface Tab {
  to: string
  icon: IconName
  label: string
}

interface Props {
  role: Role
}

const DISPATCHER_TABS: Tab[] = [
  { to: '/heute',     icon: 'house',    label: 'Heute' },
  { to: '/kurse',     icon: 'book',     label: 'Kurse' },
  { to: '/kalender',  icon: 'calendar', label: 'Kalender' },
  { to: '/tldm',      icon: 'users',    label: 'TL/DM' },
  { to: '/schueler',  icon: 'tag',      label: 'Schüler' },
  { to: '/saldi',     icon: 'wallet',   label: 'Saldi' },
]

const INSTRUCTOR_TABS: Tab[] = [
  { to: '/heute',     icon: 'house',    label: 'Heute' },
  { to: '/einsaetze', icon: 'book',     label: 'Einsätze' },
  { to: '/kalender',  icon: 'calendar', label: 'Kalender' },
  { to: '/saldo',     icon: 'wallet',   label: 'Saldo' },
  { to: '/profil',    icon: 'tag',      label: 'Profil' },
]

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
          <Icon name={t.icon} size={20} />
          <span>{t.label}</span>
        </NavLink>
      ))}
    </div>
  )
}
