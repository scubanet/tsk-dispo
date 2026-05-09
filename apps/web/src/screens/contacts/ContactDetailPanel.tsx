/**
 * ContactDetailPanel — universal contact detail panel with 11 adaptive tabs.
 *
 * Tabs show/hide based on contact.roles and contact.kind.
 */

import { useEffect, useState, useCallback } from 'react'
import { Drawer } from '@/foundation/layouts/Drawer'
import { Tabs } from '@/foundation/layouts/Tabs'
import type { TabDefinition } from '@/foundation/layouts/Tabs'
import { ContactHeader } from '@/foundation/compounds/ContactHeader'
import { getContactWithSidecars } from '@/lib/contactQueries'
import type { ContactWithSidecars } from '@/types/contacts'
import {
  OverviewTab,
  RelationshipsTab,
  ActivityTab,
  NotesAndDocsTab,
  StudentTab,
  CoursesTab,
  SaldoTab,
  SkillsTab,
  AvailabilityTab,
  OrgMembersTab,
  ContractTab,
} from './tabs'

// ── Types ────────────────────────────────────────────────────────────────

export type TabKey =
  | 'overview'
  | 'relationships'
  | 'activity'
  | 'notes'
  | 'student'
  | 'courses'
  | 'saldo'
  | 'skills'
  | 'availability'
  | 'org_members'
  | 'contract'

const TAB_LABELS: Record<TabKey, string> = {
  overview: 'Übersicht',
  relationships: 'Beziehungen',
  activity: 'Aktivität',
  notes: 'Notizen',
  student: 'Schüler',
  courses: 'Kurse',
  saldo: 'Saldo',
  skills: 'Skills',
  availability: 'Verfügbarkeit',
  org_members: 'Mitglieder',
  contract: 'Vertrag',
}

// ── Visibility logic ─────────────────────────────────────────────────────

function computeVisibleTabs(contact: ContactWithSidecars): TabKey[] {
  const tabs: TabKey[] = ['overview', 'relationships', 'activity', 'notes']
  const roles = contact.roles

  if (roles.includes('student') || roles.includes('candidate')) tabs.push('student')
  if (roles.includes('instructor') || roles.includes('student') || roles.includes('candidate')) tabs.push('courses')
  if (roles.includes('instructor')) {
    tabs.push('saldo')
    tabs.push('skills')
    tabs.push('availability')
  }
  if (contact.kind === 'organization') {
    tabs.push('org_members')
    const orgKind = contact.organization?.org_kind
    if (orgKind && ['tauchschule', 'partner', 'lieferant'].includes(orgKind)) {
      tabs.push('contract')
    }
  }

  return tabs
}

// ── Props ────────────────────────────────────────────────────────────────

interface Props {
  contactId: string | null
  open: boolean
  initialTab?: TabKey
  onClose: () => void
  onSelectContact?: (id: string) => void
}

// ── Component ────────────────────────────────────────────────────────────

export function ContactDetailPanel({
  contactId,
  open,
  initialTab,
  onClose,
  onSelectContact,
}: Props) {
  const [contact, setContact] = useState<ContactWithSidecars | null>(null)
  const [loading, setLoading] = useState(false)
  const [loadError, setLoadError] = useState<string | null>(null)
  const [activeTab, setActiveTab] = useState<TabKey>(initialTab ?? 'overview')

  // Reset tab when contactId changes
  useEffect(() => {
    setActiveTab(initialTab ?? 'overview')
  }, [contactId, initialTab])

  const load = useCallback(() => {
    if (!contactId || !open) return
    setLoading(true)
    setLoadError(null)
    getContactWithSidecars(contactId)
      .then(setContact)
      .catch((err) => setLoadError(err instanceof Error ? err.message : 'Fehler'))
      .finally(() => setLoading(false))
  }, [contactId, open])

  useEffect(() => { load() }, [load])

  const visibleTabs: TabKey[] = contact ? computeVisibleTabs(contact) : ['overview']
  const safeTab = visibleTabs.includes(activeTab) ? activeTab : visibleTabs[0]

  const tabDefs: TabDefinition<TabKey>[] = visibleTabs.map((key) => ({
    id: key,
    label: TAB_LABELS[key],
  }))

  function renderPanels(c: ContactWithSidecars): Record<TabKey, React.ReactNode> {
    return {
      overview: <OverviewTab contact={c} onUpdated={load} />,
      relationships: <RelationshipsTab contactId={c.id} />,
      activity: <ActivityTab contactId={c.id} />,
      notes: <NotesAndDocsTab />,
      student: <StudentTab contact={c} onUpdated={load} />,
      courses: <CoursesTab contactId={c.id} roles={c.roles} />,
      saldo: <SaldoTab contactId={c.id} onUpdated={load} />,
      skills: <SkillsTab contactId={c.id} />,
      availability: <AvailabilityTab contactId={c.id} />,
      org_members: <OrgMembersTab orgId={c.id} onSelectContact={onSelectContact} />,
      contract: <ContractTab contact={c} onUpdated={load} />,
    }
  }

  const drawerWidth = typeof window !== 'undefined' ? Math.round(window.innerWidth * 0.6) : 900

  return (
    <Drawer
      open={open}
      onClose={onClose}
      width={drawerWidth}
      ariaLabel="Kontakt Details"
    >
      {loading && (
        <div className="contact-detail__loading">Lade Kontakt…</div>
      )}

      {loadError && (
        <div className="contact-detail__error">
          Fehler beim Laden: {loadError}
        </div>
      )}

      {contact && !loading && (
        <div className="contact-detail__body">
          <ContactHeader
            contact={contact}
            onMoreClick={() => {
              // Phase I: hook up More-Menu
            }}
          />
          <Tabs<TabKey>
            tabs={tabDefs}
            active={safeTab}
            onChange={setActiveTab}
            ariaLabel="Kontakt-Tabs"
            panels={renderPanels(contact)}
          />
        </div>
      )}
    </Drawer>
  )
}
