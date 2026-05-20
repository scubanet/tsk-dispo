/**
 * AvatarStack — overlapping group of avatars with optional "+N" overflow.
 *
 * Foundation rules:
 *   - First N avatars rendered, rest collapsed into a neutral "+N" badge.
 *   - z-index reversed so the leftmost avatar sits on top (visual hierarchy).
 *   - Ring color comes from card background, not white — works on sand bg.
 */

import { Avatar, type AvatarSize } from './Avatar'
import './AvatarStack.css'

export interface AvatarStackPerson {
  id: string
  name: string
  photoUrl?: string | null
}

export interface AvatarStackProps {
  people: AvatarStackPerson[]
  /** How many avatars to render before collapsing to +N. Default: 3. */
  max?: number
  size?: AvatarSize
  /** Optional aria-label for the whole group. */
  ariaLabel?: string
}

export function AvatarStack({
  people,
  max = 3,
  size = 'sm',
  ariaLabel,
}: AvatarStackProps) {
  const visible = people.slice(0, max)
  const overflow = people.length - visible.length

  return (
    <div
      className={`atoll-avatar-stack atoll-avatar-stack--${size}`}
      role="group"
      aria-label={ariaLabel ?? `${people.length} Personen`}
    >
      {visible.map((p, i) => (
        <span
          key={p.id}
          className="atoll-avatar-stack__item"
          style={{ zIndex: visible.length - i }}
        >
          <Avatar id={p.id} name={p.name} photoUrl={p.photoUrl} size={size} />
        </span>
      ))}
      {overflow > 0 && (
        <span
          className="atoll-avatar-stack__item atoll-avatar-stack__overflow"
          aria-label={`und ${overflow} weitere`}
        >
          +{overflow}
        </span>
      )}
    </div>
  )
}
