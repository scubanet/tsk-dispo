// apps/web/src/screens/contacts/timeline/EventComposer.tsx
//
// Phase G Phase 2 — Segmented-Control-Orchestrator. Beim Klick auf einen
// Typ-Button expandiert die entsprechende Composer-Subkomponente. Re-Klick
// auf den aktiven Typ collapsed wieder.
import { useState } from 'react'
import type { UserEventType } from '@/types/contactEvents'
import { NoteComposer } from './composers/NoteComposer'
import { CallComposer } from './composers/CallComposer'
import { EmailLogComposer } from './composers/EmailLogComposer'
import { MeetingComposer } from './composers/MeetingComposer'
import { TaskComposer } from './composers/TaskComposer'
import { WhatsAppLogComposer } from './composers/WhatsAppLogComposer'

interface Props {
  contactId: string
}

const TYPES: { type: UserEventType; label: string }[] = [
  { type: 'note',            label: 'Notiz' },
  { type: 'call',            label: 'Anruf' },
  { type: 'email_external',  label: 'Mail' },
  { type: 'meeting_past',    label: 'Meeting' },
  { type: 'task',            label: 'Task' },
  { type: 'whatsapp_log',    label: 'WhatsApp' },
]

export function EventComposer({ contactId }: Props) {
  const [active, setActive] = useState<UserEventType | null>(null)

  return (
    <div style={{
      borderBottom: '1px solid var(--border-subtle, #eee)',
      padding: '12px 14px',
      background: 'var(--surface-primary, white)',
    }}>
      <div style={{ display: 'flex', gap: 4, marginBottom: active ? 12 : 0, flexWrap: 'wrap' }}>
        {TYPES.map(t => (
          <button
            key={t.type}
            type="button"
            onClick={() => setActive(active === t.type ? null : t.type)}
            aria-pressed={active === t.type}
            style={{
              padding: '6px 12px',
              borderRadius: 6,
              border: '1px solid var(--border-subtle, #ddd)',
              background: active === t.type ? 'var(--brand-blue-soft, #e8f0fb)' : 'transparent',
              color: active === t.type ? 'var(--brand-blue, #4a90e2)' : 'var(--text-secondary, #555)',
              fontWeight: active === t.type ? 500 : 400,
              cursor: 'pointer',
              fontSize: 13,
            }}
          >
            {t.label}
          </button>
        ))}
      </div>
      {active === 'note' && <NoteComposer contactId={contactId} onDone={() => setActive(null)} />}
      {active === 'call' && <CallComposer contactId={contactId} onDone={() => setActive(null)} />}
      {active === 'email_external' && <EmailLogComposer contactId={contactId} onDone={() => setActive(null)} />}
      {active === 'meeting_past' && <MeetingComposer contactId={contactId} onDone={() => setActive(null)} />}
      {active === 'task' && <TaskComposer contactId={contactId} onDone={() => setActive(null)} />}
      {active === 'whatsapp_log' && <WhatsAppLogComposer contactId={contactId} onDone={() => setActive(null)} />}
    </div>
  )
}
