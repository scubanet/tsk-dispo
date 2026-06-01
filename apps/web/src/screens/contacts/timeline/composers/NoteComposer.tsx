import { useState } from 'react'
import { useInsertContactEvent } from '@/hooks/useEventComposer'

interface Props {
  contactId: string
  onDone: () => void
}

export function NoteComposer({ contactId, onDone }: Props) {
  const [summary, setSummary] = useState('')
  const [body, setBody] = useState('')
  const insert = useInsertContactEvent(contactId)

  function submit() {
    if (!summary.trim()) return
    insert.mutate(
      { event_type: 'note', summary: summary.trim(), body: body.trim() || undefined },
      {
        onSuccess: () => {
          setSummary('')
          setBody('')
          onDone()
        },
      },
    )
  }

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
      <input
        type="text"
        placeholder="Titel der Notiz"
        value={summary}
        onChange={e => setSummary(e.target.value)}
        autoComplete="off"
        style={{ padding: 8 }}
      />
      <textarea
        placeholder="Text (optional)"
        value={body}
        onChange={e => setBody(e.target.value)}
        autoComplete="off"
        rows={3}
        style={{ padding: 8, resize: 'vertical' }}
      />
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
