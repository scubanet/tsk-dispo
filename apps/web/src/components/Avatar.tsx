type Size = 'sm' | 'md' | 'lg'

interface AvatarProps {
  initials: string
  color: string
  size?: Size
}

export function Avatar({ initials, color, size = 'md' }: AvatarProps) {
  const cls = size === 'md' ? 'avatar' : `avatar avatar-${size}`
  return (
    <div className={cls} style={{ background: `linear-gradient(135deg, ${color}, ${color}cc)` }}>
      {initials}
    </div>
  )
}
