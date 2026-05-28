// apps/web/src/screens/contacts/__tests__/SaveViewDialog.test.tsx
//
// Phase G Phase 4 Task 8 — Tests für SaveViewDialog.

import { describe, it, expect, vi } from 'vitest'
import { render, screen, fireEvent, waitFor } from '@testing-library/react'
import { SaveViewDialog } from '../SaveViewDialog'

describe('SaveViewDialog', () => {
  it('renders nothing when open=false', () => {
    const { container } = render(
      <SaveViewDialog
        open={false}
        onClose={vi.fn()}
        onSave={vi.fn()}
        isSaving={false}
      />,
    )
    expect(container.querySelector('[data-testid="save-view-dialog"]')).toBeNull()
  })

  it('renders input + Save + Cancel buttons when open=true', () => {
    render(
      <SaveViewDialog
        open
        onClose={vi.fn()}
        onSave={vi.fn()}
        isSaving={false}
      />,
    )
    expect(screen.getByTestId('save-view-dialog')).toBeTruthy()
    expect(screen.getByLabelText('Name der Ansicht')).toBeTruthy()
    expect(screen.getByRole('button', { name: 'Speichern' })).toBeTruthy()
    expect(screen.getByRole('button', { name: 'Abbrechen' })).toBeTruthy()
  })

  it('disables Save when name is empty (or only whitespace)', () => {
    render(
      <SaveViewDialog
        open
        onClose={vi.fn()}
        onSave={vi.fn()}
        isSaving={false}
      />,
    )
    const saveBtn = screen.getByRole('button', {
      name: 'Speichern',
    }) as HTMLButtonElement
    expect(saveBtn.disabled).toBe(true)

    const input = screen.getByLabelText(
      'Name der Ansicht',
    ) as HTMLInputElement
    fireEvent.change(input, { target: { value: '   ' } })
    expect(saveBtn.disabled).toBe(true)

    fireEvent.change(input, { target: { value: 'My View' } })
    expect(saveBtn.disabled).toBe(false)
  })

  it('submit triggers onSave with trimmed name', async () => {
    const onSave = vi.fn().mockResolvedValue(undefined)
    render(
      <SaveViewDialog
        open
        onClose={vi.fn()}
        onSave={onSave}
        isSaving={false}
      />,
    )
    const input = screen.getByLabelText(
      'Name der Ansicht',
    ) as HTMLInputElement
    fireEvent.change(input, { target: { value: '  Meine Studenten  ' } })
    fireEvent.click(screen.getByRole('button', { name: 'Speichern' }))
    await waitFor(() =>
      expect(onSave).toHaveBeenCalledWith('Meine Studenten'),
    )
  })

  it('shows error banner when onSave throws (UNIQUE conflict)', async () => {
    const onSave = vi
      .fn()
      .mockRejectedValue(new Error('duplicate key value violates unique constraint'))
    render(
      <SaveViewDialog
        open
        onClose={vi.fn()}
        onSave={onSave}
        isSaving={false}
      />,
    )
    const input = screen.getByLabelText(
      'Name der Ansicht',
    ) as HTMLInputElement
    fireEvent.change(input, { target: { value: 'My View' } })
    fireEvent.click(screen.getByRole('button', { name: 'Speichern' }))

    const banner = await screen.findByTestId('save-view-error')
    expect(banner.textContent).toBe('Name existiert bereits')
  })
})
