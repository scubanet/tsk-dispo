// supabase/functions/payments-create-intent/index.ts
// App-aufgerufen (verify_jwt = true): erzeugt einen Stripe-PaymentIntent für eine
// Rechnung und gibt das client_secret zurück. metadata.invoice_id verknüpft die
// spätere Webhook-Buchung (payments-webhook → payment_record_service).
// Aufruf: supabase.functions.invoke('payments-create-intent', { body: { invoice_id } }).
// Secrets: STRIPE_SECRET_KEY, SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY.
import { serve } from 'https://deno.land/std@0.224.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.0'
import Stripe from 'https://esm.sh/stripe@16.2.0?target=deno'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SERVICE_ROLE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const STRIPE_SECRET_KEY = Deno.env.get('STRIPE_SECRET_KEY')!

const stripe = new Stripe(STRIPE_SECRET_KEY, {
  apiVersion: '2024-06-20',
  httpClient: Stripe.createFetchHttpClient(),
})

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

    const { invoice_id } = await req.json().catch(() => ({}))
    if (!invoice_id) return json({ error: 'bad_request' }, 400)

    const admin = createClient(SUPABASE_URL, SERVICE_ROLE)
    const { data: inv } = await admin.from('invoices')
      .select('id, tenant_id, total, currency, status').eq('id', invoice_id).single()
    if (!inv) return json({ error: 'invoice_not_found' }, 404)
    if (inv.status === 'void' || inv.status === 'credited') return json({ error: 'invoice_not_payable' }, 409)

    const amount = Math.round(Number(inv.total) * 100)
    if (amount <= 0) return json({ error: 'amount_must_be_positive' }, 422)

    const intent = await stripe.paymentIntents.create({
      amount,
      currency: String(inv.currency).toLowerCase(),
      metadata: { invoice_id: inv.id, tenant_id: inv.tenant_id },
      automatic_payment_methods: { enabled: true },
    })

    return json({ client_secret: intent.client_secret, payment_intent_id: intent.id })
  } catch (e) {
    console.error('[payments-create-intent] exception', String((e as Error)?.message ?? e))
    return json({ error: 'exception', detail: String((e as Error)?.message ?? e) }, 500)
  }
})
