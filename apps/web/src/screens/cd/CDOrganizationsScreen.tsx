import { useEffect, useState } from 'react'
import { useOutletContext } from 'react-router-dom'
import { useTranslation } from 'react-i18next'
import { supabase } from '@/lib/supabase'
import { Topbar } from '@/components/Topbar'
import { Icon } from '@/components/Icon'
import { OrganizationEditSheet } from './OrganizationEditSheet'
import type { OutletCtx } from '@/layout/AppShell'

interface Org {
  id: string
  name: string
  kind: string | null
  city: string | null
  country: string | null
  email: string | null
  phone: string | null
  website: string | null
  active: boolean
}

/** Map legacy/short codes to a canonical i18n key */
function kindKey(code: string | null): string | null {
  if (!code) return null
  // Legacy 'dive_club' → 'dive_school'
  const canonical = code === 'dive_club' ? 'dive_school' : code
  return canonical
}

export function CDOrganizationsScreen() {
  const { t } = useTranslation()
  const { user } = useOutletContext<OutletCtx>()
  const [rows, setRows] = useState<Org[]>([])
  const [loading, setLoading] = useState(true)
  const [editOpen, setEditOpen] = useState(false)
  const [editingId, setEditingId] = useState<string | null>(null)
  const [refreshTick, setRefreshTick] = useState(0)
  const [search, setSearch] = useState('')

  useEffect(() => {
    let cancelled = false
    setLoading(true)
    supabase
      .from('organizations')
      .select('id, name, kind, city, country, email, phone, website, active')
      .order('name', { ascending: true })
      .then(({ data, error }) => {
        if (cancelled) return
        if (error) console.error('[cd] organizations load failed', error)
        setRows((data ?? []) as Org[])
        setLoading(false)
      })
    return () => { cancelled = true }
  }, [refreshTick])

  const canAccess = user.role === 'cd' || user.role === 'dispatcher' || user.role === 'owner'
  if (!canAccess) {
    return (
      <div style={{ padding: 40 }}>
        <div className="title-2">{t('cd_pipeline.no_access_title')}</div>
        <div className="caption">{t('cd_orgs.no_access_desc')}</div>
      </div>
    )
  }

  const filtered = rows.filter((r) => {
    const q = search.toLowerCase().trim()
    if (!q) return true
    return (
      r.name.toLowerCase().includes(q) ||
      (r.city ?? '').toLowerCase().includes(q) ||
      (r.email ?? '').toLowerCase().includes(q)
    )
  })

  function openNew() {
    setEditingId(null)
    setEditOpen(true)
  }

  function openEdit(id: string) {
    setEditingId(id)
    setEditOpen(true)
  }

  return (
    <>
      <Topbar
        title={t('nav.organizations')}
        subtitle={t('cd_orgs.subtitle', { total: rows.length, active: rows.filter(r => r.active).length })}
      >
        <div className="search" style={{ width: 220 }}>
          <Icon name="search" size={14} />
          <input
            placeholder={t('cd_orgs.search_placeholder')}
            value={search}
            onChange={(e) => setSearch(e.target.value)}
          />
        </div>
        <button className="btn" onClick={openNew}>
          <Icon name="plus" size={14} /> {t('courses.new')}
        </button>
      </Topbar>

      {loading ? (
        <div style={{ padding: 40 }} className="caption">{t('common.loading')}</div>
      ) : filtered.length === 0 ? (
        <div style={{ padding: 40 }} className="caption">
          {rows.length === 0
            ? t('cd_orgs.empty_first_time')
            : t('courses.no_matches') + '.'}
        </div>
      ) : (
        <div style={{ padding: '0 24px 24px', display: 'grid', gap: 6 }}>
          {filtered.map((o) => (
            <button
              key={o.id}
              onClick={() => openEdit(o.id)}
              className="glass-thin"
              style={{
                padding: 12,
                borderRadius: 12,
                display: 'flex',
                gap: 12,
                alignItems: 'center',
                border: 'none',
                cursor: 'pointer',
                textAlign: 'left',
                color: 'var(--ink)',
                font: 'inherit',
                width: '100%',
                opacity: o.active ? 1 : 0.55,
              }}
            >
              <div className="avatar avatar-sm" style={{ background: 'linear-gradient(135deg,#5856D6,#007aff)' }}>
                {o.name.slice(0, 2).toUpperCase()}
              </div>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontWeight: 600 }}>{o.name}</div>
                <div className="caption">
                  {[
                    o.kind ? t(`org_edit.kind_${kindKey(o.kind)}`, { defaultValue: o.kind }) : null,
                    [o.city, o.country].filter(Boolean).join(', ') || null,
                    o.email,
                  ].filter(Boolean).join(' · ') || '—'}
                </div>
              </div>
              {!o.active && <div className="caption" style={{ opacity: 0.6 }}>{t('cd_orgs.inactive')}</div>}
              <span className="caption-2" style={{ opacity: 0.4 }}>›</span>
            </button>
          ))}
        </div>
      )}

      <OrganizationEditSheet
        open={editOpen}
        onClose={() => setEditOpen(false)}
        onSaved={() => setRefreshTick((t) => t + 1)}
        orgId={editingId}
      />
    </>
  )
}
