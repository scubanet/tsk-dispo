import { supabase } from '@/lib/supabase'

// Phase-2 / M3 Verleih & Service — Lesefunktionen + RPC-Wrapper.
type Num = number | string | null | undefined
const n = (v: Num): number => Number(v ?? 0)

export interface RentalAsset {
  asset_id: string
  label: string
  asset_type: string
  status: string
  condition_grade: string | null
  next_service_due: string | null
  cert_due: string | null
  service_overdue: boolean
  cert_overdue: boolean
}
export async function fetchRentalAssets(): Promise<RentalAsset[]> {
  const { data, error } = await supabase.from('v_rental_assets_status')
    .select('asset_id, label, asset_type, status, condition_grade, next_service_due, cert_due, service_overdue, cert_overdue')
    .order('label')
  if (error) throw error
  return (data ?? []) as RentalAsset[]
}

export interface OpenRental {
  agreement_id: string
  person_id: string
  person_name: string
  out_at: string
  due_at: string | null
  asset_count: number
  overdue: boolean
}
export async function fetchOpenRentals(): Promise<OpenRental[]> {
  const { data, error } = await supabase.from('v_open_rentals')
    .select('agreement_id, person_id, out_at, due_at, asset_count, overdue')
    .order('out_at', { ascending: false })
  if (error) throw error
  const rows = (data ?? []) as Array<{ agreement_id: string; person_id: string; out_at: string; due_at: string | null; asset_count: Num; overdue: boolean }>
  const ids = [...new Set(rows.map((r) => r.person_id))]
  const names = new Map<string, string>()
  if (ids.length) {
    const { data: cs } = await supabase.from('contacts').select('id, display_name').in('id', ids)
    for (const c of (cs ?? []) as Array<{ id: string; display_name: string }>) names.set(c.id, c.display_name)
  }
  return rows.map((r) => ({
    agreement_id: r.agreement_id,
    person_id: r.person_id,
    person_name: names.get(r.person_id) ?? '—',
    out_at: r.out_at,
    due_at: r.due_at,
    asset_count: n(r.asset_count),
    overdue: r.overdue,
  }))
}

export interface ServiceJob {
  id: string
  type: string
  status: string
  description: string | null
  asset_id: string | null
  customer_person_id: string | null
  created_at: string
}
export async function fetchOpenServiceJobs(): Promise<ServiceJob[]> {
  const { data, error } = await supabase.from('service_jobs')
    .select('id, type, status, description, asset_id, customer_person_id, created_at')
    .not('status', 'in', '(done,picked_up)')
    .order('created_at', { ascending: false })
  if (error) throw error
  return (data ?? []) as ServiceJob[]
}

export interface FillLog {
  id: string
  gas: string
  mix_o2: number | null
  mix_he: number | null
  pressure_bar: number | null
  asset_id: string | null
  cylinder_ref: string | null
  cert_check_passed: boolean
  filled_at: string
}
export async function fetchRecentFills(): Promise<FillLog[]> {
  const { data, error } = await supabase.from('fill_logs')
    .select('id, gas, mix_o2, mix_he, pressure_bar, asset_id, cylinder_ref, cert_check_passed, filled_at')
    .order('filled_at', { ascending: false }).limit(20)
  if (error) throw error
  return ((data ?? []) as Array<{ id: string; gas: string; mix_o2: Num; mix_he: Num; pressure_bar: Num; asset_id: string | null; cylinder_ref: string | null; cert_check_passed: boolean; filled_at: string }>)
    .map((f) => ({
      id: f.id, gas: f.gas,
      mix_o2: f.mix_o2 == null ? null : n(f.mix_o2),
      mix_he: f.mix_he == null ? null : n(f.mix_he),
      pressure_bar: f.pressure_bar == null ? null : n(f.pressure_bar),
      asset_id: f.asset_id, cylinder_ref: f.cylinder_ref, cert_check_passed: f.cert_check_passed, filled_at: f.filled_at,
    }))
}

export interface PersonOption { id: string; name: string }
export async function searchPersons(q: string): Promise<PersonOption[]> {
  let query = supabase.from('contacts').select('id, display_name').eq('kind', 'person').order('display_name').limit(20)
  if (q.trim()) query = query.ilike('display_name', `%${q.trim()}%`)
  const { data, error } = await query
  if (error) throw error
  return ((data ?? []) as Array<{ id: string; display_name: string }>).map((c) => ({ id: c.id, name: c.display_name }))
}

export interface AssetInput {
  assetId?: string
  tenantId: string
  assetType: string
  label: string
  size?: string | null
  nextServiceDue?: string | null
  certDue?: string | null
}
export async function saveAsset(input: AssetInput): Promise<string> {
  if (input.assetId) {
    const { error } = await supabase.from('rental_assets').update({
      asset_type: input.assetType,
      label: input.label,
      size: input.size ?? null,
      next_service_due: input.nextServiceDue || null,
      cert_due: input.certDue || null,
    }).eq('id', input.assetId)
    if (error) throw error
    return input.assetId
  }
  const { data, error } = await supabase.from('rental_assets').insert({
    tenant_id: input.tenantId,
    asset_type: input.assetType,
    label: input.label,
    size: input.size ?? null,
    next_service_due: input.nextServiceDue || null,
    cert_due: input.certDue || null,
  }).select('id').single()
  if (error) throw error
  return (data as { id: string }).id
}

// ── RPC-Wrapper ───────────────────────────────────────────────────────────────
export async function rentalCheckout(args: { personId: string; assetIds: string[]; dueAt?: string | null; deposit?: number }): Promise<string> {
  const { data, error } = await supabase.rpc('rental_checkout', {
    p_person_id: args.personId, p_asset_ids: args.assetIds, p_due_at: args.dueAt ?? null, p_deposit: args.deposit ?? 0,
  })
  if (error) throw error
  return data as string
}
export async function rentalCheckin(agreementId: string): Promise<void> {
  const { error } = await supabase.rpc('rental_checkin', { p_agreement_id: agreementId })
  if (error) throw error
}
export async function serviceOpen(args: { type: string; assetId?: string | null; customerPersonId?: string | null; description?: string | null }): Promise<string> {
  const { data, error } = await supabase.rpc('service_open', {
    p_type: args.type, p_asset_id: args.assetId ?? null, p_customer_person_id: args.customerPersonId ?? null, p_description: args.description ?? null,
  })
  if (error) throw error
  return data as string
}
export async function serviceComplete(jobId: string, nextDue?: string | null): Promise<void> {
  const { error } = await supabase.rpc('service_complete', { p_job_id: jobId, p_next_due: nextDue ?? null })
  if (error) throw error
}
export async function fillLogCreate(args: { gas: string; pressureBar: number; certCheckPassed: boolean; assetId?: string | null; cylinderRef?: string | null; mixO2?: number | null; mixHe?: number | null }): Promise<string> {
  const { data, error } = await supabase.rpc('fill_log_create', {
    p_gas: args.gas, p_pressure_bar: args.pressureBar, p_cert_check_passed: args.certCheckPassed,
    p_asset_id: args.assetId ?? null, p_cylinder_ref: args.cylinderRef ?? null, p_mix_o2: args.mixO2 ?? null, p_mix_he: args.mixHe ?? null,
  })
  if (error) throw error
  return data as string
}
