/**
 * InstructorsScreen — Foundation-based rewrite (Tag 6 cutover).
 *
 * Layout:
 *   PageHeader (search + "+New" action for dispatchers/CDs)
 *   ┌─ MasterDetail ─────────────────────────────────────────┐
 *   │  ListPane (320px)            │  DetailPane              │
 *   │   list rows                  │   InstructorDetailPanel  │
 *   │     Avatar + Name + Level    │     (legacy, stays)      │
 *   │     Balance (CHF, red < 0)   │                          │
 *   └────────────────────────────────────────────────────────┘
 */

import { useEffect, useMemo, useState } from 'react'
import { useNavigate, useOutletContext, useParams } from 'react-router-dom'
import { useTranslation } from 'react-i18next'
import {
  PageHeader,
  MasterDetail,
  ListPane,
  DetailPane,
  SearchInput,
  EmptyState,
  Avatar,
  Icon,
  chf,
  padiLevelColor,
} from '@/foundation'
import { supabase } from '@/lib/supabase'
import type { OutletCtx } from '@/layout/AppShell'
import { InstructorDetailPanel } from './InstructorDetailPanel'
import { InstructorEditSheet } from './InstructorEditSheet'

interface Row {
  id: string
  name: string
  padi_level: string
  padi_nr: string | null
  email: string | null
  active: boolean
  balance_chf: number
}

export function InstructorsScreen() {
  const { t } = useTranslation()
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
        .select('id, name, padi_level, padi_nr, email, active')
        .order('last_name')
        .order('first_name'),
      supabase.from('v_instructor_balance').select('instructor_id, balance_chf'),
    ]).then(([i, b]) => {
      const balanceMap = new Map<string, number>()
      ;(b.data ?? []).forEach((row: { instructor_id: string; balance_chf: number | string }) =>
        balanceMap.set(row.instructor_id, Number(row.balance_chf ?? 0)),
      )
      setRows(
        (i.data ?? []).map((d) => ({
          ...(d as Omit<Row, 'balance_chf'>),
          balance_chf: balanceMap.get((d as { id: string }).id) ?? 0,
        })),
      )
    })
  }

  useEffect(() => {
    refetch()
  }, [])

  const filtered = useMemo(() => {
    return rows.filter((r) => {
      if (!search) return true
      const q = search.toLowerCase()
      return (
        r.name.toLowerCase().includes(q) ||
        (r.padi_level ?? '').toLowerCase().includes(q) ||
        (r.padi_nr ?? '').toLowerCase().includes(q) ||
        (r.email ?? '').toLowerCase().includes(q)
      )
    })
  }, [rows, search])

  const isDispatcher =
    user.role === 'dispatcher' || user.role === 'cd' || user.role === 'owner'

  return (
    <div className="atoll-screen">
      <PageHeader
        title={t('nav.tldm')}
        subtitle={t('instructors.count', { count: rows.length })}
        actions={
          <>
            <SearchInput
              value={search}
              onChange={setSearch}
              ariaLabel={t('common.search')}
              placeholder={t('common.search') + '…'}
            />
            {isDispatcher && (
              <button
                type="button"
                className="atoll-btn atoll-btn--primary"
                onClick={() => setCreateOpen(true)}
              >
                <Icon.Plus size={14} /> {t('courses.new')}
              </button>
            )}
          </>
        }
      />

      <div className="atoll-screen__body atoll-screen__body--full">
        <MasterDetail>
          <ListPane>
            {filtered.length === 0 ? (
              <EmptyState
                icon={<Icon.Users size={20} />}
                title={t('courses.no_matches')}
              />
            ) : (
              <ul className="atoll-people-list">
                {filtered.map((r) => (
                  <li key={r.id}>
                    <button
                      type="button"
                      className={`atoll-people-row${id === r.id ? ' atoll-people-row--active' : ''}`}
                      onClick={() => navigate(`/tldm/${r.id}`)}
                    >
                      <Avatar
                        id={r.id}
                        name={r.name}
                        size="sm"
                        color={padiLevelColor(r.padi_level)}
                      />
                      <div className="atoll-people-row__main">
                        <div className="atoll-people-row__name">
                          {r.name}
                          {!r.active && (
                            <span className="atoll-instructors-row__inactive">{t('common.inactive', 'inaktiv')}</span>
                          )}
                        </div>
                        <div className="atoll-people-row__sub">
                          {[r.padi_level, r.padi_nr ? `PADI ${r.padi_nr}` : null]
                            .filter(Boolean)
                            .join(' · ') || '—'}
                        </div>
                      </div>
                      <span
                        className={`atoll-instructors-row__balance tabular-nums${r.balance_chf < 0 ? ' atoll-instructors-row__balance--neg' : ''}`}
                      >
                        {chf(r.balance_chf)}
                      </span>
                    </button>
                  </li>
                ))}
              </ul>
            )}
          </ListPane>

          <DetailPane>
            {id ? (
              <InstructorDetailPanel instructorId={id} key={id} />
            ) : (
              <EmptyState
                icon={<Icon.Users size={20} />}
                title={t('people.pick_person')}
              />
            )}
          </DetailPane>
        </MasterDetail>
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
    </div>
  )
}
