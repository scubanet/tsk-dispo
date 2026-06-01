// apps/web/src/screens/contacts/timeline/TimelineFeed.tsx
// Center-Spalte im Mailbox-Look (Design-Handoff), gebunden an echte Daten/Funktionen:
// Quick-Log-Zeile, Filter-Tabs (Alle/WhatsApp/Mail), Verlauf mit WhatsApp-Bubbles +
// aufklappbaren Mail-Karten + System-Markern, und ein Bottom-Composer
// (Kanal-Umschalter, Templates, Mail-Betreff) der über comms-outbound sendet.
import { useEffect, useMemo, useRef, useState } from 'react'
import { useSearchParams } from 'react-router-dom'
import { useContactTimeline } from '@/hooks/useContactTimeline'
import { useDeleteContactEvent } from '@/hooks/useEventComposer'
import { useSendMessage } from '@/hooks/useSendMessage'
import { useContactTimelineRealtime } from '@/hooks/useContactTimelineRealtime'
import type { TimelineEvent, EventType } from '@/types/contactEvents'
import { NoteComposer } from './composers/NoteComposer'
import { CallComposer } from './composers/CallComposer'
import { MeetingComposer } from './composers/MeetingComposer'
import { TaskComposer } from './composers/TaskComposer'
import { MIcon, type MIconName } from './mailboxIcons'
import './mailbox.css'

interface Props {
  contactId: string
}

type Tab = 'all' | 'whatsapp' | 'email'
type Channel = 'whatsapp' | 'email'
type QuickKind = 'note' | 'call' | 'meet' | 'task'

const CH_COLOR: Record<Channel, string> = { whatsapp: '#1fa855', email: '#2563eb' }
const CH_LABEL: Record<Channel, string> = { whatsapp: 'WhatsApp', email: 'E-Mail' }

const QUICKLOG: { k: QuickKind | 'mail' | 'wa'; label: string; icon: MIconName }[] = [
  { k: 'note', label: 'Notiz', icon: 'note' },
  { k: 'call', label: 'Anruf', icon: 'phone' },
  { k: 'mail', label: 'Mail', icon: 'mail' },
  { k: 'meet', label: 'Meeting', icon: 'calendar' },
  { k: 'task', label: 'Task', icon: 'task' },
  { k: 'wa', label: 'WhatsApp', icon: 'whatsapp' },
]

const TEMPLATES = [
  'Danke für deine Nachricht! 🤿',
  'Ich melde mich gleich bei dir.',
  'Wann passt es dir für einen kurzen Call?',
  'Bis bald! 🌊',
]

// Event-Typ → Marker-Icon für Nicht-Nachrichten-Events.
const MARKER_ICON: Partial<Record<EventType, MIconName>> = {
  note: 'note', call: 'phone', meeting_past: 'calendar', task: 'task',
  saldo_movement: 'cash', course_enrollment: 'calendar', certification_issued: 'check',
}

function isOutbound(e: TimelineEvent): boolean {
  return (e.payload as { direction?: string } | null)?.direction === 'outbound'
}
function channelOf(e: TimelineEvent): Channel | null {
  if (e.event_type === 'whatsapp_log') return 'whatsapp'
  if (e.event_type === 'email_external') return 'email'
  return null
}
function timeLabel(iso: string): string {
  return new Date(iso).toLocaleTimeString('de-CH', { hour: '2-digit', minute: '2-digit' })
}
function dayLabel(iso: string): string {
  const d = new Date(iso)
  const now = new Date()
  const sameDay = (a: Date, b: Date) => a.toDateString() === b.toDateString()
  const yest = new Date(now); yest.setDate(now.getDate() - 1)
  if (sameDay(d, now)) return 'Heute'
  if (sameDay(d, yest)) return 'Gestern'
  return d.toLocaleDateString('de-CH', { day: '2-digit', month: 'long', year: 'numeric' })
}
function mailSubject(e: TimelineEvent): string {
  return (e.payload as { subject?: string } | null)?.subject || e.summary || '(kein Betreff)'
}
function mailBody(e: TimelineEvent): string {
  return e.body || e.summary || ''
}

