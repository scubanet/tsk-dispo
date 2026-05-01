// deno-lint-ignore-file no-explicit-any
import { serve } from 'https://deno.land/std@0.190.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { parseWorkbook } from './parser.ts'
import { applyMappingsAndPlan, writePlanToDatabase } from './writer.ts'

interface RequestBody {
  action: 'preview' | 'dryrun' | 'apply'
  storage_path: string
  mappings?: Record<string, string>
}

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  const auth = req.headers.get('Authorization')
  if (!auth) {
    return new Response('Unauthorized', { status: 401, headers: corsHeaders })
  }

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    { global: { headers: { Authorization: auth } } },
  )

  // Verify caller is dispatcher
  const { data: userData } = await supabase.auth.getUser()
  if (!userData.user) {
    return new Response('Forbidden', { status: 403, headers: corsHeaders })
  }

  const { data: instructor } = await supabase
    .from('instructors')
    .select('role')
    .eq('auth_user_id', userData.user.id)
    .maybeSingle()

  if (instructor?.role !== 'dispatcher') {
    return new Response('Dispatcher only', { status: 403, headers: corsHeaders })
  }

  let body: RequestBody
  try {
    body = await req.json()
  } catch {
    return new Response('Invalid JSON', { status: 400, headers: corsHeaders })
  }

  const respond = (payload: unknown, status = 200) =>
    new Response(JSON.stringify(payload), {
      status,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })

  // Download file
  const { data: file, error: dlErr } = await supabase.storage
    .from('imports')
    .download(body.storage_path)
  if (dlErr || !file) {
    return respond({ error: dlErr?.message ?? 'Download fehlgeschlagen' }, 400)
  }
  const buffer = new Uint8Array(await file.arrayBuffer())

  if (body.action === 'preview') {
    const result = await parseWorkbook(buffer)
    return respond(result)
  }

  if (body.action === 'dryrun') {
    const parsed = await parseWorkbook(buffer)
    const plan = applyMappingsAndPlan(parsed, body.mappings ?? {})
    return respond(plan.summary)
  }

  if (body.action === 'apply') {
    const parsed = await parseWorkbook(buffer)
    const plan = applyMappingsAndPlan(parsed, body.mappings ?? {})
    const result = await writePlanToDatabase(
      supabase,
      plan,
      userData.user.id,
      body.storage_path,
    )
    return respond(result)
  }

  return respond({ error: `Unknown action: ${body.action}` }, 400)
})
