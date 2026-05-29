/**
 * SettingsScreen — Foundation-based rewrite.
 *
 * Sections (vertical stack):
 *   1. Sprache              — language toggle as Foundation Pills
 *   2. Excel-Import          — link to import wizard
 *   3. Recalc banner         — appears when rates/units edited (dispatcher)
 *   4. Vergütungssätze       — editable table
 *   5. Kurspunkte            — editable table with example pay
 *   6. Benutzer              — read-only list with auth-link state
 */

import { useState } from 'react'
import { useNavigate, useOutletContext } from 'react-router-dom'
import { useTranslation } from 'react-i18next'
import { useQueryClient } from '@tanstack/react-query'
import {
  PageHeader,
  Banner,
  Pill,
  Icon,
  chf,
} from '@/foundation'
import {
  updateCompRate,
  updateCourseTypeUnits,
  updateCompUnitsForCourseType,
  recalcAllCompensations,
  type CourseTypeUnitField,
} from '@/lib/queries'
import {
  useCompRates,
  useSettingsCourseTypes,
  useSettingsUsers,
} from '@/hooks/useSettings'
import { useLanguage } from '@/i18n/useLanguage'
import type { Lang } from '@/i18n'
import type { OutletCtx } from '@/layout/AppShell'
import { ConnectedAccountsSection } from '@/screens/settings/ConnectedAccountsSection'

