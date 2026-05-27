import { describe, it, expect, vi } from 'vitest'
import { render, screen, fireEvent } from '@testing-library/react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { CallComposer } from '../CallComposer'

const mockMutate = vi.fn()
vi.mock('@/hooks/useEventComposer', () => ({
  useInsertContactEvent: () => ({ mutate: mockMutate, isPending: false, error: null }),
}))

function wrapper({ children }: { children: React.ReactNode }) {
  const qc = new QueryClient()
  return <QueryClientProvider client={qc}>{children}</QueryClientProvider>
}

describe('CallComposer', () => {
  it('submits event_type=call with summary, payload.duration_min, direction', () => {
    render(<CallComposer contactId="c1" onDone={vi.fn()} />, { wrapper })
    fireEvent.change(screen.getByPlaceholderText(/Worum ging/i), { target: { value: 'Test call' } })
    fireEvent.change(screen.getByLabelText(/Dauer/), { target: { value: '15' } })
    fireEvent.click(screen.getByLabelText(/Eingehend/i))
    fireEvent.click(screen.getByRole('button', { name: /Speichern/i }))
    expect(mockMutate).toHaveBeenCalledWith(
      expect.objectContaining({
        event_type: 'call',
        summary: 'Test call',
        payload: { duration_min: 15, direction: 'inbound' },
      }),
      expect.any(Object),
    )
  })
})
