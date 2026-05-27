import { describe, it, expect, vi } from 'vitest'
import { render, screen, fireEvent } from '@testing-library/react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { NoteComposer } from '../NoteComposer'

const mockMutate = vi.fn()
vi.mock('@/hooks/useEventComposer', () => ({
  useInsertContactEvent: () => ({
    mutate: mockMutate, isPending: false, error: null,
  }),
}))

function wrapper({ children }: { children: React.ReactNode }) {
  const qc = new QueryClient()
  return <QueryClientProvider client={qc}>{children}</QueryClientProvider>
}

describe('NoteComposer', () => {
  it('submit calls mutate with event_type=note', () => {
    const onDone = vi.fn()
    render(<NoteComposer contactId="c1" onDone={onDone} />, { wrapper })
    fireEvent.change(screen.getByPlaceholderText(/Titel/), { target: { value: 'My note' } })
    fireEvent.change(screen.getByPlaceholderText(/Text/), { target: { value: 'Body content' } })
    fireEvent.click(screen.getByRole('button', { name: /Speichern/i }))
    expect(mockMutate).toHaveBeenCalledWith(
      { event_type: 'note', summary: 'My note', body: 'Body content' },
      expect.objectContaining({ onSuccess: expect.any(Function) }),
    )
  })

  it('empty summary disables submit', () => {
    render(<NoteComposer contactId="c1" onDone={vi.fn()} />, { wrapper })
    const submit = screen.getByRole('button', { name: /Speichern/i })
    expect(submit.hasAttribute('disabled')).toBe(true)
    fireEvent.change(screen.getByPlaceholderText(/Titel/), { target: { value: 'X' } })
    expect(submit.hasAttribute('disabled')).toBe(false)
  })
})
