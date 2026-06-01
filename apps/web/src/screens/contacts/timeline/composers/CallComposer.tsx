import { useState } from 'react'
import { useInsertContactEvent } from '@/hooks/useEventComposer'
import type { Direction } from '@/types/contactEvents'

interface Props {
  contactId: string
  onDone: () => void
}

export function CallComposer({ contactId, onDone }: Props) {
  const [summary, setSummary] = useState('')
  const [body, setBody] = useState('')
  const [duration, setDuration] = useState('')
  const [direction, setDirection] = useState<Direction>('outbound')
  const insert = useInsertContactEvent(contactId)

  function submit() {
    if (!summary.trim()) return
    const minutes = duration.trim() ? Number(duration) : undefined
    insert.mutate(
      {
        event_type: 'call',
        summary: summary.trim(),
        body: body.trim() || undefined,
        payload: {
          ...(minutes !== undefined && !Number.isNaN(minutes) ? { duration_min: minutes } : {}),
          direction,
        },
      },
      {
        onSuccess: () => {
          setSummary('')
          setBody('')
          setDuration('')
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
        placeholder="Worum ging der Anruf"
        value={summary}
        onChange={e => setSummary(e.target.value)}
        autoComplete="off"
        style={{ padding: 8 }}
      />
      <textarea
        placeholder="Notizen (optional)"
        value={body}
        onChange={e => setBody(e.target.value)}
        autoComplete="off"
        rows={2}
        style={{ padding: 8 }}
      />
      <div style={{ display: 'flex', gap: 12, alignItems: 'center' }}>
        <label style={{ fontSize: 13 }}>
          Dauer
          <input
            type="number"
            value={duration}
            onChange={e => setDuration(e.target.value)}
            placeholder="Min."
            min="0"
            style={{ marginLeft: 6, width: 70, padding: 4 }}
          />
        </label>
        <label style={{ fontSize: 13 }}>
          <input
            type="radio"
            name="dir"
            checked={direction === 'outbound'}
            onChange={() => setDirection('outbound')}
          /> Ausgehend
        </label>
        <label style={{ fontSize: 13 }}>
          <input
            type="radio"
            name="dir"
            checked={direction === 'inbound'}
            onChange={() => setDirection('inbound')}
          /> Eingehend
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
          disabled={!summary.trim() || insert.isPending}
          style={{ padding: '6px 14px' }}
        >
          {insert.isPending ? 'Speichere…' : 'Speichern'}
        </button>
      </div>
    </div>
  )
}
