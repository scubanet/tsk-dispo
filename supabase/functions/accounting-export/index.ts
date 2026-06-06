// supabase/functions/accounting-export/index.ts
// App-aufgerufen (verify_jwt = true): exportiert eine Rechnung nach Bexio und
// schreibt die Bexio-Beleg-ID zurück in invoices.accounting_export_ref.
// Provider-neutraler Port "AccountingExport" — hier die Bexio-Referenzimplementierung;
// DATEV/Xero wären alternative Implementierungen derselben Signatur.
//
// Aufruf: supabase.functions.invoke('accounting-export', { body: { invoice_id, bexio_contact_id? } }).
// Secrets: BEXIO_API_TOKEN, BEXIO_USER_ID, optional BEXIO_TAX_ID / BEXIO_ACCOUNT_ID,
//          SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY.
//
// HINWEIS (Scaffold): Bexio braucht tenant-spezifische IDs. Das Mapping
// (Bexio-contact_id je Kunde, Konten-/Steuer-IDs je Position) gehört perspektivisch
// in eine bexio_config-Tabelle pro Tenant. Unten als TODO markiert; fehlt das
// Mapping, antwortet die Funktion mit 422 'bexio_mapping_missing'.
import { serve } from 'https://deno.land/std@0.224.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.0'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SERVICE_ROLE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const BEXIO_API_TOKEN = Deno.env.get('BEXIO_API_TOKEN')!
const BEXIO_USER_ID = Deno.env.get('BEXIO_USER_ID') // numerisch, Bexio-Benutzer
const BEXIO_TAX_ID = Deno.env.get('BEXIO_TAX_ID')   // TODO: pro Steuersatz/Tenant mappen
const BEXIO_ACCOUNT_ID = Deno.env.get('BEXIO_ACCOUNT_ID') // TODO: Ertragskonto pro Position/Tenant

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}
const json = (b: unknown, s = 200) =>
  new Response(JSON.stringify(b), { status: s, headers: { ...corsHeaders, 'content-type': 'application/json' } })

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (req.method !== 'POST') return json({ error: 'method_not_allowed' }, 405)

  try {
    const supa = createClient(SUPABASE_URL, Deno.env.get('SUPABASE_ANON_KEY')!, {
      global: { headers: { Authorization: req.headers.get('Authorization') ?? '' } },
    })
    const { data: { user } } = await supa.auth.getUser()
    if (!user) return json({ error: 'unauthorized' }, 401)

    const { invoice_id, bexio_contact_id } = await req.json().catch(() => ({}))
    if (!invoice_id) return json({ error: 'bad_request' }, 400)

    const admin = createClient(SUPABASE_URL, SERVICE_ROLE)

    const { data: inv } = await admin.from('invoices')
      .select('id, number, status, total, currency, issue_date, due_date, accounting_export_ref, contact_id')
      .eq('id', invoice_id).single()
    if (!inv) return json({ error: 'invoice_not_found' }, 404)

    // Idempotenz: bereits exportiert → bestehende Beleg-ID zurückgeben.
    if (inv.accounting_export_ref) {
      return json({ ok: true, already_exported: true, bexio_id: inv.accounting_export_ref })
    }

    // ── Tenant-Mapping (TODO: aus bexio_config statt Payload/Env) ────────────────
    const contactId = bexio_contact_id ?? null
    if (!contactId || !BEXIO_USER_ID) {
      return json({
        error: 'bexio_mapping_missing',
        needed: ['bexio_contact_id (Bexio-Kontakt des Kunden)', 'BEXIO_USER_ID (Secret)'],
      }, 422)
    }

    const { data: lines } = await admin.from('invoice_lines')
      .select('description, quantity, unit_price, tax_rate_pct, line_total').eq('invoice_id', invoice_id)

    // deno-lint-ignore no-explicit-any
    const positions = (lines ?? []).map((l: any) => ({
      type: 'KbPositionCustom',
      text: l.description,
      amount: String(l.unit_price),
      quantity: String(l.quantity),
      tax_id: BEXIO_TAX_ID ? Number(BEXIO_TAX_ID) : null,        // TODO: aus tax_rate_pct mappen
      account_id: BEXIO_ACCOUNT_ID ? Number(BEXIO_ACCOUNT_ID) : null, // TODO: Ertragskonto je Position
    }))

    const payload = {
      title: inv.number ?? undefined,
      contact_id: Number(contactId),
      user_id: Number(BEXIO_USER_ID),
      is_valid_from: inv.issue_date,
      is_valid_to: inv.due_date ?? inv.issue_date,
      mwst_type: 0,            // 0 = inkl. MwSt; TODO: tenant-abhängig
      mwst_is_net: true,
      show_position_taxes: true,
      positions,
    }

    const res = await fetch('https://api.bexio.com/2.0/kb_invoice', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${BEXIO_API_TOKEN}`,
        'Accept': 'application/json',
        'content-type': 'application/json',
      },
      body: JSON.stringify(payload),
    })
    const text = await res.text()
    if (!res.ok) {
      console.error('[accounting-export] bexio_failed', res.status, text)
      return json({ error: 'bexio_failed', http: res.status, detail: text }, 502)
    }
    const bexioId = String(JSON.parse(text).id)

    await admin.from('invoices').update({ accounting_export_ref: bexioId }).eq('id', invoice_id)

    return json({ ok: true, bexio_id: bexioId })
  } catch (e) {
    console.error('[accounting-export] exception', String((e as Error)?.message ?? e))
    return json({ error: 'exception', detail: String((e as Error)?.message ?? e) }, 500)
  }
})
