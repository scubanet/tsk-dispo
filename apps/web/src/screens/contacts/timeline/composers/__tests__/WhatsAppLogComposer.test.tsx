import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, screen, fireEvent } from '@testing-library/react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { WhatsAppLogComposer } from '../WhatsAppLogComposer'

const h = vi.hoisted(() => ({
  insert: vi.fn(),
  send: vi.fn(),
  accounts: [] as Array<{ id: string; channel: string; status: string }>,
}))

vi.mock('@/hooks/useEventComposer', () => ({
  useInsertContactEvent: () => ({ mutate: h.insert, isPending: false, error: null }),
}))
vi.mock('@/hooks/useSendMessage', () => ({
  useSendMessage: () => ({ mutate: h.send, isPending: false, error: null }),
}))
vi.mock('@/hooks/useMessagingAccounts', () => ({
  useMessagingAccounts: () => ({ data: h.accounts }),
}))

function wrapper({ children }: { children: React.ReactNode }) {
  const qc = new QueryClient()
  return <QueryClientProvider client={qc}>{children}</QueryClientProvider>
}

describe('WhatsAppLogComposer', () => {
  beforeEach(() => {
    h.insert.mockClear()
    h.send.mockClear()
    h.accounts = []
  })

  it('ohne verbundenes Konto: loggt event_type=whatsapp_log mit direction (Speichern)', () => {
    render(<WhatsAppLogComposer contactId="c1" onDone={vi.fn()} />, { wrapper })
    fireEvent.change(screen.getByPlaceholderText(/Inhalt der Nachricht/i), { target: { value: 'Bestätigt für morgen' } })
    fireEvent.click(screen.getByLabelText(/Empfangen/i))
    fireEvent.click(screen.getByRole('button', { name: /Speichern/i }))
    expect(h.insert).toHaveBeenCalledWith(
      expect.objectContaining({
        event_type: 'whatsapp_log',
        summary: 'Bestätigt für morgen',
        payload: { direction: 'inbound' },
      }),
      expect.any(Object),
    )
    expect(h.send).not.toHaveBeenCalled()
  })

  it('mit verbundenem WhatsApp-Konto: sendet via comms-outbound (Senden)', () => {
    h.accounts = [{ id: 'a1', channel: 'whatsapp', status: 'connected' }]
    render(<WhatsAppLogComposer contactId="c1" onDone={vi.fn()} />, { wrapper })
    fireEvent.change(screen.getByPlaceholderText(/Nachricht/i), { target: { value: 'Bis morgen!' } })
    fireEvent.click(screen.getByRole('button', { name: /Senden/i }))
    expect(h.send).toHaveBeenCalledWith(
      expect.objectContaining({ contact_id: 'c1', channel: 'whatsapp', body: 'Bis morgen!' }),
      expect.any(Object),
    )
    expect(h.insert).not.toHaveBeenCalled()
  })
})
