import { Outlet, useNavigate } from 'react-router-dom'
import { useEffect, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { Sidebar } from '@/components/Sidebar'
import { FloatingTabBar } from '@/components/FloatingTabBar'
import { Wallpaper } from '@/components/Wallpaper'
import { StatusBar } from '@/components/StatusBar'
import { useTweaks } from '@/lib/tweaks'
import { fetchCurrentUser, type CurrentUser } from '@/lib/auth'
import { useSyncRemoteLanguage } from '@/i18n/useLanguage'
import { supabase } from '@/lib/supabase'

export interface OutletCtx {
  user: CurrentUser
}

export function AppShell() {
  const { t } = useTranslation()
  const [user, setUser] = useState<CurrentUser | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(false)
  const [reloadKey, setReloadKey] = useState(0)
  const [tweaks] = useTweaks()
  const navigate = useNavigate()

  // Pull preferred language from DB after auth — runs once authUserId is known.
  useSyncRemoteLanguage(user?.authUserId ?? null)

  useEffect(() => {
    let cancelled = false
    setLoading(true)
    setError(false)
    fetchCurrentUser()
      .then((u) => {
        if (cancelled) return
        setUser(u)
        setLoading(false)
      })
      .catch(() => {
        // Transient failure resolving the current user — show a retry instead
        // of silently demoting the role or logging the user out.
        if (cancelled) return
        setError(true)
        setLoading(false)
      })
    return () => {
      cancelled = true
    }
  }, [reloadKey])

  // Redirect happens in an effect, not during render (a render-time navigate
  // warns under StrictMode/concurrent and is order-dependent).
  useEffect(() => {
    if (!loading && !error && !user) navigate('/login', { replace: true })
  }, [loading, error, user, navigate])

  async function logout() {
    await supabase.auth.signOut()
    navigate('/login', { replace: true })
  }

  if (loading) return <div style={{ padding: 40 }}>{t('common.loading')}</div>
  if (error) {
    return (
      <div style={{ padding: 40, display: 'flex', flexDirection: 'column', gap: 12, alignItems: 'flex-start' }}>
        <span>{t('common.error')}</span>
        <button onClick={() => setReloadKey((k) => k + 1)}>{t('common.retry')}</button>
      </div>
    )
  }
  if (!user) return null

  const isSidebar = tweaks.layout === 'sidebar'

  return (
    <div style={{ height: '100vh', display: 'flex', flexDirection: 'column', position: 'relative' }}>
      <Wallpaper />
      <StatusBar />

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
          <Outlet context={{ user } satisfies OutletCtx} />
        </div>

        {!isSidebar && <FloatingTabBar role={user.role} />}
      </div>
    </div>
  )
}
