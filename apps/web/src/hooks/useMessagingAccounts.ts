// apps/web/src/hooks/useMessagingAccounts.ts
// Lädt verbundene Messaging-Konten und startet den Hosted-Auth-Flow.
// Spec: docs/superpowers/specs/2026-05-29-comms-integration-unipile-design.md §6.2
import { useMutation, useQuery } from '@tanstack/react-query'
import { supabase } from '@/lib/supabase'
import type { MessagingAccount, CommsChannel } from '@/types/messaging'

export function useMessagingAccounts() {
  return useQuery({
    queryKey: ['messaging-accounts'],
    queryFn: async (): Promise<MessagingAccount[]> => {
      const { data, error } = await supabase
        .from('messaging_accounts')
        .select('*')
        .order('connected_at', { ascending: false })
      if (error) throw error
      return (data ?? []) as MessagingAccount[]
    },
  })
}

/** Startet den Hosted-Auth-Flow: holt den Link und leitet weiter. */
export function useConnectAccount() {
  return useMutation({
    mutationFn: async (channel: CommsChannel) => {
      const { data, error } = await supabase.functions.invoke('comms-connect', { body: { channel } })
      if (error) throw error
      const url = (data as { url?: string })?.url
      if (!url) throw new Error('Kein Auth-Link erhalten')
      return url
    },
    onSuccess: (url) => { window.location.href = url },
  })
}
