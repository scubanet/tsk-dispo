import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import {
  fetchCatalog, fetchAvailableSerials, fetchCategories, fetchCurrentTenantId,
  saveProduct, adjustStock,
} from '@/lib/retailQueries'

/** Mandant des eingeloggten Users (für tenant_id bei Produkt-Inserts). */
export function useCurrentTenant() {
  return useQuery({ queryKey: ['current-tenant'], queryFn: fetchCurrentTenantId, staleTime: 30 * 60_000 })
}

/** Produktkatalog mit Bestand (on_hand) + Low-Stock-Flag. */
export function useCatalog() {
  return useQuery({ queryKey: ['retail-catalog'], queryFn: fetchCatalog, staleTime: 60_000 })
}

/** Verfügbare Seriennummern (in_stock) einer Variante. */
export function useAvailableSerials(variantId: string | null | undefined) {
  return useQuery({
    queryKey: ['serials', variantId],
    queryFn: () => fetchAvailableSerials(variantId as string),
    enabled: Boolean(variantId),
    staleTime: 30_000,
  })
}

export function useProductCategories() {
  return useQuery({ queryKey: ['product-categories'], queryFn: fetchCategories, staleTime: 10 * 60_000 })
}

export function useSaveProduct() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: saveProduct,
    onSuccess: () => qc.invalidateQueries({ queryKey: ['retail-catalog'] }),
  })
}

export function useAdjustStock() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: (vars: { variantId: string; qty: number; reason?: string }) =>
      adjustStock(vars.variantId, vars.qty, vars.reason),
    onSuccess: () => qc.invalidateQueries({ queryKey: ['retail-catalog'] }),
  })
}
