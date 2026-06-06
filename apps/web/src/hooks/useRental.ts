import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import {
  fetchRentalAssets, fetchOpenRentals, fetchOpenServiceJobs, fetchRecentFills, searchPersons,
  saveAsset, rentalCheckout, rentalCheckin, serviceOpen, serviceComplete, fillLogCreate,
} from '@/lib/rentalQueries'

export function useRentalAssets() {
  return useQuery({ queryKey: ['rental-assets'], queryFn: fetchRentalAssets, staleTime: 60_000 })
}
export function useOpenRentals() {
  return useQuery({ queryKey: ['open-rentals'], queryFn: fetchOpenRentals, staleTime: 30_000 })
}
export function useOpenServiceJobs() {
  return useQuery({ queryKey: ['service-jobs'], queryFn: fetchOpenServiceJobs, staleTime: 30_000 })
}
export function useRecentFills() {
  return useQuery({ queryKey: ['fill-logs'], queryFn: fetchRecentFills, staleTime: 30_000 })
}
export function useSearchPersons(q: string) {
  return useQuery({ queryKey: ['persons', q], queryFn: () => searchPersons(q), staleTime: 30_000 })
}

function useInvalidateRental() {
  const qc = useQueryClient()
  return () => {
    qc.invalidateQueries({ queryKey: ['rental-assets'] })
    qc.invalidateQueries({ queryKey: ['open-rentals'] })
    qc.invalidateQueries({ queryKey: ['service-jobs'] })
    qc.invalidateQueries({ queryKey: ['fill-logs'] })
  }
}

export function useSaveAsset() {
  const inv = useInvalidateRental()
  return useMutation({ mutationFn: saveAsset, onSuccess: inv })
}
export function useRentalCheckout() {
  const inv = useInvalidateRental()
  return useMutation({ mutationFn: rentalCheckout, onSuccess: inv })
}
export function useRentalCheckin() {
  const inv = useInvalidateRental()
  return useMutation({ mutationFn: rentalCheckin, onSuccess: inv })
}
export function useServiceOpen() {
  const inv = useInvalidateRental()
  return useMutation({ mutationFn: serviceOpen, onSuccess: inv })
}
export function useServiceComplete() {
  const inv = useInvalidateRental()
  return useMutation({ mutationFn: (vars: { jobId: string; nextDue?: string | null }) => serviceComplete(vars.jobId, vars.nextDue), onSuccess: inv })
}
export function useFillLogCreate() {
  const inv = useInvalidateRental()
  return useMutation({ mutationFn: fillLogCreate, onSuccess: inv })
}
