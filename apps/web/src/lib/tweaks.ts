import { useEffect, useState } from 'react'

export type AccentHex = '#0A84FF' | '#30B0C7' | '#34C759' | '#AF52DE' | '#FF9500'
export type Layout = 'sidebar' | 'tabbar'

export interface Tweaks {
  dark: boolean
  accent: AccentHex
  layout: Layout
}

const STORAGE_KEY = 'tsk.tweaks.v1'

const DEFAULTS: Tweaks = {
  dark: false,
  accent: '#0A84FF',
  layout: 'sidebar',
}

export function useTweaks(): [Tweaks, <K extends keyof Tweaks>(k: K, v: Tweaks[K]) => void] {
  const [tweaks, setTweaks] = useState<Tweaks>(() => {
    try {
      const raw = localStorage.getItem(STORAGE_KEY)
      return raw ? { ...DEFAULTS, ...JSON.parse(raw) } : DEFAULTS
    } catch {
      return DEFAULTS
    }
  })

  useEffect(() => {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(tweaks))
    const root = document.documentElement
    root.classList.toggle('dark', tweaks.dark)
    root.style.setProperty('--accent', tweaks.accent)
    const hex = tweaks.accent.replace('#', '')
    const r = parseInt(hex.slice(0, 2), 16)
    const g = parseInt(hex.slice(2, 4), 16)
    const b = parseInt(hex.slice(4, 6), 16)
    root.style.setProperty('--accent-soft', `rgba(${r}, ${g}, ${b}, 0.12)`)
  }, [tweaks])

  function set<K extends keyof Tweaks>(k: K, v: Tweaks[K]) {
    setTweaks((prev) => ({ ...prev, [k]: v }))
  }

  return [tweaks, set]
}
