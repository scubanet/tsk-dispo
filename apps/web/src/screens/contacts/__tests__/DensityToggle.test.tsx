// apps/web/src/screens/contacts/__tests__/DensityToggle.test.tsx
//
// Phase G Phase 4 Task 2 — Tests für den Density-Toggle-Button.
import { describe, it, expect, vi } from 'vitest'
import { render, screen, fireEvent } from '@testing-library/react'
import { DensityToggle } from '../DensityToggle'

describe('DensityToggle', () => {
  it('renders with aria-label "Dichte: Komfortabel" when density=comfortable', () => {
    render(<DensityToggle density="comfortable" onToggle={() => {}} />)
    const btn = screen.getByRole('button', { name: 'Dichte: Komfortabel' })
    expect(btn).toBeTruthy()
    expect(btn.getAttribute('aria-label')).toBe('Dichte: Komfortabel')
  })

  it('renders with aria-label "Dichte: Kompakt" when density=compact', () => {
    render(<DensityToggle density="compact" onToggle={() => {}} />)
    const btn = screen.getByRole('button', { name: 'Dichte: Kompakt' })
    expect(btn).toBeTruthy()
    expect(btn.getAttribute('aria-label')).toBe('Dichte: Kompakt')
  })

  it('calls onToggle when clicked', () => {
    const onToggle = vi.fn()
    render(<DensityToggle density="comfortable" onToggle={onToggle} />)
    fireEvent.click(screen.getByRole('button'))
    expect(onToggle).toHaveBeenCalledTimes(1)
  })
})
