import { useEffect, useState } from 'react'
import { useOutletContext } from 'react-router-dom'
import { supabase } from '@/lib/supabase'
import { Topbar } from '@/components/Topbar'
import { Icon } from '@/components/Icon'
import type { OutletCtx } from '@/layout/AppShell'

interface Org {
  id: string
  name: string
  kind: string | null
  city: string | null
  country: string | null
  email: string | null
  active: boolean
}

export function CDOrganizationsScreen() {
  const { user } = useOutletContext<OutletCtx>()
  const [rows, setRows] = useState<Org[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    let cancelled = false
    supabase
      .from('organizations')
      .select('id, name, kind, city, country, email, active')
      .order('name', { ascending: true })
      .then(({ data, error }) => {
        if (cancelled) return
        if (error) console.error('[cd] organizations load failed', error)
        setRows((data ?? []) as Org[])
        setLoading(false)
      })
    return () => { cancelled = true }
  }, [])

  if (user.role !== 'cd') {
    return (
      <div style={{ padding: 40 }}>
        <div className="title-2">Kein Zugriff</div>
        <div className="caption">Diese Ansicht ist nur für die CD-Rolle.</div>
      </div>
    )
  }

  return (
    <>
      <Topbar title="Organisationen" subtitle={`${rows.length} Einträge`}>
        <button className="btn"><Icon name="plus" size={14} /> Neu</button>
      </Topbar>

      {loading ? (
        <div style={{ padding: 40 }} className="caption">Lade…</div>
      ) : rows.length === 0 ? (
        <div style={{ padding: 40 }} className="caption">
          Noch keine Organisationen erfasst — Tauchclubs, Firmen, Schulen, Agenturen.
        </div>
      ) : (
        <div style={{ padding: '0 24px 24px', display: 'grid', gap: 6 }}>
          {rows.map((o) => (
            <div
              key={o.id}
              className="glass-thin"
              style={{ padding: 12, borderRadius: 12, display: 'flex', gap: 12, alignItems: 'center' }}
            >
              <div className="avatar avatar-sm" style={{ background: 'linear-gradient(135deg,#5856D6,#007aff)' }}>
                {o.name.slice(0, 2).toUpperCase()}
              </div>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div style={{ fontWeight: 600 }}>{o.name}</div>
                <div className="caption">{o.kind ?? '—'} · {[o.city, o.country].filter(Boolean).join(', ') || '—'}</div>
              </div>
              {!o.active && <div className="caption" style={{ opacity: 0.6 }}>inaktiv</div>}
            </div>
          ))}
        </div>
      )}
    </>
  )
}
