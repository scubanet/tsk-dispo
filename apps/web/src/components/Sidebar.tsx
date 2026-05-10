import clsx from 'clsx'
import { NavLink } from 'react-router-dom'
import { useTranslation } from 'react-i18next'
import { Icon, type IconName } from './Icon'
import { Logo } from './Logo'
import { CopyrightFooter } from './CopyrightFooter'
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
  /** i18n key under `nav.*` */
  i18nKey: string
  roles: Role[]
}

const ITEMS: NavItem[] = [
  { to: '/cockpit',           icon: 'chart',    i18nKey: 'cockpit',         roles: ['dispatcher', 'owner', 'cd'] },
  { to: '/heute',             icon: 'house',    i18nKey: 'today',           roles: ['dispatcher', 'instructor', 'owner', 'cd'] },
  { to: '/kalender',          icon: 'calendar', i18nKey: 'calendar',        roles: ['dispatcher', 'instructor', 'owner', 'cd'] },
  { to: '/kurse',             icon: 'book',     i18nKey: 'courses',         roles: ['dispatcher', 'owner', 'cd'] },
  { to: '/tldm',              icon: 'users',    i18nKey: 'tldm',            roles: ['dispatcher', 'owner', 'cd'] },
  { to: '/schueler',          icon: 'tag',      i18nKey: 'students',        roles: ['dispatcher', 'owner', 'cd'] },
  { to: '/skills',            icon: 'grid',     i18nKey: 'skills',          roles: ['dispatcher', 'owner', 'cd'] },
  { to: '/pool',              icon: 'water',    i18nKey: 'pool',            roles: ['dispatcher', 'owner', 'cd'] },
  { to: '/saldi',             icon: 'wallet',   i18nKey: 'balances',        roles: ['dispatcher', 'owner', 'cd'] },
  { to: '/einsaetze',         icon: 'book',     i18nKey: 'my_assignments',  roles: ['instructor'] },
  { to: '/saldo',             icon: 'wallet',   i18nKey: 'my_balance',      roles: ['instructor'] },
  { to: '/profil',            icon: 'tag',      i18nKey: 'my_profile',      roles: ['instructor'] },
]

// ADRESSEN section: dispatcher / owner / cd
const ADRESSEN_ITEMS: NavItem[] = [
  { to: '/contacts',       icon: 'tag',   i18nKey: 'addressbook',       roles: ['dispatcher', 'owner', 'cd'] },
  { to: '/cd/pipeline',    icon: 'chart', i18nKey: 'pipeline',          roles: ['cd', 'owner'] },
  { to: '/communication',  icon: 'chart', i18nKey: 'communication_hub', roles: ['dispatcher', 'owner', 'cd'] },
]

// TEAM section: dispatcher / owner / cd
const TEAM_ITEMS: NavItem[] = [
  { to: '/contacts?view=team', icon: 'users', i18nKey: 'team_tldm',     roles: ['dispatcher', 'owner', 'cd'] },
  { to: '/skills',             icon: 'grid',  i18nKey: 'skills_matrix',  roles: ['dispatcher', 'owner', 'cd'] },
  { to: '/availability',       icon: 'calendar', i18nKey: 'availability', roles: ['dispatcher', 'owner', 'cd'] },
]

// CD module: CD role only.
const CD_ITEMS: NavItem[] = [
  { to: '/cd/pipeline', icon: 'chart', i18nKey: 'pipeline', roles: ['cd'] },
]

const ADMIN: NavItem[] = [
  { to: '/einstellungen', icon: 'settings', i18nKey: 'settings', roles: ['dispatcher', 'owner', 'cd'] },
]

