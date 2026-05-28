/**
 * ContactDetailPanelLegacy — pre-V2 detail panel with 12 adaptive tabs.
 *
 * Extracted from ContactDetailPanel.tsx in Phase G Phase 3 (Task 16) so that
 * ContactDetailPanel.tsx can be a thin flag-dispatcher with zero hooks at its
 * top level (no Rules-of-Hooks risk if the crm_v2 flag flips at runtime).
 *
 * Tabs show/hide based on contact.roles and contact.kind.
 */

import { useEffect, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { useQueryClient } from '@tanstack/react-query'
import { Drawer } from '@/foundation/layouts/Drawer'
import { Tabs } from '@/foundation/layouts/Tabs'
import type { TabDefinition } from '@/foundation/layouts/Tabs'
import { ContactHeader } from '@/foundation/patterns/ContactHeader'
import { useContactWithSidecars } from '@/hooks/useContactWithSidecars'
import type { ContactWithSidecars } from '@/types/contacts'
import {
  OverviewTab,
  RelationshipsTab,
  CommunicationsTab,
  ActivityTab,
  NotesAndDocsTab,
  StudentTab,
  InstructorTab,
  CoursesTab,
  SaldoTab,
  SkillsTab,
  AvailabilityTab,
  OrgMembersTab,
  ContractTab,
} from './tabs'
import { AuditHistoryTab } from './tabs/AuditHistoryTab'
import { ContactMoreMenu } from './ContactMoreMenu'

// ── Types ────────────────────────────────────────────────────────────────

export type TabKey =
  | 'overview'
  | 'relationships'
  | 'communications'
  | 'activity'
  | 'notes'
  | 'student'
  | 'instructor'
  | 'courses'
  | 'saldo'
  | 'skills'
  | 'availability'
  | 'org_members'
  | 'contract'
  | 'audit'

const TAB_LABEL_KEYS: Record<TabKey, string> = {
  overview: 'contacts.tab_overview',
  relationships: 'contacts.tab_relationships',
  communications: 'contacts.tab_communications',
  activity: 'contacts.tab_activity',
  notes: 'contacts.tab_notes',
  student: 'contacts.tab_student',
  instructor: 'contacts.tab_instructor',
  courses: 'contacts.tab_courses',
  saldo: 'contacts.tab_saldo',
  skills: 'contacts.tab_skills',
  availability: 'contacts.tab_availability',
  org_members: 'contacts.tab_org_members',
  contract: 'contacts.tab_contract',
  audit: 'contacts.tab_audit',
}

// ── Visibility logic ─────────────────────────────────────────────────────

/**
 * GL-004 H5: Aktivität + Audit-History stay in the TabKey union and in
 * `computeVisibleTabs` (so safeTab fallback + deep-links + renderPanels()
 * still work), but they're filtered out of the rendered strip via
 * `HIDDEN_STRIP_TABS`. The More-menu surfaces them explicitly.
 */
const HIDDEN_STRIP_TABS: TabKey[] = ['activity', 'audit']

function computeVisibleTabs(contact: ContactWithSidecars): TabKey[] {
  const tabs: TabKey[] = ['overview', 'relationships', 'communications', 'activity', 'notes']
  const roles = contact.roles

  if (roles.includes('student') || roles.includes('candidate')) tabs.push('student')
  if (roles.includes('instructor')) tabs.push('instructor')
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

  tabs.push('audit')
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

export function ContactDetailPanelLegacy({
  contactId,
  open,
  initialTab,
  onClose,
  onSelectContact,
}: Props) {
  const { t } = useTranslation()
  const qc = useQueryClient()
  const { data: contact = null, isLoading: loading, error } = useContactWithSidecars(
    contactId,
    open,
  )
  const loadError = error instanceof Error ? error.message : null
  const [activeTab, setActiveTab] = useState<TabKey>(initialTab ?? 'overview')
  const [showMore, setShowMore] = useState(false)

  // Reset tab when contactId changes
  useEffect(() => {
    setActiveTab(initialTab ?? 'overview')
  }, [contactId, initialTab])

  // Tabs receive `load` as their refresh callback. We invalidate just this
  // contact's sidecar query so the panel refetches, while leaving every
  // other cached contact alone.
  function load() {
    if (!contactId) return
    qc.invalidateQueries({ queryKey: ['contact', 'withSidecars', contactId] })
  }

  const visibleTabs: TabKey[] = contact ? computeVisibleTabs(contact) : ['overview']
  const safeTab = visibleTabs.includes(activeTab) ? activeTab : visibleTabs[0]

  // Pass the full tab set to <Tabs> with `hiddenInStrip` so panels still
  // render for activity/audit when activeTab is set to them via the More-menu.
  const tabDefs: TabDefinition<TabKey>[] = visibleTabs.map((key) => ({
    id: key,
    label: t(TAB_LABEL_KEYS[key]),
  }))

  function renderPanels(c: ContactWithSidecars): Record<TabKey, React.ReactNode> {
    return {
      overview: <OverviewTab contact={c} onUpdated={load} />,
      relationships: <RelationshipsTab contactId={c.id} />,
      communications: <CommunicationsTab contactId={c.id} />,
      activity: <ActivityTab contactId={c.id} />,
      notes: <NotesAndDocsTab />,
      student: <StudentTab contact={c} onUpdated={load} />,
      instructor: <InstructorTab contact={c} onUpdated={load} />,
      courses: <CoursesTab contactId={c.id} roles={c.roles} />,
      saldo: <SaldoTab contactId={c.id} onUpdated={load} />,
      skills: <SkillsTab contactId={c.id} />,
      availability: <AvailabilityTab contactId={c.id} />,
      org_members: <OrgMembersTab orgId={c.id} onSelectContact={onSelectContact} />,
      contract: <ContractTab contact={c} onUpdated={load} />,
      audit: <AuditHistoryTab contactId={c.id} />,
    }
  }

  const drawerWidth = typeof window !== 'undefined' ? Math.round(window.innerWidth * 0.6) : 900

  return (
    <Drawer
      open={open}
      onClose={onClose}
      width={drawerWidth}
      ariaLabel={t('contacts.detail_aria')}
    >
      {loading && (
        <div className="contact-detail__loading">{t('contacts.loading_contact')}</div>
      )}

      {loadError && (
        <div className="contact-detail__error">
          {t('contacts.error_loading', { msg: loadError })}
        </div>
      )}

      {contact && !loading && (
        <div className="contact-detail__body">
          <div style={{ position: 'relative' }}>
            <ContactHeader
              contact={contact}
              onMoreClick={() => setShowMore(true)}
            />
            {showMore && (
              <ContactMoreMenu
                contact={contact}
                onChanged={load}
                onShowActivity={() => { setActiveTab('activity'); setShowMore(false) }}
                onShowAudit={() => { setActiveTab('audit'); setShowMore(false) }}
                onClosed={() => setShowMore(false)}
              />
            )}
          </div>
          <Tabs<TabKey>
            tabs={tabDefs}
            active={safeTab}
            onChange={setActiveTab}
            ariaLabel={t('contacts.tabs_aria')}
            panels={renderPanels(contact)}
            hiddenInStrip={HIDDEN_STRIP_TABS}
          />
        </div>
      )}
    </Drawer>
  )
}
