/**
 * AtollCard Card-Inbox screen — owner/CD-only view of incoming card_leads.
 *
 * URL params:
 *   ?view=<id>       saved view (default: 'new')
 *   ?q=<text>        search
 *   ?lead=<id>       selected lead (deep-link target from iOS)
 */
import { useEffect } from 'react'
import { useSearchParams } from 'react-router-dom'
import {
  MasterDetail, ListPane, DetailPane, SearchInput, EmptyState, Loader,
} from '@/foundation'
import { useCardLeads } from '@/hooks/useCardLeads'
import { useCardLeadRealtime } from '@/hooks/useCardLeadRealtime'
import { useUpdateLeadStatus } from '@/hooks/useCardLeadActions'
import { CardLeadRow } from '@/components/CardLeadRow'
import { CardInboxDetailPanel } from './CardInboxDetailPanel'
import type { CardLeadViewId } from '@/lib/cardLeadQueries'

const SAVED_VIEWS: Array<{ id: CardLeadViewId; label: string }> = [
  { id: 'all',         label: 'Alle' },
  { id: 'new',         label: 'Neu' },
  { id: 'in_progress', label: 'In Bearbeitung' },
  { id: 'imported',    label: 'Importiert' },
  { id: 'archived',    label: 'Archiv' },
  { id: 'spam',        label: 'Spam' },
]

export function CardInboxScreen() {
  const [params, setParams] = useSearchParams()
  const view   = (params.get('view') ?? 'new') as CardLeadViewId
  const search = params.get('q') ?? ''
  const leadId = params.get('lead')

  const { data: leads = [], isFetching } = useCardLeads(view, search)
  const updateStatus = useUpdateLeadStatus()

  useCardLeadRealtime()

  // Auto-set status='opened' when a lead is opened for the first time
  const selectedLead = leads.find((l) => l.id === leadId)
  useEffect(() => {
    if (selectedLead && selectedLead.status === 'new') {
      updateStatus.mutate({ id: selectedLead.id, status: 'opened' })
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [selectedLead?.id])

  function setView(id: CardLeadViewId) {
    setParams((prev) => {
      const next = new URLSearchParams(prev)
      next.set('view', id)
      next.delete('lead')
      return next
    })
  }

  function setSearch(value: string) {
    setParams((prev) => {
      const next = new URLSearchParams(prev)
      if (value) next.set('q', value); else next.delete('q')
      return next
    })
  }

  function selectLead(id: string) {
    setParams((prev) => {
      const next = new URLSearchParams(prev)
      next.set('lead', id)
      return next
    })
  }

  function clearLead() {
    setParams((prev) => {
      const next = new URLSearchParams(prev)
      next.delete('lead')
      return next
    })
  }

  return (
    <div className="atoll-screen">
      <div
        className="atoll-page-header"
        style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between',
                 padding: '16px 24px 0', flexShrink: 0 }}
      >
        <h1 style={{ fontSize: 22, fontWeight: 700, margin: 0 }}>Card-Inbox</h1>
      </div>

      <div className="atoll-screen__body atoll-screen__body--full">
        <MasterDetail>
          <ListPane
            toolbar={
              <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--space-2)',
                            padding: '8px 12px 0' }}>
                <SearchInput
                  value={search}
                  onChange={setSearch}
                  ariaLabel="Card-Leads durchsuchen"
                  placeholder="Name, Email, Topic …"
                />
                <div style={{ display: 'flex', gap: 6, overflowX: 'auto',
                              paddingBottom: 'var(--space-1)', scrollbarWidth: 'none' }}>
                  {SAVED_VIEWS.map((v) => {
                    const active = view === v.id
                    return (
                      <button
                        key={v.id}
                        type="button"
                        data-active={active || undefined}
                        onClick={() => setView(v.id)}
                        style={{
                          flexShrink: 0,
                          padding: '3px 10px',
                          borderRadius: 'var(--radius-pill)',
                          border: '1px solid var(--border-primary)',
                          background: active ? 'var(--brand-blue)' : 'transparent',
                          color: active ? '#fff' : 'var(--text-body)',
                          fontSize: 12,
                          fontWeight: 500,
                          cursor: 'pointer',
                          whiteSpace: 'nowrap',
                        }}
                      >
                        {v.label}
                      </button>
                    )
                  })}
                </div>
              </div>
            }
          >
            {isFetching && leads.length === 0 ? (
              <Loader />
            ) : leads.length === 0 ? (
              <EmptyState
                title={
                  view === 'new'      ? 'Alle Leads sind bearbeitet. ✓'
                : view === 'spam'     ? 'Kein Spam — die Welt ist freundlich.'
                : 'Noch keine Card-Leads. Sobald jemand deine Public-Card-Seite ausfüllt, landet die Anfrage hier.'
                }
              />
            ) : (
              <div role="list">
                {leads.map((lead) => (
                  <CardLeadRow
                    key={lead.id}
                    lead={lead}
                    selected={lead.id === leadId}
                    onClick={() => selectLead(lead.id)}
                  />
                ))}
              </div>
            )}
          </ListPane>

          <DetailPane>
            {selectedLead ? (
              <CardInboxDetailPanel lead={selectedLead} onClose={clearLead} />
            ) : (
              <EmptyState title="Wähle einen Lead aus der Liste." />
            )}
          </DetailPane>
        </MasterDetail>
      </div>
    </div>
  )
}
