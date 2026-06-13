// apps/web/src/screens/contacts/__tests__/ContactDetailHeader.test.tsx
import { describe, it, expect, vi } from 'vitest'
import { render, screen, fireEvent } from '@testing-library/react'
import { ContactDetailHeader } from '../ContactDetailHeader'

describe('ContactDetailHeader', () => {
  it('renders contact name', () => {
    render(<ContactDetailHeader
      contactId="c1"
      displayName="Hugo Eugster"
      roles={['student']}
      onEdit={vi.fn()}
      onClose={vi.fn()}
    />)
    expect(screen.getByText('Hugo Eugster')).toBeTruthy()
  })

  it('renders role badges', () => {
    render(<ContactDetailHeader
      contactId="c1"
      displayName="Hugo"
      roles={['student', 'candidate']}
      onEdit={vi.fn()}
      onClose={vi.fn()}
    />)
    expect(screen.getByText('student')).toBeTruthy()
    expect(screen.getByText('candidate')).toBeTruthy()
  })

  it('Edit button calls onEdit', () => {
    const onEdit = vi.fn()
    render(<ContactDetailHeader
      contactId="c1"
      displayName="Hugo"
      roles={[]}
      onEdit={onEdit}
      onClose={vi.fn()}
    />)
    fireEvent.click(screen.getByRole('button', { name: /Bearbeiten/i }))
    expect(onEdit).toHaveBeenCalledOnce()
  })

  it('Close button calls onClose', () => {
    const onClose = vi.fn()
    render(<ContactDetailHeader
      contactId="c1"
      displayName="Hugo"
      roles={[]}
      onEdit={vi.fn()}
      onClose={onClose}
    />)
    fireEvent.click(screen.getByRole('button', { name: /Schliessen/i }))
    expect(onClose).toHaveBeenCalledOnce()
  })

  it('renders ⋯ button and calls onMore when provided', () => {
    const onMore = vi.fn()
    render(<ContactDetailHeader
      contactId="c1"
      displayName="Hugo"
      roles={[]}
      onEdit={vi.fn()}
      onClose={vi.fn()}
      onMore={onMore}
    />)
    fireEvent.click(screen.getByRole('button', { name: 'Mehr' }))
    expect(onMore).toHaveBeenCalledOnce()
  })

  it('omits ⋯ button when onMore is not provided', () => {
    render(<ContactDetailHeader
      contactId="c1"
      displayName="Hugo"
      roles={[]}
      onEdit={vi.fn()}
      onClose={vi.fn()}
    />)
    expect(screen.queryByRole('button', { name: 'Mehr' })).toBeNull()
  })

  it('rendert Avatar mit displayName als aria-label', () => {
    render(<ContactDetailHeader
      contactId="c1"
      displayName="Hugo Eugster"
      roles={[]}
      onEdit={vi.fn()}
      onClose={vi.fn()}
    />)
    // Avatar uses role="img" with aria-label = name
    expect(screen.getByRole('img', { name: 'Hugo Eugster' })).toBeTruthy()
  })
})
