import { useEffect, useState } from 'react'
import { useNavigate, useOutletContext } from 'react-router-dom'
import { useTranslation } from 'react-i18next'
import { Topbar } from '@/components/Topbar'
import { Icon } from '@/components/Icon'
import { Chip } from '@/components/Chip'
import { supabase } from '@/lib/supabase'
import { chf } from '@/lib/format'
import { useLanguage } from '@/i18n/useLanguage'
import type { Lang } from '@/i18n'
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
  const { t } = useTranslation()
  const navigate = useNavigate()
  const { user } = useOutletContext<OutletCtx>()
  const isDispatcher = user.role === 'dispatcher' || user.role === 'cd'

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
      .order('last_name')
      .order('first_name')
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
    // Optimistic update for instant feedback
    setRates((prev) => prev.map((r) => (r.id === rateId ? { ...r, hourly_rate_chf: newValue } : r)))
    const { error } = await supabase
      .from('comp_rates')
      .update({ hourly_rate_chf: newValue })
      .eq('id', rateId)
    if (error) {
      alert(t('settings.recalc.save_failed') + error.message)
      refetch()  // revert
      return
    }
    setDirty(true)
  }

  async function saveCourseType(id: string, field: 'theory_units' | 'pool_units' | 'lake_units', newValue: number) {
    // Optimistic update
    setCourseTypes((prev) => prev.map((c) => (c.id === id ? { ...c, [field]: newValue } : c)))
    const { error } = await supabase
      .from('course_types')
      .update({ [field]: newValue })
      .eq('id', id)
    if (error) {
      alert(t('settings.recalc.save_failed') + error.message)
      refetch()  // revert
      return
    }
    // Auch comp_units sync für Recalc — gleiche Werte für alle Rollen
    const compUnitField = field.replace('_units', '_h')
    const { error: cuErr } = await supabase
      .from('comp_units')
      .update({ [compUnitField]: newValue })
      .eq('course_type_id', id)
    if (cuErr) {
      alert(t('settings.recalc.comp_units_sync_failed') + cuErr.message)
    }
    setDirty(true)
  }

  async function runRecalc() {
    if (!confirm(t('settings.recalc.confirm'))) {
      return
    }
    setRecalcing(true)
    setRecalcMsg(null)
    const { data, error } = await supabase.rpc('recalc_all_compensations')
    setRecalcing(false)
    if (error) {
      setRecalcMsg(t('settings.recalc.error_prefix') + error.message)
      return
    }
    const row = Array.isArray(data) && data[0] ? data[0] : null
    setRecalcMsg(
      row
        ? t('settings.recalc.result', { deleted: row.deleted_count, inserted: row.inserted_count })
        : t('settings.recalc.result_generic'),
    )
    setDirty(false)
  }

  return (
    <>
      <Topbar title={t('settings.title')} subtitle={t('settings.subtitle')} />
      <div className="screen-fade scroll" style={{ padding: '20px 24px 40px', flex: 1 }}>
        <LanguageCard />

        <div className="glass card" style={{ marginBottom: 20 }}>
          <div className="title-3" style={{ marginBottom: 12 }}>{t('settings.import.title')}</div>
          <div className="caption" style={{ marginBottom: 12 }}>
            {t('settings.import.subtitle')}
          </div>
          <button className="btn" onClick={() => navigate('/einstellungen/import')}>
            <Icon name="plus" size={14} />
            {t('settings.import.open')}
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
              <strong>{t('settings.recalc.saved_notice_strong')}</strong> {t('settings.recalc.saved_notice_body')}
            </div>
            <button className="btn" onClick={runRecalc} disabled={recalcing}>
              {recalcing ? t('settings.recalc.calculating') : t('settings.recalc.button')}
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
          <div className="title-3" style={{ marginBottom: 12 }}>{t('settings.rates.title')}</div>
          <div className="caption" style={{ marginBottom: 12 }}>
            {t('settings.rates.subtitle')}
            {isDispatcher && t('settings.rates.subtitle_dispatcher_hint')}
          </div>
          <table style={{ width: '100%', fontSize: 13 }}>
            <thead>
              <tr style={{ borderBottom: '0.5px solid var(--hairline)' }}>
                <th align="left" style={{ padding: '6px 4px' }}>{t('settings.rates.col_level')}</th>
                <th align="right" style={{ padding: '6px 4px' }}>{t('settings.rates.col_chf_per_point')}</th>
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
          <div className="title-3" style={{ marginBottom: 4 }}>{t('settings.course_pay.title')}</div>
          <div className="caption" style={{ marginBottom: 12 }}>
            {t('settings.course_pay.subtitle')}
            {isDispatcher && t('settings.rates.subtitle_dispatcher_hint')}
          </div>
          <div style={{ overflow: 'auto' }}>
            <table style={{ width: '100%', fontSize: 13, minWidth: 560 }}>
              <thead>
                <tr style={{ borderBottom: '0.5px solid var(--hairline)' }}>
                  <th align="left"  style={{ padding: '6px 4px' }}>{t('settings.course_pay.col_code')}</th>
                  <th align="left"  style={{ padding: '6px 4px' }}>{t('settings.course_pay.col_course')}</th>
                  <th align="right" style={{ padding: '6px 4px' }}>{t('settings.course_pay.col_theory')}</th>
                  <th align="right" style={{ padding: '6px 4px' }}>{t('settings.course_pay.col_pool')}</th>
                  <th align="right" style={{ padding: '6px 4px' }}>{t('settings.course_pay.col_lake')}</th>
                  <th align="right" style={{ padding: '6px 4px', borderLeft: '0.5px solid var(--hairline)' }}>{t('settings.course_pay.col_total')}</th>
                  <th align="right" style={{ padding: '6px 4px' }}>{t('settings.course_pay.col_instructor_pay')}</th>
                </tr>
              </thead>
              <tbody>
                {courseTypes.map((c) => {
                  const total = Number(c.theory_units) + Number(c.pool_units) + Number(c.lake_units)
                  // Beispiel-Vergütung mit Instruktor-Satz (OWSI/MSDT/MI/CD haben alle 28 CHF)
                  const instrRate =
                    rates.find((r) => r.level === 'OWSI')?.hourly_rate_chf ??
                    rates.find((r) => r.level === 'CD')?.hourly_rate_chf ??
                    0
                  const exampleComp = total * Number(instrRate)
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
                        {chf(exampleComp)}
                      </td>
                    </tr>
                  )
                })}
              </tbody>
            </table>
          </div>
          <div className="caption-2" style={{ marginTop: 12, color: 'var(--ink-2)' }}>
            {t('settings.course_pay.footnote')}
          </div>
        </div>

        <div className="glass card">
          <div className="title-3" style={{ marginBottom: 12 }}>{t('settings.users.title')}</div>
          <div className="caption" style={{ marginBottom: 12 }}>
            {t('settings.users.summary', {
              linked: users.filter((u) => u.auth_linked).length,
              total: users.length,
              count: users.length,
            })}
          </div>
          <div style={{ maxHeight: 400, overflow: 'auto' }}>
            <table style={{ width: '100%', fontSize: 13 }}>
              <thead>
                <tr style={{ borderBottom: '0.5px solid var(--hairline)' }}>
                  <th align="left" style={{ padding: '6px 4px' }}>{t('settings.users.col_name')}</th>
                  <th align="left" style={{ padding: '6px 4px' }}>{t('settings.users.col_email')}</th>
                  <th align="left" style={{ padding: '6px 4px' }}>{t('settings.users.col_role')}</th>
                  <th align="center" style={{ padding: '6px 4px' }}>{t('settings.users.col_login')}</th>
                </tr>
              </thead>
              <tbody>
                {users.map((u) => (
                  <tr key={u.id}>
                    <td style={{ padding: '6px 4px' }}>{u.name}</td>
                    <td style={{ padding: '6px 4px' }} className="caption">{u.email || '—'}</td>
                    <td style={{ padding: '6px 4px' }}>
                      <Chip tone={u.role === 'dispatcher' || u.role === 'cd' ? 'accent' : 'neutral'}>{u.role}</Chip>
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
  const { t } = useTranslation()
  const titleClickToEdit = t('common.click_to_edit')
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
        title={titleClickToEdit}
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

function LanguageCard() {
  const { t } = useTranslation()
  const { lang, setLang } = useLanguage()

  const options: { code: Lang; label: string; flag: string }[] = [
    { code: 'de', label: t('settings.language.de'), flag: '🇩🇪' },
    { code: 'en', label: t('settings.language.en'), flag: '🇬🇧' },
  ]

  return (
    <div className="glass card" style={{ marginBottom: 20 }}>
      <div className="title-3" style={{ marginBottom: 4 }}>{t('settings.language.title')}</div>
      <div className="caption" style={{ marginBottom: 12 }}>
        {t('settings.language.subtitle')}
      </div>
      <div style={{ display: 'flex', gap: 8 }}>
        {options.map((opt) => {
          const active = lang === opt.code
          return (
            <button
              key={opt.code}
              type="button"
              onClick={() => void setLang(opt.code)}
              className={active ? 'btn' : 'btn-ghost'}
              style={{
                display: 'flex',
                alignItems: 'center',
                gap: 8,
                padding: '8px 14px',
                borderRadius: 10,
                fontSize: 13,
                fontWeight: active ? 600 : 400,
                ...(active
                  ? {}
                  : {
                      background: 'rgba(0,0,0,.04)',
                      border: '0.5px solid var(--hairline)',
                      color: 'var(--ink)',
                      cursor: 'pointer',
                    }),
              }}
            >
              <span style={{ fontSize: 16 }}>{opt.flag}</span>
              <span>{opt.label}</span>
              {active && <span style={{ marginLeft: 4 }}>✓</span>}
            </button>
          )
        })}
      </div>
    </div>
  )
}
