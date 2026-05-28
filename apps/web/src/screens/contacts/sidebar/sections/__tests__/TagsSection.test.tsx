import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { TagsSection } from '../TagsSection'
import type { ContactWithProperties } from '@/types/contactProperties'

const mockMutate = vi.fn().mockResolvedValue(undefined)
vi.mock('@/hooks/useContactFieldMutation', () => ({
  useContactFieldMutation: () => ({
    mutateAsync: mockMutate, isPending: false, error: null,
  }),
}))

function wrapper({ children }: { children: React.ReactNode }) {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } })
  return <QueryClientProvider client={qc}>{children}</QueryClientProvider>
}

const baseContact: ContactWithProperties = {
  id: 'c1', kind: 'person', display_name: 'Hugo Eugster',
  first_name: 'Hugo', last_name: 'Eugster', birth_date: null,
  primary_email: null, phones: [], addresses: [], languages: [], 
  source: 'manual',
  created_at: '2026-01-01T00:00:00Z',
  updated_at: '2026-05-27T00:00:00Z',
  owner_id: null,
  tags: [],
  instructor: null, student: null, organization: null,
  balance_chf: null, last_movement_date: null,
  roles: [],
}

beforeEach(() => {
  mockMutate.mockClear()
  // Force section open so the body is queryable (default closed otherwise).
  try {
    window.localStorage.clear()
    window.localStorage.setItem('sidebar-section-tags', 'true')
  } catch { /* noop */ }
})

describe('TagsSection', () => {
  it('renders title "Tags"', () => {
    render(<TagsSection contact={baseContact} />, { wrapper })
    expect(screen.getByText('Tags')).toBeTruthy()
  })

  it('renders both tag chips when contact has 2 tags', () => {
    render(
      <TagsSection contact={{ ...baseContact, tags: ['VIP', 'newsletter'] }} />,
      { wrapper },
    )
    expect(screen.getByText(/VIP/)).toBeTruthy()
    expect(screen.getByText(/newsletter/)).toBeTruthy()
  })

  it('renders dash when tags array is empty', () => {
    render(<TagsSection contact={baseContact} />, { wrapper })
    expect(screen.getByText('—')).toBeTruthy()
  })

  it('clicking the ×-button on a chip mutates with filtered array', async () => {
    render(
      <TagsSection contact={{ ...baseContact, tags: ['VIP', 'newsletter'] }} />,
      { wrapper },
    )
    fireEvent.click(screen.getByRole('button', { name: /Tag VIP entfernen/i }))
    await waitFor(() =>
      expect(mockMutate).toHaveBeenCalledWith({
        table: 'contacts',
        field: 'tags',
        value: ['newsletter'],
      }),
    )
  })

  it('clicking "+ Tag" opens an input field', () => {
    render(<TagsSection contact={baseContact} />, { wrapper })
    fireEvent.click(screen.getByRole('button', { name: /\+ Tag/ }))
    expect(screen.getByPlaceholderText(/neuer Tag/i)).toBeTruthy()
  })

  it('typing a tag + Enter mutates with appended array', async () => {
    render(
      <TagsSection contact={{ ...baseContact, tags: ['VIP'] }} />,
      { wrapper },
    )
    fireEvent.click(screen.getByRole('button', { name: /\+ Tag/ }))
    const input = screen.getByPlaceholderText(/neuer Tag/i) as HTMLInputElement
    fireEvent.change(input, { target: { value: 'newsletter' } })
    fireEvent.keyDown(input, { key: 'Enter' })
    await waitFor(() =>
      expect(mockMutate).toHaveBeenCalledWith({
        table: 'contacts',
        field: 'tags',
        value: ['VIP', 'newsletter'],
      }),
    )
  })

  it('adding a duplicate tag does NOT call mutate', async () => {
    render(
      <TagsSection contact={{ ...baseContact, tags: ['VIP'] }} />,
      { wrapper },
    )
    fireEvent.click(screen.getByRole('button', { name: /\+ Tag/ }))
    const input = screen.getByPlaceholderText(/neuer Tag/i) as HTMLInputElement
    fireEvent.change(input, { target: { value: 'VIP' } })
    fireEvent.keyDown(input, { key: 'Enter' })
    // Short wait to let async-mutation race finish — then check it never ran.
    await new Promise(r => setTimeout(r, 20))
    expect(mockMutate).not.toHaveBeenCalled()
  })

  it('adding empty string does NOT call mutate', async () => {
    render(<TagsSection contact={baseContact} />, { wrapper })
    fireEvent.click(screen.getByRole('button', { name: /\+ Tag/ }))
    const input = screen.getByPlaceholderText(/neuer Tag/i) as HTMLInputElement
    fireEvent.change(input, { target: { value: '   ' } })
    fireEvent.keyDown(input, { key: 'Enter' })
    await new Promise(r => setTimeout(r, 20))
    expect(mockMutate).not.toHaveBeenCalled()
  })

  it('Esc in the input cancels without calling mutate', async () => {
    render(<TagsSection contact={baseContact} />, { wrapper })
    fireEvent.click(screen.getByRole('button', { name: /\+ Tag/ }))
    const input = screen.getByPlaceholderText(/neuer Tag/i) as HTMLInputElement
    fireEvent.change(input, { target: { value: 'newsletter' } })
    fireEvent.keyDown(input, { key: 'Escape' })
    await new Promise(r => setTimeout(r, 20))
    expect(mockMutate).not.toHaveBeenCalled()
    // Input should be closed again
    expect(screen.queryByPlaceholderText(/neuer Tag/i)).toBeNull()
  })
})
