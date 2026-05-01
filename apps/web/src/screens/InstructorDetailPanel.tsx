import { useEffect, useState } from 'react'
import { useOutletContext } from 'react-router-dom'
import clsx from 'clsx'
import { format } from 'date-fns'
import { de } from 'date-fns/locale'
import { Avatar } from '@/components/Avatar'
import { Chip } from '@/components/Chip'
import { Icon } from '@/components/Icon'
import { WhatsAppButton } from '@/components/WhatsAppButton'
import { supabase } from '@/lib/supabase'
import { chf } from '@/lib/format'
import { waDirectUrl, tplDirect } from '@/lib/whatsapp'
import type { OutletCtx } from '@/layout/AppShell'
import { InstructorEditSheet } from './InstructorEditSheet'
import { CorrectionSheet } from './CorrectionSheet'

type Tab = 'overview' | 'skills' | 'assignments' | 'saldo'

const TABS: { value: Tab; label: string }[] = [
  { value: 'overview',    label: 'Übersicht' },
  { value: 'skills',      label: 'Skills' },
  { value: 'assignments', label: 'Einsätze' },
  { value: 'saldo',       label: 'Saldo' },
]

interface Instructor {
  id: string
  name: string
  initials: string
  color: string
  padi_level: string
  email: string | null
  phone: string | null
  opening_balance_chf: number
  excel_saldo_chf: number
}

