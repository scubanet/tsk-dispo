/**
 * AddressbookScreen — unified master-detail Adressbuch (Phase F1).
 *
 * URL params:
 *   ?view=<id>     saved view (default: "all")
 *   ?q=<text>      search text
 *   ?contact=<id>  selected contact
 *   ?tab=<tabkey>  active detail tab
 */

import { useState } from 'react'
import { useSearchParams } from 'react-router-dom'
import { useTranslation } from 'react-i18next'
import { useQueryClient } from '@tanstack/react-query'
import {
  MasterDetail,
  ListPane,
  DetailPane,
  SearchInput,
  EmptyState,
  Avatar,
  Icon,
  avatarColor,
} from '@/foundation'
import { type ContactListFilter } from '@/lib/contactQueries'
import { useContactList } from '@/hooks/useContactList'
import type { ContactRole } from '@/types/contacts'
import { ContactDetailPanel, type TabKey } from './ContactDetailPanel'
import { CreateContactSheet } from './CreateContactSheet'

// ── Saved views ───────────────────────────────────────────────────────────

interface SavedView {
  id: string
  labelKey: string
  filter: ContactListFilter
}

const SAVED_VIEWS: SavedView[] = [
  { id: 'all',         labelKey: 'contacts.view_all',         filter: {} },
  { id: 'persons',     labelKey: 'contacts.view_persons',     filter: { kind: 'person' } },
  { id: 'orgs',        labelKey: 'contacts.view_orgs',        filter: { kind: 'organization' } },
  { id: 'students',    labelKey: 'contacts.view_students',    filter: { roles: ['student'] } },
  { id: 'candidates',  labelKey: 'contacts.view_candidates',  filter: { roles: ['candidate'] } },
  { id: 'team',        labelKey: 'contacts.view_team',        filter: { roles: ['instructor'] } },
  { id: 'suppliers',   labelKey: 'contacts.view_suppliers',   filter: { roles: ['supplier'] } },
  { id: 'newsletter',  labelKey: 'contacts.view_newsletter',  filter: { roles: ['newsletter'] } },
]

// ── Role color dots (mirrors RolesBadgeList color mapping) ────────────────

const ROLE_COLORS: Record<ContactRole, string> = {
  instructor:           'var(--brand-blue)',
  student:              'var(--brand-teal)',
  candidate:            'var(--brand-amber)',
  organization_profile: 'var(--brand-purple)',
  cd:                   'var(--brand-deep)',
  owner:                'var(--brand-red)',
  dispatcher:           'var(--brand-pink)',
  newsletter:           'var(--text-tertiary)',
  supplier:             'var(--text-tertiary)',
  partner_rep:          'var(--text-tertiary)',
  authority:            'var(--text-tertiary)',
}

// Significant roles to show as dots (skip internal/system ones)
const DOT_ROLES: ContactRole[] = [
  'instructor', 'student', 'candidate', 'organization_profile',
  'newsletter', 'supplier', 'partner_rep', 'authority',
]

function RoleDots({ roles }: { roles: ContactRole[] }) {
  const visible = roles.filter((r) => DOT_ROLES.includes(r)).slice(0, 4)
  if (visible.length === 0) return null
  return (
    <div style={{ display: 'flex', gap: 3, alignItems: 'center', flexShrink: 0 }}>
      {visible.map((role) => (
        <span
          key={role}
          title={role}
          style={{
            width: 7,
            height: 7,
            borderRadius: '50%',
            background: ROLE_COLORS[role] ?? 'var(--text-tertiary)',
            flexShrink: 0,
          }}
        />
      ))}
    </div>
  )
}

// ── Main component ────────────────────────────────────────────────────────

