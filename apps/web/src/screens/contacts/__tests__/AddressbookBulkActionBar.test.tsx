// apps/web/src/screens/contacts/__tests__/AddressbookBulkActionBar.test.tsx
//
// Phase G Phase 4 Task 7 — Tests für die BulkActionBar.
import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, screen, fireEvent, within } from '@testing-library/react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { AddressbookBulkActionBar } from '../AddressbookBulkActionBar'

// ── Mock des Mutation-Hooks (Spy auf mutate). ────────────────────────────
const mutateSpy = vi.fn()
vi.mock('@/hooks/useBulkContactMutation', () => ({
  useBulkContactMutation: () => ({
    mutate: mutateSpy,
    mutateAsync: vi.fn(),
    isPending: false,
  }),
}))

function renderBar(props?: Partial<React.ComponentProps<typeof AddressbookBulkActionBar>>) {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } })
  return render(
    <QueryClientProvider client={qc}>
      <AddressbookBulkActionBar
        selectedIds={['c1', 'c2', 'c3']}
        onClear={vi.fn()}
        {...props}
      />
    </QueryClientProvider>,
  )
}

describe('AddressbookBulkActionBar', () => {
  beforeEach(() => {
    mutateSpy.mockClear()
  })

  it('renders counter "3 ausgewählt" for 3 selected IDs', () => {
    renderBar()
    expect(screen.getByTestId('bulk-action-counter').textContent).toBe(
      '3 ausgewählt',
    )
  })

  it('click on ✕ button triggers onClear', () => {
    const onClear = vi.fn()
    renderBar({ onClear })
    fireEvent.click(screen.getByRole('button', { name: /Auswahl aufheben/ }))
    expect(onClear).toHaveBeenCalledTimes(1)
  })

  it('click on "+ Tags" opens dropdown with 4 tag options', () => {
    renderBar()
    fireEvent.click(screen.getByRole('button', { name: /\+ Tags/ }))
    const menu = screen.getByRole('menu', { name: 'Tags hinzufügen' })
    const checkboxes = within(menu).getAllByRole('checkbox')
    expect(checkboxes.length).toBe(4)
  })

  it('selecting a tag + Apply triggers add_tags mutation', () => {
    renderBar()
    fireEvent.click(screen.getByRole('button', { name: /\+ Tags/ }))
    fireEvent.click(screen.getByLabelText('Lead'))
    fireEvent.click(screen.getByRole('button', { name: 'Anwenden' }))
    expect(mutateSpy).toHaveBeenCalledTimes(1)
    const [action] = mutateSpy.mock.calls[0]
    expect(action).toEqual({
      type: 'add_tags',
      ids: ['c1', 'c2', 'c3'],
      tags: ['lead'],
    })
  })

  it('click on "Pipeline" opens dropdown with 6 stages', () => {
    renderBar()
    fireEvent.click(screen.getByRole('button', { name: /Pipeline/ }))
    const menu = screen.getByRole('menu', { name: 'Pipeline-Stufe' })
    const items = within(menu).getAllByRole('menuitem')
    expect(items.length).toBe(6)
  })

  it('clicking a pipeline stage triggers set_pipeline_stage mutation', () => {
    renderBar()
    fireEvent.click(screen.getByRole('button', { name: /Pipeline/ }))
    const menu = screen.getByRole('menu', { name: 'Pipeline-Stufe' })
    fireEvent.click(within(menu).getByRole('menuitem', { name: 'Qualified' }))
    expect(mutateSpy).toHaveBeenCalledTimes(1)
    const [action] = mutateSpy.mock.calls[0]
    expect(action).toEqual({
      type: 'set_pipeline_stage',
      ids: ['c1', 'c2', 'c3'],
      stage: 'qualified',
    })
  })

  it('click on "✉ Massen-Mail" opens stub modal with TODO Phase 5 text', () => {
    renderBar()
    fireEvent.click(screen.getByRole('button', { name: /Massen-Mail/ }))
    const modal = screen.getByTestId('mass-mail-modal')
    expect(modal.textContent).toMatch(/TODO Phase 5/i)
  })

  it('click on ⋯ opens overflow menu with 5 items', () => {
    renderBar()
    fireEvent.click(screen.getByRole('button', { name: 'Weitere Aktionen' }))
    const menu = screen.getByRole('menu', { name: 'Weitere Aktionen' })
    const items = within(menu).getAllByRole('menuitem')
    expect(items.length).toBe(5)
    const labels = items.map((el) => el.textContent)
    expect(labels).toEqual([
      'Als aktiv setzen',
      'Als inaktiv setzen',
      'Export CSV',
      'Zu Saved View hinzufügen',
      'Archivieren',
    ])
  })
})
