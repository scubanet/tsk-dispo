// apps/web/src/screens/contacts/__tests__/FilterChipDropdown.test.tsx
//
// Phase G Phase 4 Task 5 — Tests für FilterChipDropdown.
import { describe, it, expect, vi } from 'vitest'
import { render, screen, fireEvent } from '@testing-library/react'
import { FilterChipDropdown } from '../FilterChipDropdown'

const ROLE_OPTIONS = [
  { value: 'instructor', label: 'Instructor' },
  { value: 'student', label: 'Student' },
  { value: 'cd', label: 'CD' },
  { value: 'owner', label: 'Owner' },
] as const

describe('FilterChipDropdown', () => {
  it('renders inactive chip "Label ▾" when nothing selected', () => {
    render(
      <FilterChipDropdown
        label="Rolle"
        options={ROLE_OPTIONS}
        selected={[]}
        onChange={vi.fn()}
      />,
    )
    const btn = screen.getByRole('button', { name: 'Rolle' })
    expect(btn.textContent).toBe('Rolle ▾')
  })

  it('renders active chip with single value "Label: val ▾"', () => {
    render(
      <FilterChipDropdown
        label="Rolle"
        options={ROLE_OPTIONS}
        selected={['instructor']}
        onChange={vi.fn()}
      />,
    )
    const btn = screen.getByRole('button', { name: 'Rolle' })
    expect(btn.textContent).toBe('Rolle: Instructor ▾')
  })

  it('renders "+N" overflow when more than 2 values selected', () => {
    render(
      <FilterChipDropdown
        label="Rolle"
        options={ROLE_OPTIONS}
        selected={['instructor', 'student', 'cd']}
        onChange={vi.fn()}
      />,
    )
    const btn = screen.getByRole('button', { name: 'Rolle' })
    expect(btn.textContent).toBe('Rolle: Instructor, Student +1 ▾')
  })

  it('click on chip opens dropdown', () => {
    render(
      <FilterChipDropdown
        label="Rolle"
        options={ROLE_OPTIONS}
        selected={[]}
        onChange={vi.fn()}
      />,
    )
    const btn = screen.getByRole('button', { name: 'Rolle' })
    expect(screen.queryByRole('listbox')).toBeNull()
    fireEvent.click(btn)
    expect(screen.getByRole('listbox')).toBeTruthy()
    expect(btn.getAttribute('aria-expanded')).toBe('true')
  })

  it('checking an option calls onChange with appended array', () => {
    const onChange = vi.fn()
    render(
      <FilterChipDropdown
        label="Rolle"
        options={ROLE_OPTIONS}
        selected={['instructor']}
        onChange={onChange}
      />,
    )
    fireEvent.click(screen.getByRole('button', { name: 'Rolle' }))
    fireEvent.click(screen.getByLabelText('Student'))
    expect(onChange).toHaveBeenCalledWith(['instructor', 'student'])
  })
})
