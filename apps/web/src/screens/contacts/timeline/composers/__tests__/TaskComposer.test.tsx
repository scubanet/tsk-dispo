import { describe, it, expect, vi } from 'vitest'
import { render, screen, fireEvent } from '@testing-library/react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { TaskComposer } from '../TaskComposer'

const mockMutate = vi.fn()
vi.mock('@/hooks/useEventComposer', () => ({
  useInsertContactEvent: () => ({ mutate: mockMutate, isPending: false, error: null }),
}))

function wrapper({ children }: { children: React.ReactNode }) {
  const qc = new QueryClient()
  return <QueryClientProvider client={qc}>{children}</QueryClientProvider>
}

describe('TaskComposer', () => {
  it('submits event_type=task with payload.due_date', () => {
    render(<TaskComposer contactId="c1" onDone={vi.fn()} />, { wrapper })
    fireEvent.change(screen.getByPlaceholderText(/Was ist zu tun/), { target: { value: 'Mail nachhaken' } })
    fireEvent.change(screen.getByLabelText(/Fällig/), { target: { value: '2026-06-15' } })
    fireEvent.click(screen.getByRole('button', { name: /Speichern/i }))
    expect(mockMutate).toHaveBeenCalledWith(
      expect.objectContaining({
        event_type: 'task',
        summary: 'Mail nachhaken',
        payload: expect.objectContaining({ due_date: '2026-06-15' }),
      }),
      expect.any(Object),
    )
  })

  it('due_date is required', () => {
    render(<TaskComposer contactId="c1" onDone={vi.fn()} />, { wrapper })
    fireEvent.change(screen.getByPlaceholderText(/Was ist zu tun/), { target: { value: 'Test' } })
    const submit = screen.getByRole('button', { name: /Speichern/i })
    expect(submit.hasAttribute('disabled')).toBe(true)
  })
})
