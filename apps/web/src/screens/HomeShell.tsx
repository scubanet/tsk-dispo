import { useEffect, useState } from 'react'
import { Wallpaper } from '@/components/Wallpaper'
import { StatusBar } from '@/components/StatusBar'
import { Avatar } from '@/components/Avatar'
import { supabase } from '@/lib/supabase'
import { fetchCurrentUser, type CurrentUser } from '@/lib/auth'
import { useNavigate } from 'react-router-dom'

export function HomeShell() {
  const [user, setUser] = useState<CurrentUser | null>(null)
  const navigate = useNavigate()

  useEffect(() => {
    fetchCurrentUser().then(setUser)
  }, [])

  async function logout() {
    await supabase.auth.signOut()
    navigate('/login', { replace: true })
  }

  return (
    <>
      <Wallpaper />
      <StatusBar />
      <div
        style={{
          display: 'grid',
          placeItems: 'center',
          height: '100vh',
          position: 'relative',
          zIndex: 1,
        }}
      >
        <div className="glass card" style={{ width: 480, padding: 28 }}>
          <div className="title-1" style={{ marginBottom: 6 }}>Willkommen ✓</div>
          <div className="caption" style={{ marginBottom: 24 }}>
            Plan 1 Foundation läuft. Volle UI in Plan 2.
          </div>

          {user && (
            <div style={{ display: 'flex', gap: 12, alignItems: 'center', marginBottom: 24 }}>
              <Avatar
                initials={user.name.slice(0, 2).toUpperCase()}
                color="#0A84FF"
              />
              <div>
                <div className="title-3">{user.name}</div>
                <div className="caption">
                  {user.email} · Rolle: <span className="chip chip-accent">{user.role}</span>
                </div>
              </div>
            </div>
          )}

          {(user?.role === 'dispatcher' || user?.role === 'cd') && (
            <button
              className="btn btn-secondary"
              onClick={() => navigate('/einstellungen/import')}
              style={{ marginRight: 8 }}
            >
              Excel-Import öffnen
            </button>
          )}

          <button className="btn-secondary btn" onClick={logout}>
            Logout
          </button>
        </div>
      </div>
    </>
  )
}
