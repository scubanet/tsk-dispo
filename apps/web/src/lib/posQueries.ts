import { supabase } from '@/lib/supabase'

// Laufkundschaft-Sammelkontakt (Tag walk_in, per Seed-Migration angelegt).
export async function fetchWalkInContactId(): Promise<string | null> {
  const { data, error } = await supabase.from('contacts')
    .select('id').contains('tags', ['walk_in']).limit(1).maybeSingle()
  if (error) throw error
  return (data as { id: string } | null)?.id ?? null
}

export interface SellableContact { id: string; name: string }

// Kontaktsuche fuer die Kundenauswahl an der Kasse (Name/Anzeigename).
export async function searchSellableContacts(q: string): Promise<SellableContact[]> {
  const term = q.trim()
  if (term.length < 2) return []
  const { data, error } = await supabase.from('contacts')
    .select('id, display_name, first_name, last_name')
    .or(`display_name.ilike.%${term}%,first_name.ilike.%${term}%,last_name.ilike.%${term}%`)
    .is('archived_at', null)
    .limit(20)
  if (error) throw error
  return ((data ?? []) as Array<{ id: string; display_name: string | null; first_name: string | null; last_name: string | null }>)
    .map((c) => ({
      id: c.id,
      name: c.display_name ?? [c.first_name, c.last_name].filter(Boolean).join(' ') ?? '—',
    }))
}

export async function fetchInvoiceNumber(invoiceId: string): Promise<string | null> {
  const { data, error } = await supabase.from('invoices').select('number').eq('id', invoiceId).maybeSingle()
  if (error) throw error
  return (data as { number: string | null } | null)?.number ?? null
}
