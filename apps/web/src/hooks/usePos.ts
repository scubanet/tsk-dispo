import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { fetchWalkInContactId, searchSellableContacts } from '@/lib/posQueries'
import { posCheckout, type CheckoutLine } from '@/lib/financeQueries'

export function useWalkInContact() {
  return useQuery({
    queryKey: ['pos', 'walk-in'],
    queryFn: fetchWalkInContactId,
    staleTime: 5 * 60 * 1000,
  })
}

export function useContactSearch(q: string) {
  return useQuery({
    queryKey: ['pos', 'contact-search', q],
    queryFn: () => searchSellableContacts(q),
    enabled: q.trim().length >= 2,
  })
}

export function usePosCheckout() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: (args: { contactId: string; lines: CheckoutLine[]; method: string; pay: boolean }) =>
      posCheckout(args),
    // Nach dem Verkauf Bestand + Seriennummern neu laden (sonst zeigt das Grid
    // bis zu 60 s alten on_hand und eine verkaufte Seriennummer bleibt wählbar).
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['retail-catalog'] })
      qc.invalidateQueries({ queryKey: ['serials'] })
    },
  })
}
