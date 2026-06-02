import { useEffect, useState } from 'react'
import { useInsertContactEvent } from '@/hooks/useEventComposer'

interface Props {
  contactId: string
  onDone: () => void
  /** Vorbefüllter Titel (z.B. „Task aus Nachricht"). */
  initialTitle?: string
}

export function TaskComposer({ contactId, onDone, initialTitle }: Props) {
  const [summary, setSummary] = useState(initialTitle ?? '')
  const [body, setBody] = useState('')
  const [dueDate, setDueDate] = useState('')
  const [reminder, setReminder] = useState('')
  const insert = useInsertContactEvent(contactId)

  useEffect(() => { if (initialTitle) setSummary(initialTitle) }, [initialTitle])

  function submit() {
    if (!summary.trim() || !dueDate) return
    insert.mutate(
      {
        event_type: 'task',
        summary: summary.trim(),
        body: body.trim() || undefined,
        payload: {
          due_date: dueDate,
          ...(reminder ? { reminder_at: reminder } : {}),
        },
      },
      {
        onSuccess: () => {
          setSummary('')
          setBody('')
          setDueDate('')
          setReminder('')
          onDone()
        },
      },
    )
  }

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
      <input
        type="text"
        placeholder="Was ist zu tun?"
        value={summary}
        onChange={e => setSummary(e.target.value)}
        autoComplete="off"
        style={{ padding: 8 }}
      />
      <textarea
        placeholder="Details (optional)"
        value={body}
        onChange={e => setBody(e.target.value)}
        autoComplete="off"
        rows={2}
        style={{ padding: 8 }}
      />
      <div style={{ display: 'flex', gap: 12, alignItems: 'center' }}>
        <label style={{ fontSize: 13 }}>
          Fällig am
          <input
            type="date"
            value={dueDate}
            onChange={e => setDueDate(e.target.value)}
            style={{ marginLeft: 6, padding: 4 }}
          />
        </label>
        <label style={{ fontSize: 13 }}>
          Erinnerung (optional)
          <input
            type="datetime-local"
            value={reminder}
            onChange={e => setReminder(e.target.value)}
            style={{ marginLeft: 6, padding: 4 }}
          />
        </label>
      </div>
      {insert.error && (
        <div style={{ color: 'var(--color-text-danger, #c0392b)', fontSize: 12 }}>
          {insert.error.message}
        </div>
      )}
      <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 6 }}>
        <button type="button" onClick={onDone} style={{ padding: '6px 12px' }}>
          Abbrechen
        </button>
        <button
          type="button"
          onClick={submit}
          disabled={!summary.trim() || !dueDate || insert.isPending}
          style={{ padding: '6px 14px' }}
        >
          {insert.isPending ? 'Speichere…' : 'Speichern'}
        </button>
      </div>
    </div>
  )
}
