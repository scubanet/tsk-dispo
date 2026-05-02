import { useEffect, useMemo, useState } from 'react'
import { useNavigate, useOutletContext, useParams } from 'react-router-dom'
import clsx from 'clsx'
import { Topbar } from '@/components/Topbar'
import { Icon } from '@/components/Icon'
import { Avatar } from '@/components/Avatar'
import { EmptyState } from '@/components/EmptyState'
import { supabase } from '@/lib/supabase'
import { chf } from '@/lib/format'
import type { OutletCtx } from '@/layout/AppShell'
import { InstructorDetailPanel } from './InstructorDetailPanel'
import { InstructorEditSheet } from './InstructorEditSheet'

interface Row {
  id: string
  name: string
  padi_level: string
  initials: string
  color: string
  email: string | null
  active: boolean
  balance_chf: number
}

export function InstructorsScreen() {
  const { id } = useParams<{ id?: string }>()
  const navigate = useNavigate()
  const { user } = useOutletContext<OutletCtx>()
  const [rows, setRows] = useState<Row[]>([])
  const [search, setSearch] = useState('')
  const [createOpen, setCreateOpen] = useState(false)

  function refetch() {
    Promise.all([
      supabase
        .from('instructors')
        .select('id, name, padi_level, initials, color, email, active')
        .order('name'),
      supabase.from('v_instructor_balance').select('instructor_id, balance_chf'),
    ]).then(([i, b]) => {
      const balanceMap = new Map<string, number>()
      ;(b.data ?? []).forEach((row: any) =>
        balanceMap.set(row.instructor_id, Number(row.balance_chf ?? 0)),
      )
      setRows(
        (i.data ?? []).map((d: any) => ({
          ...d,
          balance_chf: balanceMap.get(d.id) ?? 0,
        })) as Row[],
      )
    })
  }

  useEffect(() => { refetch() }, [])

  const filtered = useMemo(() => {
    return rows.filter((r) => {
      if (!search) return true
      return (
        r.name.toLowerCase().includes(search.toLowerCase()) ||
        r.padi_level.toLowerCase().includes(search.toLowerCase())
      )
    })
  }, [rows, search])

  const selected = rows.find((r) => r.id === id)
  const isDispatcher = user.role === 'dispatcher'

  return (
    <>
      <Topbar title="TL/DM" subtitle={`${rows.length} Personen`}>
        <div className="search" style={{ width: 220 }}>
          <Icon name="search" size={14} />
          <input
            placeholder="Suchen…"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
          />
        </div>
        {isDispatcher && (
          <button className="btn" onClick={() => setCreateOpen(true)}>
            <Icon name="plus" size={14} /> Neu
          </button>
        )}
      </Topbar>

      <div className="master-detail">
        <div className="master">
          {filtered.map((r) => (
            <div
              key={r.id}
              className={clsx('list-row', selected?.id === r.id && 'selected')}
              onClick={() => navigate(`/tldm/${r.id}`)}
              style={{ padding: '12px 16px' }}
            >
              <Avatar initials={r.initials} color={r.color} size="sm" />
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontWeight: 500, fontSize: 14, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                  {r.name}
                </div>
                <div className="caption">{r.padi_level}</div>
              </div>
              <div
                className="mono"
                style={{
                  fontSize: 12,
                  color: r.balance_chf < 0 ? '#FF3B30' : 'var(--ink-2)',
                }}
              >
                {chf(r.balance_chf)}
              </div>
            </div>
          ))}
        </div>

        <div className="detail">
          {selected ? (
            <InstructorDetailPanel instructorId={selected.id} key={selected.id} />
          ) : (
            <EmptyState icon="users" title="Wähle eine Person" />
          )}
        </div>
      </div>

      <InstructorEditSheet
        instructorId={null}
        open={createOpen}
        onClose={() => setCreateOpen(false)}
        onSaved={(newId) => {
          refetch()
          if (newId) navigate(`/tldm/${newId}`)
        }}
        currentUserAuthId={user.authUserId}
      />
    </>
  )
}
