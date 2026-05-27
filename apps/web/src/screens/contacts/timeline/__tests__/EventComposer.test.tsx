// apps/web/src/screens/contacts/timeline/__tests__/EventComposer.test.tsx
import { describe, it, expect, vi } from 'vitest'
import { render, screen, fireEvent } from '@testing-library/react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { EventComposer } from '../EventComposer'

vi.mock('@/hooks/useEventComposer', () => ({
  useInsertContactEvent: () => ({ mutate: vi.fn(), isPending: false, error: null }),
}))

function wrapper({ children }: { children: React.ReactNode }) {
  const qc = new QueryClient()
  return <QueryClientProvider client={qc}>{children}</QueryClientProvider>
}

describe('EventComposer', () => {
  it('renders segmented control with all 6 types', () => {
    render(<EventComposer contactId="c1" />, { wrapper })
    expect(screen.getByRole('button', { name: 'Notiz' })).toBeTruthy()
    expect(screen.getByRole('button', { name: 'Anruf' })).toBeTruthy()
    expect(screen.getByRole('button', { name: 'Mail' })).toBeTruthy()
    expect(screen.getByRole('button', { name: 'Meeting' })).toBeTruthy()
    expect(screen.getByRole('button', { name: 'Task' })).toBeTruthy()
    expect(screen.getByRole('button', { name: 'WhatsApp' })).toBeTruthy()
  })

  it('clicking Notiz expands NoteComposer', () => {
    render(<EventComposer contactId="c1" />, { wrapper })
    fireEvent.click(screen.getByRole('button', { name: 'Notiz' }))
    expect(screen.getByPlaceholderText(/Titel der Notiz/i)).toBeTruthy()
  })

  it('clicking Anruf expands CallComposer', () => {
    render(<EventComposer contactId="c1" />, { wrapper })
    fireEvent.click(screen.getByRole('button', { name: 'Anruf' }))
    expect(screen.getByPlaceholderText(/Worum ging der Anruf/i)).toBeTruthy()
  })

  it('selecting a different type swaps the form', () => {
    render(<EventComposer contactId="c1" />, { wrapper })
    fireEvent.click(screen.getByRole('button', { name: 'Notiz' }))
    expect(screen.getByPlaceholderText(/Titel der Notiz/i)).toBeTruthy()
    fireEvent.click(screen.getByRole('button', { name: 'Task' }))
    expect(screen.queryByPlaceholderText(/Titel der Notiz/i)).toBeNull()
    expect(screen.getByPlaceholderText(/Was ist zu tun/i)).toBeTruthy()
  })
})
