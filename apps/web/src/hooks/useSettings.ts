import { useQuery } from '@tanstack/react-query'
import {
  fetchCompRates,
  fetchSettingsCourseTypes,
  fetchSettingsUsers,
  type CompRate,
  type SettingsCourseType,
  type SettingsUser,
} from '@/lib/queries'

/**
 * Hooks for the SettingsScreen — comp rates, course-type unit allocations,
 * and the user list. All three share the `'settings'` cache namespace so a
 * generic invalidate after recalculation refreshes everything in one shot.
 *
 * `staleTime: 5 min` — settings data is reference-style, changes rarely,
 * and the Recalc banner gives explicit feedback when something just moved.
 */

export function useCompRates() {
  return useQuery<CompRate[], Error>({
    queryKey: ['settings', 'compRates'],
    queryFn: () => fetchCompRates(),
    staleTime: 5 * 60_000,
  })
}

export function useSettingsCourseTypes() {
  return useQuery<SettingsCourseType[], Error>({
    queryKey: ['settings', 'courseTypes'],
    queryFn: () => fetchSettingsCourseTypes(),
    staleTime: 5 * 60_000,
  })
}

export function useSettingsUsers() {
  return useQuery<SettingsUser[], Error>({
    queryKey: ['settings', 'users'],
    queryFn: () => fetchSettingsUsers(),
    staleTime: 5 * 60_000,
  })
}
