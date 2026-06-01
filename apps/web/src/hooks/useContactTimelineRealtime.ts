// apps/web/src/hooks/useContactTimelineRealtime.ts
//
// Realtime-Kanal für die Kontakt-Timeline. Abonniert INSERT/UPDATE auf
// contact_events des offenen Kontakts und invalidiert die Timeline-Query, damit
// vor allem EINGEHENDE Nachrichten (serverseitig per Webhook eingefügt) ohne
// Reload erscheinen. Eigene Sends/Deletes invalidieren bereits über ihre
// Mutation-Hooks — hier geht es um die server-seitig erzeugten Events.
//
// RLS bleibt aktiv: contact_events ist in der supabase_realtime-Publication
// (Migration 0130), und Realtime liefert nur Zeilen, die der Nutzer sehen darf.
import { useEffect } from 'react'
import { useQueryClient } from '@tanstack/react-query'
import { supabase } from '@/lib/supabase'

export function useContactTimelineRealtime(contactId: string) {
  const qc = useQueryClient()

  useEffect(() => {
    // Realtime ist best-effort: ohne contactId — oder wenn der Supabase-Client
    // keinen channel() bereitstellt (z.B. in Unit-Tests mit Teil-Mock) — läuft
    // die Timeline einfach ohne Live-Update weiter, statt beim Render zu crashen.
    if (!contactId || typeof supabase.channel !== 'function') return

    const invalidate = () => {
      qc.invalidateQueries({ queryKey: ['contact-timeline', contactId] })
      qc.invalidateQueries({ queryKey: ['global-activity'] })
    }

    const filter = `contact_id=eq.${contactId}`
    const channel = supabase
      .channel(`contact_events:${contactId}`)
      .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'contact_events', filter }, invalidate)
      .on('postgres_changes', { event: 'UPDATE', schema: 'public', table: 'contact_events', filter }, invalidate)
      .subscribe()

    return () => {
      void supabase.removeChannel(channel)
    }
  }, [contactId, qc])
}
