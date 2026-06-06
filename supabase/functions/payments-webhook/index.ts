// supabase/functions/payments-webhook/index.ts
// Stripe-Webhook: bucht bei payment_intent.succeeded eine Zahlung über die
// service-role-only RPC payment_record_service(). Signatur wird gegen das
// Stripe-Webhook-Secret geprüft (verify_jwt = false in config.toml — Stripe
// trägt keinen Supabase-JWT, die Signatur IST die Authentisierung).
// Idempotenz: payment_record_service dedupliziert über provider_ref.
//
// PaymentIntent muss metadata.invoice_id tragen (gesetzt in payments-create-intent).
// Secrets: STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET, SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY.
import { serve } from 'https://deno.land/std@0.224.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.0'
import Stripe from 'https://esm.sh/stripe@16.2.0?target=deno'

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!
const SERVICE_ROLE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
const STRIPE_SECRET_KEY = Deno.env.get('STRIPE_SECRET_KEY')!
const STRIPE_WEBHOOK_SECRET = Deno.env.get('STRIPE_WEBHOOK_SECRET')!

const stripe = new Stripe(STRIPE_SECRET_KEY, {
  apiVersion: '2024-06-20',
  httpClient: Stripe.createFetchHttpClient(),
})
const cryptoProvider = Stripe.createSubtleCryptoProvider()

serve(async (req) => {
  if (req.method !== 'POST') return new Response('method_not_allowed', { status: 405 })

  const sig = req.headers.get('stripe-signature')
  if (!sig) return new Response('missing_signature', { status: 400 })

  const raw = await req.text()
  let event: Stripe.Event
  try {
    event = await stripe.webhooks.constructEventAsync(raw, sig, STRIPE_WEBHOOK_SECRET, undefined, cryptoProvider)
  } catch (e) {
    return new Response(`invalid_signature: ${String((e as Error)?.message ?? e)}`, { status: 400 })
  }

  try {
    if (event.type === 'payment_intent.succeeded') {
      const pi = event.data.object as Stripe.PaymentIntent
      const invoiceId = pi.metadata?.invoice_id
      if (!invoiceId) return new Response('ok (no invoice_id in metadata)', { status: 200 })

      // Stripe-Beträge sind in der kleinsten Währungseinheit (CHF/EUR: Rappen/Cents).
      const amount = (pi.amount_received ?? pi.amount) / 100

      const admin = createClient(SUPABASE_URL, SERVICE_ROLE)
      const { error } = await admin.rpc('payment_record_service', {
        p_invoice_id: invoiceId,
        p_method: 'card',
        p_amount: amount,
        p_provider: 'stripe',
        p_provider_ref: pi.id,
      })
      if (error) {
        // 500 → Stripe wiederholt den Webhook (idempotent dank provider_ref).
        console.error('[payments-webhook] payment_record_service failed', error.message)
        return new Response(`db_error: ${error.message}`, { status: 500 })
      }
    }
    // Unbehandelte Event-Typen quittieren wir mit 200, damit Stripe nicht retryt.
    return new Response('ok', { status: 200 })
  } catch (e) {
    console.error('[payments-webhook] exception', String((e as Error)?.message ?? e))
    return new Response('exception', { status: 500 })
  }
})