export function SettingsScreen() {
  const { t } = useTranslation()
  const navigate = useNavigate()
  const { user } = useOutletContext<OutletCtx>()
  const isDispatcher = user.role === 'dispatcher' || user.role === 'cd' || user.role === 'owner'

  const qc = useQueryClient()
  const { data: rates = [] } = useCompRates()
  const { data: courseTypes = [] } = useSettingsCourseTypes()
  const { data: users = [] } = useSettingsUsers()
  const [dirty, setDirty] = useState(false)
  const [recalcing, setRecalcing] = useState(false)
  const [recalcMsg, setRecalcMsg] = useState<{ kind: 'success' | 'error'; text: string } | null>(null)
  const [diveCenterNr, setDiveCenterNr] = useState<string>(
    () => localStorage.getItem('atoll.padi_dive_center_nr') ?? '',
  )
  const [diveCenterNrDraft, setDiveCenterNrDraft] = useState<string>(
    () => localStorage.getItem('atoll.padi_dive_center_nr') ?? '',
  )

  async function saveRate(rateId: string, newValue: number) {
    // Optimistic: patch the cached list in-place. The fetch-on-error path
    // restores authoritative values via invalidate.
    qc.setQueryData(['settings', 'compRates'], (prev: typeof rates | undefined) =>
      (prev ?? []).map((r) => (r.id === rateId ? { ...r, hourly_rate_chf: newValue } : r)),
    )
    try {
      await updateCompRate(rateId, newValue)
      setDirty(true)
    } catch (err) {
      alert(t('settings.recalc.save_failed') + (err instanceof Error ? err.message : String(err)))
      qc.invalidateQueries({ queryKey: ['settings', 'compRates'] })
    }
  }

  async function saveCourseType(
    id: string,
    field: CourseTypeUnitField,
    newValue: number,
  ) {
    qc.setQueryData(['settings', 'courseTypes'], (prev: typeof courseTypes | undefined) =>
      (prev ?? []).map((c) => (c.id === id ? { ...c, [field]: newValue } : c)),
    )
    try {
      await updateCourseTypeUnits(id, field, newValue)
    } catch (err) {
      alert(t('settings.recalc.save_failed') + (err instanceof Error ? err.message : String(err)))
      qc.invalidateQueries({ queryKey: ['settings', 'courseTypes'] })
      return
    }
    // Keep comp_units in sync. Failure here is non-blocking — the rate
    // hours can drift from course-type units, recalc will reconcile.
    const compUnitField = field.replace('_units', '_h') as 'theory_h' | 'pool_h' | 'lake_h'
    try {
      await updateCompUnitsForCourseType(id, compUnitField, newValue)
    } catch (err) {
      alert(t('settings.recalc.comp_units_sync_failed') + (err instanceof Error ? err.message : String(err)))
    }
    setDirty(true)
  }

  async function runRecalc() {
    if (!confirm(t('settings.recalc.confirm'))) return
    setRecalcing(true)
    setRecalcMsg(null)
    try {
      const row = await recalcAllCompensations()
      setRecalcing(false)
      setRecalcMsg({
        kind: 'success',
        text: row
          ? t('settings.recalc.result', { deleted: row.deleted_count, inserted: row.inserted_count })
          : t('settings.recalc.result_generic'),
      })
      setDirty(false)
      // Recalc rewrites movements globally → blow away any cached saldo /
      // movements / KPI snapshots so the UI doesn't keep showing stale numbers.
      qc.invalidateQueries({ queryKey: ['saldi'] })
      qc.invalidateQueries({ queryKey: ['myMovements'] })
      qc.invalidateQueries({ queryKey: ['cockpit'] })
    } catch (err) {
      setRecalcing(false)
      setRecalcMsg({
        kind: 'error',
        text: t('settings.recalc.error_prefix') + (err instanceof Error ? err.message : String(err)),
      })
    }
  }

  return (
    <div className="atoll-screen">
      <PageHeader title={t('settings.title')} subtitle={t('settings.subtitle')} />

      <div className="atoll-screen__body">
        <LanguageCard />

        {/* Excel import */}
        <section className="atoll-cockpit__card">
          <h2 className="atoll-cockpit__card-title">{t('settings.import.title')}</h2>
          <p className="atoll-cockpit__card-sub">{t('settings.import.subtitle')}</p>
          <div>
            <button
              type="button"
              className="atoll-btn atoll-btn--primary"
              onClick={() => navigate('/einstellungen/import')}
            >
              <Icon.Plus size={14} /> {t('settings.import.open')}
            </button>
          </div>
        </section>

        {isDispatcher && <ConnectedAccountsSection />}

        {dirty && isDispatcher && (
          <Banner tone="warning" title={t('settings.recalc.saved_notice_strong')}>
            <div className="atoll-settings__banner-row">
              <span>{t('settings.recalc.saved_notice_body')}</span>
              <button
                type="button"
                className="atoll-btn atoll-btn--primary"
                onClick={runRecalc}
                disabled={recalcing}
              >
                {recalcing ? t('settings.recalc.calculating') : t('settings.recalc.button')}
              </button>
            </div>
          </Banner>
        )}

        {recalcMsg && (
          <Banner
            tone={recalcMsg.kind === 'success' ? 'success' : 'danger'}
            onDismiss={() => setRecalcMsg(null)}
          >
            {recalcMsg.text}
          </Banner>
        )}

        {/* Comp rates */}
        <section className="atoll-cockpit__card">
          <h2 className="atoll-cockpit__card-title">{t('settings.rates.title')}</h2>
          <p className="atoll-cockpit__card-sub">
            {t('settings.rates.subtitle')}
            {isDispatcher && t('settings.rates.subtitle_dispatcher_hint')}
          </p>
          <table className="atoll-saldi__table">
            <thead>
              <tr>
                <th align="left">{t('settings.rates.col_level')}</th>
                <th align="right">{t('settings.rates.col_chf_per_point')}</th>
              </tr>
            </thead>
            <tbody>
              {rates.map((r) => (
                <tr key={r.id}>
                  <td>{r.level}</td>
                  <td align="right" className="tabular-nums">
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
        </section>

        {/* Course types */}
        <section className="atoll-cockpit__card">
          <h2 className="atoll-cockpit__card-title">{t('settings.course_pay.title')}</h2>
          <p className="atoll-cockpit__card-sub">
            {t('settings.course_pay.subtitle')}
            {isDispatcher && t('settings.rates.subtitle_dispatcher_hint')}
          </p>
          <div className="atoll-settings__table-scroll">
            <table className="atoll-saldi__table atoll-settings__pay-table">
              <thead>
                <tr>
                  <th align="left">{t('settings.course_pay.col_code')}</th>
                  <th align="left">{t('settings.course_pay.col_course')}</th>
                  <th align="right">{t('settings.course_pay.col_theory')}</th>
                  <th align="right">{t('settings.course_pay.col_pool')}</th>
                  <th align="right">{t('settings.course_pay.col_lake')}</th>
                  <th align="right" className="atoll-settings__col-divider">
                    {t('settings.course_pay.col_total')}
                  </th>
                  <th align="right">{t('settings.course_pay.col_instructor_pay')}</th>
                </tr>
              </thead>
              <tbody>
                {courseTypes.map((c) => {
                  const total = Number(c.theory_units) + Number(c.pool_units) + Number(c.lake_units)
                  const instrRate =
                    rates.find((r) => r.level === 'OWSI')?.hourly_rate_chf ??
                    rates.find((r) => r.level === 'CD')?.hourly_rate_chf ??
                    0
                  const exampleComp = total * Number(instrRate)
                  return (
                    <tr key={c.id}>
                      <td className="mono">{c.code}</td>
                      <td>{c.label}</td>
                      <td align="right" className="tabular-nums">
                        {isDispatcher ? (
                          <NumberCell value={c.theory_units} onSave={(v) => saveCourseType(c.id, 'theory_units', v)} />
                        ) : (
                          fmtPoints(c.theory_units)
                        )}
                      </td>
                      <td align="right" className="tabular-nums">
                        {isDispatcher ? (
                          <NumberCell value={c.pool_units} onSave={(v) => saveCourseType(c.id, 'pool_units', v)} />
                        ) : (
                          fmtPoints(c.pool_units)
                        )}
                      </td>
                      <td align="right" className="tabular-nums">
                        {isDispatcher ? (
                          <NumberCell value={c.lake_units} onSave={(v) => saveCourseType(c.id, 'lake_units', v)} />
                        ) : (
                          fmtPoints(c.lake_units)
                        )}
                      </td>
                      <td
                        align="right"
                        className="tabular-nums atoll-settings__col-divider atoll-settings__total"
                      >
                        {fmtPoints(total)}
                      </td>
                      <td align="right" className="tabular-nums atoll-saldi__excel">
                        {chf(exampleComp)}
                      </td>
                    </tr>
                  )
                })}
              </tbody>
            </table>
          </div>
          <div className="atoll-cockpit__card-sub" style={{ marginTop: 'var(--space-3)', marginBottom: 0 }}>
            {t('settings.course_pay.footnote')}
          </div>
        </section>

        {/* PADI settings */}
        <section className="atoll-cockpit__card">
          <h2 className="atoll-cockpit__card-title">{t('settings.padi.title')}</h2>
          <p className="atoll-cockpit__card-sub">{t('settings.padi.subtitle')}</p>
          <div className="atoll-settings__padi-row">
            <label className="atoll-settings__padi-label" htmlFor="padi-dive-center-nr">
              {t('settings.padi.dive_center_nr_label')}
            </label>
            <input
              id="padi-dive-center-nr"
              type="text"
              className="atoll-settings__padi-input"
              value={diveCenterNrDraft}
              onChange={(e) => setDiveCenterNrDraft(e.target.value)}
              onBlur={() => {
                const v = diveCenterNrDraft.trim()
                localStorage.setItem('atoll.padi_dive_center_nr', v)
                setDiveCenterNr(v)
              }}
              onKeyDown={(e) => {
                if (e.key === 'Enter') {
                  const v = diveCenterNrDraft.trim()
                  localStorage.setItem('atoll.padi_dive_center_nr', v)
                  setDiveCenterNr(v)
                  ;(e.target as HTMLInputElement).blur()
                }
              }}
              placeholder={t('settings.padi.dive_center_nr_placeholder')}
            />
            {diveCenterNr && (
              <span className="atoll-settings__padi-saved">
                <Icon.Check size={12} aria-hidden style={{ color: 'var(--brand-teal)' }} />
                {t('settings.padi.saved')}
              </span>
            )}
          </div>
        </section>

        {/* Users */}
        <section className="atoll-cockpit__card">
          <h2 className="atoll-cockpit__card-title">{t('settings.users.title')}</h2>
          <p className="atoll-cockpit__card-sub">
            {t('settings.users.summary', {
              linked: users.filter((u) => u.auth_linked).length,
              total: users.length,
              count: users.length,
            })}
          </p>
          <div className="atoll-settings__users-scroll">
            <table className="atoll-saldi__table">
              <thead>
                <tr>
                  <th align="left">{t('settings.users.col_name')}</th>
                  <th align="left">{t('settings.users.col_email')}</th>
                  <th align="left">{t('settings.users.col_role')}</th>
                  <th align="center">{t('settings.users.col_login')}</th>
                </tr>
              </thead>
              <tbody>
                {users.map((u) => (
                  <tr key={u.id}>
                    <td>{u.name}</td>
                    <td className="atoll-saldi__excel">{u.email || '—'}</td>
                    <td>
                      <Pill
                        tone={
                          u.role === 'owner' ? 'pro'
                          : u.role === 'cd' || u.role === 'dispatcher' ? 'brand'
                          : 'neutral'
                        }
                        size="sm"
                      >
                        {u.role}
                      </Pill>
                    </td>
                    <td align="center">
                      {u.auth_linked ? (
                        <Icon.Check size={14} aria-hidden style={{ color: 'var(--brand-teal)' }} />
                      ) : (
                        <span className="atoll-saldi__excel">—</span>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>
      </div>
    </div>
  )
}

// ──────────────────────── NumberCell ────────────────────────

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
      <button
        type="button"
        className="atoll-settings__numcell"
        title={t('common.click_to_edit')}
        onClick={() => {
          setDraft(String(value))
          setEditing(true)
        }}
      >
        {fmtPoints(value)}{suffix}
      </button>
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
      className="atoll-settings__numinput"
    />
  )
}

function fmtPoints(n: number | string): string {
  const num = Number(n)
  if (num === 0) return '—'
  return num % 1 === 0 ? num.toFixed(0) : num.toFixed(1)
}

// ──────────────────────── Language card ────────────────────────

function LanguageCard() {
  const { t } = useTranslation()
  const { lang, setLang } = useLanguage()

  const options: { code: Lang; label: string; flag: string }[] = [
    { code: 'de', label: t('settings.language.de'), flag: '🇩🇪' },
    { code: 'en', label: t('settings.language.en'), flag: '🇬🇧' },
  ]

  return (
    <section className="atoll-cockpit__card">
      <h2 className="atoll-cockpit__card-title">{t('settings.language.title')}</h2>
      <p className="atoll-cockpit__card-sub">{t('settings.language.subtitle')}</p>
      <div className="atoll-settings__lang-row">
        {options.map((opt) => {
          const active = lang === opt.code
          return (
            <button
              key={opt.code}
              type="button"
              onClick={() => void setLang(opt.code)}
              className={`atoll-settings__lang${active ? ' atoll-settings__lang--active' : ''}`}
            >
              <span className="atoll-settings__lang-flag">{opt.flag}</span>
              <span>{opt.label}</span>
              {active && <Icon.Check size={12} aria-hidden />}
            </button>
          )
        })}
      </div>
    </section>
  )
}
