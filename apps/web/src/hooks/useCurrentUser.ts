// apps/web/src/hooks/useCurrentUser.ts
//
// Phase G Phase 5 Task 4 — simpler React-Query-Wrapper um `fetchCurrentUser`.
//
// Genutzt vom ActivityScreen (für owner_scope='mine' → actorId-Lookup) und
// potentiell von künftigen Screens, die wissen müssen, wer eingeloggt ist.
//
// Cache: `['current-user']` — global, weil der eingeloggte User bei
// app-lifetime stabil ist. Kein staleTime nötig (Default 0 = refetch on
// mount); der HomeShell mountet einmalig im App-Root, alle weiteren Aufrufe
// kriegen den Cache.
import { useQuery } from '@tanstack/react-query'
import { fetchCurrentUser, type CurrentUser } from '@/lib/auth'

export function useCurrentUser() {
  return useQuery<CurrentUser | null, Error>({
    queryKey: ['current-user'],
    queryFn: fetchCurrentUser,
  })
}