export function Sidebar({ role, userName, userEmail, onLogout }: SidebarProps) {
  const { t } = useTranslation()
  const main = ITEMS.filter((i) => i.roles.includes(role))
  const adressen = ADRESSEN_ITEMS.filter((i) => i.roles.includes(role))
  const team = TEAM_ITEMS.filter((i) => i.roles.includes(role))
  const cd = CD_ITEMS.filter((i) => i.roles.includes(role))
  const admin = ADMIN.filter((i) => i.roles.includes(role))

  return (
    <aside className="sidebar glass-thin">
      <div style={{ padding: '8px 12px 18px', display: 'flex', gap: 12, alignItems: 'center' }}>
        <Logo size={48} />
        <div style={{ minWidth: 0 }}>
          <div style={{ fontSize: 16, fontWeight: 700, lineHeight: 1.1, letterSpacing: '.06em' }}>
            ATOLL
          </div>
          <div className="caption-2" style={{ marginTop: 3, fontSize: 11, opacity: 0.75 }}>
            The Scuba OS
          </div>
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
          <span>{t(`nav.${item.i18nKey}`)}</span>
        </NavLink>
      ))}

      {adressen.length > 0 && (
        <>
          <div className="sb-section">{t('nav.section_adressen')}</div>
          {adressen.map((item) => (
            <NavLink
              key={item.to}
              to={item.to}
              className={({ isActive }) => clsx('sb-row', isActive && 'active')}
            >
              <span className="sb-icon">
                <Icon name={item.icon} size={17} />
              </span>
              <span>{t(`nav.${item.i18nKey}`)}</span>
            </NavLink>
          ))}
        </>
      )}

      {team.length > 0 && (
        <>
          <div className="sb-section">{t('nav.section_team')}</div>
          {team.map((item) => (
            <NavLink
              key={item.to}
              to={item.to}
              className={({ isActive }) => clsx('sb-row', isActive && 'active')}
            >
              <span className="sb-icon">
                <Icon name={item.icon} size={17} />
              </span>
              <span>{t(`nav.${item.i18nKey}`)}</span>
            </NavLink>
          ))}
        </>
      )}

      {cd.length > 0 && (
        <>
          <div className="sb-section">{t('nav.section_cd')}</div>
          {cd.map((item) => (
            <NavLink
              key={item.to}
              to={item.to}
              className={({ isActive }) => clsx('sb-row', isActive && 'active')}
            >
              <span className="sb-icon">
                <Icon name={item.icon} size={17} />
              </span>
              <span>{t(`nav.${item.i18nKey}`)}</span>
            </NavLink>
          ))}
        </>
      )}

      {admin.length > 0 && (
        <>
          <div className="sb-section">{t('nav.section_admin')}</div>
          {admin.map((item) => (
            <NavLink
              key={item.to}
              to={item.to}
              className={({ isActive }) => clsx('sb-row', isActive && 'active')}
            >
              <span className="sb-icon">
                <Icon name={item.icon} size={17} />
              </span>
              <span>{t(`nav.${item.i18nKey}`)}</span>
            </NavLink>
          ))}
          <button
            type="button"
            onClick={onLogout}
            className="sb-row"
            style={{ background: 'transparent', border: 'none', font: 'inherit', textAlign: 'left', cursor: 'pointer', color: 'var(--ink)' }}
          >
            <span className="sb-icon">
              <Icon name="logout" size={17} />
            </span>
            <span>{t('auth.logout')}</span>
          </button>
        </>
      )}

      {/* Instructor hat keine Verwaltungs-Sektion → eigener Logout am Ende */}
      {admin.length === 0 && (
        <button
          type="button"
          onClick={onLogout}
          className="sb-row"
          style={{ marginTop: 12, background: 'transparent', border: 'none', font: 'inherit', textAlign: 'left', cursor: 'pointer', color: 'var(--ink)' }}
        >
          <span className="sb-icon">
            <Icon name="logout" size={17} />
          </span>
          <span>Abmelden</span>
        </button>
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
          <button className="btn-icon" onClick={onLogout} title={t('auth.logout')}>
            <Icon name="logout" size={14} />
          </button>
        </div>
        <CopyrightFooter variant="compact" />
      </div>
    </aside>
  )
}
