/**
 * useLanguage — pick / read the user's UI language.
 *
 * Phase J — Etappe 2c.1:
 *   • Read   from `contact_instructor.preferred_language` (Login = Instructor)
 *   • Write  defensiv: Sidecar + Legacy `instructors`-Tabelle
 *            (Edge-Functions für E-Mail/Push lesen noch instructors.preferred_language —
 *             Single-Write auf den Sidecar kommt mit Etappe 3 wenn Sync-Triggers droppen).
 *
 * Cache: localStorage (instant boot, no flicker).
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

      const { data: auth } = await supabase.auth.getUser()
      const userId = auth?.user?.id
      if (!userId) return

      // 1) New source of truth: contact_instructor sidecar
      void supabase
        .from('contact_instructor')
        .update({ preferred_language: newLang })
        .eq('auth_user_id', userId)
        .then(({ error }) => {
          if (error) {
            // eslint-disable-next-line no-console
            console.warn('[i18n] could not persist to contact_instructor:', error.message)
          }
        })

      // 2) Legacy instructors-Tabelle — bis Edge-Functions migriert sind
      void supabase
        .from('instructors')
        .update({ preferred_language: newLang })
        .eq('auth_user_id', userId)
        .then(({ error }) => {
          if (error) {
            // eslint-disable-next-line no-console
            console.warn('[i18n] could not persist to instructors (legacy):', error.message)
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
      .from('contact_instructor')
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
