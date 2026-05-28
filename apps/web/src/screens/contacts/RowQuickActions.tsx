/**
 * RowQuickActions — Quick-Action-Buttons in der Adressbuch-Row (Phase G Phase 4 Task 9).
 *
 * Rendert zwei Icon-Buttons (Mail + Notiz), die VOR dem ⋯-More-Menü in der
 * Actions-Cell der `AddressbookTable` sitzen. Sichtbarkeit ist über CSS
 * (`RowQuickActions.css`) an `[role="row"]:hover` gekoppelt — also keine
 * per-Row useState-Logik.
 *
 * Click-Handler sind aktuell Stubs (console.log + window.alert). Echtes
 * Wire-up zu EventComposer/Mail-Composer kommt in Phase 5.
 *
 * Layout/Size:
 *   - comfortable → 22×22px Buttons.
 *   - compact     → 18×18px Buttons.
 *   - e.stopPropagation() auf beiden Buttons, damit der Row-Click NICHT feuert
 *     und stattdessen die Quick-Aktion ausgelöst wird.
 */

import type { CSSProperties, MouseEvent } from 'react'
import { Icon } from '@/foundation'
import type { Contact } from '@/types/contacts'
import './RowQuickActions.css'

export interface RowQuickActionsProps {
  contact: Contact
  density: 'compact' | 'comfortable'
}

export function RowQuickActions({ contact, density }: RowQuickActionsProps) {
  const compact = density === 'compact'
  const buttonSize = compact ? 18 : 22
  const iconSize = compact ? 12 : 14

  const buttonStyle: CSSProperties = {
    width: buttonSize,
    height: buttonSize,
    display: 'inline-flex',
    alignItems: 'center',
    justifyContent: 'center',
    background: 'transparent',
    border: 'none',
    borderRadius: 'var(--radius-sm, 4px)',
    cursor: 'pointer',
    color: 'var(--text-tertiary)',
    padding: 0,
    lineHeight: 1,
  }

  const handleMail = (e: MouseEvent<HTMLButtonElement>) => {
    e.stopPropagation()
    // Phase 5: wire to EventComposer / Mail-Send.
    // eslint-disable-next-line no-console
    console.log('quick-mail', contact.id)
    window.alert('Quick-Mail kommt in Phase 5')
  }

  const handleNote = (e: MouseEvent<HTMLButtonElement>) => {
    e.stopPropagation()
    // Phase 5: wire to inline Notiz-Form / NoteComposer.
    // eslint-disable-next-line no-console
    console.log('quick-note', contact.id)
    window.alert('Quick-Note kommt in Phase 5')
  }

  return (
    <div
      data-row-quick-actions=""
      style={{
        display: 'inline-flex',
        alignItems: 'center',
        gap: compact ? 2 : 4,
      }}
    >
      <button
        type="button"
        aria-label={`Quick-Mail an ${contact.display_name}`}
        title="Mail"
        onClick={handleMail}
        style={buttonStyle}
      >
        <Icon.Mail size={iconSize} />
      </button>
      <button
        type="button"
        aria-label={`Quick-Notiz für ${contact.display_name}`}
        title="Notiz"
        onClick={handleNote}
        style={buttonStyle}
      >
        <Icon.Document size={iconSize} />
      </button>
    </div>
  )
}
