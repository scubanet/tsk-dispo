import { useEffect, useMemo, useState } from 'react'
import { useNavigate, useOutletContext, useParams } from 'react-router-dom'
import type { OutletCtx } from '@/layout/AppShell'
import clsx from 'clsx'
import { Topbar } from '@/components/Topbar'
import { Icon } from '@/components/Icon'
import { Avatar } from '@/components/Avatar'
import { Chip } from '@/components/Chip'
import { EmptyState } from '@/components/EmptyState'
import { fetchStudents, type Student } from '@/lib/queries'
import { initialsFromName } from '@/lib/format'
import { StudentDetailPanel } from './StudentDetailPanel'
import { StudentEditSheet } from './StudentEditSheet'

export function StudentsScreen() {
  const { id } = useParams<{ id?: string }>()
  const navigate = useNavigate()
  const { user } = useOutletContext<OutletCtx>()
  const isCD = user.role === 'cd'
  const [rows, setRows] = useState<Student[]>([])
  const [search, setSearch] = useState('')
  const [filter, setFilter] = useState<'active' | 'all'>('active')
  const [createOpen, setCreateOpen] = useState(false)

  function refetch() {
    fetchStudents().then(setRows)
  }

  useEffect(() => { refetch() }, [])

  const filtered = useMemo(() => {
    let arr = rows
    if (filter === 'active') arr = arr.filter((r) => r.active)
    if (search) {
      const q = search.toLowerCase()
      arr = arr.filter(
        (r) =>
          r.name.toLowerCase().includes(q) ||
          r.email?.toLowerCase().includes(q) ||
          r.padi_nr?.toLowerCase().includes(q),
      )
    }
    return arr
  }, [rows, filter, search])

  const selected = rows.find((r) => r.id === id)

  return (
    <>
      <Topbar title="Schüler" subtitle={`${rows.length} insgesamt · ${rows.filter((r) => r.active).length} aktiv`}>
        <div className="search" style={{ width: 220 }}>
          <Icon name="search" size={14} />
          <input
            placeholder="Name, Email, PADI-Nr…"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
          />
        </div>
        <button className="btn" onClick={() => setCreateOpen(true)}>
          <Icon name="plus" size={14} /> Neu
        </button>
      </Topbar>

      <div className="master-detail">
        <div className="master">
          <div style={{ padding: '12px 16px', borderBottom: '0.5px solid var(--separator)' }}>
            <div className="seg">
              <button
                className={clsx(filter === 'active' && 'active')}
                onClick={() => setFilter('active')}
              >Aktiv</button>
              <button
                className={clsx(filter === 'all' && 'active')}
                onClick={() => setFilter('all')}
              >Alle</button>
            </div>
          </div>

          {filtered.length === 0 ? (
            <EmptyState icon="users" title="Keine Treffer" />
          ) : (
            filtered.map((r) => (
              <div
                key={r.id}
                className={clsx('list-row', selected?.id === r.id && 'selected')}
                onClick={() => navigate(`/schueler/${r.id}`)}
                style={{ padding: '12px 16px', display: 'flex', gap: 12, alignItems: 'center' }}
              >
                <Avatar
                  initials={initialsFromName(r.name)}
                  color={r.active ? '#34C759' : '#8E8E93'}
                  size="sm"
                />
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ fontWeight: 500, fontSize: 14, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                    {r.name}
                  </div>
                  <div className="caption" style={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                    {r.padi_nr ? `PADI ${r.padi_nr}` : (r.email || r.phone || '—')}
                  </div>
                </div>
                <Chip tone="accent">{r.level || 'Anfänger'}</Chip>
              </div>
            ))
          )}
        </div>

        <div className="detail">
          {selected ? (
            <StudentDetailPanel studentId={selected.id} key={selected.id} />
          ) : (
            <EmptyState icon="users" title="Wähle einen Schüler" description="Klick links auf einen Eintrag, um Details zu sehen." />
          )}
        </div>
      </div>

      <StudentEditSheet
        open={createOpen}
        onClose={() => setCreateOpen(false)}
        onSaved={(newId) => {
          refetch()
          if (newId) navigate(`/schueler/${newId}`)
        }}
        studentId={null}
        showCdFields={isCD}
      />
    </>
  )
}
