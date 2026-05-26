import { useSearchParams } from 'react-router-dom'
import type { Lang } from '@/screens/PublicCardScreen.i18n'

interface Props {
  current: Lang
}

const LABELS: Record<Lang, string> = {
  de: 'Deutsch',
  en: 'English',
  fr: 'Français',
}

/**
 * Tiny dropdown to switch the page language via ?lang= query param.
 * Used on PublicCardScreen — the only multilingual screen in the web app.
 */
export function LanguageSwitcher({ current }: Props) {
  const [, setSearchParams] = useSearchParams()

  function pick(lang: Lang) {
    setSearchParams((prev) => {
      const next = new URLSearchParams(prev)
      next.set('lang', lang)
      return next
    }, { replace: true })
  }

  return (
    <details
      style={{
        position: 'absolute',
        top: 16,
        right: 16,
        zIndex: 10,
      }}
    >
      <summary
        style={{
          listStyle: 'none',
          cursor: 'pointer',
          padding: '6px 10px',
          background: 'rgba(0,0,0,0.04)',
          border: '1px solid rgba(0,0,0,0.08)',
          borderRadius: 8,
          fontSize: 13,
          userSelect: 'none',
        }}
      >
        🌐 {LABELS[current]}
      </summary>
      <div
        style={{
          marginTop: 4,
          background: 'white',
          border: '1px solid rgba(0,0,0,0.1)',
          borderRadius: 8,
          boxShadow: '0 4px 12px rgba(0,0,0,0.1)',
          minWidth: 140,
        }}
      >
        {(['de', 'en', 'fr'] as const).map((lang) => (
          <button
            key={lang}
            type="button"
            onClick={() => pick(lang)}
            style={{
              display: 'block',
              width: '100%',
              padding: '8px 12px',
              background: lang === current ? 'rgba(0,0,0,0.04)' : 'transparent',
              border: 'none',
              cursor: 'pointer',
              textAlign: 'left',
              fontSize: 13,
              fontWeight: lang === current ? 600 : 400,
            }}
          >
            {LABELS[lang]}
          </button>
        ))}
      </div>
    </details>
  )
}
