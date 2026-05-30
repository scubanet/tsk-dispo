// apps/web/src/hooks/useSendMessage.ts
// Sendet eine Nachricht über die comms-outbound Edge Function.
// Spec: docs/superpowers/specs/2026-05-29-comms-integration-unipile-design.md §6.2
import { useMutation, useQueryClient } from '@tanstack/react-query'
import { supabase } from '@/lib/supabase'
import type { CommsChannel } from '@/types/messaging'

export interface SendInput {
  contact_id: string
  channel: CommsChannel
  body: string
  subject?: string
}

export function useSendMessage(contactId: string) {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: async (input: SendInput) => {
      const { data, error } = await supabase.functions.invoke('comms-outbound', { body: input })
      if (error) throw error
      return data as { ok: boolean; provider_message_id: string }
    },
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['contact-timeline', contactId] })
      qc.invalidateQueries({ queryKey: ['global-activity'] })
    },
  })
}
