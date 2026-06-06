import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { fetchContactFinance, fetchActiveTaxRates, posCheckout } from '@/lib/financeQueries'

/** Finanz-Übersicht eines Kontakts (Saldo, Guthaben, Pakete, Rechnungen, Zahlungen). */
export function useContactFinance(contactId: string | null | undefined) {
  return useQuery({
    queryKey: ['contact-finance', contactId],
    queryFn: () => fetchContactFinance(contactId as string),
    enabled: Boolean(contactId),
    staleTime: 60_000,
  })
}

/** Aktive MwSt-Sätze des Mandanten (für den Checkout-Dropdown). */
export function useActiveTaxRates() {
  return useQuery({
    queryKey: ['tax-rates'],
    queryFn: fetchActiveTaxRates,
    staleTime: 5 * 60_000,
  })
}

/** POS-Checkout: Order → Rechnung → (optional) Zahlung in einem RPC. */
export function usePosCheckout(contactId: string) {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: posCheckout,
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['contact-finance', contactId] })
    },
  })
}
