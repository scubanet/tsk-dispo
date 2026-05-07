import clsx from 'clsx'
import { NavLink, useNavigate } from 'react-router-dom'
import { useTranslation } from 'react-i18next'
import { Icon, type IconName } from './Icon'
import { supabase } from '@/lib/supabase'
import type { Role } from '@/lib/auth'

interface Tab {
  to: string
  icon: IconName
  /** key under `nav.tab_*` */
  tabKey: string
}

interface Props {
  role: Role
}

const DISPATCHER_TABS: Tab[] = [
  { to: '/heute',     icon: 'house',    tabKey: 'today' },
  { to: '/kurse',     icon: 'book',     tabKey: 'courses' },
  { to: '/kalender',  icon: 'calendar', tabKey: 'calendar' },
  { to: '/tldm',      icon: 'users',    tabKey: 'tldm' },
  { to: '/schueler',  icon: 'tag',      tabKey: 'students' },
  { to: '/saldi',     icon: 'wallet',   tabKey: 'balances' },
]

const INSTRUCTOR_TABS: Tab[] = [
  { to: '/heute',     icon: 'house',    tabKey: 'today' },
  { to: '/einsaetze', icon: 'book',     tabKey: 'assignments' },
  { to: '/kalender',  icon: 'calendar', tabKey: 'calendar' },
  { to: '/saldo',     icon: 'wallet',   tabKey: 'balance' },
  { to: '/profil',    icon: 'tag',      tabKey: 'profile' },
]

export function FloatingTabBar({ role }: Props) {
  const { t } = useTranslation()
  const tabs = role === 'dispatcher' || role === 'cd' ? DISPATCHER_TABS : INSTRUCTOR_TABS
  const navigate = useNavigate()

  async function logout() {
    await supabase.auth.signOut()
    navigate('/login', { replace: true })
  }

  return (
    <div className="tabbar glass-strong">
      {tabs.map((tab) => (
        <NavLink
          key={tab.to}
          to={tab.to}
          className={({ isActive }) => clsx('tb-item', isActive && 'active')}
        >
          <Icon name={tab.icon} size={20} />
          <span>{t(`nav.tab_${tab.tabKey}`)}</span>
        </NavLink>
      ))}
      <button
        type="button"
        onClick={logout}
        className="tb-item"
        style={{ background: 'transparent', border: 'none', font: 'inherit', cursor: 'pointer', color: 'inherit' }}
        title={t('auth.logout')}
      >
        <Icon name="logout" size={20} />
        <span>{t('nav.tab_logout')}</span>
      </button>
    </div>
  )
}
