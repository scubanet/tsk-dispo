import { useQuery } from '@tanstack/react-query'
import {
  fetchMyProfile,
  fetchMySkills,
  fetchCertifications,
  type MyProfile,
  type MySkill,
} from '@/lib/queries'
import type { Certification } from '@/types/foundation'

/**
 * React-Query hook around `fetchMyProfile`. Loads the instructor profile
 * (name, padi level, padi number, email, primary phone) for the MyProfile
 * screen.
 *
 * Cache key: `['myProfile', instructorId]`. Mutations that touch the
 * underlying `contacts` row should invalidate this AND `['contact',
 * 'withSidecars', instructorId]` if the contact is also open in the
 * adressbook panel.
 */
export function useMyProfile(instructorId: string | null | undefined) {
  return useQuery<MyProfile | null, Error>({
    queryKey: ['myProfile', instructorId],
    queryFn: () => fetchMyProfile(instructorId as string),
    enabled: Boolean(instructorId),
  })
}

/**
 * React-Query hook around `fetchMySkills`. Used by MyProfile to render
 * the instructor's own skills as pill list.
 *
 * Cache key: `['mySkills', instructorId]`.
 */
export function useMySkills(instructorId: string | null | undefined) {
  return useQuery<MySkill[], Error>({
    queryKey: ['mySkills', instructorId],
    queryFn: () => fetchMySkills(instructorId as string),
    enabled: Boolean(instructorId),
  })
}

/**
 * React-Query hook around `fetchCertifications`. Loads BrevetsView data
 * for the instructor's own MyProfile screen.
 *
 * Cache key: `['certifications', personId]`. Reusable beyond MyProfile —
 * any contact's certification panel can use the same hook.
 */
export function useCertifications(personId: string | null | undefined) {
  return useQuery<Certification[], Error>({
    queryKey: ['certifications', personId],
    queryFn: () => fetchCertifications(personId as string),
    enabled: Boolean(personId),
  })
}
