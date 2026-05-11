/**
 * Icon registry — inline SVG components with semantic names.
 *
 * Foundation rules:
 *   - No external dependencies (consistent with legacy `components/Icon.tsx`).
 *   - 1.5px stroke, no fill, currentColor — picks up the surrounding text color.
 *   - 16px default size; override with `size` prop.
 *   - Use semantic names so the icon library can be swapped in one file.
 *
 * Implemented in plain TS (React.createElement, no JSX) so the file can keep
 * the .ts extension required by existing tooling.
 */

import { createElement, type SVGProps, type ReactNode } from 'react'

export interface IconProps extends Omit<SVGProps<SVGSVGElement>, 'size'> {
  size?: number
  strokeWidth?: number
}

function svg(children: ReactNode | ReactNode[]) {
  return function Icon({ size = 16, strokeWidth = 1.5, ...rest }: IconProps) {
    return createElement(
      'svg',
      {
        xmlns: 'http://www.w3.org/2000/svg',
        width: size,
        height: size,
        viewBox: '0 0 24 24',
        fill: 'none',
        stroke: 'currentColor',
        strokeWidth,
        strokeLinecap: 'round',
        strokeLinejoin: 'round',
        'aria-hidden': true,
        ...rest,
      },
      children
    )
  }
}

const path = (d: string) => createElement('path', { d, key: d })
const circle = (cx: number, cy: number, r: number, key: string) =>
  createElement('circle', { cx, cy, r, key })
const line = (x1: number, y1: number, x2: number, y2: number, key: string) =>
  createElement('line', { x1, y1, x2, y2, key })
const rect = (x: number, y: number, w: number, h: number, rx: number, key: string) =>
  createElement('rect', { x, y, width: w, height: h, rx, ry: rx, key })
const polyline = (points: string, key: string) =>
  createElement('polyline', { points, key })

// ─────────── Icons ───────────

const User = svg([
  circle(12, 8, 4, 'c'),
  path('M4 21v-2a4 4 0 0 1 4-4h8a4 4 0 0 1 4 4v2'),
])

const Users = svg([
  path('M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2'),
  circle(9, 7, 4, 'c'),
  path('M22 21v-2a4 4 0 0 0-3-3.87'),
  path('M16 3.13a4 4 0 0 1 0 7.75'),
])

const Calendar = svg([
  rect(3, 4, 18, 18, 2, 'r'),
  line(16, 2, 16, 6, 'l1'),
  line(8, 2, 8, 6, 'l2'),
  line(3, 10, 21, 10, 'l3'),
])

const ChevronRight = svg(polyline('9 18 15 12 9 6', 'p'))
const ChevronLeft = svg(polyline('15 18 9 12 15 6', 'p'))
const ChevronDown = svg(polyline('6 9 12 15 18 9', 'p'))
const ChevronUp = svg(polyline('18 15 12 9 6 15', 'p'))

const Search = svg([circle(11, 11, 7, 'c'), line(21, 21, 16.65, 16.65, 'l')])

const Close = svg([line(18, 6, 6, 18, 'a'), line(6, 6, 18, 18, 'b')])

const Check = svg(polyline('20 6 9 17 4 12', 'p'))

const Plus = svg([line(12, 5, 12, 19, 'v'), line(5, 12, 19, 12, 'h')])

const Mail = svg([
  rect(3, 5, 18, 14, 2, 'r'),
  polyline('3 7 12 13 21 7', 'p'),
])

const Phone = svg(
  path(
    'M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6 19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72c.13.96.37 1.9.72 2.81a2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6l1.27-1.27a2 2 0 0 1 2.11-.45c.91.35 1.85.59 2.81.72A2 2 0 0 1 22 16.92z'
  )
)

const Warning = svg([
  path('M10.29 3.86 1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z'),
  line(12, 9, 12, 13, 'l1'),
  line(12, 17, 12.01, 17, 'l2'),
])

const Info = svg([
  circle(12, 12, 10, 'c'),
  line(12, 16, 12, 12, 'l1'),
  line(12, 8, 12.01, 8, 'l2'),
])

const Success = svg([
  path('M22 11.08V12a10 10 0 1 1-5.93-9.14'),
  polyline('22 4 12 14.01 9 11.01', 'p'),
])

const Clock = svg([circle(12, 12, 10, 'c'), polyline('12 6 12 12 16 14', 'p')])

const Brevet = svg([
  circle(12, 8, 6, 'c'),
  polyline('9 14 6 22 12 19 18 22 15 14', 'p'),
])

const Settings = svg([
  circle(12, 12, 3, 'c'),
  path('M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-4 0v-.09a1.65 1.65 0 0 0-1-1.51 1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1 0-4h.09a1.65 1.65 0 0 0 1.51-1 1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 2.83-2.83l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9c.36.36 1.51 1 1.51 1H21a2 2 0 0 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z'),
])

const Logout = svg([
  path('M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4'),
  polyline('16 17 21 12 16 7', 'p'),
  line(21, 12, 9, 12, 'l'),
])

const Filter = svg(
  createElement('polygon', {
    points: '22 3 2 3 10 12.46 10 19 14 21 14 12.46 22 3',
  })
)

const Sort = svg(path('M3 6h18M6 12h12M9 18h6'))

const Home = svg(
  path('M3 9l9-7 9 7v11a2 2 0 0 1-2 2h-4v-7h-6v7H5a2 2 0 0 1-2-2z')
)

const Building = svg([
  rect(4, 2, 16, 20, 2, 'r'),
  line(9, 22, 9, 2, 'l1'),
  line(15, 22, 15, 2, 'l2'),
  line(4, 12, 20, 12, 'l3'),
])

const Document = svg([
  path('M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z'),
  polyline('14 2 14 8 20 8', 'p'),
  line(16, 13, 8, 13, 'l1'),
  line(16, 17, 8, 17, 'l2'),
  line(10, 9, 8, 9, 'l3'),
])

// ─────────── Registry ───────────

export const Icon = {
  User,
  Users,
  Calendar,
  ChevronRight,
  ChevronLeft,
  ChevronDown,
  ChevronUp,
  Search,
  Close,
  Check,
  Plus,
  Mail,
  Phone,
  Warning,
  Info,
  Success,
  Clock,
  Brevet,
  Settings,
  Logout,
  Filter,
  Sort,
  Home,
  Building,
  Document,
} as const

export type IconName = keyof typeof Icon
