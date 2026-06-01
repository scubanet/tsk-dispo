import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, screen, fireEvent } from '@testing-library/react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { EmailLogComposer } from '../EmailLogComposer'

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

describe('EmailLogComposer', () => {
  beforeEach(() => {
    h.insert.mockClear()
    h.send.mockClear()
    h.accounts = []
  })

  it('ohne verbundenes Konto: loggt event_type=email_external (Speichern)', () => {
    render(<EmailLogComposer contactId="c1" onDone={vi.fn()} />, { wrapper })
    fireEvent.change(screen.getByPlaceholderText(/Betreff/i), { target: { value: 'Re: OWD Anmeldung' } })
    fireEvent.change(screen.getByPlaceholderText(/Zusammenfassung/i), { target: { value: 'Bestätigt für Juli' } })
    fireEvent.click(screen.getByRole('button', { name: /Speichern/i }))
    expect(h.insert).toHaveBeenCalledWith(
      expect.objectContaining({
        event_type: 'email_external',
        summary: 'Bestätigt für Juli',
        payload: expect.objectContaining({ subject: 'Re: OWD Anmeldung', direction: 'outbound' }),
      }),
      expect.any(Object),
    )
    expect(h.send).not.toHaveBeenCalled()
  })

  it('mit verbundenem E-Mail-Konto: sendet via comms-outbound (Senden)', () => {
    h.accounts = [{ id: 'a1', channel: 'email', status: 'connected' }]
    render(<EmailLogComposer contactId="c1" onDone={vi.fn()} />, { wrapper })
    fireEvent.change(screen.getByPlaceholderText(/Betreff/i), { target: { value: 'Hallo Lena' } })
    fireEvent.change(screen.getByPlaceholderText(/Nachricht/i), { target: { value: 'Bis Februar!' } })
    fireEvent.click(screen.getByRole('button', { name: /Senden/i }))
    expect(h.send).toHaveBeenCalledWith(
      expect.objectContaining({ contact_id: 'c1', channel: 'email', subject: 'Hallo Lena', body: 'Bis Februar!' }),
      expect.any(Object),
    )
    expect(h.insert).not.toHaveBeenCalled()
  })
})
