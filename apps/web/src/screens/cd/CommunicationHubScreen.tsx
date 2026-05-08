/**
 * CommunicationHubScreen — Foundation-based rewrite.
 *
 * Layout:
 *   PageHeader (search + new touchpoint)
 *     toolbar: FilterTabBar (all / inbound / outbound) + SortDropdown (channels)
 *   ┌─ list of touchpoint cards ─────────────────────────────┐
 *   │  Pill (channel + direction) · contact name · stage     │
 *   │  Subject (medium weight)                                │
 *   │  Body (clamp 2 lines)                                   │
 *   │  duration_minutes · outcome                             │
 *   └─────────────────────────────────────────────────────────┘
 */

import { useEffect, useMemo, useState } from 'react'
import { useOutletContext } from 'react-router-dom'
import { useTranslation } from 'react-i18next'
import {
  PageHeader,
  FilterTabBar,
  SortDropdown,
  SearchInput,
  EmptyState,
  Pill,
  Icon,
  dateTimeShort,
} from '@/foundation'
import { supabase } from '@/lib/supabase'
import { CommunicationEditSheet, CHANNELS } from './CommunicationEditSheet'
import type { OutletCtx } from '@/layout/AppShell'

interface Entry {
  id: string
  contact_id: string
  channel: string
  direction: string
  occurred_on: string
  subject: string | null
  body: string | null
  duration_minutes: number | null
  outcome: string | null
  contact: {
    id: string
    name: string
    is_student: boolean
    is_candidate: boolean
  } | null
  created_by_instructor: { id: string; name: string } | null
}

type DirFilter = 'all' | 'inbound' | 'outbound'

export function CommunicationHubScreen() {
  const { t } = useTranslation()
  const { user } = useOutletContext<OutletCtx>()
  const canAccess =
    user.role === 'dispatcher' || user.role === 'cd' || user.role === 'owner'

  const [rows, setRows] = useState<Entry[]>([])
  const [loading, setLoading] = useState(true)
  const [search, setSearch] = useState('')
  const [channel, setChannel] = useState('')
  const [direction, setDirection] = useState<DirFilter>('all')
  const [editOpen, setEditOpen] = useState(false)
  const [editingId, setEditingId] = useState<string | null>(null)
  const [createOpen, setCreateOpen] = useState(false)
  const [refreshTick, setRefreshTick] = useState(0)

  useEffect(() => {
    if (!canAccess) return
    let cancelled = false
    setLoading(true)
    supabase
      .from('communication_entries')
      .select(
        'id, contact_id, channel, direction, occurred_on, subject, body, duration_minutes, outcome, contact:people!contact_id(id, name, is_student, is_candidate), created_by_instructor:instructors!created_by(id, name)',
      )
      .order('occurred_on', { ascending: false })
      .limit(500)
      .then(({ data, error }) => {
        if (cancelled) return
        if (error) console.error('[comm-hub] load failed', error)
        setRows((data ?? []) as unknown as Entry[])
        setLoading(false)
      })
    return () => {
      cancelled = true
    }
  }, [canAccess, refreshTick])

  const filtered = useMemo(() => {
    return rows.filter((r) => {
      if (channel && r.channel !== channel) return false
      if (direction !== 'all' && r.direction !== direction) return false
      if (search) {
        const q = search.toLowerCase()
        const hay = `${r.contact?.name ?? ''} ${r.subject ?? ''} ${r.body ?? ''} ${r.outcome ?? ''}`.toLowerCase()
        if (!hay.includes(q)) return false
      }
      return true
    })
  }, [rows, search, channel, direction])

  if (!canAccess) {
    return (
      <div className="atoll-screen">
        <PageHeader
          title={t('nav.communication')}
          subtitle={t('comm_hub.no_access_desc')}
        />
        <div className="atoll-screen__body">
          <EmptyState
            icon={<Icon.Info size={20} />}
            title={t('cd_pipeline.no_access_title')}
            body={t('comm_hub.no_access_desc')}
          />
        </div>
      </div>
    )
  }

  const stats = {
    total: rows.length,
    inbound: rows.filter((r) => r.direction === 'inbound').length,
    outbound: rows.filter((r) => r.direction === 'outbound').length,
  }

  const dirTabs = [
    { id: 'all' as const, label: t('people.tab_all'), count: stats.total },
    { id: 'inbound' as const, label: `↓ ${t('comm_hub.inbound')}`, count: stats.inbound },
    { id: 'outbound' as const, label: `↑ ${t('comm_hub.outbound')}`, count: stats.outbound },
  ]

  const channelOptions = [
    { id: '', label: t('comm_hub.all_channels') },
    ...CHANNELS.map((c) => ({ id: c.code, label: c.label })),
  ]

  return (
    <div className="atoll-screen">
      <PageHeader
        title={t('nav.communication')}
        subtitle={t('comm_hub.subtitle', {
          total: stats.total,
          inbound: stats.inbound,
          outbound: stats.outbound,
        })}
        actions={
          <>
            <SearchInput
              value={search}
              onChange={setSearch}
              ariaLabel={t('comm_hub.search_placeholder')}
              placeholder={t('comm_hub.search_placeholder')}
            />
            <button
              type="button"
              className="atoll-btn atoll-btn--primary"
              onClick={() => setCreateOpen(true)}
            >
              <Icon.Plus size={14} /> {t('courses.new')}
            </button>
          </>
        }
        belowTitle={
          <div className="atoll-comm__toolbar">
            <FilterTabBar<DirFilter>
              tabs={dirTabs}
              active={direction}
              onChange={setDirection}
              ariaLabel={t('comm_hub.inbound')}
            />
            <SortDropdown
              options={channelOptions}
              value={channel}
              onChange={setChannel}
              ariaLabel={t('comm_hub.all_channels')}
            />
          </div>
        }
      />

      <div className="atoll-screen__body">
        {loading ? (
          <div className="atoll-cockpit__loading">{t('common.loading')}</div>
        ) : filtered.length === 0 ? (
          <EmptyState
            icon={<Icon.Mail size={20} />}
            title={
              rows.length === 0
                ? t('comm_hub.empty_first_time')
                : t('comm_hub.no_filter_matches')
            }
          />
        ) : (
          <div className="atoll-comm__list">
            {filtered.map((c) => {
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
                    <span className="atoll-comm__entry-name">
                      {c.contact?.name ?? '—'}
                    </span>
                    {c.contact?.is_candidate && (
                      <Pill tone="danger" size="sm">
                        {t('student_edit.stage_candidate')}
                      </Pill>
                    )}
                    {c.contact?.is_student && !c.contact?.is_candidate && (
                      <Pill tone="brand" size="sm">
                        {t('comm_hub.student_badge')}
                      </Pill>
                    )}
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
      </div>

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
      />
    </div>
  )
}
