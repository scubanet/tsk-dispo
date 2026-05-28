// apps/web/src/screens/contacts/__tests__/ColumnPicker.test.tsx
//
// Phase G Phase 4 Task 3 — Tests für den ColumnPicker-Dropdown.
import { describe, it, expect, vi } from 'vitest'
import { render, screen, fireEvent } from '@testing-library/react'
import { ColumnPicker } from '../ColumnPicker'

describe('ColumnPicker', () => {
  it('renders the toggle button', () => {
    render(
      <ColumnPicker
        visibleIds={['name', 'email']}
        onToggle={vi.fn()}
        onReset={vi.fn()}
      />,
    )
    const btn = screen.getByRole('button', { name: 'Spalten konfigurieren' })
    expect(btn).toBeTruthy()
    expect(btn.getAttribute('aria-expanded')).toBe('false')
  })

  it('opens dropdown when button is clicked', () => {
    render(
      <ColumnPicker
        visibleIds={['name', 'email']}
        onToggle={vi.fn()}
        onReset={vi.fn()}
      />,
    )
    const btn = screen.getByRole('button', { name: 'Spalten konfigurieren' })
    expect(screen.queryByRole('menu')).toBeNull()

    fireEvent.click(btn)
    expect(screen.getByRole('menu')).toBeTruthy()
    expect(btn.getAttribute('aria-expanded')).toBe('true')
    // Catalog-Items sichtbar
    expect(screen.getByLabelText('Telefon')).toBeTruthy()
    expect(screen.getByLabelText('Saldo')).toBeTruthy()
  })

  it('toggling a checkbox calls onToggle(id)', () => {
    const onToggle = vi.fn()
    render(
      <ColumnPicker
        visibleIds={['name', 'email']}
        onToggle={onToggle}
        onReset={vi.fn()}
      />,
    )
    fireEvent.click(screen.getByRole('button', { name: 'Spalten konfigurieren' }))
    const phoneCheckbox = screen.getByLabelText('Telefon') as HTMLInputElement
    expect(phoneCheckbox.checked).toBe(false)
    fireEvent.click(phoneCheckbox)
    expect(onToggle).toHaveBeenCalledWith('phone')
  })

  it('reset link calls onReset', () => {
    const onReset = vi.fn()
    render(
      <ColumnPicker
        visibleIds={['name', 'email', 'phone']}
        onToggle={vi.fn()}
        onReset={onReset}
      />,
    )
    fireEvent.click(screen.getByRole('button', { name: 'Spalten konfigurieren' }))
    fireEvent.click(screen.getByRole('button', { name: /Zurücksetzen/i }))
    expect(onReset).toHaveBeenCalledTimes(1)
  })

  it('name checkbox is disabled (always-on)', () => {
    render(
      <ColumnPicker
        visibleIds={['name', 'email']}
        onToggle={vi.fn()}
        onReset={vi.fn()}
      />,
    )
    fireEvent.click(screen.getByRole('button', { name: 'Spalten konfigurieren' }))
    const nameCheckbox = screen.getByLabelText('Name') as HTMLInputElement
    expect(nameCheckbox.disabled).toBe(true)
    expect(nameCheckbox.checked).toBe(true)
  })
})
