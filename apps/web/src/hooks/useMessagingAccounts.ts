// apps/web/src/hooks/useMessagingAccounts.ts
// Lädt die verbundenen Messaging-Konten — genutzt von den Composern für die
// Send-vs-Log-Entscheidung. (Der frühere Unipile-Hosted-Auth-Flow wurde mit
// dem Wechsel auf 360dialog/Resend entfernt.)
import { useQuery } from '@tanstack/react-query'
import { supabase } from '@/lib/supabase'
import type { MessagingAccount } from '@/types/messaging'

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
