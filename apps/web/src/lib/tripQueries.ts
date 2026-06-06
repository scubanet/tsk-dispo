import { supabase } from '@/lib/supabase'

// Phase-2 / M4 Trips & Buchungen — Lesefunktionen + RPC-Wrapper.
type Num = number | string | null | undefined
const n = (v: Num): number => Number(v ?? 0)

export interface Departure {
  departure_id: string
  name: string
  datetime: string
  status: string
  capacity: number
  booked: number
  waitlisted: number
  free: number
  meeting_point: string | null
}
export async function fetchDepartures(): Promise<Departure[]> {
  const { data, error } = await supabase.from('v_trip_departures')
    .select('departure_id, name, datetime, status, capacity, booked, waitlisted, free, meeting_point')
    .order('datetime', { ascending: true })
  if (error) throw error
  return ((data ?? []) as Array<Record<string, unknown>>).map((d) => ({
    departure_id: String(d.departure_id),
    name: String(d.name ?? ''),
    datetime: String(d.datetime ?? ''),
    status: String(d.status ?? ''),
    capacity: n(d.capacity as Num),
    booked: n(d.booked as Num),
    waitlisted: n(d.waitlisted as Num),
    free: n(d.free as Num),
    meeting_point: (d.meeting_point as string) ?? null,
  }))
}

export interface DiveSite {
  id: string
  name: string
  region: string | null
  min_cert_rank: number
  difficulty: string | null
  max_depth_m: number | null
}
export async function fetchDiveSites(): Promise<DiveSite[]> {
  const { data, error } = await supabase.from('dive_sites')
    .select('id, name, region, min_cert_rank, difficulty, max_depth_m').eq('is_active', true).order('name')
  if (error) throw error
  return ((data ?? []) as Array<{ id: string; name: string; region: string | null; min_cert_rank: Num; difficulty: string | null; max_depth_m: Num }>)
    .map((s) => ({ id: s.id, name: s.name, region: s.region, min_cert_rank: n(s.min_cert_rank), difficulty: s.difficulty, max_depth_m: s.max_depth_m == null ? null : n(s.max_depth_m) }))
}

export interface ManifestRow {
  booking_id: string
  person_id: string
  person_name: string
  status: string
  cert_check: string
  needs_rental: boolean
  needs_guide: boolean
  payment_status: string
}
export async function fetchManifest(departureId: string): Promise<ManifestRow[]> {
  const { data, error } = await supabase.from('v_trip_manifest')
    .select('booking_id, person_id, person_name, status, cert_check, needs_rental, needs_guide, payment_status, booked_at')
    .eq('departure_id', departureId).order('booked_at')
  if (error) throw error
  return (data ?? []) as ManifestRow[]
}

// ── Mutationen (Stammdaten) ───────────────────────────────────────────────────
export interface SiteInput { siteId?: string; tenantId: string; name: string; region?: string | null; minCertRank: number; difficulty?: string | null; maxDepth?: number | null }
export async function saveSite(input: SiteInput): Promise<string> {
  const fields = {
    name: input.name, region: input.region ?? null, min_cert_rank: input.minCertRank,
    difficulty: input.difficulty || null, max_depth_m: input.maxDepth ?? null,
  }
  if (input.siteId) {
    const { error } = await supabase.from('dive_sites').update(fields).eq('id', input.siteId)
    if (error) throw error
    return input.siteId
  }
  const { data, error } = await supabase.from('dive_sites').insert({ tenant_id: input.tenantId, ...fields }).select('id').single()
  if (error) throw error
  return (data as { id: string }).id
}

export interface DepartureInput { departureId?: string; tenantId: string; name: string; datetimeIso: string; capacity: number; meetingPoint?: string | null; siteIds: string[] }
export async function saveDeparture(input: DepartureInput): Promise<string> {
  if (input.departureId) {
    const { error } = await supabase.from('trip_departures').update({
      name: input.name, datetime: input.datetimeIso, capacity: input.capacity, meeting_point: input.meetingPoint ?? null,
    }).eq('id', input.departureId)
    if (error) throw error
    return input.departureId
  }
  const { data, error } = await supabase.from('trip_departures').insert({
    tenant_id: input.tenantId, name: input.name, datetime: input.datetimeIso, capacity: input.capacity, meeting_point: input.meetingPoint ?? null,
  }).select('id').single()
  if (error) throw error
  const depId = (data as { id: string }).id
  if (input.siteIds.length) {
    const { error: le } = await supabase.from('trip_departure_sites')
      .insert(input.siteIds.map((sid, i) => ({ tenant_id: input.tenantId, departure_id: depId, site_id: sid, ord: i + 1 })))
    if (le) throw le
  }
  return depId
}

// ── RPC-Wrapper ───────────────────────────────────────────────────────────────
export interface BookResult { booking_id: string; status: string; cert_check: string }
export async function tripBook(args: { departureId: string; personId: string; certRank: number; override: boolean; needsRental: boolean; needsGuide: boolean }): Promise<BookResult> {
  const { data, error } = await supabase.rpc('trip_book', {
    p_departure_id: args.departureId, p_person_id: args.personId, p_diver_cert_rank: args.certRank,
    p_override: args.override, p_needs_rental: args.needsRental, p_needs_guide: args.needsGuide,
  })
  if (error) throw error
  return data as BookResult
}
export async function tripCancelBooking(bookingId: string): Promise<void> {
  const { error } = await supabase.rpc('trip_cancel_booking', { p_booking_id: bookingId })
  if (error) throw error
}
export async function tripCheckin(bookingId: string, attended: boolean): Promise<void> {
  const { error } = await supabase.rpc('trip_checkin', { p_booking_id: bookingId, p_attended: attended })
  if (error) throw error
}
