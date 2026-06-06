import { supabase } from '@/lib/supabase'

// Phase-1 Kundenfinanzen — Lesefunktionen + Checkout-RPC.
// Postgres `numeric` kommt als String über PostgREST → konsequent Number() casten.

export interface ContactFinanceSummary {
  open_invoice_balance: number
  store_credit_balance: number
  open_package_units: number
}
export interface ContactInvoice {
  id: string
  number: string | null
  status: string
  total: number
  currency: string
  issue_date: string | null
  due_date: string | null
  paid: number
  balance: number
}
export interface ContactPayment {
  id: string
  amount: number
  currency: string
  method: string
  kind: string
  received_at: string
}
export interface TaxRate { id: string; code: string; rate_pct: number }
export interface ContactFinance {
  summary: ContactFinanceSummary
  invoices: ContactInvoice[]
  payments: ContactPayment[]
}

type Num = number | string | null | undefined
const n = (v: Num): number => Number(v ?? 0)

export async function fetchContactFinance(contactId: string): Promise<ContactFinance> {
  const [summaryRes, invoicesRes, balancesRes, paymentsRes] = await Promise.all([
    supabase.from('v_contact_finance')
      .select('open_invoice_balance, store_credit_balance, open_package_units')
      .eq('contact_id', contactId).maybeSingle(),
    supabase.from('invoices')
      .select('id, number, status, total, currency, issue_date, due_date')
      .eq('contact_id', contactId).order('issue_date', { ascending: false }),
    supabase.from('v_invoice_balance')
      .select('invoice_id, paid, balance').eq('contact_id', contactId),
    supabase.from('payments')
      .select('id, amount, currency, method, kind, received_at')
      .eq('contact_id', contactId).order('received_at', { ascending: false }).limit(10),
  ])
  if (summaryRes.error) throw summaryRes.error
  if (invoicesRes.error) throw invoicesRes.error
  if (balancesRes.error) throw balancesRes.error
  if (paymentsRes.error) throw paymentsRes.error

  const balMap = new Map<string, { paid: number; balance: number }>()
  for (const b of (balancesRes.data ?? []) as Array<{ invoice_id: string; paid: Num; balance: Num }>) {
    balMap.set(b.invoice_id, { paid: n(b.paid), balance: n(b.balance) })
  }

  const s = (summaryRes.data ?? {}) as Partial<Record<keyof ContactFinanceSummary, Num>>

  return {
    summary: {
      open_invoice_balance: n(s.open_invoice_balance),
      store_credit_balance: n(s.store_credit_balance),
      open_package_units: n(s.open_package_units),
    },
    invoices: ((invoicesRes.data ?? []) as Array<{
      id: string; number: string | null; status: string; total: Num
      currency: string; issue_date: string | null; due_date: string | null
    }>).map((i) => ({
      id: i.id,
      number: i.number,
      status: i.status,
      total: n(i.total),
      currency: i.currency,
      issue_date: i.issue_date,
      due_date: i.due_date,
      paid: balMap.get(i.id)?.paid ?? 0,
      balance: balMap.get(i.id)?.balance ?? n(i.total),
    })),
    payments: ((paymentsRes.data ?? []) as Array<{
      id: string; amount: Num; currency: string; method: string; kind: string; received_at: string
    }>).map((p) => ({
      id: p.id,
      amount: n(p.amount),
      currency: p.currency,
      method: p.method,
      kind: p.kind,
      received_at: p.received_at,
    })),
  }
}

export async function fetchActiveTaxRates(): Promise<TaxRate[]> {
  const { data, error } = await supabase.from('tax_rates')
    .select('id, code, rate_pct').is('valid_to', null).order('code')
  if (error) throw error
  return ((data ?? []) as Array<{ id: string; code: string; rate_pct: Num }>)
    .map((r) => ({ id: r.id, code: r.code, rate_pct: n(r.rate_pct) }))
}

export interface CheckoutLine {
  description: string
  quantity: number
  unit_price: number
  discount_pct?: number
  tax_rate_id?: string | null
  item_type?: string
  item_ref_id?: string | null
  serial_unit_id?: string | null
}

export async function posCheckout(args: {
  contactId: string
  lines: CheckoutLine[]
  method: string
  pay: boolean
}): Promise<{ order_id: string; invoice_id: string }> {
  const { data, error } = await supabase.rpc('pos_checkout', {
    p_contact_id: args.contactId,
    p_lines: args.lines,
    p_method: args.method,
    p_pay: args.pay,
  })
  if (error) throw error
  return data as { order_id: string; invoice_id: string }
}
