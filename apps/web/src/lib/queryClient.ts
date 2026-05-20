import { QueryClient } from '@tanstack/react-query'

/**
 * Singleton TanStack Query client.
 *
 * Defaults chosen to match the data-freshness expectations of an ops dashboard:
 *
 * - `staleTime: 30s` — most ATOLL data (courses, assignments, contacts) doesn't
 *   change second-by-second. 30 s of cache + dedup is the sweet spot between
 *   freshness and request volume. This intentionally mirrors the debounce window
 *   already used in `AtollEventLoader` so the two layers compose cleanly.
 * - `gcTime: 5 min` — keep evicted queries around for 5 minutes so navigating
 *   away and back doesn't refetch on hot paths.
 * - `retry: 1` — one quiet retry on transient failure; beyond that, surface
 *   the error to the user (the ErrorBoundary or local error UI takes over).
 * - `refetchOnWindowFocus: true` — when the user tabs back to ATOLL after
 *   working in another window, stale data refreshes automatically.
 * - `refetchOnReconnect: true` — auto-recover after offline / patchy signal
 *   (relevant at TSK lakeside sites).
 *
 * Per-query overrides are encouraged: a `useReadOnlyConstants()`-style hook
 * can set `staleTime: Infinity`, while a `useLiveCounts()`-style hook can
 * lower `staleTime` to 5 s.
 */
export const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 30_000,
      gcTime: 5 * 60_000,
      retry: 1,
      refetchOnWindowFocus: true,
      refetchOnReconnect: true,
    },
    mutations: {
      retry: 0,
    },
  },
})
