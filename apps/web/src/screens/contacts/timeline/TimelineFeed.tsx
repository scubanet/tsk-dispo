// apps/web/src/screens/contacts/timeline/TimelineFeed.tsx
import { useEffect, useRef, useState } from 'react'
import { useSearchParams } from 'react-router-dom'
import { useContactTimeline } from '@/hooks/useContactTimeline'
import type { TimelineFilter } from '@/types/contactEvents'
import { EventCard } from './EventCard'
import { TimelineFilterBar } from './TimelineFilterBar'
import { EventComposer } from './EventComposer'

interface Props {
  contactId: string
}

export function TimelineFeed({ contactId }: Props) {
  const [filter, setFilter] = useState<TimelineFilter>({})
  const tl = useContactTimeline(contactId, filter)
  const events = tl.data?.pages.flat() ?? []

  // Phase G Phase 5 Task 6 — Event-Highlight via `?event=<id>`-URL-Param.
  // Wenn die App via ActivityEventCard ins DetailPanel navigiert, wird die
  // entsprechende Card hier hervorgehoben (Border-Pulse 1.5s) und in den
  // Viewport gescrollt.
  const [searchParams] = useSearchParams()
  const eventId = searchParams.get('event')
  const highlightedRef = useRef<HTMLElement | null>(null)

  useEffect(() => {
    if (!eventId || events.length === 0) return
    const node = highlightedRef.current
    if (!node) return
    // happy-dom hat scrollIntoView nicht implementiert — wir fallen leise zurück.
    if (typeof node.scrollIntoView === 'function') {
      node.scrollIntoView({ behavior: 'smooth', block: 'center' })
    }
  }, [eventId, events.length])

  return (
    <div style={{ display: 'flex', flexDirection: 'column', height: '100%' }}>
      <EventComposer contactId={contactId} />
      <TimelineFilterBar value={filter} onChange={setFilter} />
      <div style={{ flex: 1, overflowY: 'auto', minHeight: 0 }}>
        {tl.isLoading && (
          <div style={{ padding: 20, color: 'var(--text-secondary)' }}>Lade Timeline…</div>
        )}
        {tl.error && (
          <div style={{ padding: 20, color: 'var(--color-text-danger, #c0392b)' }}>
            Fehler: {tl.error.message}
            <button type="button" onClick={() => tl.refetch()} style={{ marginLeft: 12 }}>↻ Retry</button>
          </div>
        )}
        {!tl.isLoading && !tl.error && events.length === 0 && (
          <div style={{ padding: 20, color: 'var(--text-tertiary)', textAlign: 'center' }}>
            Noch keine Events. Erfasse oben eine Notiz, einen Anruf oder Task.
          </div>
        )}
        {events.map(e => {
          const isHighlighted = e.event_id === eventId
          return (
            <EventCard
              key={e.event_id}
              event={e}
              highlighted={isHighlighted}
              ref={isHighlighted ? highlightedRef : undefined}
            />
          )
        })}
        {tl.hasNextPage && (
          <div style={{ padding: 16, textAlign: 'center' }}>
            <button
              type="button"
              onClick={() => tl.fetchNextPage()}
              disabled={tl.isFetchingNextPage}
              style={{ padding: '6px 14px' }}
            >
              {tl.isFetchingNextPage ? 'Lade…' : 'Mehr anzeigen'}
            </button>
          </div>
        )}
      </div>
    </div>
  )
}
