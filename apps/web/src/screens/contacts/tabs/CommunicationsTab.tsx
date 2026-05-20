/**
 * CommunicationsTab — chronological list of communication entries for a contact.
 *
 * Reads from `communication_entries` filtered by `contact_id`. Clicking an entry
 * opens the existing CommunicationEditSheet so all CRUD lives in one place.
 */

import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { useOutletContext } from 'react-router-dom'
import { useQueryClient } from '@tanstack/react-query'
import { Pill, Icon, dateTimeShort } from '@/foundation'
import { CommunicationEditSheet, CHANNELS } from '../../cd/CommunicationEditSheet'
import { useContactCommunications } from '@/hooks/useContactTabs'
import type { OutletCtx } from '@/layout/AppShell'

interface Props {
  contactId: string
}

export function CommunicationsTab({ contactId }: Props) {
  const { t } = useTranslation()
  const { user } = useOutletContext<OutletCtx>()
  const qc = useQueryClient()
  const { data: rows = [], isLoading: loading } = useContactCommunications(contactId)
  const [editingId, setEditingId] = useState<string | null>(null)
  const [editOpen, setEditOpen] = useState(false)
  const [createOpen, setCreateOpen] = useState(false)

  function invalidate() {
    // Invalidate the per-contact list *and* the global CommunicationHub list
    // so both views stay consistent after a save.
    qc.invalidateQueries({ queryKey: ['contact', 'communications', contactId] })
    qc.invalidateQueries({ queryKey: ['communicationEntries'] })
  }

  if (loading) {
    return (
      <div className="contact-tab-body tab-stub">
        {t('contacts.loading_communications')}
      </div>
    )
  }

  return (
    <div className="contact-tab-body">
      <div
        style={{
          display: 'flex',
          justifyContent: 'flex-end',
          marginBottom: 'var(--space-3)',
        }}
      >
        <button
          type="button"
          className="atoll-btn atoll-btn--primary"
          onClick={() => setCreateOpen(true)}
        >
          <Icon.Plus size={14} /> {t('contacts.new_communication')}
        </button>
      </div>

      {rows.length === 0 ? (
        <div className="tab-stub">{t('contacts.no_communications')}</div>
      ) : (
        <div className="atoll-comm__list">
          {rows.map((c) => {
            const ch = CHANNELS.find((x) => x.code === c.channel)
            return (
              <button
                key={c.id}
                type="button"
                className="atoll-comm__entry"
                onClick={() => {
                  setEditingId(c.id)
                  setEditOpen(true)
                }}
              >
                <div className="atoll-comm__entry-head">
                  <Pill
                    tone={c.direction === 'inbound' ? 'brand' : 'success'}
                    size="sm"
                  >
                    {ch?.label ?? c.channel}
                    {c.direction === 'inbound' ? ' ↓' : ' ↑'}
                  </Pill>
                  {c.created_by_instructor && (
                    <Pill tone="pro" size="sm">
                      {c.created_by_instructor.name}
                    </Pill>
                  )}
                  <span className="atoll-comm__entry-time tabular-nums">
                    {dateTimeShort(c.occurred_on)}
                  </span>
                </div>
                {c.subject && (
                  <div className="atoll-comm__entry-subject">{c.subject}</div>
                )}
                {c.body && <div className="atoll-comm__entry-body">{c.body}</div>}
                {(c.duration_minutes != null || c.outcome) && (
                  <div className="atoll-comm__entry-meta">
                    {c.duration_minutes != null && (
                      <span>
                        {t('student_detail.minutes', { count: c.duration_minutes })}
                      </span>
                    )}
                    {c.outcome && (
                      <span className="atoll-comm__entry-outcome">→ {c.outcome}</span>
                    )}
                  </div>
                )}
              </button>
            )
          })}
        </div>
      )}

      <CommunicationEditSheet
        open={editOpen}
        onClose={() => setEditOpen(false)}
        onSaved={invalidate}
        entryId={editingId}
        createdById={user.instructorId}
      />

      <CommunicationEditSheet
        open={createOpen}
        onClose={() => setCreateOpen(false)}
        onSaved={invalidate}
        createdById={user.instructorId}
        contactId={contactId}
      />
    </div>
  )
}
