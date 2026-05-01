// deno-lint-ignore-file no-explicit-any
import { serve } from 'https://deno.land/std@0.190.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import ExcelJS from 'npm:exceljs@4.4.0'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

/**
 * Weekly Excel-Export.
 *
 * Generates a .xlsx in the original Excel-format style and stores it in
 * Supabase Storage (bucket "exports") with a timestamped filename.
 *
 * Triggered by: Supabase Cron Job (Sunday 23:00 UTC) → POST to this function.
 * Or: manually by Dominik via the SettingsScreen "Export jetzt" button.
 */

serve(async (_req) => {
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  )

  const respond = (data: unknown, status = 200) =>
    new Response(JSON.stringify(data), {
      status,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })

  // Build workbook
  const wb = new ExcelJS.Workbook()
  wb.creator = 'TSK Dispo App'
  wb.created = new Date()

  // === Sheet 1: Kursplanung ===
  const ws1 = wb.addWorksheet('1 Kursplanung')
  ws1.columns = [
    { header: 'Titel Kurs',   key: 'code',          width: 12 },
    { header: 'Bezeichnung',  key: 'title',         width: 40 },
    { header: 'Status',       key: 'status',        width: 10 },
    { header: 'StartDatum',   key: 'start_date',    width: 12 },
    { header: 'Zusatzdaten',  key: 'additional',    width: 24 },
    { header: 'Info',         key: 'info',          width: 30 },
    { header: 'HauptInstr',   key: 'haupt',         width: 24 },
    { header: 'Assistenten',  key: 'assists',       width: 30 },
    { header: '# TN',         key: 'num',           width: 6  },
    { header: 'Pool',         key: 'pool',          width: 6  },
    { header: 'Notizen',      key: 'notes',         width: 30 },
  ]

  const { data: courses } = await supabase
    .from('courses')
    .select(`
      id, title, status, start_date, additional_dates, info, notes, num_participants, pool_booked,
      course_type:course_types(code, label)
    `)
    .order('start_date')

  const { data: allAssignments } = await supabase
    .from('course_assignments')
    .select('course_id, role, instructor:instructors(name)')

  const assignsByCourse = new Map<string, any[]>()
  for (const a of allAssignments ?? []) {
    if (!assignsByCourse.has(a.course_id)) assignsByCourse.set(a.course_id, [])
    assignsByCourse.get(a.course_id)!.push(a)
  }

  for (const c of courses ?? []) {
    const aList = assignsByCourse.get(c.id) ?? []
    const haupt = aList.find((x) => x.role === 'haupt')?.instructor?.name ?? ''
    const assists = aList
      .filter((x) => x.role === 'assist')
      .map((x) => x.instructor?.name)
      .filter(Boolean)
      .join(' / ')
    ws1.addRow({
      code: (c.course_type as any)?.code ?? '',
      title: c.title,
      status: c.status === 'confirmed' ? 'sicher' : c.status === 'tentative' ? 'evtl.' : 'CXL',
      start_date: c.start_date,
      additional: (c.additional_dates as string[] || []).join(' / '),
      info: c.info ?? '',
      haupt,
      assists,
      num: c.num_participants,
      pool: c.pool_booked ? 'ja' : '',
      notes: c.notes ?? '',
    })
  }

  // === Sheet 2: Saldo-Übersicht ===
  const ws2 = wb.addWorksheet('Saldo Übersicht')
  ws2.columns = [
    { header: 'Name',          key: 'name',          width: 28 },
    { header: 'PADI Lvl',      key: 'level',         width: 16 },
    { header: 'Eröffnung CHF', key: 'opening',       width: 14 },
    { header: 'App-Saldo CHF', key: 'app_balance',   width: 16 },
    { header: 'Excel-Saldo (Import)', key: 'excel',  width: 18 },
    { header: 'Δ',             key: 'diff',          width: 12 },
  ]

  const { data: instructors } = await supabase
    .from('instructors')
    .select('id, name, padi_level, opening_balance_chf, excel_saldo_chf')
    .order('name')

  const { data: balances } = await supabase
    .from('v_instructor_balance')
    .select('instructor_id, balance_chf')

  const balByInstr = new Map<string, number>()
  for (const b of balances ?? []) {
    balByInstr.set(b.instructor_id, Number(b.balance_chf ?? 0))
  }

  for (const i of instructors ?? []) {
    const appBalance = balByInstr.get(i.id) ?? 0
    ws2.addRow({
      name: i.name,
      level: i.padi_level,
      opening: i.opening_balance_chf,
      app_balance: appBalance,
      excel: i.excel_saldo_chf,
      diff: appBalance - Number(i.excel_saldo_chf ?? 0),
    })
  }

  // === Sheet 3: Bewegungen pro Person ===
  const ws3 = wb.addWorksheet('Bewegungen')
  ws3.columns = [
    { header: 'Datum',       key: 'date',        width: 12 },
    { header: 'Instructor',  key: 'name',        width: 24 },
    { header: 'Beschreibung',key: 'description', width: 36 },
    { header: 'Art',         key: 'kind',        width: 12 },
    { header: 'CHF',         key: 'amount',      width: 12 },
  ]

  const { data: movements } = await supabase
    .from('account_movements')
    .select('date, amount_chf, kind, description, instructor:instructors(name)')
    .order('date', { ascending: false })

  for (const m of movements ?? []) {
    ws3.addRow({
      date: m.date,
      name: (m.instructor as any)?.name ?? '',
      description: m.description ?? '',
      kind: m.kind,
      amount: Number(m.amount_chf),
    })
  }

  // Header bold
  for (const ws of [ws1, ws2, ws3]) {
    ws.getRow(1).font = { bold: true }
  }

  // Buffer + upload
  const buffer = await wb.xlsx.writeBuffer()
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-').slice(0, 19)
  const filename = `tsk-dispo-export-${timestamp}.xlsx`
  const path = `weekly/${filename}`

  const { error: upErr } = await supabase.storage
    .from('exports')
    .upload(path, buffer, {
      contentType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      upsert: false,
    })
  if (upErr) return respond({ error: upErr.message }, 500)

  // Optional public URL (signed) for download
  const { data: signed } = await supabase.storage
    .from('exports')
    .createSignedUrl(path, 60 * 60 * 24 * 7) // 7 days

  return respond({
    ok: true,
    filename,
    path,
    courses: courses?.length ?? 0,
    instructors: instructors?.length ?? 0,
    movements: movements?.length ?? 0,
    download_url: signed?.signedUrl,
    timestamp,
  })
})
