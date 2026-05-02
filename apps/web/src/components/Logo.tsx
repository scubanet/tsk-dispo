/**
 * ATOLL Logo
 *
 * Top-down view of an atoll: outer reef ring (white) + inner lagoon (subtle fill)
 * + tiny islet at center. Sits on a blue→teal gradient square — die Farben des
 * tropischen Wassers vom flachen Riff bis in die tiefe Lagune.
 *
 * Skaliert von 24px (StatusBar) bis 512px (PWA-Icon).
 */
interface Props {
  size?: number
  /** Show only the symbol, no rounded square background. Useful on top of glass surfaces. */
  bare?: boolean
  /** Optional gradient override (default: blue → teal). */
  gradient?: [string, string]
}

export function Logo({ size = 32, bare = false, gradient = ['#0A84FF', '#30B0C7'] }: Props) {
  // Gradient ID muss eindeutig sein wenn mehrere Logos auf einer Seite sind
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
        <rect
          width="32"
          height="32"
          rx="8"
          fill={`url(#${gradId})`}
        />
      )}

      {/* Outer reef ring — slight asymmetry mit subtle gap unten-rechts (atoll passage) */}
      <path
        d="M 16 5 A 11 11 0 1 1 22 25"
        stroke="white"
        strokeWidth="1.6"
        strokeLinecap="round"
        fill="none"
        opacity="0.95"
      />

      {/* Inner lagoon — radial gradient für Tiefen-Eindruck */}
      <circle cx="16" cy="16" r="5" fill={`url(#${gradId}-lagoon)`} />

      {/* Center islet */}
      <circle cx="16" cy="16" r="1.4" fill="white" opacity="0.95" />
    </svg>
  )
}
