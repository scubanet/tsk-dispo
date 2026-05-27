import { describe, it, expect, vi } from 'vitest'
import { render, screen, fireEvent } from '@testing-library/react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { EmailLogComposer } from '../EmailLogComposer'

const mockMutate = vi.fn()
vi.mock('@/hooks/useEventComposer', () => ({
  useInsertContactEvent: () => ({ mutate: mockMutate, isPending: false, error: null }),
}))

function wrapper({ children }: { children: React.ReactNode }) {
  const qc = new QueryClient()
  return <QueryClientProvider client={qc}>{children}</QueryClientProvider>
}

describe('EmailLogComposer', () => {
  it('submits event_type=email_external with subject + direction', () => {
    render(<EmailLogComposer contactId="c1" onDone={vi.fn()} />, { wrapper })
    fireEvent.change(screen.getByPlaceholderText(/Subject/i), { target: { value: 'Re: OWD Anmeldung' } })
    fireEvent.change(screen.getByPlaceholderText(/Zusammenfassung/i), { target: { value: 'Bestätigt für Juli' } })
    fireEvent.click(screen.getByRole('button', { name: /Speichern/i }))
    expect(mockMutate).toHaveBeenCalledWith(
      expect.objectContaining({
        event_type: 'email_external',
        summary: 'Bestätigt für Juli',
        payload: expect.objectContaining({ subject: 'Re: OWD Anmeldung', direction: 'outbound' }),
      }),
      expect.any(Object),
    )
  })
})
