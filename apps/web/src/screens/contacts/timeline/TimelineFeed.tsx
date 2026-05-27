// apps/web/src/screens/contacts/timeline/TimelineFeed.tsx
import { useState } from 'react'
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
        {events.map(e => <EventCard key={e.event_id} event={e} />)}
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
