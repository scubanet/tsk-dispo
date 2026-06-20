import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, screen, waitFor, act, fireEvent } from '@testing-library/react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { MemoryRouter } from 'react-router-dom'
import { ContactDetailPanelV2 } from '../ContactDetailPanelV2'

// ContactEditSheet zieht zur Render-Zeit OverviewTab inkl. Foundation-Pattern
// hinein — für die V2-Panel-Tests reicht uns ein Mock, der nur signalisiert
// ob das Sheet "open" ist.
vi.mock('../ContactEditSheet', () => ({
  ContactEditSheet: ({ open, contactId }: { open: boolean; contactId: string | null }) =>
    open ? <div data-testid="contact-edit-sheet">edit:{contactId}</div> : null,
}))

// Mock Supabase: returns contact summary + empty timeline + properties fetch
vi.mock('@/lib/supabase', () => {
  // Contact summary / properties fetch:
  const singleContact = vi.fn().mockResolvedValue({
    data: {
      id: 'c1',
      kind: 'person',
      display_name: 'Hugo Eugster',
      first_name: 'Hugo',
      last_name: 'Eugster',
      birth_date: null,
      primary_email: null,
      emails: [],
      phones: [], addresses: [], languages: [],
      roles: [],
      source: null,
      created_at: '2026-01-01T00:00:00Z',
      updated_at: '2026-05-27T00:00:00Z',
      owner_id: null,
      tags: [],
      instructor: null,
      student: null,
      organization: null,
      balance: null,
    },
    error: null,
  })
  // Sidecar fetches (getContactWithSidecars loads instructor/student/org).
  const sidecarNull = vi.fn().mockResolvedValue({ data: null, error: null })
  // Timeline fetch:
  const builder: Record<string, unknown> = {}
  const limit = vi.fn().mockReturnValue(builder)
  const order2 = vi.fn().mockReturnValue(builder)
  const order1 = vi.fn().mockReturnValue({ order: order2 })
  builder.in = vi.fn().mockReturnValue(builder)
  builder.gte = vi.fn().mockReturnValue(builder)
  builder.lte = vi.fn().mockReturnValue(builder)
  builder.or = vi.fn().mockReturnValue(builder)
  builder.limit = limit
  builder.then = (resolve: (v: { data: unknown; error: null }) => unknown) => resolve({ data: [], error: null })

  const fromMock = vi.fn().mockImplementation((table: string) => {
    if (table === 'contacts') {
      return {
        select: vi.fn().mockReturnValue({
          eq: vi.fn().mockReturnValue({ single: singleContact, maybeSingle: singleContact }),
        }),
      }
    }
    if (table === 'contact_instructor' || table === 'contact_student' || table === 'contact_organization') {
      return {
        select: vi.fn().mockReturnValue({
          eq: vi.fn().mockReturnValue({ maybeSingle: sidecarNull }),
        }),
      }
    }
    // Default: timeline-View
    return {
      select: vi.fn().mockReturnValue({
        eq: vi.fn().mockReturnValue({ order: order1 }),
      }),
    }
  })
  return { supabase: { from: fromMock } }
})

function wrapper({ children }: { children: React.ReactNode }) {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } })
  return (
    <MemoryRouter>
      <QueryClientProvider client={qc}>{children}</QueryClientProvider>
    </MemoryRouter>
  )
}

describe('ContactDetailPanelV2', () => {
  beforeEach(() => {
    window.localStorage.clear()
  })

  it('renders 3-pane shell with header + timeline + sidebar (expanded by default)', async () => {
    render(<ContactDetailPanelV2 contactId="c1" onClose={vi.fn()} />, { wrapper })
    // Header has the close button
    await waitFor(() => expect(screen.queryByLabelText(/Schliessen/i)).toBeTruthy())
    // Timeline shell appears (composer segmented control button visible).
    expect(screen.getAllByRole('button', { name: 'Notiz' }).length).toBeGreaterThanOrEqual(1)
    // Sidebar present, open by default
    const sidebar = screen.getByTestId('properties-sidebar')
    expect(sidebar).toBeTruthy()
    expect(sidebar.getAttribute('data-open')).toBe('true')
  })

  it('toggles sidebar collapsed/expanded on click', async () => {
    render(<ContactDetailPanelV2 contactId="c1" onClose={vi.fn()} />, { wrapper })
    await waitFor(() => expect(screen.getByTestId('properties-sidebar')).toBeTruthy())
    const toggle = screen.getByTestId('sidebar-toggle')
    const sidebar = screen.getByTestId('properties-sidebar')
    expect(sidebar.getAttribute('data-open')).toBe('true')
    act(() => { toggle.click() })
    expect(sidebar.getAttribute('data-open')).toBe('false')
    act(() => { toggle.click() })
    expect(sidebar.getAttribute('data-open')).toBe('true')
  })

  it('persists toggle state in localStorage', async () => {
    render(<ContactDetailPanelV2 contactId="c1" onClose={vi.fn()} />, { wrapper })
    await waitFor(() => expect(screen.getByTestId('sidebar-toggle')).toBeTruthy())
    act(() => { screen.getByTestId('sidebar-toggle').click() })
    expect(window.localStorage.getItem('contactDetail.sidebarOpen')).toBe('false')
  })

  it('reads initial sidebar state from localStorage', async () => {
    window.localStorage.setItem('contactDetail.sidebarOpen', 'false')
    render(<ContactDetailPanelV2 contactId="c1" onClose={vi.fn()} />, { wrapper })
    await waitFor(() => expect(screen.getByTestId('properties-sidebar')).toBeTruthy())
    const sidebar = screen.getByTestId('properties-sidebar')
    expect(sidebar.getAttribute('data-open')).toBe('false')
  })

  it('⋯-Menü ist erreichbar und öffnet den Rollen-Manager-Eintrag', async () => {
    render(<ContactDetailPanelV2 contactId="c1" onClose={vi.fn()} />, { wrapper })
    // ⋯-Trigger im Header (vorher fehlend → Rollen unsetzbar):
    const moreBtn = await screen.findByRole('button', { name: 'Mehr' })
    fireEvent.click(moreBtn)
    // ContactMoreMenu erscheint …
    expect(screen.getByRole('menu')).toBeTruthy()
    // … inklusive "Rollen verwalten" (i18n-Key, da kein Provider im Test):
    expect(
      screen.getByRole('menuitem', { name: /action_manage_roles|Manage roles|Rollen verwalten/i }),
    ).toBeTruthy()
  })

  it('Klick auf Bearbeiten öffnet das ContactEditSheet', async () => {
    render(<ContactDetailPanelV2 contactId="c1" onClose={vi.fn()} />, { wrapper })
    // Sheet zunächst nicht offen:
    expect(screen.queryByTestId('contact-edit-sheet')).toBeNull()
    // Bearbeiten-Button im Header klicken:
    const editBtn = await screen.findByRole('button', { name: /Bearbeiten/i })
    fireEvent.click(editBtn)
    // Sheet ist jetzt offen, mit korrekter contactId:
    const sheet = screen.getByTestId('contact-edit-sheet')
    expect(sheet).toBeTruthy()
    expect(sheet.textContent).toContain('edit:c1')
  })
})
