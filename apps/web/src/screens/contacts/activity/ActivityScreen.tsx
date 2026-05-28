// apps/web/src/screens/contacts/activity/ActivityScreen.tsx
//
// Phase G Phase 5 Task 4 — Top-Level ActivityScreen für /aktivitaet.
//
// Komponiert FilterBar + Composer + Event-Feed in voller Breite (KEIN
// Master-Detail). Layout-Pattern lehnt sich an AddressbookScreen.tsx an
// (atoll-page-header + atoll-screen__body--full). DetailPanel-Highlighting
// für einen geklickten Event-Anchor kommt in T6.
//
// State-Flow:
//   useActivityFilter  → liefert UI-Filter + URL-Sync + toGlobalActivityFilter
//   useCurrentUser     → contact_instructor.contact_id (für owner_scope='mine')
//   useGlobalActivity  → Infinite-Query mit Cursor-Pagination (50 per page)
//   useQuery(contacts) → Batch-Lookup von Display-Names für die geladenen
//                        Events (vermeidet N+1)
//
// Pragma — IntersectionObserver-Fallback:
// happy-dom v15 implementiert IntersectionObserver, aber wir lassen
// trotzdem einen sichtbaren „Mehr laden"-Button stehen. Das macht das
// Verhalten auch im a11y-Sinn explizit (kein versteckter Auto-Trigger),
// und Tests können den Button direkt klicken statt das Sentinel-Element
// in den Viewport zu scrollen.

import { useEffect, useMemo, useRef } from 'react'
import { useQuery } from '@tanstack/react-query'
import { useActivityFilter } from '@/hooks/useActivityFilter'
import { useGlobalActivity } from '@/hooks/useGlobalActivity'
import { useCurrentUser } from '@/hooks/useCurrentUser'
import { listContacts } from '@/lib/contactQueries'
import { ActivityFilterBar } from './ActivityFilterBar'
import { ActivityComposer } from './ActivityComposer'
import { ActivityEventCard } from './ActivityEventCard'

