import { describe, it, expect, vi } from 'vitest'
import { render, screen, fireEvent } from '@testing-library/react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { WhatsAppLogComposer } from '../WhatsAppLogComposer'

const mockMutate = vi.fn()
vi.mock('@/hooks/useEventComposer', () => ({
  useInsertContactEvent: () => ({ mutate: mockMutate, isPending: false, error: null }),
}))

function wrapper({ children }: { children: React.ReactNode }) {
  const qc = new QueryClient()
  return <QueryClientProvider client={qc}>{children}</QueryClientProvider>
}

describe('WhatsAppLogComposer', () => {
  it('submits event_type=whatsapp_log with direction', () => {
    render(<WhatsAppLogComposer contactId="c1" onDone={vi.fn()} />, { wrapper })
    fireEvent.change(screen.getByPlaceholderText(/Inhalt der Nachricht/i), { target: { value: 'Bestätigt für morgen' } })
    fireEvent.click(screen.getByLabelText(/Empfangen/i))
    fireEvent.click(screen.getByRole('button', { name: /Speichern/i }))
    expect(mockMutate).toHaveBeenCalledWith(
      expect.objectContaining({
        event_type: 'whatsapp_log',
        summary: 'Bestätigt für morgen',
        payload: { direction: 'inbound' },
      }),
      expect.any(Object),
    )
  })
})
