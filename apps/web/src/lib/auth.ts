import { supabase } from './supabase'

export type Role = 'dispatcher' | 'instructor' | 'owner' | 'cd'

// CD ist Superset vom Dispatcher: alle Dispatcher-Funktionen + CD-Module.
// Owner ist read-only Beobachter.
export const isPrivileged = (r: Role) => r === 'dispatcher' || r === 'cd' || r === 'owner'
export const isCD = (r: Role) => r === 'cd'
export const canEditOps = (r: Role) => r === 'dispatcher' || r === 'cd'

export interface CurrentUser {
  authUserId: string
  instructorId: string | null
  name: string
  role: Role
  email: string
}

export async function fetchCurrentUser(): Promise<CurrentUser | null> {
  const { data: sess } = await supabase.auth.getUser()
  if (!sess.user) return null

  // Phase J — Etappe 2c.1: Login-Read kommt aus contact_instructor.
  // Sync-Triggers in 0083+0088 garantieren dass Legacy `instructors`-Schreiber
  // weiterhin app_role/name/email in den Sidecar spiegeln.
  const { data, error } = await supabase
    .from('contact_instructor')
    .select(
      'contact_id, app_role, ' +
        'contact:contacts!inner(display_name, primary_email)',
    )
    .eq('auth_user_id', sess.user.id)
    .maybeSingle()

  if (error) {
    console.error('[auth] fetchCurrentUser failed:', error)
    return {
      authUserId: sess.user.id,
      instructorId: null,
      name: sess.user.email ?? 'Unbekannt',
      role: 'instructor',
      email: sess.user.email ?? '',
    }
  }

  if (!data) {
    // Auth user exists but no contact_instructor row is linked.
    // Admin must map the auth user to a contact via Settings.
    console.warn(
      '[auth] No contact_instructor row linked to auth user',
      sess.user.id,
      'email:',
      sess.user.email,
      '— falling back to default instructor role.',
    )
    return {
      authUserId: sess.user.id,
      instructorId: null,
      name: sess.user.email ?? 'Neu',
      role: 'instructor',
      email: sess.user.email ?? '',
    }
  }

  // Supabase typings für Embed-Joins variieren — bewusst breit cast und
  // lokal mappen, weil die Shape generic ist.
  const row = data as unknown as {
    contact_id: string
    app_role: Role
    contact: { display_name: string | null; primary_email: string | null } | null
  }

  return {
    authUserId: sess.user.id,
    instructorId: row.contact_id,
    name: row.contact?.display_name ?? sess.user.email ?? 'Unbekannt',
    role: row.app_role,
    email: row.contact?.primary_email ?? sess.user.email ?? '',
  }
}
