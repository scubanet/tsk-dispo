import { Icon } from './Icon'

interface Props {
  url: string
  label?: string
  variant?: 'btn' | 'btn-secondary' | 'btn-icon'
  fullWidth?: boolean
}

export function WhatsAppButton({ url, label = 'In WhatsApp posten', variant = 'btn-secondary', fullWidth }: Props) {
  return (
    <a
      href={url}
      target="_blank"
      rel="noopener noreferrer"
      className={`btn ${variant !== 'btn' ? variant : ''}`}
      style={{
        textDecoration: 'none',
        background: variant === 'btn-secondary'
          ? 'var(--brand-whatsapp-50)'
          : 'var(--brand-whatsapp)',
        color: variant === 'btn-secondary' ? 'var(--brand-whatsapp-800)' : 'white',
        border: variant === 'btn-secondary' ? '0.5px solid var(--brand-whatsapp)' : '0',
        width: fullWidth ? '100%' : undefined,
        justifyContent: 'center',
      }}
    >
      <Icon name="whatsapp" size={14} />
      {label}
    </a>
  )
}
