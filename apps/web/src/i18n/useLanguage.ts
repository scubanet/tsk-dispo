/**
 * useLanguage — pick / read the user's UI language.
 *
 * Source of truth: `people.preferred_language` in Supabase.
 * Cache: localStorage (instant boot, no flicker).
 *
 * On change:
 *   1. localStorage write (instant)
 *   2. i18next changeLanguage  (re-renders everything)
 *   3. supabase update         (background, fire-and-forget; failure is logged but doesn't break UI)
 *
 * On boot (`useSyncRemoteLanguage`):
 *   After auth, read `people.preferred_language` and reconcile with localStorage.
 *   If they differ, the DB wins.
 */
import { useCallback, useEffect } from 'react'
import { useTranslation } from 'react-i18next'
import { supabase } from '@/lib/supabase'
import { STORAGE_KEY, type Lang, SUPPORTED_LANGS } from './index'

export function useLanguage() {
  const { i18n } = useTranslation()
  const lang = (i18n.resolvedLanguage ?? i18n.language ?? 'de').split('-')[0] as Lang

  const setLang = useCallback(
    async (newLang: Lang) => {
      if (!SUPPORTED_LANGS.includes(newLang)) return
      try {
        localStorage.setItem(STORAGE_KEY, newLang)
      } catch {
        /* storage might be blocked — UI still updates */
      }
      await i18n.changeLanguage(newLang)

      // Background-persist to DB (don't await — UI must not wait on the network).
      // Mirror the choice into BOTH tables that store preferred_language:
      //   - people.preferred_language       (used by app UI)
      //   - instructors.preferred_language  (used by edge functions for emails + APNs push)
      // The two tables are linked via auth_user_id.
      const { data: auth } = await supabase.auth.getUser()
      const userId = auth?.user?.id
      if (!userId) return
      void supabase
        .from('people')
        .update({ preferred_language: newLang })
        .eq('auth_user_id', userId)
        .then(({ error }) => {
          if (error) {
            // eslint-disable-next-line no-console
            console.warn('[i18n] could not persist language to people:', error.message)
          }
        })
      void supabase
        .from('instructors')
        .update({ preferred_language: newLang })
        .eq('auth_user_id', userId)
        .then(({ error }) => {
          if (error) {
            // eslint-disable-next-line no-console
            console.warn('[i18n] could not persist language to instructors:', error.message)
          }
        })
    },
    [i18n],
  )

  return { lang, setLang }
}

/**
 * Mount once near the auth boundary. After login it pulls the user's stored
 * `preferred_language` and applies it (if it differs from the local cache).
 */
export function useSyncRemoteLanguage(authUserId: string | null) {
  const { i18n } = useTranslation()

  useEffect(() => {
    if (!authUserId) return
    let cancelled = false
    void supabase
      .from('people')
      .select('preferred_language')
      .eq('auth_user_id', authUserId)
      .maybeSingle()
      .then(({ data, error }) => {
        if (cancelled || error || !data?.preferred_language) return
        const remote = data.preferred_language as Lang
        if (!SUPPORTED_LANGS.includes(remote)) return
        if (i18n.resolvedLanguage !== remote) {
          try { localStorage.setItem(STORAGE_KEY, remote) } catch { /* noop */ }
          void i18n.changeLanguage(remote)
        }
      })
    return () => {
      cancelled = true
    }
  }, [authUserId, i18n])
}
