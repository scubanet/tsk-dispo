/**
 * Color helpers for pass.json: theme-preset → CSS rgb(...) string,
 * plus a robust hex parser that handles 3- and 6-digit hex with/without #.
 */
import type { CardData } from './pass-types.ts'

const PRESET_RGB = {
  courseDirector: 'rgb(34, 103, 16)',   // PADI-green-ish
  seaExplorers:   'rgb(0, 95, 138)',    // ocean blue
  privat:         'rgb(80, 80, 80)',    // neutral grey
} as const

export interface Rgb { r: number; g: number; b: number }

export function hexToRgb(hex: string): Rgb | null {
  let h = hex.trim().replace(/^#/, '')
  if (h.length === 3) {
    h = h.split('').map((c) => c + c).join('')
  }
  if (!/^[0-9a-fA-F]{6}$/.test(h)) return null
  return {
    r: parseInt(h.slice(0, 2), 16),
    g: parseInt(h.slice(2, 4), 16),
    b: parseInt(h.slice(4, 6), 16),
  }
}

export function colorForTheme(theme: CardData['theme']): string {
  if (theme.preset !== 'custom') {
    return PRESET_RGB[theme.preset]
  }

  const rgb = theme.gradient_start_hex ? hexToRgb(theme.gradient_start_hex) : null
  if (!rgb) return PRESET_RGB.privat
  return `rgb(${rgb.r}, ${rgb.g}, ${rgb.b})`
}
