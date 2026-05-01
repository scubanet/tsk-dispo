import { useState } from 'react'
import type { PreviewData } from './index'

interface Props {
  preview: PreviewData
  onMappingsConfirmed: (mappings: Record<string, string>) => void
}

export function Stage2Mapping({ preview, onMappingsConfirmed }: Props) {
  const [codeMap, setCodeMap] = useState<Record<string, string>>({})
  const [nameMap, setNameMap] = useState<Record<string, string>>({})

  const knownNames = preview.raw.instructors.map((i) => i.name).sort()

  function handleConfirm() {
    const merged: Record<string, string> = {}
    for (const [k, v] of Object.entries(codeMap)) merged[`code:${k}`] = v
    for (const [k, v] of Object.entries(nameMap)) merged[`name:${k}`] = v
    onMappingsConfirmed(merged)
  }

  const noAmbiguities =
    preview.ambiguous_codes.length === 0 && preview.ambiguous_names.length === 0

  return (
    <div className="glass card" style={{ padding: 24 }}>
      <div className="title-3" style={{ marginBottom: 12 }}>Schritt 2 — Mehrdeutigkeiten</div>

      <div className="caption" style={{ marginBottom: 16 }}>
        {preview.course_rows} Kurszeilen · {preview.instructors_in_summary} Instructors gefunden
      </div>

      {noAmbiguities && (
        <div className="chip chip-green" style={{ marginBottom: 16 }}>
          ✓ Keine Mehrdeutigkeiten — kann direkt weiter
        </div>
      )}

      {preview.ambiguous_codes.length > 0 && (
        <>
          <div className="caption" style={{ margin: '12px 0 6px' }}>Unklare Kurstyp-Codes:</div>
          {preview.ambiguous_codes.map((code) => (
            <div
              key={code}
              style={{ display: 'flex', gap: 12, marginBottom: 8, alignItems: 'center' }}
            >
              <span className="mono" style={{ width: 160 }}>{code}</span>
              <input
                placeholder="DB-Code (z.B. DRY)"
                value={codeMap[code] ?? ''}
                onChange={(e) => setCodeMap({ ...codeMap, [code]: e.target.value })}
                style={{
                  padding: '6px 10px',
                  border: '0.5px solid var(--hairline)',
                  borderRadius: 8,
                  background: 'var(--surface-strong)',
                }}
              />
            </div>
          ))}
        </>
      )}

      {preview.ambiguous_names.length > 0 && (
        <>
          <div className="caption" style={{ margin: '20px 0 6px' }}>
            Unklare Instructor-Namen:
          </div>
          {preview.ambiguous_names.map((name) => (
            <div
              key={name}
              style={{ display: 'flex', gap: 12, marginBottom: 8, alignItems: 'center' }}
            >
              <span className="mono" style={{ width: 200 }}>{name}</span>
              <select
                value={nameMap[name] ?? ''}
                onChange={(e) => setNameMap({ ...nameMap, [name]: e.target.value })}
                style={{
                  padding: '6px 10px',
                  border: '0.5px solid var(--hairline)',
                  borderRadius: 8,
                  background: 'var(--surface-strong)',
                  minWidth: 240,
                }}
              >
                <option value="">— bitte wählen —</option>
                {knownNames.map((n) => (
                  <option key={n} value={n}>{n}</option>
                ))}
                <option value="__skip__">⏭ überspringen</option>
              </select>
            </div>
          ))}
        </>
      )}

      <button className="btn" onClick={handleConfirm} style={{ marginTop: 20 }}>
        Mapping bestätigen → Dry-Run
      </button>
    </div>
  )
}
