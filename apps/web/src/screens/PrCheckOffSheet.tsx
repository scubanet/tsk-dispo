import { useEffect, useState } from 'react'
import { Sheet } from '@/components/Sheet'
import { Icon } from '@/components/Icon'
import { supabase } from '@/lib/supabase'
import type { CourseParticipant } from '@/lib/queries'

export type ScoreSchema = 'score1to5' | 'score1to5_decimal' | 'percent' | 'passFail' | 'rubric' | 'done'

interface SkillContext {
  code: string
  title: string
  scoreSchema: ScoreSchema
  passThreshold?: number
}

interface ExistingRecord {
  id: string
  student_id: string
  pr_code: string
  status: string
  score: number | null
  pass: boolean | null
  assessed_on: string | null
  assessed_by_text: string | null
  notes: string | null
}

interface RowState {
  status: string         // not_started | in_progress | completed | remediation
  score: string          // numeric as string (1-5 or percent)
  pass: 'yes' | 'no' | ''
  notes: string
  assessed_on: string    // ISO date
  recordId?: string      // existing PR record id, if loaded
  dirty: boolean
}

interface Props {
  open: boolean
  onClose: () => void
  onSaved: () => void
  courseId: string
  skill: SkillContext | null
  participants: CourseParticipant[]
  defaultAssessor: string
  defaultDate?: string
}

const STATUS_OPTIONS = [
  { code: 'not_started', label: 'Offen',         tone: 'rgba(255,255,255,.10)' },
  { code: 'in_progress', label: 'Laufend',       tone: 'rgba(255,204,0,.18)' },
  { code: 'completed',   label: 'Abgenommen',    tone: 'rgba(52,199,89,.20)' },
  { code: 'remediation', label: 'Remediation',   tone: 'rgba(255,69,58,.18)' },
]

