import { describe, it, expect, vi } from 'vitest'
import { render, screen, fireEvent } from '@testing-library/react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { MeetingComposer } from '../MeetingComposer'

const mockMutate = vi.fn()
vi.mock('@/hooks/useEventComposer', () => ({
  useInsertContactEvent: () => ({ mutate: mockMutate, isPending: false, error: null }),
}))

function wrapper({ children }: { children: React.ReactNode }) {
  const qc = new QueryClient()
  return <QueryClientProvider client={qc}>{children}</QueryClientProvider>
}

describe('MeetingComposer', () => {
  it('submits event_type=meeting_past with payload.duration_min and occurred_at', () => {
    render(<MeetingComposer contactId="c1" onDone={vi.fn()} />, { wrapper })
    fireEvent.change(screen.getByPlaceholderText(/Worum ging/i), { target: { value: 'Kaffee am See' } })
    fireEvent.change(screen.getByLabelText(/Dauer/), { target: { value: '60' } })
    fireEvent.change(screen.getByLabelText(/Datum/), { target: { value: '2026-05-15' } })
    fireEvent.click(screen.getByRole('button', { name: /Speichern/i }))
    expect(mockMutate).toHaveBeenCalledWith(
      expect.objectContaining({
        event_type: 'meeting_past',
        summary: 'Kaffee am See',
        occurred_at: '2026-05-15',
        payload: expect.objectContaining({ duration_min: 60 }),
      }),
      expect.any(Object),
    )
  })
})
