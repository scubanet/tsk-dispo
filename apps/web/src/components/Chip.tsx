import clsx from 'clsx'
import type { ReactNode } from 'react'

type Tone = 'neutral' | 'accent' | 'green' | 'orange' | 'red' | 'purple'

const TONE_CLASS: Record<Tone, string> = {
  neutral: '',
  accent: 'chip-accent',
  green: 'chip-green',
  orange: 'chip-orange',
  red: 'chip-red',
  purple: 'chip-purple',
}

export function Chip({ tone = 'neutral', children }: { tone?: Tone; children: ReactNode }) {
  return <span className={clsx('chip', TONE_CLASS[tone])}>{children}</span>
}
