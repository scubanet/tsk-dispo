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

  const { data, error } = await supabase
    .from('instructors')
    .select('id, name, role, email')
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
    // Auth user exists but no instructor row is linked.
    // This means an admin needs to map the email to an instructor record
    // (Einstellungen → User). Log loudly so dispatcher mis-config is debuggable.
    console.warn(
      '[auth] No instructor row linked to auth user',
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

  return {
    authUserId: sess.user.id,
    instructorId: data.id,
    name: data.name,
    role: data.role as Role,
    email: data.email ?? sess.user.email ?? '',
  }
}