export function PrCheckOffSheet({
  open,
  onClose,
  onSaved,
  courseId,
  skill,
  participants,
  defaultAssessor,
  defaultDate,
}: Props) {
  const [rows, setRows] = useState<Record<string, RowState>>({})
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState<string | null>(null)

  const cands = participants
    .filter((p) => p.status !== 'dropped')
    .filter((p) => !!p.student)

  useEffect(() => {
    if (!open || !skill) return
    setError(null)
    // Bestehende Records dieses Skills für alle Kandidaten dieses Kurses laden
    supabase
      .from('performance_records')
      .select('id, student_id, pr_code, status, score, pass, assessed_on, assessed_by_text, notes')
      .eq('course_id', courseId)
      .eq('pr_code', skill.code)
      .then(({ data }) => {
        const initial: Record<string, RowState> = {}
        const existing = (data ?? []) as ExistingRecord[]
        for (const c of cands) {
          const r = existing.find((e) => e.student_id === c.student!.id)
          initial[c.student!.id] = {
            status: r?.status ?? 'not_started',
            score: r?.score != null ? String(r.score) : '',
            pass: r?.pass === true ? 'yes' : r?.pass === false ? 'no' : '',
            notes: r?.notes ?? '',
            assessed_on: r?.assessed_on ?? defaultDate ?? new Date().toISOString().slice(0, 10),
            recordId: r?.id,
            dirty: false,
          }
        }
        setRows(initial)
      })
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [open, skill?.code, courseId])

  function update(studentId: string, patch: Partial<RowState>) {
    setRows((prev) => ({
      ...prev,
      [studentId]: { ...prev[studentId], ...patch, dirty: true },
    }))
  }

  function quickSet(studentId: string, status: string) {
    const patch: Partial<RowState> = { status }
    // Quick-set Logik: bei "completed" automatisch Pass + Default-Score setzen, falls leer
    if (status === 'completed' && skill) {
      if (skill.scoreSchema === 'passFail') patch.pass = 'yes'
      else if (skill.scoreSchema === 'score1to5' && !rows[studentId]?.score) patch.score = String(skill.passThreshold ?? 3)
      else if (skill.scoreSchema === 'percent' && !rows[studentId]?.score) patch.score = String(skill.passThreshold ?? 75)
    }
    if (status === 'remediation' && skill?.scoreSchema === 'passFail') {
      patch.pass = 'no'
    }
    update(studentId, patch)
  }

  // Setzt Score und leitet Status automatisch ab (für score1to5 und percent)
  function setScore(studentId: string, score: string) {
    if (!skill) return
    const patch: Partial<RowState> = { score }
    if (score === '') {
      patch.status = 'not_started'
    } else {
      const n = Number(score)
      const threshold = skill.passThreshold ?? (skill.scoreSchema === 'percent' ? 75 : 3)
      patch.status = n >= threshold ? 'completed' : 'remediation'
    }
    update(studentId, patch)
  }

  function setPass(studentId: string, pass: 'yes' | 'no') {
    const patch: Partial<RowState> = {
      pass,
      status: pass === 'yes' ? 'completed' : 'remediation',
    }
    update(studentId, patch)
  }

  // Einfacher Done-Toggle ohne Score / Pass-Fail
  function setDone(studentId: string, done: boolean) {
    update(studentId, {
      status: done ? 'completed' : 'not_started',
      // pass/score bleiben null
    })
  }

  async function save() {
    if (!skill) return
    setSaving(true)
    setError(null)
    const dirty = Object.entries(rows).filter(([, r]) => r.dirty)
    if (dirty.length === 0) {
      setSaving(false)
      onClose()
      return
    }
    const payload = dirty.map(([studentId, r]) => ({
      student_id: studentId,
      course_id: courseId,
      pr_code: skill.code,
      status: r.status,
      score: r.score === '' ? null : Number(r.score),
      pass: r.pass === 'yes' ? true : r.pass === 'no' ? false : null,
      assessed_on: r.assessed_on || null,
      assessed_by_text: defaultAssessor || null,
      notes: r.notes.trim() || null,
    }))
    // upsert auf UNIQUE(student_id, course_id, pr_code) — siehe Migration 0051
    const { error: upErr } = await supabase
      .from('performance_records')
      .upsert(payload, { onConflict: 'student_id,course_id,pr_code' })
    if (upErr) {
      setError(upErr.message)
      setSaving(false)
      return
    }
    setSaving(false)
    onSaved()
    onClose()
  }

  if (!skill) return null

  const dirtyCount = Object.values(rows).filter((r) => r.dirty).length

  return (
    <Sheet open={open} onClose={onClose} title="PR Check-Off" width={640}>
      <div style={{ display: 'grid', gap: 14 }}>
        <div className="glass-thin" style={{ padding: 12, borderRadius: 12 }}>
          <div className="caption-2" style={{ opacity: 0.6, marginBottom: 4 }}>
            <span className="mono">{skill.code}</span>
          </div>
          <div style={{ fontWeight: 700, fontSize: 15 }}>{skill.title}</div>
          <div className="caption" style={{ marginTop: 4 }}>
            Schema: {labelFor(skill.scoreSchema)}
            {skill.scoreSchema === 'score1to5' && skill.passThreshold ? ` · Pass ≥ ${skill.passThreshold}/5` : ''}
            {skill.scoreSchema === 'score1to5_decimal' && skill.passThreshold ? ` · Pass ≥ ${skill.passThreshold.toFixed(2)}/5` : ''}
            {skill.scoreSchema === 'percent' && skill.passThreshold ? ` · Pass ≥ ${skill.passThreshold}%` : ''}
          </div>
        </div>

        {cands.length === 0 ? (
          <div className="caption" style={{ padding: 20 }}>
            Keine Kandidat:innen im Kurs — über den „Teilnehmer"-Tab erst Personen einschreiben.
          </div>
        ) : (
          <div style={{ display: 'grid', gap: 10 }}>
            {cands.map((c) => {
              const row = rows[c.student!.id]
              if (!row) return null
              return (
                <div
                  key={c.id}
                  className="glass-thin"
                  style={{ padding: 12, borderRadius: 12, display: 'grid', gap: 10 }}
                >
                  <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                    <div className="avatar avatar-sm" style={{ background: 'linear-gradient(135deg,#34c759,#00c2a8)' }}>
                      {c.student!.name.split(' ').map((s) => s[0]).join('').slice(0, 2).toUpperCase()}
                    </div>
                    <div style={{ fontWeight: 600, flex: 1 }}>{c.student!.name}</div>
                    {row.dirty && (
                      <span className="caption-2" style={{ color: '#FFCC00' }}>· geändert</span>
                    )}
                  </div>

                  {/* Score-/Pass-Eingabe direkt — Status leitet sich automatisch ab */}
                  {skill.scoreSchema === 'score1to5' && (
                    <div style={{ display: 'flex', gap: 6, alignItems: 'center' }}>
                      <div style={{ display: 'flex', gap: 4 }}>
                        {[1, 2, 3, 4, 5].map((n) => {
                          const passes = n >= (skill.passThreshold ?? 3)
                          const selected = row.score === String(n)
                          return (
                            <button
                              key={n}
                              onClick={() => setScore(c.student!.id, String(n))}
                              style={{
                                width: 40,
                                height: 40,
                                borderRadius: 10,
                                border: selected
                                  ? `1px solid ${passes ? 'rgba(52,199,89,.6)' : 'rgba(255,149,0,.6)'}`
                                  : '0.5px solid var(--hairline)',
                                background: selected
                                  ? (passes ? 'rgba(52,199,89,.30)' : 'rgba(255,149,0,.30)')
                                  : 'transparent',
                                fontWeight: 700,
                                fontSize: 16,
                                cursor: 'pointer',
                                color: 'var(--ink)',
                              }}
                              title={passes ? 'Pass' : 'unter Threshold → Remediation'}
                            >
                              {n}
                            </button>
                          )
                        })}
                      </div>
                      {row.status === 'completed' && <span className="caption-2" style={{ color: '#34C759' }}>✓ Abgenommen</span>}
                      {row.status === 'remediation' && <span className="caption-2" style={{ color: '#FF9500' }}>⟲ Remediation</span>}
                      {row.score && (
                        <button
                          onClick={() => setScore(c.student!.id, '')}
                          className="caption-2"
                          style={{
                            marginLeft: 'auto',
                            padding: '4px 8px',
                            background: 'transparent',
                            border: '0.5px solid var(--hairline)',
                            borderRadius: 6,
                            color: 'var(--ink-secondary)',
                            cursor: 'pointer',
                          }}
                        >
                          zurücksetzen
                        </button>
                      )}
                    </div>
                  )}

                  {skill.scoreSchema === 'score1to5_decimal' && (
                    <div style={{ display: 'flex', gap: 10, alignItems: 'center' }}>
                      <input
                        type="number"
                        min={1}
                        max={5}
                        step={0.01}
                        value={row.score}
                        onChange={(e) => setScore(c.student!.id, e.target.value)}
                        style={{
                          width: 110,
                          padding: '8px 10px',
                          borderRadius: 8,
                          border: '0.5px solid var(--hairline)',
                          background: 'var(--surface-strong)',
                          color: 'var(--ink)',
                          fontSize: 16,
                          fontWeight: 700,
                          textAlign: 'center',
                        }}
                        placeholder="1.00–5.00"
                      />
                      <span className="caption-2">/ 5.00</span>
                      {row.status === 'completed' && (
                        <span className="caption-2" style={{ color: '#34C759' }}>
                          ✓ ≥ {skill.passThreshold?.toFixed(2)}
                        </span>
                      )}
                      {row.status === 'remediation' && (
                        <span className="caption-2" style={{ color: '#FF9500' }}>
                          ⟲ &lt; {skill.passThreshold?.toFixed(2)}
                        </span>
                      )}
                    </div>
                  )}

                  {skill.scoreSchema === 'percent' && (
                    <div style={{ display: 'flex', gap: 10, alignItems: 'center' }}>
                      <input
                        type="number"
                        min={0}
                        max={100}
                        value={row.score}
                        onChange={(e) => setScore(c.student!.id, e.target.value)}
                        style={{
                          width: 90,
                          padding: '8px 10px',
                          borderRadius: 8,
                          border: '0.5px solid var(--hairline)',
                          background: 'var(--surface-strong)',
                          color: 'var(--ink)',
                          fontSize: 14,
                          fontWeight: 600,
                        }}
                        placeholder="0–100"
                      />
                      <span className="caption-2">%</span>
                      {row.status === 'completed' && <span className="caption-2" style={{ color: '#34C759' }}>✓ Pass</span>}
                      {row.status === 'remediation' && <span className="caption-2" style={{ color: '#FF9500' }}>⟲ unter Threshold</span>}
                    </div>
                  )}

                  {skill.scoreSchema === 'passFail' && (
                    <div style={{ display: 'flex', gap: 6 }}>
                      <button
                        onClick={() => setPass(c.student!.id, 'yes')}
                        style={{
                          padding: '8px 18px',
                          borderRadius: 8,
                          border: '0.5px solid var(--hairline)',
                          background: row.pass === 'yes' ? 'rgba(52,199,89,.30)' : 'transparent',
                          color: 'var(--ink)',
                          fontWeight: 600,
                          fontSize: 14,
                          cursor: 'pointer',
                        }}
                      >✓ Pass</button>
                      <button
                        onClick={() => setPass(c.student!.id, 'no')}
                        style={{
                          padding: '8px 18px',
                          borderRadius: 8,
                          border: '0.5px solid var(--hairline)',
                          background: row.pass === 'no' ? 'rgba(255,69,58,.30)' : 'transparent',
                          color: 'var(--ink)',
                          fontWeight: 600,
                          fontSize: 14,
                          cursor: 'pointer',
                        }}
                      >✗ Fail</button>
                    </div>
                  )}

                  {skill.scoreSchema === 'done' && (
                    <label
                      style={{
                        display: 'flex',
                        alignItems: 'center',
                        gap: 10,
                        padding: '8px 12px',
                        borderRadius: 10,
                        border: '0.5px solid var(--hairline)',
                        background: row.status === 'completed' ? 'rgba(52,199,89,.18)' : 'transparent',
                        cursor: 'pointer',
                        userSelect: 'none',
                      }}
                    >
                      <input
                        type="checkbox"
                        checked={row.status === 'completed'}
                        onChange={(e) => setDone(c.student!.id, e.target.checked)}
                        style={{ width: 18, height: 18, cursor: 'pointer' }}
                      />
                      <span style={{ fontWeight: 600 }}>
                        {row.status === 'completed' ? '✓ Erledigt' : 'als erledigt markieren'}
                      </span>
                    </label>
                  )}

                  {skill.scoreSchema === 'rubric' && (
                    /* Rubric: nur Status-Buttons, da kein Skalar-Score */
                    <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
                      {STATUS_OPTIONS.map((s) => (
                        <button
                          key={s.code}
                          onClick={() => quickSet(c.student!.id, s.code)}
                          style={{
                            padding: '6px 12px',
                            borderRadius: 999,
                            fontSize: 12,
                            border: '0.5px solid var(--hairline)',
                            background: row.status === s.code ? s.tone : 'transparent',
                            fontWeight: row.status === s.code ? 700 : 400,
                            cursor: 'pointer',
                            color: 'var(--ink)',
                          }}
                        >
                          {s.label}
                        </button>
                      ))}
                    </div>
                  )}

                  <div style={{ display: 'grid', gridTemplateColumns: '140px 1fr', gap: 8 }}>
                    <input
                      type="date"
                      value={row.assessed_on}
                      onChange={(e) => update(c.student!.id, { assessed_on: e.target.value })}
                      style={{
                        padding: '6px 10px',
                        borderRadius: 8,
                        border: '0.5px solid var(--hairline)',
                        background: 'var(--surface-strong)',
                        color: 'var(--ink)',
                        fontSize: 13,
                      }}
                    />
                    <input
                      type="text"
                      value={row.notes}
                      onChange={(e) => update(c.student!.id, { notes: e.target.value })}
                      placeholder="Notiz (optional)"
                      style={{
                        padding: '6px 10px',
                        borderRadius: 8,
                        border: '0.5px solid var(--hairline)',
                        background: 'var(--surface-strong)',
                        color: 'var(--ink)',
                        fontSize: 13,
                      }}
                    />
                  </div>
                </div>
              )
            })}
          </div>
        )}

        {error && <div className="chip chip-red">{error}</div>}

        <div style={{ display: 'flex', gap: 8, marginTop: 4, alignItems: 'center' }}>
          <span className="caption">
            Assessor: <strong>{defaultAssessor}</strong> · {dirtyCount} Änderung{dirtyCount === 1 ? '' : 'en'}
          </span>
          <button className="btn-secondary btn" onClick={onClose} style={{ marginLeft: 'auto' }}>
            Abbrechen
          </button>
          <button className="btn" onClick={save} disabled={saving || dirtyCount === 0}>
            {saving ? 'Speichere…' : <><Icon name="check" size={12} /> Speichern</>}
          </button>
        </div>
      </div>
    </Sheet>
  )
}

function labelFor(s: ScoreSchema): string {
  switch (s) {
    case 'score1to5':         return '1–5 Demonstration'
    case 'score1to5_decimal': return '1.00–5.00 Lehrprobe'
    case 'percent':           return 'Prozent'
    case 'passFail':          return 'Pass / Fail'
    case 'rubric':            return 'Rubric'
    case 'done':              return 'Erledigt-Toggle'
  }
}
