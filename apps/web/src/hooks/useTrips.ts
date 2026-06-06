import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import {
  fetchDepartures, fetchDiveSites, fetchManifest,
  saveSite, saveDeparture, tripBook, tripCancelBooking, tripCheckin,
} from '@/lib/tripQueries'

export function useDepartures() {
  return useQuery({ queryKey: ['trip-departures'], queryFn: fetchDepartures, staleTime: 30_000 })
}
export function useDiveSites() {
  return useQuery({ queryKey: ['dive-sites'], queryFn: fetchDiveSites, staleTime: 5 * 60_000 })
}
export function useManifest(departureId: string | null | undefined) {
  return useQuery({
    queryKey: ['manifest', departureId],
    queryFn: () => fetchManifest(departureId as string),
    enabled: Boolean(departureId),
    staleTime: 15_000,
  })
}

function useInvalidateTrips() {
  const qc = useQueryClient()
  return (departureId?: string) => {
    qc.invalidateQueries({ queryKey: ['trip-departures'] })
    qc.invalidateQueries({ queryKey: ['dive-sites'] })
    if (departureId) qc.invalidateQueries({ queryKey: ['manifest', departureId] })
    else qc.invalidateQueries({ queryKey: ['manifest'] })
  }
}

export function useSaveSite() {
  const inv = useInvalidateTrips()
  return useMutation({ mutationFn: saveSite, onSuccess: () => inv() })
}
export function useSaveDeparture() {
  const inv = useInvalidateTrips()
  return useMutation({ mutationFn: saveDeparture, onSuccess: () => inv() })
}
export function useTripBook(departureId: string) {
  const inv = useInvalidateTrips()
  return useMutation({ mutationFn: tripBook, onSuccess: () => inv(departureId) })
}
export function useTripCancel(departureId: string) {
  const inv = useInvalidateTrips()
  return useMutation({ mutationFn: tripCancelBooking, onSuccess: () => inv(departureId) })
}
export function useTripCheckin(departureId: string) {
  const inv = useInvalidateTrips()
  return useMutation({
    mutationFn: (vars: { bookingId: string; attended: boolean }) => tripCheckin(vars.bookingId, vars.attended),
    onSuccess: () => inv(departureId),
  })
}
