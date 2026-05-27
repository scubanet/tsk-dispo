import { useState } from 'react'
import { useInsertContactEvent } from '@/hooks/useEventComposer'
import type { Direction } from '@/types/contactEvents'

interface Props {
  contactId: string
  onDone: () => void
}

export function EmailLogComposer({ contactId, onDone }: Props) {
  const [subject, setSubject] = useState('')
  const [summary, setSummary] = useState('')
  const [direction, setDirection] = useState<Direction>('outbound')
  const insert = useInsertContactEvent(contactId)

  function submit() {
    if (!subject.trim() || !summary.trim()) return
    insert.mutate(
      {
        event_type: 'email_external',
        summary: summary.trim(),
        payload: { subject: subject.trim(), direction },
      },
      {
        onSuccess: () => {
          setSubject('')
          setSummary('')
          setDirection('outbound')
          onDone()
        },
      },
    )
  }

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
      <input
        type="text"
        placeholder="Subject der Mail"
        value={subject}
        onChange={e => setSubject(e.target.value)}
        style={{ padding: 8 }}
      />
      <textarea
        placeholder="Zusammenfassung des Inhalts"
        value={summary}
        onChange={e => setSummary(e.target.value)}
        rows={3}
        style={{ padding: 8 }}
      />
      <div style={{ display: 'flex', gap: 12 }}>
        <label style={{ fontSize: 13 }}>
          <input
            type="radio"
            name="dir"
            checked={direction === 'outbound'}
            onChange={() => setDirection('outbound')}
          /> Gesendet
        </label>
        <label style={{ fontSize: 13 }}>
          <input
            type="radio"
            name="dir"
            checked={direction === 'inbound'}
            onChange={() => setDirection('inbound')}
          /> Empfangen
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
          disabled={!subject.trim() || !summary.trim() || insert.isPending}
          style={{ padding: '6px 14px' }}
        >
          {insert.isPending ? 'Speichere…' : 'Speichern'}
        </button>
      </div>
    </div>
  )
}
