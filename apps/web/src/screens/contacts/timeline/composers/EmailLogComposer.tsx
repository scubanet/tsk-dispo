import { useState } from 'react'
import { useInsertContactEvent } from '@/hooks/useEventComposer'
import { useMessagingAccounts } from '@/hooks/useMessagingAccounts'
import { useSendMessage } from '@/hooks/useSendMessage'
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
  const send = useSendMessage(contactId)
  const { data: accounts } = useMessagingAccounts()

  // Echtes Senden, sobald ein E-Mail-Konto verbunden ist; sonst manuelles Log.
  const emailConnected = (accounts ?? []).some(a => a.channel === 'email' && a.status === 'connected')

  function reset() {
    setSubject('')
    setSummary('')
    setDirection('outbound')
    onDone()
  }

  function submit() {
    if (!subject.trim() || !summary.trim()) return
    if (emailConnected) {
      send.mutate(
        { contact_id: contactId, channel: 'email', subject: subject.trim(), body: summary.trim() },
        { onSuccess: reset },
      )
    } else {
      insert.mutate(
        {
          event_type: 'email_external',
          summary: summary.trim(),
          payload: { subject: subject.trim(), direction },
        },
        { onSuccess: reset },
      )
    }
  }

  const busy = insert.isPending || send.isPending
  const err = insert.error || send.error

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
        placeholder={emailConnected ? 'Nachricht' : 'Zusammenfassung des Inhalts'}
        value={summary}
        onChange={e => setSummary(e.target.value)}
        rows={3}
        style={{ padding: 8 }}
      />
      {!emailConnected && (
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
      )}
      {err && (
        <div style={{ color: 'var(--color-text-danger, #c0392b)', fontSize: 12 }}>
          {err.message}
        </div>
      )}
      <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 6 }}>
        <button type="button" onClick={onDone} style={{ padding: '6px 12px' }}>
          Abbrechen
        </button>
        <button
          type="button"
          onClick={submit}
          disabled={!subject.trim() || !summary.trim() || busy}
          style={{ padding: '6px 14px' }}
        >
          {emailConnected
            ? (busy ? 'Sende…' : 'Senden')
            : (busy ? 'Speichere…' : 'Speichern')}
        </button>
      </div>
    </div>
  )
}
