// deno-lint-ignore-file no-explicit-any
import { serve } from 'https://deno.land/std@0.190.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

interface WebhookPayload {
  type: 'INSERT' | 'UPDATE' | 'DELETE'
  table: string
  record: any
  old_record: any | null
  schema: string
}

const RESEND_KEY = Deno.env.get('RESEND_API_KEY')
const FROM_EMAIL = Deno.env.get('NOTIFICATION_FROM_EMAIL') ?? 'no-reply@course-director.ch'
const APP_URL = Deno.env.get('APP_URL') ?? 'https://dispo.course-director.ch'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

async function sendEmail(to: string, subject: string, html: string) {
  if (!RESEND_KEY) {
    console.warn('[send-notification] RESEND_API_KEY missing — skipping email')
    return { skipped: true }
  }
  const res = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${RESEND_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ from: FROM_EMAIL, to, subject, html }),
  })
  if (!res.ok) {
    const text = await res.text()
    console.error('[send-notification] Resend error', res.status, text)
    return { error: text }
  }
  return await res.json()
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  )

  let payload: WebhookPayload
  try {
    payload = await req.json()
  } catch {
    return new Response('Invalid JSON', { status: 400, headers: corsHeaders })
  }

  if (payload.table !== 'course_assignments') {
    return new Response('ignored', { headers: corsHeaders })
  }

  const respond = (data: unknown) =>
    new Response(JSON.stringify(data), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })

  // INSERT — neuer Einsatz
  if (payload.type === 'INSERT') {
    const a = payload.record
    const { data: inst } = await supabase
      .from('instructors')
      .select('name, email')
      .eq('id', a.instructor_id)
      .maybeSingle()
    const { data: course } = await supabase
      .from('courses')
      .select('title, start_date, course_types(code, label)')
      .eq('id', a.course_id)
      .maybeSingle()

    if (!inst?.email || !course) return respond({ skipped: 'missing email or course' })

    const result = await sendEmail(
      inst.email,
      `Neuer Einsatz: ${course.title}`,
      `<div style="font-family: -apple-system, sans-serif; max-width: 480px; margin: 0 auto; padding: 24px;">
        <h2 style="color: #0A84FF; margin: 0 0 8px;">Neuer Einsatz zugewiesen</h2>
        <p style="color: #666; margin: 0 0 24px;">Hi ${inst.name?.split(' ')[0] ?? ''},</p>
        <div style="background: #f5f5f7; padding: 16px; border-radius: 12px; border-left: 3px solid #0A84FF;">
          <div style="font-weight: 600; font-size: 16px;">${course.title}</div>
          <div style="color: #666; margin-top: 4px;">
            ${(course as any).course_types?.label ?? '—'} · ${course.start_date}
          </div>
          <div style="color: #666; margin-top: 4px;">
            Rolle: <strong>${a.role}</strong>
          </div>
        </div>
        <p style="margin: 24px 0 8px;">
          <a href="${APP_URL}/heute" style="background: #0A84FF; color: white; padding: 10px 18px; border-radius: 999px; text-decoration: none; display: inline-block;">
            In TSK Dispo öffnen
          </a>
        </p>
        <p style="color: #999; font-size: 12px; margin-top: 32px;">
          TSK Dispo · automatische Nachricht · keine Antwort nötig
        </p>
      </div>`,
    )
    return respond({ ok: true, sent_to: inst.email, result })
  }

  // DELETE — Einsatz gestrichen
  if (payload.type === 'DELETE') {
    const a = payload.old_record
    const { data: inst } = await supabase
      .from('instructors')
      .select('name, email')
      .eq('id', a.instructor_id)
      .maybeSingle()
    const { data: course } = await supabase
      .from('courses')
      .select('title, start_date')
      .eq('id', a.course_id)
      .maybeSingle()

    if (!inst?.email || !course) return respond({ skipped: 'missing email or course' })

    const result = await sendEmail(
      inst.email,
      `Einsatz storniert: ${course.title}`,
      `<div style="font-family: -apple-system, sans-serif; max-width: 480px; margin: 0 auto; padding: 24px;">
        <h2 style="color: #FF9500; margin: 0 0 8px;">Einsatz storniert</h2>
        <p style="color: #666; margin: 0 0 24px;">Hi ${inst.name?.split(' ')[0] ?? ''},</p>
        <div style="background: #f5f5f7; padding: 16px; border-radius: 12px; border-left: 3px solid #FF9500;">
          <div style="font-weight: 600; font-size: 16px;">${course.title}</div>
          <div style="color: #666; margin-top: 4px;">War: ${course.start_date}</div>
        </div>
        <p style="color: #999; font-size: 12px; margin-top: 32px;">
          TSK Dispo · automatische Nachricht
        </p>
      </div>`,
    )
    return respond({ ok: true, sent_to: inst.email, result })
  }

  return respond({ ignored: payload.type })
})
