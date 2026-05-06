/**
 * Copyright-Footer für ATOLL / atoll.swiss
 *
 * Variante "compact" → einzeilig, sehr dezent (für Sidebar-Bottom)
 * Variante "full"    → mehrzeilig mit ATOLL-Wordmark (für Login/About)
 */
interface Props {
  variant?: 'compact' | 'full'
  align?: 'left' | 'center' | 'right'
}

const YEAR = new Date().getFullYear()

export function CopyrightFooter({ variant = 'compact', align = 'center' }: Props) {
  if (variant === 'full') {
    return (
      <div
        style={{
          textAlign: align,
          marginTop: 24,
          padding: '12px 0',
          fontSize: 11,
          opacity: 0.7,
          letterSpacing: '.02em',
          lineHeight: 1.5,
        }}
      >
        <div style={{ fontWeight: 600, letterSpacing: '.12em', fontSize: 10, opacity: 0.85 }}>
          ATOLL · The Scuba OS
        </div>
        <div style={{ marginTop: 4 }}>
          © {YEAR} <strong>Dominik Weckherlin</strong> · alle Rechte vorbehalten
        </div>
        <div style={{ opacity: 0.7, marginTop: 2 }}>
          ATOLL® und{' '}
          <a
            href="https://atoll.swiss"
            target="_blank"
            rel="noopener noreferrer"
            style={{ color: 'inherit', textDecoration: 'none', borderBottom: '0.5px solid currentColor' }}
          >
            atoll.swiss
          </a>{' '}
          sind Marken von Dominik Weckherlin
        </div>
      </div>
    )
  }

  // compact
  return (
    <div
      style={{
        textAlign: align,
        padding: '6px 8px',
        fontSize: 9.5,
        opacity: 0.55,
        letterSpacing: '.02em',
        lineHeight: 1.4,
      }}
      title={`ATOLL® / atoll.swiss — © ${YEAR} Dominik Weckherlin · alle Rechte vorbehalten`}
    >
      © {YEAR} <strong style={{ fontWeight: 600 }}>D. Weckherlin</strong> · ATOLL® · atoll.swiss
    </div>
  )
}
