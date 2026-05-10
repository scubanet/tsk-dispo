/**
 * CommunicationsTab — chronological list of communication entries for a contact.
 *
 * Reads from `communication_entries` filtered by `contact_id`. Clicking an entry
 * opens the existing CommunicationEditSheet so all CRUD lives in one place.
 */

import { useEffect, useState, useCallback } from 'react'
import { useTranslation } from 'react-i18next'
import { useOutletContext } from 'react-router-dom'
import { supabase } from '@/lib/supabase'
import { Pill, Icon, dateTimeShort } from '@/foundation'
import { CommunicationEditSheet, CHANNELS } from '../../cd/CommunicationEditSheet'
import type { OutletCtx } from '@/layout/AppShell'

interface Entry {
  id: string
  channel: string
  direction: string
  occurred_on: string
  subject: string | null
  body: string | null
  duration_minutes: number | null
  outcome: string | null
  created_by_instructor: { id: string; name: string } | null
}

interface Props {
  contactId: string
}

export function CommunicationsTab({ contactId }: Props) {
  const { t } = useTranslation()
  const { user } = useOutletContext<OutletCtx>()
  const [rows, setRows] = useState<Entry[]>([])
  const [loading, setLoading] = useState(true)
  const [editingId, setEditingId] = useState<string | null>(null)
  const [editOpen, setEditOpen] = useState(false)
  const [createOpen, setCreateOpen] = useState(false)
  const [refreshTick, setRefreshTick] = useState(0)

  const load = useCallback(() => {
    let cancelled = false
    setLoading(true)
    supabase
      .from('communication_entries')
      .select(
        'id, channel, direction, occurred_on, subject, body, duration_minutes, outcome, created_by_instructor:instructors!created_by(id, name)',
      )
      .eq('contact_id', contactId)
      .order('occurred_on', { ascending: false })
      .limit(200)
      .then(({ data, error }) => {
        if (cancelled) return
        if (error) console.error('[contact-comms] load failed', error)
        setRows((data ?? []) as unknown as Entry[])
        setLoading(false)
      })
    return () => {
      cancelled = true
    }
  }, [contactId])

  useEffect(() => {
    load()
  }, [load, refreshTick])

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
          marginBottom: 12,
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
        onSaved={() => setRefreshTick((tick) => tick + 1)}
        entryId={editingId}
        createdById={user.instructorId}
      />

      <CommunicationEditSheet
        open={createOpen}
        onClose={() => setCreateOpen(false)}
        onSaved={() => setRefreshTick((tick) => tick + 1)}
        createdById={user.instructorId}
        contactId={contactId}
      />
    </div>
  )
}
