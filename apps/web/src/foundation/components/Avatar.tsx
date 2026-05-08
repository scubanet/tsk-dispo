/**
 * Avatar — circular initials badge with deterministic color.
 *
 * Foundation rules:
 *   - Color is derived from `id` via `avatarColor()` — never random.
 *   - Sizes follow the type-scale: sm=24, md=32, lg=40, xl=64.
 *   - Never use red (the palette excludes it).
 *   - Photo URL takes precedence; initials are the fallback.
 */

import { avatarColor } from '../lib/colors'
import { initialsFromName } from '../lib/numbers'
import './Avatar.css'

export type AvatarSize = 'sm' | 'md' | 'lg' | 'xl'

export interface AvatarProps {
  /** Stable id used to deterministically pick the color. */
  id: string
  /** Person's full name — initials are extracted from this. */
  name: string
  /** Optional photo URL — replaces initials when present. */
  photoUrl?: string | null
  size?: AvatarSize
  /** Optional explicit color override. */
  color?: string
  /** Decorative ring (e.g., for "active" state). */
  ringed?: boolean
  /** Accessible label — defaults to `name`. */
  ariaLabel?: string
}

export function Avatar({
  id,
  name,
  photoUrl,
  size = 'md',
  color,
  ringed = false,
  ariaLabel,
}: AvatarProps) {
  const bg = color ?? avatarColor(id)
  const initials = initialsFromName(name)
  const cls = ['atoll-avatar', `atoll-avatar--${size}`, ringed && 'atoll-avatar--ringed']
    .filter(Boolean)
    .join(' ')

  if (photoUrl) {
    return (
      <span
        className={cls}
        role="img"
        aria-label={ariaLabel ?? name}
        style={{
          backgroundImage: `url(${photoUrl})`,
          backgroundSize: 'cover',
          backgroundPosition: 'center',
        }}
      />
    )
  }

  return (
    <span
      className={cls}
      role="img"
      aria-label={ariaLabel ?? name}
      style={{ background: bg }}
    >
      {initials}
    </span>
  )
}
