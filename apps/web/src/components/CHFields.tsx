/**
 * CHDateField / CHTimeField — locale-stable Swiss date & time inputs.
 *
 * Problem: native <input type="date"> / <input type="time"> render in the
 * browser's UI language (en-US on an English Safari → MM/DD/YYYY + 12h AM/PM),
 * regardless of the page `lang` or the app's own de-CH formatting. WebKit in
 * particular ignores the document language for these controls.
 *
 * Solution: show a controlled TEXT input formatted dd.MM.yyyy / HH:mm (always
 * CH), parse user input back to the ISO value the rest of the app stores
 * (yyyy-MM-dd / HH:mm). When `picker` is on (default), a small button also opens
 * the *native* picker via showPicker() for convenience — only the always-visible
 * field is forced to CH. Pass `picker={false}` in compact/inline layouts.
 *
 * Drop-in API mirrors the native controlled input:
 *   <CHDateField value={isoDate} onChange={setIsoDate} style={inputStyle} />
 *   <CHTimeField value={hhmm}    onChange={setHhmm}    style={inputStyle} picker={false} />
 */
import { useEffect, useRef, useState, type CSSProperties } from 'react'

// ── date helpers (ISO yyyy-MM-dd ↔ CH dd.MM.yyyy) ─────────────────────────
export function isoToChDate(iso: string | null | undefined): string {
  if (!iso) return ''
  const m = iso.match(/^(\d{4})-(\d{2})-(\d{2})/)
  return m ? `${m[3]}.${m[2]}.${m[1]}` : ''
}

export function chToIsoDate(ch: string): string | null {
  const s = ch.trim()
  if (s === '') return ''
  const m = s.match(/^(\d{1,2})[.\/-](\d{1,2})[.\/-](\d{2,4})$/)
  if (!m) return null
  let [, d, mo, y] = m
  if (y.length === 2) y = `20${y}`
  const dd = d.padStart(2, '0')
  const mm = mo.padStart(2, '0')
  const iso = `${y}-${mm}-${dd}`
  const dt = new Date(`${iso}T00:00:00`)
  if (isNaN(dt.getTime())) return null
  if (dt.getUTCFullYear() !== Number(y) || dt.getUTCMonth() + 1 !== Number(mm) || dt.getUTCDate() !== Number(dd)) {
    return null // reject impossible dates like 31.02.
  }
  return iso
}

// ── time helpers (HH:mm, 24h) ─────────────────────────────────────────────
export function normalizeChTime(s: string): string | null {
  const t = s.trim()
  if (t === '') return ''
  const m = t.match(/^(\d{1,2})[:.]?(\d{2})$/)
  if (!m) return null
  const h = Number(m[1])
  const min = Number(m[2])
  if (h > 23 || min > 59) return null
  return `${String(h).padStart(2, '0')}:${String(min).padStart(2, '0')}`
}

const calendarIcon = (
  <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" aria-hidden>
    <rect x="3" y="4" width="18" height="18" rx="2" />
    <path d="M16 2v4M8 2v4M3 10h18" />
  </svg>
)
const clockIcon = (
  <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" aria-hidden>
    <circle cx="12" cy="12" r="9" />
    <path d="M12 7v5l3 2" />
  </svg>
)

interface FieldProps {
  /** ISO value: yyyy-MM-dd for date, HH:mm for time. '' = empty. */
  value: string
  onChange: (value: string) => void
  style?: CSSProperties
  disabled?: boolean
  id?: string
  placeholder?: string
  /** Show the native-picker affordance. Default true. Set false in compact rows. */
  picker?: boolean
}

function PickerButton({ icon, onClick, disabled }: { icon: React.ReactNode; onClick: () => void; disabled?: boolean }) {
  return (
    <button
      type="button"
      tabIndex={-1}
      aria-hidden
      disabled={disabled}
      onMouseDown={(e) => e.preventDefault()}
      onClick={onClick}
      style={{
        position: 'absolute', right: 6, top: '50%', transform: 'translateY(-50%)',
        display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
        border: 0, background: 'transparent', padding: 2, cursor: disabled ? 'default' : 'pointer',
        color: 'var(--text-tertiary, #888)', lineHeight: 0,
      }}
    >
      {icon}
    </button>
  )
}

export function CHDateField({ value, onChange, style, disabled, id, placeholder = 'TT.MM.JJJJ', picker = true }: FieldProps) {
  const [text, setText] = useState(() => isoToChDate(value))
  const focused = useRef(false)
  const pickerRef = useRef<HTMLInputElement>(null)

  useEffect(() => { if (!focused.current) setText(isoToChDate(value)) }, [value])

  const onText = (raw: string) => {
    setText(raw)
    const iso = chToIsoDate(raw)
    if (iso !== null) onChange(iso)
  }
  const onBlur = () => {
    focused.current = false
    const iso = chToIsoDate(text)
    if (iso !== null) { onChange(iso); setText(isoToChDate(iso)) }
    else setText(isoToChDate(value))
  }
  const textInput = (extra?: CSSProperties) => (
    <input
      id={id} type="text" inputMode="numeric" autoComplete="off"
      value={text} disabled={disabled} placeholder={placeholder}
      onFocus={() => { focused.current = true }}
      onChange={(e) => onText(e.target.value)}
      onBlur={onBlur}
      style={{ ...style, ...extra }}
    />
  )

  if (!picker) return textInput()
  return (
    <div style={{ position: 'relative' }}>
      {textInput({ paddingRight: 30 })}
      <PickerButton icon={calendarIcon} disabled={disabled} onClick={() => pickerRef.current?.showPicker?.()} />
      <input
        ref={pickerRef} type="date" value={value || ''} disabled={disabled} tabIndex={-1} aria-hidden
        onChange={(e) => onChange(e.target.value)}
        style={{ position: 'absolute', right: 6, bottom: 0, width: 1, height: 1, opacity: 0, pointerEvents: 'none' }}
      />
    </div>
  )
}

export function CHTimeField({ value, onChange, style, disabled, id, placeholder = 'HH:MM', picker = true }: FieldProps) {
  const [text, setText] = useState(() => value ?? '')
  const focused = useRef(false)
  const pickerRef = useRef<HTMLInputElement>(null)

  useEffect(() => { if (!focused.current) setText(value ?? '') }, [value])

  const onText = (raw: string) => {
    setText(raw)
    const hhmm = normalizeChTime(raw)
    if (hhmm !== null) onChange(hhmm)
  }
  const onBlur = () => {
    focused.current = false
    const hhmm = normalizeChTime(text)
    if (hhmm !== null) { onChange(hhmm); setText(hhmm) }
    else setText(value ?? '')
  }
  const textInput = (extra?: CSSProperties) => (
    <input
      id={id} type="text" inputMode="numeric" autoComplete="off"
      value={text} disabled={disabled} placeholder={placeholder}
      onFocus={() => { focused.current = true }}
      onChange={(e) => onText(e.target.value)}
      onBlur={onBlur}
      style={{ ...style, ...extra }}
    />
  )

  if (!picker) return textInput()
  return (
    <div style={{ position: 'relative' }}>
      {textInput({ paddingRight: 30 })}
      <PickerButton icon={clockIcon} disabled={disabled} onClick={() => pickerRef.current?.showPicker?.()} />
      <input
        ref={pickerRef} type="time" value={value || ''} disabled={disabled} tabIndex={-1} aria-hidden
        onChange={(e) => onChange(e.target.value)}
        style={{ position: 'absolute', right: 6, bottom: 0, width: 1, height: 1, opacity: 0, pointerEvents: 'none' }}
      />
    </div>
  )
}
