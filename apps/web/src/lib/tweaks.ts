import { useEffect, useState } from 'react'

export type AccentHex = '#0A84FF' | '#30B0C7' | '#34C759' | '#AF52DE' | '#FF9500'
export type Layout = 'sidebar' | 'tabbar'
/** 'auto' folgt der OS-Einstellung (prefers-color-scheme). */
export type ThemeMode = 'auto' | 'light' | 'dark'

export interface Tweaks {
  theme: ThemeMode
  accent: AccentHex
  layout: Layout
}

const STORAGE_KEY = 'tsk.tweaks.v1'

const DEFAULTS: Tweaks = {
  theme: 'auto',
  accent: '#0A84FF',
  layout: 'sidebar',
}

function loadTweaks(): Tweaks {
  try {
    const raw = localStorage.getItem(STORAGE_KEY)
    if (!raw) return DEFAULTS
    const parsed = JSON.parse(raw) as Partial<Tweaks> & { dark?: boolean }
    // Migration v1: altes `dark: boolean` → `theme` (Premium-Sweep Phase 2)
    if (parsed.theme === undefined && parsed.dark !== undefined) {
      parsed.theme = parsed.dark ? 'dark' : 'light'
    }
    return { ...DEFAULTS, ...parsed }
  } catch {
    return DEFAULTS
  }
}

/** Resolved Dark-Zustand für einen ThemeMode (auto → System). */
export function resolveDark(theme: ThemeMode): boolean {
  if (theme === 'dark') return true
  if (theme === 'light') return false
  return window.matchMedia('(prefers-color-scheme: dark)').matches
}

export function useTweaks(): [Tweaks, <K extends keyof Tweaks>(k: K, v: Tweaks[K]) => void] {
  const [tweaks, setTweaks] = useState<Tweaks>(loadTweaks)

  useEffect(() => {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(tweaks))

    const root = document.documentElement
    const apply = () => root.classList.toggle('dark', resolveDark(tweaks.theme))
    apply()

    root.style.setProperty('--accent', tweaks.accent)
    const hex = tweaks.accent.replace('#', '')
    const r = parseInt(hex.slice(0, 2), 16)
    const g = parseInt(hex.slice(2, 4), 16)
    const b = parseInt(hex.slice(4, 6), 16)
    root.style.setProperty('--accent-soft', `rgba(${r}, ${g}, ${b}, 0.12)`)

    // Bei 'auto' auf System-Wechsel reagieren (z. B. macOS-Auto-Dark am Abend).
    const mq = window.matchMedia('(prefers-color-scheme: dark)')
    const onChange = () => {
      if (tweaks.theme === 'auto') apply()
    }
    mq.addEventListener('change', onChange)
    return () => mq.removeEventListener('change', onChange)
  }, [tweaks])

  function set<K extends keyof Tweaks>(k: K, v: Tweaks[K]) {
    setTweaks((prev) => ({ ...prev, [k]: v }))
  }

  return [tweaks, set]
}
