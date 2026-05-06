import { useState } from 'react'

/**
 * ATOLL Logo
 *
 * Lädt primär ein PNG/SVG aus `/public/atoll-logo.png` (oder atoll-logo.svg).
 * Falls die Datei fehlt, fällt es zurück auf die SVG-Atoll-Symbol-Variante
 * (Ring + Lagune + Inselchen) — damit es immer rendert.
 *
 * Skaliert von 24px (StatusBar) bis 512px (PWA-Icon).
 */
interface Props {
  size?: number
  /** Show only the symbol, no rounded square background. Useful on top of glass surfaces. */
  bare?: boolean
  /** Optional gradient override (default: blue → teal) — nur für SVG-Fallback. */
  gradient?: [string, string]
}

export function Logo({ size = 32, bare = false, gradient = ['#0A84FF', '#30B0C7'] }: Props) {
  const [imgFailed, setImgFailed] = useState(false)

  // Primär: das gelieferte File aus /public/. Falls 404 → onError → Fallback auf SVG.
  if (!imgFailed) {
    return (
      <img
        src="/atoll-logo.png"
        alt="ATOLL"
        width={size}
        height={size}
        onError={() => setImgFailed(true)}
        style={{
          display: 'block',
          flexShrink: 0,
          objectFit: 'contain',
          width: size,
          height: size,
        }}
      />
    )
  }

  // Fallback: bisheriges SVG-Atoll-Symbol
  const gradId = `atoll-grad-${gradient[0].slice(1)}-${gradient[1].slice(1)}`
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 32 32"
      xmlns="http://www.w3.org/2000/svg"
      style={{ display: 'block', flexShrink: 0 }}
    >
      <defs>
        <linearGradient id={gradId} x1="0" y1="0" x2="1" y2="1">
          <stop offset="0%" stopColor={gradient[0]} />
          <stop offset="100%" stopColor={gradient[1]} />
        </linearGradient>
        <radialGradient id={`${gradId}-lagoon`} cx="0.5" cy="0.5" r="0.5">
          <stop offset="0%" stopColor="white" stopOpacity="0.55" />
          <stop offset="100%" stopColor="white" stopOpacity="0.15" />
        </radialGradient>
      </defs>
      {!bare && (
        <rect width="32" height="32" rx="8" fill={`url(#${gradId})`} />
      )}
      <path
        d="M 16 5 A 11 11 0 1 1 22 25"
        stroke="white"
        strokeWidth="1.6"
        strokeLinecap="round"
        fill="none"
        opacity="0.95"
      />
      <circle cx="16" cy="16" r="5" fill={`url(#${gradId}-lagoon)`} />
      <circle cx="16" cy="16" r="1.4" fill="white" opacity="0.95" />
    </svg>
  )
}
