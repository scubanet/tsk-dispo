// apps/web/src/screens/contacts/__tests__/ContactEditSheet.test.tsx
//
// Phase G — ContactEditSheet schliesst die V2-Adress-Lücke. Der Sheet wickelt
// die Legacy-`OverviewTab` in einen Foundation-`Drawer` und ist offen-gating
// durch das `open`-Prop.
import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, screen, fireEvent } from '@testing-library/react'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { ContactEditSheet } from '../ContactEditSheet'
import type { ContactWithSidecars } from '@/types/contacts'

// ── useContactWithSidecars-Mock ───────────────────────────────────────────
// Wir kontrollieren das Hook-Resultat pro Test über `setMockContact`.
let mockContact: ContactWithSidecars | null = null

vi.mock('@/hooks/useContactWithSidecars', () => ({
  useContactWithSidecars: () => ({
    data: mockContact,
    isLoading: mockContact === null,
    error: null,
  }),
}))

// OverviewTab triggert beim Mount keinen Schreibzugriff, aber lädt aus
// `@/lib/contactQueries`. Wir stubben das Modul, damit kein Supabase-Aufruf
// passiert. Die OverviewTab-Komponente selber wird nicht gemockt – wir
// wollen ihren echten Render-Output prüfen.
vi.mock('@/lib/contactQueries', () => ({
  updateContactField: vi.fn().mockResolvedValue(undefined),
}))

const SAMPLE_CONTACT: ContactWithSidecars = {
  id: 'c1',
  kind: 'person',
  first_name: 'Hugo',
  last_name: 'Eugster',
  display_name: 'Hugo Eugster',
  legal_name: null,
  trading_name: null,
  birth_date: null,
  gender: null,
  primary_email: null,
  emails: [],
  phones: [],
  addresses: [],
  languages: [],
  roles: ['student'],
  tags: [],
  notes: null,
  owner_id: null,
  consent_marketing: false,
  consent_marketing_at: null,
  consent_marketing_source: null,
  source: null,
  archived_at: null,
  merged_into_id: null,
  created_at: '2026-01-01T00:00:00Z',
  updated_at: '2026-05-27T00:00:00Z',
  created_by: null,
  instructor: null,
  student: null,
  organization: null,
} as unknown as ContactWithSidecars

function wrapper({ children }: { children: React.ReactNode }) {
  const qc = new QueryClient({ defaultOptions: { queries: { retry: false } } })
  return <QueryClientProvider client={qc}>{children}</QueryClientProvider>
}

describe('ContactEditSheet', () => {
  beforeEach(() => {
    mockContact = SAMPLE_CONTACT
  })

  it('rendert nichts, wenn open=false', () => {
    const { container } = render(
      <ContactEditSheet contactId="c1" open={false} onClose={vi.fn()} />,
      { wrapper },
    )
    // Drawer schaltet bei open=false komplett ab.
    expect(container.querySelector('.atoll-drawer-root')).toBeNull()
    expect(screen.queryByText(/bearbeiten/i)).toBeNull()
  })

  it('rendert Drawer mit Titel "{display_name} bearbeiten" wenn open=true', () => {
    render(<ContactEditSheet contactId="c1" open onClose={vi.fn()} />, { wrapper })
    expect(screen.getByText(/Hugo Eugster bearbeiten/i)).toBeTruthy()
    // Drawer-Root vorhanden:
    expect(document.querySelector('.atoll-drawer-root')).not.toBeNull()
  })

  it('enthält die OverviewTab-Stammdaten-Section', () => {
    render(<ContactEditSheet contactId="c1" open onClose={vi.fn()} />, { wrapper })
    // OverviewTab rendert eine .contact-section mit __title-Heading. Wir
    // suchen direkt das Element — i18n liefert in Tests den Key zurück,
    // also matched „contacts.section_master" ODER „Stammdaten".
    const sectionTitle = document.querySelector('.contact-section__title')
    expect(sectionTitle).not.toBeNull()
    expect(sectionTitle?.textContent).toMatch(/section_master|Stammdaten/i)
  })

  it('zeigt Loading-State, wenn contact noch nicht geladen ist', () => {
    mockContact = null
    render(<ContactEditSheet contactId="c1" open onClose={vi.fn()} />, { wrapper })
    expect(screen.getByTestId('contact-edit-loading')).toBeTruthy()
  })

  it('Close-Button im Drawer-Header ruft onClose()', () => {
    const onClose = vi.fn()
    render(<ContactEditSheet contactId="c1" open onClose={onClose} />, { wrapper })
    const closeBtn = screen.getByRole('button', { name: /Schliessen/i })
    fireEvent.click(closeBtn)
    expect(onClose).toHaveBeenCalledOnce()
  })
})
