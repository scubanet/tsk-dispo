// apps/web/src/screens/contacts/DensityToggle.tsx
//
// Phase G Phase 4 Task 2 — kleiner Icon-Button, der zwischen Compact (32px Row)
// und Comfortable (44px Row) wechselt. Persistenz übernimmt useAddressbookDensity.
//
// Icon-Entscheidung: Foundation-Icon-Lib hat (noch) kein passendes Density-Glyph.
// Wir nutzen ein leichtgewichtiges Inline-SVG mit zwei vs. drei horizontalen
// Linien — visuell intuitiv (mehr Linien = kompakter) und ohne neue Asset-Files.
//   comfortable → 2 Linien (mehr Luft zwischen den Zeilen)
//   compact     → 3 Linien (Zeilen rücken näher zusammen)
import type { AddressbookDensity } from '@/hooks/useAddressbookDensity'

export interface DensityToggleProps {
  density: AddressbookDensity
  onToggle: () => void
}

export function DensityToggle({ density, onToggle }: DensityToggleProps) {
  const isCompact = density === 'compact'
  const label = isCompact ? 'Dichte: Kompakt' : 'Dichte: Komfortabel'

  return (
    <button
      type="button"
      aria-label={label}
      title={label}
      onClick={onToggle}
      style={{
        width: 22,
        height: 22,
        display: 'inline-flex',
        alignItems: 'center',
        justifyContent: 'center',
        background: 'transparent',
        border: '1px solid var(--border-primary)',
        borderRadius: 'var(--radius-sm, 4px)',
        cursor: 'pointer',
        color: 'var(--text-secondary)',
        padding: 0,
        flexShrink: 0,
      }}
    >
      <svg
        width={14}
        height={14}
        viewBox="0 0 14 14"
        aria-hidden="true"
        focusable="false"
      >
        {isCompact ? (
          // 3 close lines = compact rows
          <g stroke="currentColor" strokeWidth={1.4} strokeLinecap="round">
            <line x1="2" y1="4" x2="12" y2="4" />
            <line x1="2" y1="7" x2="12" y2="7" />
            <line x1="2" y1="10" x2="12" y2="10" />
          </g>
        ) : (
          // 2 spaced lines = comfortable rows
          <g stroke="currentColor" strokeWidth={1.4} strokeLinecap="round">
            <line x1="2" y1="4.5" x2="12" y2="4.5" />
            <line x1="2" y1="9.5" x2="12" y2="9.5" />
          </g>
        )}
      </svg>
    </button>
  )
}
