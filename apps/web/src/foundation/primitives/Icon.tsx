// apps/web/src/foundation/primitives/Icon.tsx
//
// Foundation Icon — minimale Inline-SVG-Library für die paar Icons die
// wir aktuell brauchen (Phase G EventCard). Wenn die Anzahl >25 Icons
// braucht, lohnt sich @tabler/icons-react als dep.
// Stroke-paths sind direkt aus Tabler Icons v3 (MIT) übernommen oder
// — wo nicht sicher abrufbar — durch einen einfachen Punkt-Placeholder
// ersetzt mit TODO-Kommentar. Stroke linejoin=round, linecap=round.
import type { JSX } from 'react'

export type IconName =
  | 'note' | 'phone' | 'mail' | 'calendar-event' | 'checkbox'
  | 'brand-whatsapp' | 'school' | 'certificate' | 'cash' | 'arrow-right'
  | 'anchor' | 'id-badge' | 'user-cog' | 'edit' | 'point'

interface IconProps {
  name: IconName
  size?: number
  ariaLabel?: string
}

const PATHS: Record<IconName, JSX.Element> = {
  // note — Rechteck mit horizontalen Linien innen
  note: (
    <>
      <path d="M5 3h11l4 4v12a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2z" />
      <path d="M15 3v4a1 1 0 0 0 1 1h4" />
      <path d="M7 13h8" />
      <path d="M7 17h6" />
    </>
  ),
  // phone — klassischer Hörer
  phone: (
    <path d="M5 4h4l2 5l-2.5 1.5a11 11 0 0 0 5 5l1.5 -2.5l5 2v4a2 2 0 0 1 -2 2a16 16 0 0 1 -15 -15a2 2 0 0 1 2 -2" />
  ),
  // mail — Briefumschlag
  mail: (
    <>
      <rect x="3" y="5" width="18" height="14" rx="2" />
      <path d="M3 7l9 6l9 -6" />
    </>
  ),
  // calendar-event — Kalender mit Punkt
  'calendar-event': (
    <>
      <rect x="4" y="5" width="16" height="16" rx="2" />
      <path d="M16 3v4" />
      <path d="M8 3v4" />
      <path d="M4 11h16" />
      <circle cx="12" cy="16" r="1.5" fill="currentColor" />
    </>
  ),
  // checkbox — Quadrat mit Häkchen
  checkbox: (
    <>
      <rect x="4" y="4" width="16" height="16" rx="2" />
      <path d="M9 12l2 2l4 -4" />
    </>
  ),
  // brand-whatsapp — TODO: ersetzen mit tabler-path
  'brand-whatsapp': (
    <>
      {/* TODO: ersetzen mit tabler-path */}
      <circle cx="12" cy="12" r="9" />
      <path d="M9 10c0 4 3 7 7 7l1 -3l-3 -1l-1 1c-1 0 -2 -1 -2 -2l1 -1l-1 -3z" />
    </>
  ),
  // school — TODO: ersetzen mit tabler-path
  school: (
    <>
      {/* TODO: ersetzen mit tabler-path */}
      <path d="M22 9l-10 -4l-10 4l10 4l10 -4v6" />
      <path d="M6 10.6v5.4a6 3 0 0 0 12 0v-5.4" />
    </>
  ),
  // certificate — TODO: ersetzen mit tabler-path
  certificate: (
    <>
      {/* TODO: ersetzen mit tabler-path */}
      <circle cx="15" cy="15" r="3" />
      <path d="M13 17.5v4.5l2 -1.5l2 1.5v-4.5" />
      <path d="M10 19h-5a2 2 0 0 1 -2 -2v-10c0 -1.1 .9 -2 2 -2h14a2 2 0 0 1 2 2v6" />
      <path d="M6 9h12" />
      <path d="M6 12h3" />
      <path d="M6 15h2" />
    </>
  ),
  // cash — Banknote
  cash: (
    <>
      <rect x="3" y="6" width="18" height="12" rx="2" />
      <circle cx="12" cy="12" r="2.5" />
      <path d="M3 10h2" />
      <path d="M19 10h2" />
    </>
  ),
  // arrow-right — simple Pfeil
  'arrow-right': (
    <>
      <path d="M5 12h14" />
      <path d="M13 6l6 6l-6 6" />
    </>
  ),
  // anchor — TODO: ersetzen mit tabler-path (placeholder: simple anchor shape)
  anchor: (
    <>
      {/* TODO: ersetzen mit tabler-path */}
      <circle cx="12" cy="6" r="2" />
      <path d="M12 8v13" />
      <path d="M5 12h14" />
      <path d="M3 16a9 9 0 0 0 18 0" />
    </>
  ),
  // id-badge — TODO: ersetzen mit tabler-path
  'id-badge': (
    <>
      {/* TODO: ersetzen mit tabler-path */}
      <rect x="3" y="4" width="18" height="16" rx="2" />
      <path d="M10 8h4" />
      <circle cx="12" cy="13" r="2" />
      <path d="M8 18a4 4 0 0 1 8 0" />
    </>
  ),
  // user-cog — TODO: ersetzen mit tabler-path
  'user-cog': (
    <>
      {/* TODO: ersetzen mit tabler-path */}
      <circle cx="9" cy="7" r="3" />
      <path d="M3 21v-2a4 4 0 0 1 4 -4h4a4 4 0 0 1 4 4v2" />
      <circle cx="18" cy="17" r="2" />
    </>
  ),
  // edit — Bleistift
  edit: (
    <>
      <path d="M4 20h4l10.5 -10.5a1.5 1.5 0 0 0 -4 -4l-10.5 10.5v4" />
      <path d="M13.5 6.5l4 4" />
    </>
  ),
  // point — kleiner gefüllter Kreis
  point: (
    <circle cx="12" cy="12" r="2" fill="currentColor" />
  ),
}

export function Icon({ name, size = 16, ariaLabel }: IconProps) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth={2}
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-label={ariaLabel}
      aria-hidden={ariaLabel ? undefined : true}
      role={ariaLabel ? 'img' : undefined}
    >
      {PATHS[name]}
    </svg>
  )
}
