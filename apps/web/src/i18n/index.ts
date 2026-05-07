/**
 * i18n bootstrap
 *
 * - Resources for `de` and `en`
 * - Detection priority: localStorage('atoll.lang') → navigator.language → 'de'
 * - Side effect: keeps `<html lang>` in sync (a11y)
 *
 * To switch language at runtime, use the `useLanguage` hook (see ./useLanguage.ts).
 */
import i18n from 'i18next'
import { initReactI18next } from 'react-i18next'
import LanguageDetector from 'i18next-browser-languagedetector'

import de from './locales/de.json'
import en from './locales/en.json'

export const SUPPORTED_LANGS = ['de', 'en'] as const
export type Lang = (typeof SUPPORTED_LANGS)[number]

export const STORAGE_KEY = 'atoll.lang'

i18n
  .use(LanguageDetector)
  .use(initReactI18next)
  .init({
    resources: {
      de: { translation: de },
      en: { translation: en },
    },
    fallbackLng: 'de',
    supportedLngs: SUPPORTED_LANGS as unknown as string[],
    interpolation: { escapeValue: false }, // React already escapes
    detection: {
      order: ['localStorage', 'navigator'],
      lookupLocalStorage: STORAGE_KEY,
      caches: ['localStorage'],
    },
    returnNull: false,
  })

// Keep <html lang> in sync — boot + on every change
function syncHtmlLang(lng: string) {
  if (typeof document !== 'undefined') {
    document.documentElement.lang = lng.split('-')[0]
  }
}
syncHtmlLang(i18n.language)
i18n.on('languageChanged', syncHtmlLang)

export default i18n