export function InstructorDetailPanel({ instructorId }: { instructorId: string }) {
  const { user } = useOutletContext<OutletCtx>()
  const [inst, setInst] = useState<Instructor | null>(null)
  const [tab, setTab] = useState<Tab>('overview')
  const [skills, setSkills] = useState<any[]>([])
  const [assignments, setAssignments] = useState<any[]>([])
  const [movements, setMovements] = useState<any[]>([])
  const [editOpen, setEditOpen] = useState(false)
  const [correctionOpen, setCorrectionOpen] = useState(false)
  const [refreshTick, setRefreshTick] = useState(0)

  useEffect(() => {
    supabase
      .from('instructors')
      .select('id, name, initials, color, padi_level, email, phone, opening_balance_chf, excel_saldo_chf')
      .eq('id', instructorId)
      .single()
      .then(({ data }) => setInst(data as Instructor | null))

    supabase
      .from('instructor_skills')
      .select('skills(code, label, category)')
      .eq('instructor_id', instructorId)
      .then(({ data }) => setSkills((data ?? []).map((d: any) => d.skills).filter(Boolean)))

    supabase
      .from('course_assignments')
      .select('id, role, courses(id, title, start_date, status)')
      .eq('instructor_id', instructorId)
      .then(({ data }) => {
        const sorted = (data ?? []).sort((a: any, b: any) =>
          (b.courses?.start_date ?? '').localeCompare(a.courses?.start_date ?? ''),
        )
        setAssignments(sorted)
      })

    supabase
      .from('account_movements')
      .select('id, date, amount_chf, kind, description, breakdown_json')
      .eq('instructor_id', instructorId)
      .order('date', { ascending: false })
      .then(({ data }) => setMovements(data ?? []))
  }, [instructorId, refreshTick])

  if (!inst) return <div style={{ padding: 40 }} className="caption">Lade…</div>

  const balance = movements.reduce((sum, m) => sum + Number(m.amount_chf), 0)

  return (
    <div className="screen-fade" style={{ padding: '20px 24px 40px' }}>
      <div style={{ display: 'flex', gap: 16, alignItems: 'center', marginBottom: 20 }}>
        <Avatar initials={inst.initials} color={inst.color} size="lg" />
        <div style={{ flex: 1 }}>
          <div className="title-1">{inst.name}</div>
          <div className="caption">{inst.padi_level} · {inst.email || '—'}</div>
        </div>
        {user.role === 'dispatcher' && inst.phone && (
          <WhatsAppButton
            url={waDirectUrl(inst.phone, tplDirect({ to_name: inst.name.split(' ')[0], message: '' }))}
            label="Anschreiben"
          />
        )}
        {user.role === 'dispatcher' && (
          <button className="btn-secondary btn" onClick={() => setEditOpen(true)}>
            <Icon name="settings" size={14} /> Bearbeiten
          </button>
        )}
      </div>

      <InstructorEditSheet
        instructorId={instructorId}
        open={editOpen}
        onClose={() => setEditOpen(false)}
        onSaved={() => setRefreshTick((t) => t + 1)}
        currentUserAuthId={user.authUserId}
      />

      <CorrectionSheet
        open={correctionOpen}
        onClose={() => setCorrectionOpen(false)}
        onSaved={() => setRefreshTick((t) => t + 1)}
        defaultInstructorId={instructorId}
      />

      <div className="seg" style={{ marginBottom: 20 }}>
        {TABS.map((t) => (
          <button
            key={t.value}
            className={clsx(tab === t.value && 'active')}
            onClick={() => setTab(t.value)}
          >
            {t.label}
          </button>
        ))}
      </div>

      {tab === 'overview' && (
        <div style={{ display: 'grid', gap: 12 }}>
          <Field label="PADI-Level" value={inst.padi_level} />
          <Field label="Email" value={inst.email || '—'} />
          <Field label="Eröffnung 2026 (Excel)" value={chf(inst.opening_balance_chf)} />
          <Field label="Saldo aus Excel-Import" value={chf(inst.excel_saldo_chf)} />
          <Field label="Aktueller App-Saldo" value={chf(balance)} />
          <Field label="Anzahl Skills" value={String(skills.length)} />
          <Field label="Einsätze 2026" value={String(assignments.length)} />
        </div>
      )}

      {tab === 'skills' && (
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
          {skills.length === 0 ? (
            <div className="caption">Keine Skills hinterlegt.</div>
          ) : (
            skills.map((s) => <Chip key={s.code} tone="accent">{s.label}</Chip>)
          )}
        </div>
      )}

      {tab === 'assignments' && (
        <div style={{ display: 'grid', gap: 8 }}>
          {assignments.length === 0 ? (
            <div className="caption">Noch keine Einsätze.</div>
          ) : (
            assignments.map((a) => (
              <div key={a.id} className="glass-thin" style={{ padding: 12, borderRadius: 12 }}>
                <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                  <span style={{ fontWeight: 500 }}>{a.courses?.title ?? '—'}</span>
                  <Chip tone="accent">{a.role}</Chip>
                </div>
                <div className="caption" style={{ marginTop: 4, display: 'flex', gap: 8, alignItems: 'center' }}>
                  {a.courses?.start_date && format(new Date(a.courses.start_date), 'd. MMM yyyy', { locale: de })}
                  <Chip tone={a.courses?.status === 'confirmed' ? 'green' : a.courses?.status === 'tentative' ? 'orange' : 'red'}>
                    {a.courses?.status}
                  </Chip>
                </div>
              </div>
            ))
          )}
        </div>
      )}

      {tab === 'saldo' && (
        <>
          <div style={{ display: 'flex', alignItems: 'flex-end', justifyContent: 'space-between', marginBottom: 12 }}>
            <div
              className="title-1 mono"
              style={{ color: balance < 0 ? '#FF3B30' : 'var(--ink)' }}
            >
              {chf(balance)}
            </div>
            {user.role === 'dispatcher' && (
              <button className="btn-secondary btn" onClick={() => setCorrectionOpen(true)}>
                <Icon name="plus" size={14} /> Korrektur buchen
              </button>
            )}
          </div>
          <div className="caption" style={{ marginBottom: 12 }}>
            Aktueller berechneter Saldo aus {movements.length} Bewegungen.
          </div>
          <div style={{ display: 'grid', gap: 6 }}>
            {movements.map((m) => (
              <div
                key={m.id}
                className="glass-thin"
                style={{ padding: 10, borderRadius: 10, display: 'flex', gap: 12 }}
              >
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ fontSize: 13, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                    {m.description || m.kind}
                  </div>
                  <div className="caption-2">
                    {format(new Date(m.date), 'd. MMM yyyy', { locale: de })} · {m.kind}
                  </div>
                </div>
                <div
                  className="mono"
                  style={{ fontWeight: 600, color: Number(m.amount_chf) < 0 ? '#FF3B30' : 'inherit' }}
                >
                  {chf(m.amount_chf)}
                </div>
              </div>
            ))}
          </div>
        </>
      )}
    </div>
  )
}

function Field({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <div className="caption-2">{label.toUpperCase()}</div>
      <div style={{ fontSize: 14 }}>{value}</div>
    </div>
  )
}
