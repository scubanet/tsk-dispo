import { useEffect, useMemo, useState } from 'react'
import { useOutletContext } from 'react-router-dom'
import { format } from 'date-fns'
import { de } from 'date-fns/locale'
import clsx from 'clsx'
import { supabase } from '@/lib/supabase'
import { Topbar } from '@/components/Topbar'
import { Icon } from '@/components/Icon'
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
  contact: { id: string; name: string; is_student: boolean; is_candidate: boolean } | null
  created_by_instructor: { id: string; name: string } | null
}

const CHANNEL_FILTERS = [
  { code: '',         label: 'Alle Kanäle' },
  ...CHANNELS,
]

export function CommunicationHubScreen() {
  const { user } = useOutletContext<OutletCtx>()
  const canAccess = user.role === 'dispatcher' || user.role === 'cd' || user.role === 'owner'

  const [rows, setRows] = useState<Entry[]>([])
  const [loading, setLoading] = useState(true)
  const [search, setSearch] = useState('')
  const [channel, setChannel] = useState('')
  const [direction, setDirection] = useState<'all' | 'inbound' | 'outbound'>('all')
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
      .select('id, contact_id, channel, direction, occurred_on, subject, body, duration_minutes, outcome, contact:people!contact_id(id, name, is_student, is_candidate), created_by_instructor:instructors!created_by(id, name)')
      .order('occurred_on', { ascending: false })
      .limit(500)
      .then(({ data, error }) => {
        if (cancelled) return
        if (error) console.error('[comm-hub] load failed', error)
        setRows((data ?? []) as unknown as Entry[])
        setLoading(false)
      })
    return () => { cancelled = true }
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
      <div style={{ padding: 40 }}>
        <div className="title-2">Kein Zugriff</div>
        <div className="caption">Communication Hub ist nur für Dispatcher, CD und Owner.</div>
      </div>
    )
  }

  const stats = {
    total: rows.length,
    inbound: rows.filter((r) => r.direction === 'inbound').length,
    outbound: rows.filter((r) => r.direction === 'outbound').length,
  }

  return (
    <>
      <Topbar title="Communication" subtitle={`${stats.total} Touchpoints · ${stats.inbound} eingehend · ${stats.outbound} ausgehend`}>
        <div className="search" style={{ width: 220 }}>
          <Icon name="search" size={14} />
          <input
            placeholder="Person, Betreff, Inhalt…"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
          />
        </div>
        <button className="btn" onClick={() => setCreateOpen(true)}>
          <Icon name="plus" size={14} /> Neu
        </button>
      </Topbar>

      <div style={{ padding: '0 24px 12px', display: 'flex', gap: 8, flexWrap: 'wrap' }}>
        <div className="seg">
          <button className={clsx(direction === 'all' && 'active')} onClick={() => setDirection('all')}>Alle</button>
          <button className={clsx(direction === 'inbound' && 'active')} onClick={() => setDirection('inbound')}>↓ Eingehend</button>
          <button className={clsx(direction === 'outbound' && 'active')} onClick={() => setDirection('outbound')}>↑ Ausgehend</button>
        </div>
        <select
          value={channel}
          onChange={(e) => setChannel(e.target.value)}
          style={{
            padding: '6px 10px',
            borderRadius: 8,
            border: '0.5px solid var(--hairline)',
            background: 'var(--surface-strong)',
            color: 'var(--ink)',
            fontSize: 13,
          }}
        >
          {CHANNEL_FILTERS.map((c) => <option key={c.code} value={c.code}>{c.label}</option>)}
        </select>
      </div>

      {loading ? (
        <div style={{ padding: 40 }} className="caption">Lade…</div>
      ) : filtered.length === 0 ? (
        <div style={{ padding: 40 }} className="caption">
          {rows.length === 0
            ? 'Noch keine Touchpoints erfasst — über „Neu" oder direkt am Kontakt.'
            : 'Keine Treffer mit diesen Filtern.'}
        </div>
      ) : (
        <div style={{ padding: '0 24px 24px', display: 'grid', gap: 6 }}>
          {filtered.map((c) => {
            const ch = CHANNELS.find((x) => x.code === c.channel)
            return (
              <button
                key={c.id}
                className="glass-thin"
                onClick={() => {
                  setEditingId(c.id)
                  setEditOpen(true)
                }}
                style={{
                  padding: 12,
                  borderRadius: 12,
                  border: 'none',
                  cursor: 'pointer',
                  textAlign: 'left',
                  color: 'var(--ink)',
                  font: 'inherit',
                  width: '100%',
                  display: 'grid',
                  gap: 6,
                }}
              >
                <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                  <span
                    style={{
                      padding: '2px 8px',
                      borderRadius: 999,
                      background: c.direction === 'inbound' ? 'rgba(0,122,255,.20)' : 'rgba(52,199,89,.20)',
                      fontSize: 11,
                      fontWeight: 600,
                    }}
                  >
                    {ch?.label ?? c.channel}{c.direction === 'inbound' ? ' ↓' : ' ↑'}
                  </span>
                  <span style={{ fontWeight: 600 }}>{c.contact?.name ?? '—'}</span>
                  {c.contact?.is_candidate && <span className="caption-2" style={{ padding: '2px 8px', borderRadius: 999, background: 'rgba(255,69,58,.20)' }}>Kandidat</span>}
                  {c.contact?.is_student && !c.contact?.is_candidate && <span className="caption-2" style={{ padding: '2px 8px', borderRadius: 999, background: 'rgba(0,122,255,.20)' }}>Schüler</span>}
                  {c.created_by_instructor && (
                    <span className="caption-2" style={{ padding: '2px 8px', borderRadius: 999, background: 'rgba(88,86,214,.20)' }}>
                      {c.created_by_instructor.name}
                    </span>
                  )}
                  <span className="caption-2" style={{ marginLeft: 'auto' }}>
                    {format(new Date(c.occurred_on), 'd. MMM yyyy, HH:mm', { locale: de })}
                  </span>
                </div>
                {c.subject && <div style={{ fontWeight: 500 }}>{c.subject}</div>}
                {c.body && (
                  <div className="caption" style={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap', display: '-webkit-box', WebkitLineClamp: 2, WebkitBoxOrient: 'vertical' }}>
                    {c.body}
                  </div>
                )}
                {(c.duration_minutes != null || c.outcome) && (
                  <div style={{ display: 'flex', gap: 12 }}>
                    {c.duration_minutes != null && <span className="caption-2">{c.duration_minutes} min</span>}
                    {c.outcome && <span className="caption-2" style={{ fontStyle: 'italic' }}>→ {c.outcome}</span>}
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
        onSaved={() => setRefreshTick((t) => t + 1)}
        entryId={editingId}
        createdById={user.instructorId}
      />

      <CommunicationEditSheet
        open={createOpen}
        onClose={() => setCreateOpen(false)}
        onSaved={() => setRefreshTick((t) => t + 1)}
        createdById={user.instructorId}
      />
    </>
  )
}
