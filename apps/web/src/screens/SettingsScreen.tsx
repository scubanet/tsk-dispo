import { useEffect, useState } from 'react'
import { useNavigate, useOutletContext } from 'react-router-dom'
import { Topbar } from '@/components/Topbar'
import { Icon } from '@/components/Icon'
import { Chip } from '@/components/Chip'
import { supabase } from '@/lib/supabase'
import { chf } from '@/lib/format'
import type { OutletCtx } from '@/layout/AppShell'

interface CompRate {
  id: string
  level: string
  hourly_rate_chf: number
}

interface CourseType {
  id: string
  code: string
  label: string
  theory_units: number
  pool_units: number
  lake_units: number
  active: boolean
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
  const { user } = useOutletContext<OutletCtx>()
  const isDispatcher = user.role === 'dispatcher'

  const [rates, setRates] = useState<CompRate[]>([])
  const [courseTypes, setCourseTypes] = useState<CourseType[]>([])
  const [users, setUsers] = useState<UserRow[]>([])
  const [dirty, setDirty] = useState(false)
  const [recalcing, setRecalcing] = useState(false)
  const [recalcMsg, setRecalcMsg] = useState<string | null>(null)

  function refetch() {
    supabase
      .from('comp_rates')
      .select('id, level, hourly_rate_chf')
      .is('valid_to', null)
      .order('level')
      .then(({ data }) => setRates((data as CompRate[] | null) ?? []))

    supabase
      .from('course_types')
      .select('id, code, label, theory_units, pool_units, lake_units, active')
      .eq('active', true)
      .order('code')
      .then(({ data }) => setCourseTypes((data as CourseType[] | null) ?? []))

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
  }

  useEffect(() => { refetch() }, [])

  async function saveRate(rateId: string, newValue: number) {
    const { error } = await supabase
      .from('comp_rates')
      .update({ hourly_rate_chf: newValue })
      .eq('id', rateId)
    if (error) {
      alert('Fehler beim Speichern: ' + error.message)
      refetch()
      return
    }
    setDirty(true)
  }

  async function saveCourseType(id: string, field: 'theory_units' | 'pool_units' | 'lake_units', newValue: number) {
    const { error } = await supabase
      .from('course_types')
      .update({ [field]: newValue })
      .eq('id', id)
    if (error) {
      alert('Fehler beim Speichern: ' + error.message)
      refetch()
      return
    }
    // Auch comp_units sync für Recalc — gleiche Werte für alle Rollen
    await supabase
      .from('comp_units')
      .update({ [field.replace('_units', '_h')]: newValue })
      .eq('course_type_id', id)
    setDirty(true)
  }

  async function runRecalc() {
    if (!confirm('Alle bestehenden Vergütungs-Buchungen werden gelöscht und mit den aktuellen Sätzen + Punkten neu berechnet. Fortfahren?')) {
      return
    }
    setRecalcing(true)
    setRecalcMsg(null)
    const { data, error } = await supabase.rpc('recalc_all_compensations')
    setRecalcing(false)
    if (error) {
      setRecalcMsg('Fehler: ' + error.message)
      return
    }
    const row = Array.isArray(data) && data[0] ? data[0] : null
    setRecalcMsg(
      row
        ? `✓ ${row.deleted_count} alte Buchungen gelöscht, ${row.inserted_count} neue erstellt.`
        : '✓ Recalc abgeschlossen.',
    )
    setDirty(false)
  }

