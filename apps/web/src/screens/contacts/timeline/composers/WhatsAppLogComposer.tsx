import { useState } from 'react'
import { useInsertContactEvent } from '@/hooks/useEventComposer'
import { useMessagingAccounts } from '@/hooks/useMessagingAccounts'
import { useSendMessage } from '@/hooks/useSendMessage'
import type { Direction } from '@/types/contactEvents'

interface Props {
  contactId: string
  onDone: () => void
}

export function WhatsAppLogComposer({ contactId, onDone }: Props) {
  const [summary, setSummary] = useState('')
  const [direction, setDirection] = useState<Direction>('outbound')
  const insert = useInsertContactEvent(contactId)
  const send = useSendMessage(contactId)
  const { data: accounts } = useMessagingAccounts()

  // Echtes Senden, sobald ein WhatsApp-Konto verbunden ist; sonst manuelles Log.
  const whatsappConnected = (accounts ?? []).some(a => a.channel === 'whatsapp' && a.status === 'connected')

  function reset() {
    setSummary('')
    setDirection('outbound')
    onDone()
  }

  function submit() {
    if (!summary.trim()) return
    if (whatsappConnected) {
      send.mutate(
        { contact_id: contactId, channel: 'whatsapp', body: summary.trim() },
        { onSuccess: reset },
      )
    } else {
      insert.mutate(
        {
          event_type: 'whatsapp_log',
          summary: summary.trim(),
          payload: { direction },
        },
        { onSuccess: reset },
      )
    }
  }

  const busy = insert.isPending || send.isPending
  const err = insert.error || send.error

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
      <textarea
        placeholder={whatsappConnected ? 'Nachricht' : 'Inhalt der Nachricht'}
        value={summary}
        onChange={e => setSummary(e.target.value)}
        autoComplete="off"
        rows={3}
        style={{ padding: 8 }}
      />
      {!whatsappConnected && (
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
          disabled={!summary.trim() || busy}
          style={{ padding: '6px 14px' }}
        >
          {whatsappConnected
            ? (busy ? 'Sende…' : 'Senden')
            : (busy ? 'Speichere…' : 'Speichern')}
        </button>
      </div>
    </div>
  )
}
