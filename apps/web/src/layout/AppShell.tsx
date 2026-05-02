import { Outlet, useNavigate } from 'react-router-dom'
import { useEffect, useState } from 'react'
import { Sidebar } from '@/components/Sidebar'
import { FloatingTabBar } from '@/components/FloatingTabBar'
import { Wallpaper } from '@/components/Wallpaper'
import { StatusBar } from '@/components/StatusBar'
import { useTweaks } from '@/lib/tweaks'
import { fetchCurrentUser, type CurrentUser } from '@/lib/auth'
import { supabase } from '@/lib/supabase'

export interface OutletCtx {
  user: CurrentUser
}

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
