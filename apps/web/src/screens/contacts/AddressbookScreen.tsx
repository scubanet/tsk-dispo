/**
 * AddressbookScreen — unified master-detail Adressbuch (Phase F1).
 *
 * URL params:
 *   ?view=<id>     saved view (default: "all")
 *   ?q=<text>      search text
 *   ?contact=<id>  selected contact
 *   ?tab=<tabkey>  active detail tab
 */

import { useEffect, useMemo, useState } from 'react'
import { useSearchParams } from 'react-router-dom'
import { useTranslation } from 'react-i18next'
import { useQueryClient } from '@tanstack/react-query'
import {
  MasterDetail,
  ListPane,
  DetailPane,
  SearchInput,
  EmptyState,
  Icon,
} from '@/foundation'
import { type ContactListFilter } from '@/lib/contactQueries'
import { useContactList } from '@/hooks/useContactList'
import { useAddressbookDensity } from '@/hooks/useAddressbookDensity'
import { useAddressbookColumns } from '@/hooks/useAddressbookColumns'
import { useAddressbookSort } from '@/hooks/useAddressbookSort'
import { useBulkSelection } from '@/hooks/useBulkSelection'
import {
  useAddressbookFilter,
  type AddressbookFilterState,
} from '@/hooks/useAddressbookFilter'
import { ContactDetailPanel, type TabKey } from './ContactDetailPanel'
import { CreateContactSheet } from './CreateContactSheet'
import { AddressbookTable } from './AddressbookTable'
import { CompactContactList } from './CompactContactList'
import { DensityToggle } from './DensityToggle'
import { ColumnPicker } from './ColumnPicker'
import { AddressbookFilterBar } from './AddressbookFilterBar'
import { AddressbookBulkActionBar } from './AddressbookBulkActionBar'

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
  const { sort, onHeaderClick } = useAddressbookSort()
  const {
    filter: addressFilter,
    setFilter: setAddressFilter,
    clear: clearAddressFilter,
  } = useAddressbookFilter()

  // Merge der drei Filter-Quellen (Saved-View + Search + FilterBar) zu einer
  // ContactListFilter. Explizite FilterBar-Selektionen überschreiben
  // Saved-View-Defaults pro Feld (AND-kombinierte Filter).
  //
  // Achtung: saldo_bucket/last_contact_bucket sind im Hook-Type singular
  // (positive | negative | zero). Wir nehmen den ersten Eintrag aus dem
  // Array, mehrere selektierte Buckets sind ein Carry-Forward für Phase 4.x.
  const filter: ContactListFilter = {
    ...currentView.filter,
    searchText: search || undefined,
    sort: sort.length > 0 ? sort : undefined,
    roles:
      addressFilter.roles.length > 0
        ? addressFilter.roles
        : currentView.filter.roles,
    tags: addressFilter.tags.length > 0 ? addressFilter.tags : undefined,
    pipeline_stages:
      addressFilter.pipeline_stages.length > 0
        ? addressFilter.pipeline_stages
        : undefined,
    languages:
      addressFilter.languages.length > 0
        ? addressFilter.languages
        : undefined,
    sources:
      addressFilter.sources.length > 0 ? addressFilter.sources : undefined,
    saldo_bucket: addressFilter.saldo_buckets[0],
    last_contact_bucket: addressFilter.last_contact_buckets[0],
    archivedOnly: addressFilter.status.includes('archived'),
  }
  const { data, isFetching: loading } = useContactList(filter, 0, 500)
  const rows = data?.rows ?? []

  const [createOpen, setCreateOpen] = useState(false)
  const [density, , toggleDensity] = useAddressbookDensity()
  const { visibleIds, toggle: toggleColumn, reset: resetColumns } = useAddressbookColumns()

  // ── Bulk-Selection (Phase G Phase 4 T6) ────────────────────────────────
  // currentIds in stabiler Referenz, damit der useBulkSelection-Effect nur
  // bei tatsächlichem Wechsel der ID-Liste feuert.
  const currentIds = useMemo(() => rows.map((r) => r.id), [rows])
  const bulk = useBulkSelection(currentIds)

  // Master-detail-Mode (contact param gesetzt) zeigt CompactContactList ohne
  // Checkboxen — die Bulk-Selektion ergibt dort keinen Sinn, also wegwerfen.
  useEffect(() => {
    if (contactId !== null && bulk.selected.size > 0) {
      bulk.clear()
    }
  }, [contactId, bulk])

  function handleToggleAll() {
    if (bulk.allSelected) {
      bulk.clear()
      return
    }
    if (currentIds.length > 100) {
      const ok =
        typeof window === 'undefined'
          ? true
          : window.confirm(
              `${currentIds.length} Treffer auswählen?`,
            )
      if (!ok) return
    }
    bulk.selectAll()
  }

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

  // Shared toolbar — appears identical in full-width AND master-detail mode.
  const toolbar = (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--space-2)', padding: '8px 12px 0' }}>
      <SearchInput
        value={search}
        onChange={setSearch}
        ariaLabel={t('contacts.search_aria')}
        placeholder={t('contacts.search_placeholder')}
      />
      {/* Saved-view chips. GL-004 M4: right-edge fade hints at
          horizontal scroll when more chips overflow the container.
          Density-Toggle sitzt rechts daneben, außerhalb der scroll-area. */}
      <div style={{ display: 'flex', alignItems: 'center', gap: 8, minWidth: 0 }}>
        <div
          style={{
            display: 'flex',
            gap: 6,
            overflowX: 'auto',
            paddingBottom: 'var(--space-1)',
            scrollbarWidth: 'none',
            maskImage: 'linear-gradient(to right, black calc(100% - 24px), transparent)',
            WebkitMaskImage: 'linear-gradient(to right, black calc(100% - 24px), transparent)',
            flex: 1,
            minWidth: 0,
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
                borderRadius: 'var(--radius-pill)',
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
        <DensityToggle density={density} onToggle={toggleDensity} />
        <ColumnPicker
          visibleIds={visibleIds}
          onToggle={toggleColumn}
          onReset={resetColumns}
        />
      </div>
      <AddressbookFilterBar
        filter={addressFilter}
        onChange={(key, values) => {
          // setFilter ist Partial<AddressbookFilterState> — wir lassen TS via
          // generic key/values eine valide Combo erzwingen, dann übergeben
          // wir an den merging setFilter.
          setAddressFilter({ [key]: values } as Partial<AddressbookFilterState>)
        }}
        onClear={clearAddressFilter}
      />
    </div>
  )

  const loadingNode = (
    <div style={{ padding: 'var(--space-6)', color: 'var(--text-tertiary)', fontSize: 13 }}>{t('contacts.loading')}</div>
  )
  const emptyNode = (
    <EmptyState icon={<Icon.Users size={20} />} title={t('contacts.no_contacts')} />
  )

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
        {contactId === null ? (
          /* ── Full-width table mode ──────────────────────────
             Kein DetailPane sichtbar. AddressbookTable bekommt die
             ganze Bühne und kann ihre Spalten atmen lassen. */
          <div
            data-testid="addressbook-fullwidth"
            style={{
              display: 'flex',
              flexDirection: 'column',
              flex: 1,
              minHeight: 0,
              background: 'var(--bg-card)',
            }}
          >
            <div style={{ flexShrink: 0 }}>{toolbar}</div>
            <div style={{ flex: 1, minHeight: 0, overflowY: 'auto', padding: '0 12px 12px' }}>
              {loading ? loadingNode : rows.length === 0 ? emptyNode : (
                <AddressbookTable
                  rows={rows}
                  selectedId={null}
                  onSelect={selectContact}
                  density={density}
                  columns={visibleIds}
                  sort={sort}
                  onHeaderClick={onHeaderClick}
                  selected={bulk.selected}
                  isSelected={bulk.isSelected}
                  onToggleRow={bulk.toggle}
                  onToggleAll={handleToggleAll}
                  allSelected={bulk.allSelected}
                  someSelected={bulk.someSelected}
                />
              )}
            </div>
            {bulk.selected.size > 0 && (
              <AddressbookBulkActionBar
                selectedIds={Array.from(bulk.selected)}
                onClear={bulk.clear}
              />
            )}
          </div>
        ) : (
          /* ── Master-detail mode ─────────────────────────────
             Kompakte Single-Column-Liste + DetailPane. */
          <MasterDetail>
            <ListPane toolbar={toolbar}>
              {loading ? loadingNode : rows.length === 0 ? emptyNode : (
                <CompactContactList
                  rows={rows}
                  selectedId={contactId}
                  onSelect={selectContact}
                />
              )}
            </ListPane>

            <DetailPane>
              <ContactDetailPanel
                contactId={contactId}
                open
                initialTab={tab}
                onClose={clearContact}
              />
            </DetailPane>
          </MasterDetail>
        )}
      </div>

      {/* Create sheet — single mount works in both modes */}
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