  return (
    <>
      <Topbar title="Einstellungen" subtitle="Vergütungssätze · Kurs-Punkte · Import · User" />
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

        {dirty && isDispatcher && (
          <div
            className="chip-orange"
            style={{
              marginBottom: 20,
              padding: 14,
              borderRadius: 12,
              display: 'flex',
              gap: 12,
              alignItems: 'center',
            }}
          >
            <Icon name="bell" size={18} />
            <div style={{ flex: 1, fontSize: 13 }}>
              <strong>Änderungen gespeichert.</strong> Bestehende Vergütungen sind noch mit den alten Sätzen berechnet.
              Klick auf "Vergütungen neu berechnen" um alle Saldi zu aktualisieren.
            </div>
            <button className="btn" onClick={runRecalc} disabled={recalcing}>
              {recalcing ? 'Berechne…' : 'Vergütungen neu berechnen'}
            </button>
          </div>
        )}

        {recalcMsg && (
          <div
            className="chip"
            style={{
              marginBottom: 20,
              padding: 12,
              borderRadius: 8,
              fontSize: 13,
              background: recalcMsg.startsWith('✓') ? 'rgba(52,199,89,.12)' : 'rgba(255,59,48,.12)',
              color: recalcMsg.startsWith('✓') ? '#34C759' : '#FF3B30',
            }}
          >
            {recalcMsg}
          </div>
        )}

        <div className="glass card" style={{ marginBottom: 20 }}>
          <div className="title-3" style={{ marginBottom: 12 }}>Vergütungssätze pro Level</div>
          <div className="caption" style={{ marginBottom: 12 }}>
            CHF pro Punkt. Multipliziert mit den Kurs-Punkten unten ergibt die Vergütung.
            {isDispatcher && ' · Klick auf den Wert zum Bearbeiten.'}
          </div>
          <table style={{ width: '100%', fontSize: 13 }}>
            <thead>
              <tr style={{ borderBottom: '0.5px solid var(--hairline)' }}>
                <th align="left" style={{ padding: '6px 4px' }}>Level</th>
                <th align="right" style={{ padding: '6px 4px' }}>CHF / Punkt</th>
              </tr>
            </thead>
            <tbody>
              {rates.map((r) => (
                <tr key={r.id}>
                  <td style={{ padding: '6px 4px' }}>{r.level}</td>
                  <td align="right" className="mono" style={{ padding: '6px 4px' }}>
                    {isDispatcher ? (
                      <NumberCell
                        value={r.hourly_rate_chf}
                        suffix=" CHF"
                        onSave={(v) => saveRate(r.id, v)}
                      />
                    ) : (
                      chf(r.hourly_rate_chf)
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>

        <div className="glass card" style={{ marginBottom: 20 }}>
          <div className="title-3" style={{ marginBottom: 4 }}>Kursentschädigungen (Punkte)</div>
          <div className="caption" style={{ marginBottom: 12 }}>
            Punkte je Kurstyp · Theorie + Pool + See = Total. Vergütung = Total × CHF/Punkt.
            {isDispatcher && ' · Klick auf einen Wert zum Bearbeiten.'}
          </div>
          <div style={{ overflow: 'auto' }}>
            <table style={{ width: '100%', fontSize: 13, minWidth: 560 }}>
              <thead>
                <tr style={{ borderBottom: '0.5px solid var(--hairline)' }}>
                  <th align="left"  style={{ padding: '6px 4px' }}>Code</th>
                  <th align="left"  style={{ padding: '6px 4px' }}>Kurs</th>
                  <th align="right" style={{ padding: '6px 4px' }}>Theorie</th>
                  <th align="right" style={{ padding: '6px 4px' }}>Pool</th>
                  <th align="right" style={{ padding: '6px 4px' }}>See</th>
                  <th align="right" style={{ padding: '6px 4px', borderLeft: '0.5px solid var(--hairline)' }}>Total</th>
                  <th align="right" style={{ padding: '6px 4px' }}>CD-Vergütung</th>
                </tr>
              </thead>
              <tbody>
                {courseTypes.map((c) => {
                  const total = Number(c.theory_units) + Number(c.pool_units) + Number(c.lake_units)
                  const cdRate = rates.find((r) => r.level === 'CD')?.hourly_rate_chf ?? 0
                  const cdComp = total * Number(cdRate)
                  return (
                    <tr key={c.id} style={{ borderBottom: '0.5px solid var(--hairline)' }}>
                      <td style={{ padding: '6px 4px' }} className="mono">{c.code}</td>
                      <td style={{ padding: '6px 4px' }}>{c.label}</td>
                      <td align="right" style={{ padding: '6px 4px' }}>
                        {isDispatcher ? (
                          <NumberCell value={c.theory_units} onSave={(v) => saveCourseType(c.id, 'theory_units', v)} />
                        ) : (
                          <span className="mono">{fmtPoints(c.theory_units)}</span>
                        )}
                      </td>
                      <td align="right" style={{ padding: '6px 4px' }}>
                        {isDispatcher ? (
                          <NumberCell value={c.pool_units} onSave={(v) => saveCourseType(c.id, 'pool_units', v)} />
                        ) : (
                          <span className="mono">{fmtPoints(c.pool_units)}</span>
                        )}
                      </td>
                      <td align="right" style={{ padding: '6px 4px' }}>
                        {isDispatcher ? (
                          <NumberCell value={c.lake_units} onSave={(v) => saveCourseType(c.id, 'lake_units', v)} />
                        ) : (
                          <span className="mono">{fmtPoints(c.lake_units)}</span>
                        )}
                      </td>
                      <td align="right" className="mono" style={{ padding: '6px 4px', borderLeft: '0.5px solid var(--hairline)', fontWeight: 600 }}>
                        {fmtPoints(total)}
                      </td>
                      <td align="right" className="mono" style={{ padding: '6px 4px', color: 'var(--ink-2)' }}>
                        {chf(cdComp)}
                      </td>
                    </tr>
                  )
                })}
              </tbody>
            </table>
          </div>
          <div className="caption-2" style={{ marginTop: 12, color: 'var(--ink-2)' }}>
            CD-Vergütung als Beispiel-Rechnung mit aktuellem CD-Satz · andere Levels analog.
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

function NumberCell({
  value,
  suffix,
  onSave,
}: {
  value: number
  suffix?: string
  onSave: (n: number) => void | Promise<void>
}) {
  const [editing, setEditing] = useState(false)
  const [draft, setDraft] = useState(String(value))

  function commit() {
    const num = Number(draft.replace(',', '.'))
    setEditing(false)
    if (isNaN(num) || num < 0) {
      setDraft(String(value))
      return
    }
    if (num !== Number(value)) onSave(num)
  }

  if (!editing) {
    return (
      <span
        className="mono"
        onClick={() => {
          setDraft(String(value))
          setEditing(true)
        }}
        style={{
          cursor: 'pointer',
          padding: '2px 6px',
          borderRadius: 4,
          display: 'inline-block',
        }}
        onMouseEnter={(e) => (e.currentTarget.style.background = 'rgba(0,0,0,.04)')}
        onMouseLeave={(e) => (e.currentTarget.style.background = 'transparent')}
        title="Klicken zum Bearbeiten"
      >
        {fmtPoints(value)}{suffix}
      </span>
    )
  }

  return (
    <input
      autoFocus
      type="number"
      step="0.5"
      min="0"
      value={draft}
      onChange={(e) => setDraft(e.target.value)}
      onBlur={commit}
      onKeyDown={(e) => {
        if (e.key === 'Enter') commit()
        if (e.key === 'Escape') {
          setEditing(false)
          setDraft(String(value))
        }
      }}
      className="mono"
      style={{
        width: 70,
        padding: '2px 6px',
        textAlign: 'right',
        borderRadius: 4,
        border: '1px solid var(--accent)',
        font: 'inherit',
        fontSize: 13,
      }}
    />
  )
}

function fmtPoints(n: number | string): string {
  const num = Number(n)
  if (num === 0) return '—'
  return num % 1 === 0 ? num.toFixed(0) : num.toFixed(1)
}
