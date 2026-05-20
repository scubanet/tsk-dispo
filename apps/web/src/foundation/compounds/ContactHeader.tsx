/**
 * ContactHeader — sticky header for a contact detail panel.
 *
 * Shows: Avatar (xl=64), display_name, RolesBadgeList, owner badge,
 * quick-action buttons (email, WhatsApp, call, optional primary action, more menu).
 *
 * Requires at least primary_email or a phones entry for link buttons to render.
 */

import { useTranslation } from 'react-i18next'
import type { ContactWithSidecars, ContactRole } from '@/types/contacts'
import { Avatar } from '../components/Avatar'
import { RolesBadgeList } from './RolesBadgeList'

export interface PrimaryAction {
  label: string
  onClick: () => void
}

export interface ContactHeaderProps {
  contact: ContactWithSidecars
  ownerName?: string
  onRoleClick?: (role: ContactRole) => void
  onMoreClick?: () => void
  onPrimaryAction?: PrimaryAction
}

export function ContactHeader({
  contact,
  ownerName,
  onRoleClick,
  onMoreClick,
  onPrimaryAction,
}: ContactHeaderProps) {
  const { t } = useTranslation()
  // Derive primary email and phone for quick-action links
  const primaryEmail =
    contact.primary_email ??
    contact.emails.find((e) => e.primary)?.email ??
    contact.emails[0]?.email ??
    null

  const primaryPhone =
    contact.phones.find((p) => p.primary)?.e164 ??
    contact.phones[0]?.e164 ??
    null

  // WhatsApp: e164 minus the leading '+'
  const whatsappNumber = primaryPhone ? primaryPhone.replace(/^\+/, '') : null

  return (
    <header className="contact-header">
      <div className="contact-header__top">
        <Avatar
          id={contact.id}
          name={contact.display_name}
          size="xl"
        />
        <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--space-1)', flex: 1, minWidth: 0 }}>
          <h1 className="contact-header__name">{contact.display_name}</h1>
          <div className="contact-header__meta">
            <RolesBadgeList roles={contact.roles} onClick={onRoleClick} />
            {ownerName && (
              <span className="contact-header__owner">
                {t('contacts.supervised_by', { name: ownerName })}
              </span>
            )}
          </div>
        </div>
        {/* GL-004 L2: More-menu trigger now lives top-right of the header,
            so the secondary actions (archive, merge, role manager) are
            discoverable instead of buried below the avatar. */}
        {onMoreClick && (
          <button
            type="button"
            className="contact-header__action-btn contact-header__more-trigger"
            onClick={onMoreClick}
            aria-label={t('contacts.action_more')}
            title={t('contacts.action_more')}
          >
            ⋯
          </button>
        )}
      </div>

      <div className="contact-header__actions">
        {primaryEmail && (
          <a
            href={`mailto:${primaryEmail}`}
            className="contact-header__action-btn"
            title={`${t('contacts.action_email')}: ${primaryEmail}`}
          >
            ✉️ {t('contacts.action_email')}
          </a>
        )}
        {whatsappNumber && (
          <a
            href={`https://wa.me/${whatsappNumber}`}
            target="_blank"
            rel="noreferrer"
            className="contact-header__action-btn"
            title={t('contacts.action_whatsapp')}
          >
            💬 {t('contacts.action_whatsapp')}
          </a>
        )}
        {primaryPhone && (
          <a
            href={`tel:${primaryPhone}`}
            className="contact-header__action-btn"
            title={`${t('contacts.action_call')}: ${primaryPhone}`}
          >
            📞 {t('contacts.action_call')}
          </a>
        )}

        {onPrimaryAction && (
          <button
            type="button"
            className="contact-header__action-btn contact-header__action-btn--primary"
            onClick={onPrimaryAction.onClick}
          >
            {onPrimaryAction.label}
          </button>
        )}
      </div>
    </header>
  )
}