export function ActivityScreen() {
  // ── Filter / URL-State ────────────────────────────────────────────
  const { filter, setFilter, clear, toGlobalActivityFilter } =
    useActivityFilter()

  // ── Current User (für owner_scope='mine') ─────────────────────────
  const currentUser = useCurrentUser()
  const actorId = currentUser.data?.instructorId ?? undefined

  // ── Globaler Activity-Feed (infinite) ─────────────────────────────
  const globalFilter = useMemo(
    () => toGlobalActivityFilter(actorId),
    [toGlobalActivityFilter, actorId],
  )
  const activity = useGlobalActivity(globalFilter)

  const events = useMemo(
    () => activity.data?.pages.flat() ?? [],
    [activity.data],
  )

  // ── Batch-Lookup: Display-Names für alle geladenen Events ─────────
  // Wir sammeln die unique contact_ids und feuern *eine* listContacts-
  // Query mit ihnen. Pragmatisch: filter.kind/roles ungefiltert lassen,
  // damit die Map alle IDs auflöst, auch wenn der Contact archiviert ist
  // (wir wollen den Namen trotzdem zeigen, auch wenn die Karte historisch
  // ist).
  const contactIds = useMemo(() => {
    const set = new Set<string>()
    for (const ev of events) set.add(ev.contact_id)
    return Array.from(set)
  }, [events])

  const contactNamesQuery = useQuery({
    queryKey: ['activity-contact-names', contactIds],
    enabled: contactIds.length > 0,
    queryFn: async () => {
      // listContacts hat keinen `ids`-Filter — kleinster Workaround:
      // pageSize = ids.length, dann clientseitig filtern. Bei > paar
      // hundert IDs wechseln wir auf einen eigenen RPC; für T4 (50er
      // pages) reicht das.
      const { rows } = await listContacts({}, 0, contactIds.length)
      const map = new Map<string, string>()
      const idSet = new Set(contactIds)
      for (const r of rows) {
        if (idSet.has(r.id)) {
          map.set(
            r.id,
            r.display_name ??
              [r.last_name, r.first_name].filter(Boolean).join(', ') ??
              r.id,
          )
        }
      }
      return map
    },
  })
  const namesMap = contactNamesQuery.data

  // ── Infinite-Scroll Sentinel (zusätzlich zum „Mehr laden"-Button) ──
  const sentinelRef = useRef<HTMLDivElement | null>(null)
  useEffect(() => {
    if (typeof IntersectionObserver === 'undefined') return
    const node = sentinelRef.current
    if (!node) return
    const observer = new IntersectionObserver(
      (entries) => {
        const entry = entries[0]
        if (!entry?.isIntersecting) return
        if (activity.hasNextPage && !activity.isFetchingNextPage) {
          activity.fetchNextPage()
        }
      },
      { threshold: 0.1 },
    )
    observer.observe(node)
    return () => observer.disconnect()
  }, [activity])

  // ── Render-Bausteine ─────────────────────────────────────────────
  const initialLoading = activity.isLoading && events.length === 0
  const hasError = activity.isError
  const isEmpty = !initialLoading && events.length === 0 && !hasError

  return (
    <div className="atoll-screen" data-testid="activity-screen">
      {/* Screen header */}
      <div
        className="atoll-page-header"
        style={{
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          padding: '16px 24px 0',
          flexShrink: 0,
        }}
      >
        <h1 style={{ fontSize: 22, fontWeight: 700, margin: 0 }}>Aktivität</h1>
      </div>

      <div className="atoll-screen__body atoll-screen__body--full">
        <div
          style={{
            display: 'flex',
            flexDirection: 'column',
            flex: 1,
            minHeight: 0,
            background: 'var(--bg-card)',
          }}
        >
          {/* FilterBar — sticky-top */}
          <div
            style={{
              flexShrink: 0,
              padding: '8px 12px 0',
              position: 'sticky',
              top: 0,
              zIndex: 11,
              background: 'var(--bg-card)',
            }}
          >
            <ActivityFilterBar
              filter={filter}
              onChange={setFilter}
              onClear={clear}
            />
          </div>

          {/* Composer — sticky-top (unterhalb FilterBar, eigener z-index) */}
          <ActivityComposer />

          {/* Feed */}
          <div
            style={{
              flex: 1,
              minHeight: 0,
              overflowY: 'auto',
            }}
            data-testid="activity-feed"
          >
            {hasError && (
              <div
                data-testid="activity-error"
                style={{
                  padding: '12px 14px',
                  color: 'var(--text-error, #c0392b)',
                  fontSize: 13,
                }}
              >
                Fehler beim Laden: {activity.error?.message ?? 'unbekannt'}
              </div>
            )}

            {initialLoading && (
              <div
                data-testid="activity-loading"
                style={{
                  padding: 'var(--space-6, 16px)',
                  color: 'var(--text-tertiary, #888)',
                  fontSize: 13,
                }}
              >
                Lädt…
              </div>
            )}

            {isEmpty && (
              <div
                data-testid="activity-empty"
                style={{
                  padding: 'var(--space-6, 16px)',
                  color: 'var(--text-tertiary, #888)',
                  fontSize: 13,
                }}
              >
                Keine Aktivität
              </div>
            )}

            {!initialLoading && events.length > 0 && (
              <>
                {events.map((ev) => (
                  <ActivityEventCard
                    key={ev.event_id}
                    event={ev}
                    contactName={namesMap?.get(ev.contact_id)}
                  />
                ))}

                {/* IntersectionObserver-Sentinel (auto-load) +
                    sichtbarer „Mehr laden"-Button (a11y + happy-dom-fallback) */}
                <div
                  ref={sentinelRef}
                  data-testid="activity-feed-sentinel"
                  style={{
                    padding: '12px',
                    display: 'flex',
                    justifyContent: 'center',
                  }}
                >
                  {activity.hasNextPage ? (
                    <button
                      type="button"
                      onClick={() => activity.fetchNextPage()}
                      disabled={activity.isFetchingNextPage}
                      style={{
                        padding: '6px 14px',
                        borderRadius: 'var(--radius-pill, 9999px)',
                        border: '1px solid var(--border-primary)',
                        background: 'transparent',
                        color: 'var(--text-body)',
                        fontSize: 12,
                        fontWeight: 500,
                        cursor: activity.isFetchingNextPage
                          ? 'wait'
                          : 'pointer',
                      }}
                    >
                      {activity.isFetchingNextPage ? 'Lädt…' : 'Mehr laden'}
                    </button>
                  ) : (
                    <span
                      style={{
                        fontSize: 11,
                        color: 'var(--text-tertiary, #888)',
                      }}
                    >
                      Ende der Liste
                    </span>
                  )}
                </div>
              </>
            )}
          </div>
        </div>
      </div>
    </div>
  )
}
