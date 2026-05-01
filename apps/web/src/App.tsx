import { BrowserRouter, Route, Routes, Navigate } from 'react-router-dom'
import { useEffect, useState } from 'react'
import type { Session } from '@supabase/supabase-js'
import { supabase } from '@/lib/supabase'
import { LoginScreen } from '@/screens/LoginScreen'
import { AuthCallback } from '@/screens/AuthCallback'
import { HomeShell } from '@/screens/HomeShell'
import { ImportWizard } from '@/screens/ImportWizard'

function App() {
  const [session, setSession] = useState<Session | null>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    supabase.auth.getSession().then(({ data }) => {
      setSession(data.session)
      setLoading(false)
    })
    const { data: sub } = supabase.auth.onAuthStateChange((_event, s) => {
      setSession(s)
    })
    return () => sub.subscription.unsubscribe()
  }, [])

  if (loading) return <div style={{ padding: 40 }}>Lade…</div>

  return (
    <BrowserRouter>
      <Routes>
        <Route
          path="/login"
          element={session ? <Navigate to="/heute" replace /> : <LoginScreen />}
        />
        <Route path="/auth/callback" element={<AuthCallback />} />
        <Route
          path="/heute"
          element={session ? <HomeShell /> : <Navigate to="/login" replace />}
        />
        <Route
          path="/einstellungen/import"
          element={session ? <ImportWizard /> : <Navigate to="/login" replace />}
        />
        <Route path="*" element={<Navigate to={session ? '/heute' : '/login'} replace />} />
      </Routes>
    </BrowserRouter>
  )
}

export default App
