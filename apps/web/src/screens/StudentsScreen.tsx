/**
 * StudentsScreen — Foundation-based rewrite (Tag 4 cutover).
 *
 * Layout:
 *   PageHeader (search + "+New" action)
 *   ┌─ MasterDetail ─────────────────────────────────────────┐
 *   │  ListPane (320px)            │  DetailPane              │
 *   │   FilterTabBar               │   StudentDetailPanel     │
 *   │   list rows                  │     (legacy, stays)      │
 *   └────────────────────────────────────────────────────────┘
 *
 * Filter tabs: All / Schüler / Kandidaten / Org.
 */

import { useEffect, useMemo, useState } from 'react'
import { useNavigate, useOutletContext, useParams } from 'react-router-dom'
import { useTranslation } from 'react-i18next'
import {
  PageHeader,
  MasterDetail,
  ListPane,
  DetailPane,
  FilterTabBar,
  SearchInput,
  EmptyState,
  Avatar,
  Pill,
  Icon,
  avatarColor,
} from '@/foundation'
import type { OutletCtx } from '@/layout/AppShell'
import { fetchStudents, type Student } from '@/lib/queries'
import { StudentDetailPanel } from './StudentDetailPanel'
import { StudentEditSheet } from './StudentEditSheet'

type Tab = 'all' | 'students' | 'candidates' | 'orgs'

export function StudentsScreen() {
  const { t } = useTranslation()
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

  useEffect(() => {
    refetch()
  }, [])

  // Org/CRM is exclusive: people who are NEITHER student NOR candidate but
  // have a pipeline stage or org assignment.
  const isOrgOnly = (r: Student) =>
    !r.is_student &&
    !r.is_candidate &&
    (!!r.organization_id || (!!r.pipeline_stage && r.pipeline_stage !== 'none'))

  const counts = useMemo(
    () => ({
      all: rows.length,
      students: rows.filter((r) => r.is_student).length,
      candidates: rows.filter((r) => r.is_candidate).length,
      orgs: rows.filter(isOrgOnly).length,
    }),
    [rows],
  )

  const filtered = useMemo(() => {
    let arr = rows
    if (tab === 'students') arr = arr.filter((r) => r.is_student)
    if (tab === 'candidates') arr = arr.filter((r) => r.is_candidate)
    if (tab === 'orgs') arr = arr.filter(isOrgOnly)
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

  const tabs = [
    { id: 'all' as const, label: t('people.tab_all'), count: counts.all },
    { id: 'students' as const, label: t('people.tab_students'), count: counts.students },
    { id: 'candidates' as const, label: t('people.tab_candidates'), count: counts.candidates },
    { id: 'orgs' as const, label: t('people.tab_orgs'), count: counts.orgs },
  ]

  return (
    <div className="atoll-screen">
      <PageHeader
        title={t('nav.people')}
        subtitle={t('people.total', { count: rows.length })}
        actions={
          <>
            <SearchInput
              value={search}
              onChange={setSearch}
              ariaLabel={t('people.search_placeholder')}
              placeholder={t('people.search_placeholder')}
            />
            <button
              type="button"
              className="atoll-btn atoll-btn--primary"
              onClick={() => setCreateOpen(true)}
            >
              <Icon.Plus size={14} /> {t('courses.new')}
            </button>
          </>
        }
      />

      <div className="atoll-screen__body atoll-screen__body--full">
        <MasterDetail>
          <ListPane
            toolbar={
              <FilterTabBar<Tab>
                tabs={tabs}
                active={tab}
                onChange={setTab}
                ariaLabel={t('nav.people')}
              />
            }
          >
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
                      onClick={() => navigate(`/schueler/${r.id}`)}
                    >
                      <Avatar
                        id={r.id}
                        name={r.name}
                        size="sm"
                        color={
                          r.is_candidate
                            ? 'var(--brand-red)'  // Candidate keeps red as a deliberate marker
                            : r.is_student
                              ? 'var(--brand-blue)'
                              : avatarColor(r.id)
                        }
                      />
                      <div className="atoll-people-row__main">
                        <div className="atoll-people-row__name">{r.name}</div>
                        <div className="atoll-people-row__sub">
                          {[r.padi_nr && `PADI ${r.padi_nr}`, r.email, r.phone]
                            .filter(Boolean)
                            .join(' · ') || '—'}
                        </div>
                      </div>
                      {r.level && r.level !== 'Anfänger' && (
                        <Pill tone="brand" size="sm">
                          {r.level}
                        </Pill>
                      )}
                    </button>
                  </li>
                ))}
              </ul>
            )}
          </ListPane>

          <DetailPane>
            {id ? (
              <StudentDetailPanel studentId={id} key={id} />
            ) : (
              <EmptyState
                icon={<Icon.Users size={20} />}
                title={t('people.pick_person')}
                body={t('people.pick_person_desc')}
              />
            )}
          </DetailPane>
        </MasterDetail>
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
    </div>
  )
}
