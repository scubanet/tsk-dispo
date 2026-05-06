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

type Tab = 'all' | 'students' | 'candidates' | 'orgs'

export function StudentsScreen() {
  const { id } = useParams<{ id?: string }>()
  const navigate = useNavigate()
  const { user } = useOutletContext<OutletCtx>()
  const isCD = user.role === 'cd'
  const [rows, setRows] = useState<Student[]>([])
  const [search, setSearch] = useState('')
  const [tab, setTab] = useState<Tab>(isCD ? 'all' : 'students')
  const [createOpen, setCreateOpen] = useState(false)

  function refetch() {
    fetchStudents().then(setRows)
  }

  useEffect(() => { refetch() }, [])

  // Org/CRM ist exklusiv: nur Personen die WEDER Schüler NOCH Kandidat sind,
  // aber eine Pipeline-Stage oder Org-Zuordnung haben.
  const isOrgOnly = (r: Student) =>
    !r.is_student && !r.is_candidate &&
    (!!r.organization_id || (!!r.pipeline_stage && r.pipeline_stage !== 'none'))

  const counts = useMemo(() => ({
    all:        rows.length,
    students:   rows.filter((r) => r.is_student).length,
    candidates: rows.filter((r) => r.is_candidate).length,
    orgs:       rows.filter(isOrgOnly).length,
  }), [rows])

  const filtered = useMemo(() => {
    let arr = rows
    if (tab === 'students')   arr = arr.filter((r) => r.is_student)
    if (tab === 'candidates') arr = arr.filter((r) => r.is_candidate)
    if (tab === 'orgs')       arr = arr.filter(isOrgOnly)
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
  }, [rows, tab, search])

  const selected = rows.find((r) => r.id === id)

  return (
    <>
      <Topbar title="Personen" subtitle={`${rows.length} insgesamt`}>
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
          <div style={{ padding: '12px 16px', borderBottom: '0.5px solid var(--separator)', display: 'grid', gap: 8 }}>
            <div className="seg">
              <button className={clsx(tab === 'all' && 'active')}        onClick={() => setTab('all')}>Alle <span style={{opacity:.6}}>· {counts.all}</span></button>
              <button className={clsx(tab === 'students' && 'active')}   onClick={() => setTab('students')}>Schüler <span style={{opacity:.6}}>· {counts.students}</span></button>
              <button className={clsx(tab === 'candidates' && 'active')} onClick={() => setTab('candidates')}>Kandidaten <span style={{opacity:.6}}>· {counts.candidates}</span></button>
              <button className={clsx(tab === 'orgs' && 'active')}       onClick={() => setTab('orgs')}>Org/CRM <span style={{opacity:.6}}>· {counts.orgs}</span></button>
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
                  color={
                    r.is_candidate ? '#FF3B30'   // rot = Kandidat (Vorrang)
                    : r.is_student ? '#007AFF'  // blau = Schüler
                    : '#34C759'                 // grün = sonstige (Org/CRM)
                  }
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
            <EmptyState icon="users" title="Wähle eine Person" description="Klick links auf einen Eintrag, um Details zu sehen." />
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