export function TimelineFeed({ contactId }: Props) {
  const tl = useContactTimeline(contactId)
  const events = useMemo(() => tl.data?.pages.flat() ?? [], [tl.data])
  const del = useDeleteContactEvent(contactId)
  const send = useSendMessage(contactId)
  useContactTimelineRealtime(contactId)

  const [tab, setTab] = useState<Tab>('all')
  const [search, setSearch] = useState('')
  const [searchOpen, setSearchOpen] = useState(false)
  const [channel, setChannel] = useState<Channel>('whatsapp')
  const [draft, setDraft] = useState('')
  const [subject, setSubject] = useState('')
  const [expanded, setExpanded] = useState<Record<string, boolean>>({})
  const [quick, setQuick] = useState<QuickKind | null>(null)
  const [toast, setToast] = useState('')

  // ── Highlight via ?event=<id> (Activity-Feed-Navigation) ──────────────
  const [searchParams] = useSearchParams()
  const highlightEventId = searchParams.get('event')
  const highlightedRef = useRef<HTMLElement | null>(null)
  useEffect(() => {
    if (!highlightEventId || events.length === 0) return
    const node = highlightedRef.current
    if (node && typeof node.scrollIntoView === 'function') {
      node.scrollIntoView({ behavior: 'smooth', block: 'center' })
    }
  }, [highlightEventId, events.length])

  useEffect(() => {
    if (!toast) return
    const t = setTimeout(() => setToast(''), 2600)
    return () => clearTimeout(t)
  }, [toast])

  const counts = useMemo(() => ({
    all: events.length,
    whatsapp: events.filter(e => e.event_type === 'whatsapp_log').length,
    email: events.filter(e => e.event_type === 'email_external').length,
  }), [events])

  const q = search.trim().toLowerCase()
  const shown = useMemo(() => events.filter(e => {
    if (tab === 'whatsapp' && e.event_type !== 'whatsapp_log') return false
    if (tab === 'email' && e.event_type !== 'email_external') return false
    if (!q) return true
    return ((e.summary || '') + ' ' + (e.body || '')).toLowerCase().includes(q)
  }), [events, tab, q])

  const groups = useMemo(() => {
    const out: { day: string; items: TimelineEvent[] }[] = []
    shown.forEach(e => {
      const day = dayLabel(e.occurred_at)
      const last = out[out.length - 1]
      if (last && last.day === day) last.items.push(e)
      else out.push({ day, items: [e] })
    })
    return out
  }, [shown])

  function hl(text: string) {
    if (!q) return text
    const parts = text.split(new RegExp('(' + q.replace(/[.*+?^${}()|[\]\\]/g, '\\$&') + ')', 'ig'))
    return parts.map((p, i) => (p.toLowerCase() === q ? <mark key={i} className="mb-hl">{p}</mark> : p))
  }

  function doSend() {
    const text = draft.trim()
    if (!text || send.isPending) return
    send.mutate(
      { contact_id: contactId, channel, body: text, subject: channel === 'email' ? (subject.trim() || '(kein Betreff)') : undefined },
      {
        onSuccess: () => { setDraft(''); setToast((channel === 'whatsapp' ? 'WhatsApp' : 'E-Mail') + ' gesendet ✓') },
        onError: () => setToast('Senden fehlgeschlagen'),
      },
    )
  }

  function doDelete(id: string) {
    if (typeof window !== 'undefined' && window.confirm('Nachricht löschen?')) del.mutate(id)
  }

  function replyTo(e: TimelineEvent) {
    const ch = channelOf(e)
    if (!ch) return
    setChannel(ch)
    if (ch === 'email') setSubject((mailSubject(e).startsWith('Re:') ? mailSubject(e) : `Re: ${mailSubject(e)}`))
    setQuick(null)
  }

  function quickTask() { setQuick('task') }

  const TickOut = () => (
    <span className="mb-tick"><MIcon.doubleCheck size={15} /></span>
  )

  const WaBubble = ({ e }: { e: TimelineEvent }) => {
    const out = isOutbound(e)
    return (
      <div className={`mb-warow ${out ? 'out' : 'in'}`}>
        <div className={`mb-wabubble ${out ? 'out' : 'in'}`}>
          <div className="mb-wachip"><MIcon.whatsapp size={12} /> WhatsApp</div>
          <div className="mb-watext">{hl(e.body || e.summary || '')}</div>
          <div className="mb-wameta">
            <span>{timeLabel(e.occurred_at)}</span>
            {out && <TickOut />}
          </div>
        </div>
        <div className="mb-quick">
          <button title="Antworten" onClick={() => replyTo(e)}><MIcon.reply size={14} /></button>
          <button title="Task erstellen" onClick={quickTask}><MIcon.task size={14} /></button>
          <button className="danger" title="Löschen" onClick={() => doDelete(e.event_id)}><MIcon.trash size={14} /></button>
        </div>
      </div>
    )
  }

  const MailCard = ({ e }: { e: TimelineEvent }) => {
    const out = isOutbound(e)
    const open = !!expanded[e.event_id]
    return (
      <div className={`mb-mailcard ${out ? 'out' : 'in'} ${open ? 'open' : ''}`}>
        <button className="mb-mailhead" onClick={() => setExpanded(x => ({ ...x, [e.event_id]: !x[e.event_id] }))}>
          <span className="mb-mailicon"><MIcon.mail size={16} /></span>
          <span className="mb-mailmeta">
            <span className="mb-maildir">{out ? 'Gesendet' : 'Empfangen'} · E-Mail</span>
            <span className="mb-mailsubj">{hl(mailSubject(e))}</span>
            {!open && <span className="mb-mailprev">{mailBody(e)}</span>}
          </span>
          <span className="mb-mailright">
            <span className="mb-mailtime">{timeLabel(e.occurred_at)}</span>
            {out && <TickOut />}
            <MIcon.chevronDown size={16} style={{ transform: open ? 'rotate(180deg)' : 'none', transition: '.2s', color: '#94a3b8' }} />
          </span>
        </button>
        {open && (
          <div className="mb-mailbody">
            <div className="mb-bodytext">{hl(mailBody(e))}</div>
            <div className="mb-mailactions">
              <button className="primary" onClick={() => replyTo(e)}><MIcon.reply size={14} /> Antworten</button>
              <button onClick={quickTask}><MIcon.task size={14} /> Task</button>
              <button className="danger" onClick={() => doDelete(e.event_id)}><MIcon.trash size={14} /> Löschen</button>
            </div>
          </div>
        )}
      </div>
    )
  }

  const SystemMarker = ({ e }: { e: TimelineEvent }) => {
    const Ico = MIcon[MARKER_ICON[e.event_type] ?? 'dot']
    return (
      <div className="mb-sysmarker">
        <span>
          <Ico size={14} />
          <b>{e.summary || e.event_type}</b>
          {e.body ? <span> — {e.body.slice(0, 80)}</span> : null}
          <span className="mb-systime">· {timeLabel(e.occurred_at)}</span>
        </span>
      </div>
    )
  }

  function renderItem(e: TimelineEvent) {
    if (e.event_type === 'whatsapp_log') return <WaBubble e={e} />
    if (e.event_type === 'email_external') return <MailCard e={e} />
    return <SystemMarker e={e} />
  }

  return (
    <div className="mb">
      {/* quick log row */}
      <div className="mb-quicklog">
        {QUICKLOG.map(({ k, label, icon }) => {
          const Ico = MIcon[icon]
          const on = (k === 'mail' && channel === 'email') || (k === 'wa' && channel === 'whatsapp') || (k === quick)
          return (
            <button key={k} className={`mb-qlbtn ${on ? 'on' : ''}`} onClick={() => {
              if (k === 'mail') { setChannel('email'); setQuick(null) }
              else if (k === 'wa') { setChannel('whatsapp'); setQuick(null) }
              else setQuick(cur => (cur === k ? null : (k as QuickKind)))
            }}>
              <Ico size={15} />{label}
            </button>
          )
        })}
      </div>
      {quick && (
        <div className="mb-qlpanel">
          {quick === 'note' && <NoteComposer contactId={contactId} onDone={() => setQuick(null)} />}
          {quick === 'call' && <CallComposer contactId={contactId} onDone={() => setQuick(null)} />}
          {quick === 'meet' && <MeetingComposer contactId={contactId} onDone={() => setQuick(null)} />}
          {quick === 'task' && <TaskComposer contactId={contactId} onDone={() => setQuick(null)} />}
        </div>
      )}

      {/* filter tabs + search */}
      <div className="mb-filters">
        <div className="mb-tabs">
          {([['all', 'Alle'], ['whatsapp', 'WhatsApp'], ['email', 'Mail']] as [Tab, string][]).map(([k, l]) => (
            <button key={k} className={`mb-tab ${tab === k ? 'on' : ''}`} onClick={() => setTab(k)}
              style={tab === k && k !== 'all' ? { color: CH_COLOR[k as Channel], borderColor: CH_COLOR[k as Channel] } : undefined}>
              {k === 'whatsapp' && <MIcon.whatsapp size={14} />}
              {k === 'email' && <MIcon.mail size={14} />}
              <span>{l}</span><span className="mb-tabcount">{counts[k]}</span>
            </button>
          ))}
        </div>
        <div className={`mb-searchbox ${searchOpen || q ? 'open' : ''}`}>
          <button className="mb-iconbtn ghost" aria-label="Suche" onClick={() => setSearchOpen(o => !o)}><MIcon.search size={16} /></button>
          {(searchOpen || q) && (
            <input autoFocus value={search} onChange={e => setSearch(e.target.value)} placeholder="Im Verlauf suchen…"
              onBlur={() => { if (!q) setSearchOpen(false) }} />
          )}
          {q && <button className="mb-clear" aria-label="Suche löschen" onClick={() => setSearch('')}><MIcon.x size={13} /></button>}
        </div>
      </div>

      {/* thread */}
      <div className="mb-thread">
        {tl.isLoading && <div className="mb-noresults">Lade Timeline…</div>}
        {tl.error && (
          <div className="mb-noresults" style={{ color: 'var(--danger-fg, #c0392b)' }}>
            Fehler: {tl.error.message}
            <button type="button" onClick={() => tl.refetch()} style={{ marginLeft: 12 }}>↻ Retry</button>
          </div>
        )}
        {!tl.isLoading && !tl.error && shown.length === 0 && (
          <div className="mb-noresults">{q ? `Keine Nachrichten gefunden für „${search}"` : 'Noch keine Einträge. Erfasse oben eine Notiz, einen Anruf oder eine Nachricht.'}</div>
        )}

        {groups.map(g => (
          <div key={g.day}>
            <div className="mb-day"><span>{g.day}</span></div>
            {g.items.map(e => {
              const isHi = e.event_id === highlightEventId
              return (
                <article key={e.event_id} data-event-id={e.event_id}
                  data-event-highlighted={isHi ? 'true' : undefined}
                  ref={isHi ? highlightedRef : undefined}>
                  {renderItem(e)}
                </article>
              )
            })}
          </div>
        ))}

        {tl.hasNextPage && (
          <div style={{ padding: 12, textAlign: 'center' }}>
            <button type="button" className="mb-qlbtn" onClick={() => tl.fetchNextPage()} disabled={tl.isFetchingNextPage}>
              {tl.isFetchingNextPage ? 'Lade…' : 'Mehr anzeigen'}
            </button>
          </div>
        )}
      </div>

      {/* composer */}
      <div className="mb-composer">
        <div className="mb-cswitch">
          {(['whatsapp', 'email'] as Channel[]).map(k => (
            <button key={k} className={channel === k ? 'on' : ''} onClick={() => setChannel(k)}
              style={channel === k ? { background: CH_COLOR[k] } : undefined}>
              {k === 'whatsapp' ? <MIcon.whatsapp size={14} /> : <MIcon.mail size={14} />} {CH_LABEL[k]}
            </button>
          ))}
        </div>

        {channel === 'whatsapp' && (
          <div className="mb-templates">
            {TEMPLATES.map((t, i) => <button key={i} onClick={() => setDraft(t)}>{t}</button>)}
          </div>
        )}
        {channel === 'email' && (
          <div className="mb-mailfields">
            <div className="mb-field"><span>Betreff</span>
              <input value={subject} onChange={e => setSubject(e.target.value)} placeholder="Betreff" /></div>
          </div>
        )}

        <div className={`mb-inputbar ${channel}`}>
          <textarea rows={channel === 'email' ? 3 : 1}
            placeholder={channel === 'whatsapp' ? 'Nachricht' : 'Schreib deine E-Mail…'}
            value={draft} onChange={e => setDraft(e.target.value)}
            onKeyDown={e => { if (channel === 'whatsapp' && e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); doSend() } }} />
          <button className="mb-send" aria-label="Senden" style={{ background: CH_COLOR[channel] }}
            disabled={!draft.trim() || send.isPending} onClick={doSend}>
            <MIcon.send size={17} />
          </button>
        </div>
      </div>

      {toast && <div className="mb-toast">{toast}</div>}
    </div>
  )
}
