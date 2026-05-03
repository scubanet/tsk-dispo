import { useEffect, useState } from 'react'
import { useOutletContext } from 'react-router-dom'
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

const KIND_LABEL: Record<string, string> = {
  dive_club: 'Tauchclub',
  company:   'Firma',
  school:    'Schule',
  agency:    'Agentur',
  resort:    'Resort / Tauchbasis',
  other:     'Andere',
}

export function CDOrganizationsScreen() {
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

  if (user.role !== 'cd') {
    return (
      <div style={{ padding: 40 }}>
        <div className="title-2">Kein Zugriff</div>
        <div className="caption">Diese Ansicht ist nur für die CD-Rolle.</div>
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
      <Topbar title="Organisationen" subtitle={`${rows.length} Einträge · ${rows.filter(r => r.active).length} aktiv`}>
        <div className="search" style={{ width: 220 }}>
          <Icon name="search" size={14} />
          <input
            placeholder="Name, Ort, Email…"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
          />
        </div>
        <button className="btn" onClick={openNew}>
          <Icon name="plus" size={14} /> Neu
        </button>
      </Topbar>

      {loading ? (
        <div style={{ padding: 40 }} className="caption">Lade…</div>
      ) : filtered.length === 0 ? (
        <div style={{ padding: 40 }} className="caption">
          {rows.length === 0
            ? 'Noch keine Organisationen erfasst — Tauchclubs, Firmen, Schulen, Agenturen.'
            : 'Keine Treffer.'}
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
                    o.kind ? (KIND_LABEL[o.kind] ?? o.kind) : null,
                    [o.city, o.country].filter(Boolean).join(', ') || null,
                    o.email,
                  ].filter(Boolean).join(' · ') || '—'}
                </div>
              </div>
              {!o.active && <div className="caption" style={{ opacity: 0.6 }}>inaktiv</div>}
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
