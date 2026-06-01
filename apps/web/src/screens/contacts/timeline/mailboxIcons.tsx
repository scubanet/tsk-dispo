// mailboxIcons.tsx — Icon-Set für die Mailbox-Center-Spalte, portiert aus dem
// Design-Handoff (shared.jsx). Eigenständig, damit wir nicht von der kleinen
// Foundation-Icon-Registry abhängen. Stroke-Pfade aus Tabler-/Handoff-Quelle.
import type { CSSProperties } from 'react'

interface IconProps {
  size?: number
  stroke?: number
  style?: CSSProperties
}

function make(paths: string[]) {
  return function I({ size = 16, stroke = 2, style }: IconProps) {
    return (
      <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor"
        strokeWidth={stroke} strokeLinecap="round" strokeLinejoin="round" style={style} aria-hidden="true">
        {paths.map((d, i) => <path key={i} d={d} />)}
      </svg>
    )
  }
}

export const MIcon = {
  mail: make(['M3 6.5A2.5 2.5 0 0 1 5.5 4h13A2.5 2.5 0 0 1 21 6.5v11A2.5 2.5 0 0 1 18.5 20h-13A2.5 2.5 0 0 1 3 17.5z', 'm3.5 6.5 8.5 6 8.5-6']),
  whatsapp: make(['M12 3a9 9 0 0 0-7.7 13.6L3 21l4.5-1.2A9 9 0 1 0 12 3Z', 'M8.5 8.2c.2-.5.4-.5.7-.5h.5c.2 0 .4 0 .6.5l.6 1.4c.1.2 0 .4-.1.6l-.4.5c-.1.2-.2.3 0 .6.3.5.8 1.1 1.5 1.5.3.2.5.2.7 0l.5-.5c.2-.2.4-.2.6-.1l1.3.7c.3.1.4.3.4.5 0 .6-.4 1.3-1.2 1.4-.7.1-1.6 0-3.2-.9-1.9-1.1-3-2.9-3.1-3.4-.1-.5-.4-1.6 0-2.3Z']),
  reply: make(['M9 14 4 9l5-5', 'M4 9h9a7 7 0 0 1 7 7v3']),
  task: make(['m9 11 3 3 8-8', 'M21 12v6a3 3 0 0 1-3 3H6a3 3 0 0 1-3-3V6a3 3 0 0 1 3-3h9']),
  send: make(['M14.5 4.5 21 12l-6.5 7.5', 'M3 12h17']),
  paperclip: make(['M21 11.5 12.5 20a5 5 0 0 1-7-7l8-8a3.3 3.3 0 0 1 4.7 4.7l-8 8a1.6 1.6 0 0 1-2.3-2.3l7.3-7.3']),
  smile: make(['M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18Z', 'M9 10h.01', 'M15 10h.01', 'M8.5 14.5a4 4 0 0 0 7 0']),
  search: make(['M11 19a8 8 0 1 0 0-16 8 8 0 0 0 0 16Z', 'm21 21-4.3-4.3']),
  x: make(['M6 6l12 12', 'M18 6 6 18']),
  chevronDown: make(['M6 9.5 12 15.5 18 9.5']),
  phone: make(['M5 4h3l1.5 4-2 1.5a12 12 0 0 0 5 5l1.5-2 4 1.5v3a2 2 0 0 1-2 2A16 16 0 0 1 3 6a2 2 0 0 1 2-2Z']),
  calendar: make(['M4 7a2 2 0 0 1 2-2h12a2 2 0 0 1 2 2v12a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2z', 'M4 10h16', 'M8 3v4', 'M16 3v4']),
  note: make(['M5 4h9l5 5v11H5z', 'M14 4v5h5']),
  check: make(['M4 12.5 9 17.5 20 6.5']),
  doubleCheck: make(['M2 12.5 7 17.5 17 6.5', 'M11 16.5 12.5 18 22.5 7']),
  cash: make(['M4 7a2 2 0 0 1 2-2h12a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2z', 'M4 9h16', 'M9 14h2']),
  trash: make(['M4 7h16', 'M10 11v6', 'M14 11v6', 'M6 7l1 12a2 2 0 0 0 2 2h6a2 2 0 0 0 2-2l1-12', 'M9 7V4a1 1 0 0 1 1-1h4a1 1 0 0 1 1 1v3']),
  dot: make(['M12 12h.01']),
}

export type MIconName = keyof typeof MIcon
