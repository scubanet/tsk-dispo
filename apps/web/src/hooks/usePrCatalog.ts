import { useQuery } from '@tanstack/react-query'
import { fetchPrCatalog, type PrCatalogRow } from '@/lib/queries'

/**
 * React-Query hook around `fetchPrCatalog`. Loads the active German catalog
 * for one course-type kind (DM/IDC/EFRI/SPEI).
 *
 * Catalogs are versioned, edited rarely, and shared across every course of
 * that kind — `staleTime: 30 min` reflects that.
 *
 * Cache key: `['prCatalog', catalogKind]`.
 */
export function usePrCatalog(catalogKind: string | null | undefined, enabled: boolean = true) {
  return useQuery<PrCatalogRow | null, Error>({
    queryKey: ['prCatalog', catalogKind],
    queryFn: () => fetchPrCatalog(catalogKind as string),
    enabled: enabled && Boolean(catalogKind),
    staleTime: 30 * 60_000,
  })
}
