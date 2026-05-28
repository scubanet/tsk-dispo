import { BrowserRouter, Route, Routes, Navigate } from 'react-router-dom'
import { lazy, Suspense, useEffect, useState } from 'react'
import type { Session } from '@supabase/supabase-js'
import { supabase } from '@/lib/supabase'
import { ErrorBoundary } from '@/components/ErrorBoundary'
import { AppShell } from '@/layout/AppShell'
import { Loader } from '@/foundation/primitives/Loader'

// ─── Code-split screens ──────────────────────────────────────────────
// Each screen lives in its own Vite chunk and is fetched on first navigation
// to that route. Reduces the initial bundle by 40–60 % (Felix F1 from the
// 2026-05-20 review). Re-exports use `default: m.X` because the screens
// use named exports.
const LoginScreen           = lazy(() => import('@/screens/LoginScreen').then(m => ({ default: m.LoginScreen })))
const AuthCallback          = lazy(() => import('@/screens/AuthCallback').then(m => ({ default: m.AuthCallback })))
const ImportWizard          = lazy(() => import('@/screens/ImportWizard').then(m => ({ default: m.ImportWizard })))
const TodayScreen           = lazy(() => import('@/screens/TodayScreen').then(m => ({ default: m.TodayScreen })))
const CoursesScreen         = lazy(() => import('@/screens/CoursesScreen').then(m => ({ default: m.CoursesScreen })))
const InstructorsScreen     = lazy(() => import('@/screens/InstructorsScreen').then(m => ({ default: m.InstructorsScreen })))
const SkillMatrixScreen     = lazy(() => import('@/screens/SkillMatrixScreen').then(m => ({ default: m.SkillMatrixScreen })))
const PoolScreen            = lazy(() => import('@/screens/PoolScreen').then(m => ({ default: m.PoolScreen })))
const SaldiScreen           = lazy(() => import('@/screens/SaldiScreen').then(m => ({ default: m.SaldiScreen })))
const CalendarScreen        = lazy(() => import('@/screens/CalendarScreen').then(m => ({ default: m.CalendarScreen })))
const SettingsScreen        = lazy(() => import('@/screens/SettingsScreen').then(m => ({ default: m.SettingsScreen })))
const StudentsScreen        = lazy(() => import('@/screens/StudentsScreen').then(m => ({ default: m.StudentsScreen })))
const MyAssignmentsScreen   = lazy(() => import('@/screens/MyAssignmentsScreen').then(m => ({ default: m.MyAssignmentsScreen })))
const MySaldoScreen         = lazy(() => import('@/screens/MySaldoScreen').then(m => ({ default: m.MySaldoScreen })))
const MyProfileScreen       = lazy(() => import('@/screens/MyProfileScreen').then(m => ({ default: m.MyProfileScreen })))
const CockpitScreen         = lazy(() => import('@/screens/CockpitScreen').then(m => ({ default: m.CockpitScreen })))
const CDPipelineScreen      = lazy(() => import('@/screens/cd/CDPipelineScreen').then(m => ({ default: m.CDPipelineScreen })))
const CDOrganizationsScreen = lazy(() => import('@/screens/cd/CDOrganizationsScreen').then(m => ({ default: m.CDOrganizationsScreen })))
// CommunicationHubScreen-Import bewusst entfernt (Phase G P5 T5): /communication redirected jetzt auf /aktivitaet.
// Die Datei CommunicationHubScreen.tsx bleibt bis Phase 6, ist aber nicht mehr geroutet.
const AddressbookScreen     = lazy(() => import('@/screens/contacts/AddressbookScreen').then(m => ({ default: m.AddressbookScreen })))
const ActivityScreen        = lazy(() => import('@/screens/contacts/activity/ActivityScreen').then(m => ({ default: m.ActivityScreen })))
const CardInboxScreen       = lazy(() => import('@/screens/contacts/CardInboxScreen').then(m => ({ default: m.CardInboxScreen })))
const PublicCardScreen      = lazy(() => import('@/screens/PublicCardScreen').then(m => ({ default: m.PublicCardScreen })))

/**
 * Suspense fallback for code-split routes. Wraps the shared `<Loader>`
 * foundation component with a minimum height so the layout doesn't jump
 * while the next chunk is being fetched.
 */
function RouteLoader() {
  return (
    <div style={{ minHeight: '40vh', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
      <Loader />
    </div>
  )
}

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

  if (loading) return <Loader />

  return (
    <ErrorBoundary>
      <BrowserRouter>
        <Suspense fallback={<RouteLoader />}>
          <Routes>
            <Route
              path="/login"
              element={session ? <Navigate to="/heute" replace /> : <LoginScreen />}
            />
            <Route path="/auth/callback" element={<AuthCallback />} />

            {/* AtollCard public card page — the QR-target route. No auth gate. */}
            <Route path="/c/:slug" element={<PublicCardScreen />} />

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
              <Route path="/cd/pipeline"            element={<CDPipelineScreen />} />
              <Route path="/cd/organisationen"      element={<CDOrganizationsScreen />} />
              <Route path="/aktivitaet"             element={<ActivityScreen />} />
              {/* Phase G P5 T5: alte /communication-Route auf /aktivitaet redirecten (1 Release lang). */}
              <Route path="/communication"          element={<Navigate to="/aktivitaet" replace />} />
              <Route path="/contacts"               element={<AddressbookScreen />} />
              <Route path="/contacts/card-inbox"    element={<CardInboxScreen />} />
              <Route path="*"                       element={<Navigate to="/heute" replace />} />
            </Route>
          </Routes>
        </Suspense>
      </BrowserRouter>
    </ErrorBoundary>
  )
}

export default App
