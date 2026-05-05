import { BrowserRouter, Route, Routes, Navigate } from 'react-router-dom'
import { useEffect, useState } from 'react'
import type { Session } from '@supabase/supabase-js'
import { supabase } from '@/lib/supabase'
import { LoginScreen } from '@/screens/LoginScreen'
import { AuthCallback } from '@/screens/AuthCallback'
import { ImportWizard } from '@/screens/ImportWizard'
import { AppShell } from '@/layout/AppShell'
import { TodayScreen } from '@/screens/TodayScreen'
import { CoursesScreen } from '@/screens/CoursesScreen'
import { InstructorsScreen } from '@/screens/InstructorsScreen'
import { SkillMatrixScreen } from '@/screens/SkillMatrixScreen'
import { PoolScreen } from '@/screens/PoolScreen'
import { SaldiScreen } from '@/screens/SaldiScreen'
import { CalendarScreen } from '@/screens/CalendarScreen'
import { SettingsScreen } from '@/screens/SettingsScreen'
import { StudentsScreen } from '@/screens/StudentsScreen'
import { MyAssignmentsScreen } from '@/screens/MyAssignmentsScreen'
import { MySaldoScreen } from '@/screens/MySaldoScreen'
import { MyProfileScreen } from '@/screens/MyProfileScreen'
import { CockpitScreen } from '@/screens/CockpitScreen'
import { CDCandidatesScreen } from '@/screens/cd/CDCandidatesScreen'
import { CDOnlyCandidatesScreen } from '@/screens/cd/CDOnlyCandidatesScreen'
import { CDPipelineScreen } from '@/screens/cd/CDPipelineScreen'
import { CDOrganizationsScreen } from '@/screens/cd/CDOrganizationsScreen'

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

        {/* All authenticated routes wrapped in AppShell */}
        <Route element={session ? <AppShell /> : <Navigate to="/login" replace />}>
          <Route path="/heute"                  element={<TodayScreen />} />
          <Route path="/cockpit"                element={<CockpitScreen />} />
          <Route path="/kalender"               element={<CalendarScreen />} />
          <Route path="/kurse"                  element={<CoursesScreen />} />
          <Route path="/kurse/:id"              element={<CoursesScreen />} />
          <Route path="/tldm"                   element={<InstructorsScreen />} />
          <Route path="/tldm/:id"               element={<InstructorsScreen />} />
          <Route path="/schueler"               element={<StudentsScreen />} />
          <Route path="/schueler/:id"           element={<StudentsScreen />} />
          <Route path="/skills"                 element={<SkillMatrixScreen />} />
          <Route path="/pool"                   element={<PoolScreen />} />
          <Route path="/saldi"                  element={<SaldiScreen />} />
          <Route path="/einstellungen"          element={<SettingsScreen />} />
          <Route path="/einstellungen/import"   element={<ImportWizard />} />
          <Route path="/einsaetze"              element={<MyAssignmentsScreen />} />
          <Route path="/saldo"                  element={<MySaldoScreen />} />
          <Route path="/profil"                 element={<MyProfileScreen />} />
          {/* CD-Modul */}
          <Route path="/cd/kontakte"            element={<CDCandidatesScreen />} />
          <Route path="/cd/kandidaten"          element={<CDOnlyCandidatesScreen />} />
          <Route path="/cd/pipeline"            element={<CDPipelineScreen />} />
          <Route path="/cd/organisationen"      element={<CDOrganizationsScreen />} />
          <Route path="*"                       element={<Navigate to="/heute" replace />} />
        </Route>
      </Routes>
    </BrowserRouter>
  )
}

export default App
