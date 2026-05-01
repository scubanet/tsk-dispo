import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { Topbar } from '@/components/Topbar'
import { Icon } from '@/components/Icon'
import { Chip } from '@/components/Chip'
import { supabase } from '@/lib/supabase'
import { chf } from '@/lib/format'

interface CompRate {
  id: string
  level: string
  hourly_rate_chf: number
}

interface UserRow {
  id: string
  name: string
  email: string | null
  role: string
  auth_linked: boolean
}

export function SettingsScreen() {
  const navigate = useNavigate()
  const [rates, setRates] = useState<CompRate[]>([])
  const [users, setUsers] = useState<UserRow[]>([])

  useEffect(() => {
    supabase
      .from('comp_rates')
      .select('id, level, hourly_rate_chf')
      .is('valid_to', null)
      .order('level')
      .then(({ data }) => setRates((data as CompRate[] | null) ?? []))

    supabase
      .from('instructors')
      .select('id, name, email, role, auth_user_id')
      .order('name')
      .then(({ data }) => {
        setUsers(
          (data ?? []).map((d: any) => ({
            id: d.id,
            name: d.name,
            email: d.email,
            role: d.role,
            auth_linked: !!d.auth_user_id,
          })),
        )
      })
  }, [])

  return (
    <>
      <Topbar title="Einstellungen" subtitle="Vergütungssätze · Import · User" />
      <div className="screen-fade scroll" style={{ padding: '20px 24px 40px', flex: 1 }}>
        <div className="glass card" style={{ marginBottom: 20 }}>
          <div className="title-3" style={{ marginBottom: 12 }}>Excel-Import</div>
          <div className="caption" style={{ marginBottom: 12 }}>
            4-stufiger Wizard zum einmaligen Import deines Excel-Sheets.
          </div>
          <button className="btn" onClick={() => navigate('/einstellungen/import')}>
            <Icon name="plus" size={14} />
            Import öffnen
          </button>
        </div>

        <div className="glass card" style={{ marginBottom: 20 }}>
          <div className="title-3" style={{ marginBottom: 12 }}>Vergütungssätze</div>
          <table style={{ width: '100%', fontSize: 13 }}>
            <thead>
              <tr style={{ borderBottom: '0.5px solid var(--hairline)' }}>
                <th align="left" style={{ padding: '6px 4px' }}>Level</th>
                <th align="right" style={{ padding: '6px 4px' }}>Stundensatz</th>
              </tr>
            </thead>
            <tbody>
              {rates.map((r) => (
                <tr key={r.id}>
                  <td style={{ padding: '6px 4px' }}>{r.level}</td>
                  <td align="right" className="mono">{chf(r.hourly_rate_chf)}</td>
                </tr>
              ))}
            </tbody>
          </table>
          <div className="caption-2" style={{ marginTop: 8 }}>
            Bearbeitung in v1.5 — aktuell read-only.
          </div>
        </div>

        <div className="glass card">
          <div className="title-3" style={{ marginBottom: 12 }}>User & Login-Verknüpfungen</div>
          <div className="caption" style={{ marginBottom: 12 }}>
            {users.filter((u) => u.auth_linked).length} von {users.length} Personen haben einen Login.
          </div>
          <div style={{ maxHeight: 400, overflow: 'auto' }}>
            <table style={{ width: '100%', fontSize: 13 }}>
              <thead>
                <tr style={{ borderBottom: '0.5px solid var(--hairline)' }}>
                  <th align="left" style={{ padding: '6px 4px' }}>Name</th>
                  <th align="left" style={{ padding: '6px 4px' }}>Email</th>
                  <th align="left" style={{ padding: '6px 4px' }}>Rolle</th>
                  <th align="center" style={{ padding: '6px 4px' }}>Login</th>
                </tr>
              </thead>
              <tbody>
                {users.map((u) => (
                  <tr key={u.id}>
                    <td style={{ padding: '6px 4px' }}>{u.name}</td>
                    <td style={{ padding: '6px 4px' }} className="caption">{u.email || '—'}</td>
                    <td style={{ padding: '6px 4px' }}>
                      <Chip tone={u.role === 'dispatcher' ? 'accent' : 'neutral'}>{u.role}</Chip>
                    </td>
                    <td align="center" style={{ padding: '6px 4px' }}>
                      {u.auth_linked ? '✓' : '—'}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </>
  )
}
