export type IconName =
  | 'house' | 'users' | 'book' | 'calendar' | 'anchor' | 'water'
  | 'wallet' | 'chart' | 'settings' | 'plus' | 'bell' | 'search'
  | 'filter' | 'check' | 'x' | 'chevron-right' | 'chevron-left'
  | 'chevron-down' | 'menu' | 'wrench' | 'logout' | 'tag'
  | 'thermometer' | 'eye' | 'location' | 'depth' | 'card'
  | 'tank' | 'boat' | 'grid' | 'whatsapp'

interface Props {
  name: IconName
  size?: number
  className?: string
  strokeWidth?: number
}

const PATHS: Record<IconName, string> = {
  house: 'M3 12L12 3l9 9v9a2 2 0 0 1-2 2h-3v-7H10v7H7a2 2 0 0 1-2-2v-9z',
  users: 'M16 11a3 3 0 1 0 0-6 3 3 0 0 0 0 6zM8 11a3 3 0 1 0 0-6 3 3 0 0 0 0 6zm0 2c-2.7 0-8 1.3-8 4v2h10v-2c0-1 .3-1.9.8-2.7-.9-.2-1.9-.3-2.8-.3zm8 0c-.3 0-.7 0-1 .1.6 1 1 2.1 1 3.2v1.7H22v-2c0-2.7-5.3-3-6-3z',
  book: 'M4 4h6c1.7 0 3 1.3 3 3v13c0-1.7-1.3-3-3-3H4V4zm16 0h-6c-1.7 0-3 1.3-3 3v13c0-1.7 1.3-3 3-3h6V4z',
  calendar: 'M7 2v3H5a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V7a2 2 0 0 0-2-2h-2V2h-2v3H9V2H7zm-2 6h14v11H5V8z',
  anchor: 'M12 2a3 3 0 0 0-1 5.8V10H8v2h3v6.9c-2.7-.4-5-2.4-5.7-5L8 13l-3-2-3 2 1.7 1c1 4.3 4.7 7.5 9.3 7.9V20h.5c4.6-.4 8.3-3.6 9.3-7.9l1.7-1-3-2-3 2 2.7.9c-.7 2.6-3 4.6-5.7 5V12h3v-2h-3V7.8c1.7-.4 3-2 3-3.8a3 3 0 0 0-3-3z',
  water: 'M12 2c-1 2-6 7-6 12a6 6 0 0 0 12 0c0-5-5-10-6-12z',
  wallet: 'M21 7H3a2 2 0 0 0-2 2v9a2 2 0 0 0 2 2h18a2 2 0 0 0 2-2V9a2 2 0 0 0-2-2zm-3 8a2 2 0 1 1 0-4 2 2 0 0 1 0 4zM5 5h14V3H5a2 2 0 0 0-2 2v.5c.6-.3 1.3-.5 2-.5z',
  chart: 'M3 13h2v8H3v-8zm4-5h2v13H7V8zm4-4h2v17h-2V4zm4 8h2v9h-2v-9zm4-3h2v12h-2V9z',
  settings: 'M19.4 13a7.5 7.5 0 0 0 0-2l2-1.6-2-3.4-2.4 1a7.5 7.5 0 0 0-1.7-1L15 3h-4l-.3 2.5a7.5 7.5 0 0 0-1.7 1l-2.4-1-2 3.4L6.6 11a7.5 7.5 0 0 0 0 2l-2 1.6 2 3.4 2.4-1c.5.4 1 .8 1.7 1L11 21h4l.3-2.5c.6-.2 1.2-.5 1.7-1l2.4 1 2-3.4-2-1.6zM12 15a3 3 0 1 1 0-6 3 3 0 0 1 0 6z',
  plus: 'M12 5v14M5 12h14',
  bell: 'M18 8a6 6 0 0 0-12 0c0 7-3 9-3 9h18s-3-2-3-9zM13.7 21a2 2 0 0 1-3.4 0',
  search: 'M11 4a7 7 0 1 0 4.3 12.5l4.6 4.6 1.4-1.4-4.6-4.6A7 7 0 0 0 11 4zm0 2a5 5 0 1 1 0 10 5 5 0 0 1 0-10z',
  filter: 'M3 4h18v2l-7 8v6l-4-2v-4L3 6V4z',
  check: 'M5 12l5 5L20 7',
  x: 'M18 6L6 18M6 6l12 12',
  'chevron-right': 'M9 6l6 6-6 6',
  'chevron-left': 'M15 6l-6 6 6 6',
  'chevron-down': 'M6 9l6 6 6-6',
  menu: 'M3 6h18M3 12h18M3 18h18',
  wrench: 'M14.7 6.3a3 3 0 1 1 4.2 4.2l-1.7 1.7-4.2-4.2zM3 17l8.5-8.5 4.2 4.2L7.2 21H3v-4z',
  logout: 'M16 17l5-5-5-5M21 12H9M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4',
  tag: 'M21 12l-9 9-9-9 9-9 9 9zM7 7h.01',
  thermometer: 'M14 14V5a2 2 0 0 0-4 0v9a4 4 0 1 0 4 0z',
  eye: 'M1 12s4-7 11-7 11 7 11 7-4 7-11 7-11-7-11-7zm11 3a3 3 0 1 0 0-6 3 3 0 0 0 0 6z',
  location: 'M12 2a7 7 0 0 0-7 7c0 5 7 13 7 13s7-8 7-13a7 7 0 0 0-7-7zm0 9a2 2 0 1 1 0-4 2 2 0 0 1 0 4z',
  depth: 'M2 12l5-3v2h10V9l5 3-5 3v-2H7v2l-5-3z',
  card: 'M3 5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5zm2 4v10h14V9H5zm0-2h14V5H5v2z',
  tank: 'M9 2v2H7v18h10V4h-2V2H9zm0 4h6v14H9V6z',
  boat: 'M2 18h20l-2 4H4l-2-4zm2-2l8-12 8 12H4z',
  grid: 'M4 4h7v7H4V4zm9 0h7v7h-7V4zM4 13h7v7H4v-7zm9 0h7v7h-7v-7z',
  whatsapp: 'M12 2a10 10 0 0 0-8.5 15.2L2 22l4.9-1.5A10 10 0 1 0 12 2zm0 18a8 8 0 0 1-4.1-1.1l-.3-.2-3 .9.9-2.9-.2-.3A8 8 0 1 1 12 20zm4.5-5.7c-.2-.1-1.4-.7-1.6-.8-.2-.1-.4-.1-.6.1-.2.2-.6.8-.8 1-.1.2-.3.2-.5.1-.7-.4-1.5-.8-2.2-1.7-.6-.7-1-1.5-1.1-1.8-.1-.2 0-.4.1-.5l.4-.5c.1-.2.2-.3.2-.4.1-.2 0-.3 0-.5l-.7-1.7c-.2-.4-.4-.4-.6-.4h-.5c-.2 0-.5.1-.7.3-.2.2-.9.9-.9 2.2 0 1.3.9 2.5 1.1 2.7.1.2 1.9 2.9 4.6 4 .6.3 1.1.5 1.5.6.6.2 1.2.2 1.6.1.5-.1 1.4-.6 1.6-1.1.2-.6.2-1 .1-1.1-.1-.1-.2-.1-.4-.2z',
}

export function Icon({ name, size = 16, className, strokeWidth = 1.6 }: Props) {
  const path = PATHS[name]
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth={strokeWidth}
      strokeLinecap="round"
      strokeLinejoin="round"
      className={className}
    >
      <path d={path} />
    </svg>
  )
}
