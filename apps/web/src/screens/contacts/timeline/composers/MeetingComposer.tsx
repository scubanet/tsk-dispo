import { useState } from 'react'
import { useInsertContactEvent } from '@/hooks/useEventComposer'

interface Props {
  contactId: string
  onDone: () => void
}

export function MeetingComposer({ contactId, onDone }: Props) {
  const [summary, setSummary] = useState('')
  const [body, setBody] = useState('')
  const [date, setDate] = useState('')
  const [duration, setDuration] = useState('')
  const [location, setLocation] = useState('')
  const insert = useInsertContactEvent(contactId)

  function submit() {
    if (!summary.trim()) return
    const minutes = duration.trim() ? Number(duration) : undefined
    insert.mutate(
      {
        event_type: 'meeting_past',
        summary: summary.trim(),
        body: body.trim() || undefined,
        ...(date.trim() ? { occurred_at: date.trim() } : {}),
        payload: {
          ...(minutes !== undefined && !Number.isNaN(minutes) ? { duration_min: minutes } : {}),
          ...(location.trim() ? { location: location.trim() } : {}),
        },
      },
      {
        onSuccess: () => {
          setSummary('')
          setBody('')
          setDate('')
          setDuration('')
          setLocation('')
          onDone()
        },
      },
    )
  }

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
      <input
        type="text"
        placeholder="Worum ging das Meeting"
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
      <div style={{ display: 'flex', gap: 12, alignItems: 'center', flexWrap: 'wrap' }}>
        <label style={{ fontSize: 13 }}>
          Datum
          <input
            type="date"
            value={date}
            onChange={e => setDate(e.target.value)}
            style={{ marginLeft: 6, padding: 4 }}
          />
        </label>
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
        <input
          type="text"
          placeholder="Ort (optional)"
          value={location}
          onChange={e => setLocation(e.target.value)}
          autoComplete="off"
          style={{ padding: 4, flex: 1, minWidth: 120 }}
        />
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