export function AddressbookScreen() {
  const { t } = useTranslation()
  const [searchParams, setSearchParams] = useSearchParams()

  const viewId = searchParams.get('view') ?? 'all'
  const search = searchParams.get('q') ?? ''
  const contactId = searchParams.get('contact') ?? null
  const tab = (searchParams.get('tab') ?? 'overview') as TabKey

  const currentView = SAVED_VIEWS.find((v) => v.id === viewId) ?? SAVED_VIEWS[0]

  const qc = useQueryClient()
  const filter: ContactListFilter = {
    ...currentView.filter,
    searchText: search || undefined,
  }
  const { data, isFetching: loading } = useContactList(filter, 0, 500)
  const rows = data?.rows ?? []

  const [createOpen, setCreateOpen] = useState(false)

  // ── Param helpers ──────────────────────────────────────────────────────

  function setView(id: string) {
    setSearchParams((prev) => {
      const next = new URLSearchParams(prev)
      next.set('view', id)
      next.delete('contact')
      next.delete('tab')
      return next
    })
  }

  function setSearch(value: string) {
    setSearchParams((prev) => {
      const next = new URLSearchParams(prev)
      if (value) next.set('q', value)
      else next.delete('q')
      return next
    })
  }

  function selectContact(id: string) {
    setSearchParams((prev) => {
      const next = new URLSearchParams(prev)
      next.set('contact', id)
      next.delete('tab')
      return next
    })
  }

  function clearContact() {
    setSearchParams((prev) => {
      const next = new URLSearchParams(prev)
      next.delete('contact')
      next.delete('tab')
      return next
    })
  }

  // ── Render ─────────────────────────────────────────────────────────────

  return (
    <div className="atoll-screen">
      {/* Screen header */}
      <div
        className="atoll-page-header"
        style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '16px 24px 0', flexShrink: 0 }}
      >
        <h1 style={{ fontSize: 22, fontWeight: 700, margin: 0 }}>{t('contacts.addressbook_title')}</h1>
        <button
          type="button"
          className="atoll-btn atoll-btn--primary"
          onClick={() => setCreateOpen(true)}
        >
          <Icon.Plus size={14} /> {t('contacts.new_contact')}
        </button>
      </div>

      <div className="atoll-screen__body atoll-screen__body--full">
        <MasterDetail>
          {/* ── Master / List pane ────────────────────────────── */}
          <ListPane
            toolbar={
              <div style={{ display: 'flex', flexDirection: 'column', gap: 8, padding: '8px 12px 0' }}>
                <SearchInput
                  value={search}
                  onChange={setSearch}
                  ariaLabel={t('contacts.search_aria')}
                  placeholder={t('contacts.search_placeholder')}
                />
                {/* Saved-view chips */}
                <div
                  style={{
                    display: 'flex',
                    gap: 6,
                    overflowX: 'auto',
                    paddingBottom: 4,
                    scrollbarWidth: 'none',
                  }}
                >
                  {SAVED_VIEWS.map((v) => (
                    <button
                      key={v.id}
                      type="button"
                      data-active={v.id === viewId || undefined}
                      onClick={() => setView(v.id)}
                      style={{
                        flexShrink: 0,
                        padding: '3px 10px',
                        borderRadius: 20,
                        border: '1px solid var(--border-primary)',
                        background: v.id === viewId ? 'var(--brand-blue)' : 'transparent',
                        color: v.id === viewId ? '#fff' : 'var(--text-body)',
                        fontSize: 12,
                        fontWeight: 500,
                        cursor: 'pointer',
                        whiteSpace: 'nowrap',
                      }}
                    >
                      {t(v.labelKey)}
                    </button>
                  ))}
                </div>
              </div>
            }
          >
            {loading ? (
              <div style={{ padding: 24, color: 'var(--text-tertiary)', fontSize: 13 }}>{t('contacts.loading')}</div>
            ) : rows.length === 0 ? (
              <EmptyState
                icon={<Icon.Users size={20} />}
                title={t('contacts.no_contacts')}
              />
            ) : (
              <ul className="atoll-people-list">
                {rows.map((r) => (
                  <li key={r.id}>
                    <button
                      type="button"
                      className={`atoll-people-row${contactId === r.id ? ' atoll-people-row--active' : ''}`}
                      onClick={() => selectContact(r.id)}
                    >
                      <Avatar
                        id={r.id}
                        name={r.display_name}
                        size="sm"
                        color={avatarColor(r.id)}
                      />
                      <div className="atoll-people-row__main">
                        <div className="atoll-people-row__name">{r.display_name}</div>
                        <div className="atoll-people-row__sub">
                          {r.primary_email ?? (r.kind === 'organization' ? t('contacts.kind_organisation') : '')}
                        </div>
                      </div>
                      <RoleDots roles={r.roles} />
                    </button>
                  </li>
                ))}
              </ul>
            )}
          </ListPane>

          {/* ── Detail pane ───────────────────────────────────── */}
          <DetailPane>
            {contactId ? (
              <ContactDetailPanel
                contactId={contactId}
                open
                initialTab={tab}
                onClose={clearContact}
              />
            ) : (
              <EmptyState
                icon={<Icon.Users size={24} />}
                title={t('contacts.empty_select_title')}
                body={t('contacts.empty_select_body')}
              />
            )}
          </DetailPane>
        </MasterDetail>
      </div>

      {/* Create sheet */}
      <CreateContactSheet
        open={createOpen}
        onClose={() => setCreateOpen(false)}
        onCreated={(newId) => {
          qc.invalidateQueries({ queryKey: ['contacts'] })
          selectContact(newId)
        }}
      />
    </div>
  )
}
