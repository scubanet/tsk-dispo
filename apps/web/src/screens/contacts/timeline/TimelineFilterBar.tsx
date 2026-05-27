// apps/web/src/screens/contacts/timeline/TimelineFilterBar.tsx
import type { TimelineFilter, EventType } from '@/types/contactEvents'

interface Props {
  value: TimelineFilter
  onChange: (next: TimelineFilter) => void
}

// Bucket-Definition: ein UI-Chip kann mehrere event_types zusammenfassen.
// 'Kurs' = course_enrollment + certification_issued + skill_checked + intake_checkpoint.
// 'Saldo' = saldo_movement nur.
// 'Mail' = email_external nur (System-Events haben keinen Mail-Typ in Phase G).
const BUCKETS: { label: string; types: EventType[] }[] = [
  { label: 'Notiz',   types: ['note'] },
  { label: 'Anruf',   types: ['call'] },
  { label: 'Mail',    types: ['email_external'] },
  { label: 'WhatsApp',types: ['whatsapp_log'] },
  { label: 'Termin',  types: ['meeting_past'] },
  { label: 'Task',    types: ['task'] },
  { label: 'Kurs',    types: ['course_enrollment', 'certification_issued', 'skill_checked', 'intake_checkpoint'] },
  { label: 'Saldo',   types: ['saldo_movement'] },
  { label: 'Pipeline',types: ['pipeline_change'] },
  { label: 'Audit',   types: ['role_change', 'audit_edit'] },
]

export function TimelineFilterBar({ value, onChange }: Props) {
  const activeSet = new Set(value.event_types ?? [])
  const noFilter = !value.event_types?.length

  function toggleBucket(types: EventType[]) {
    // If all types in bucket are active, remove them; otherwise add them.
    const allActive = types.every(t => activeSet.has(t))
    const next = new Set(activeSet)
    if (allActive) {
      types.forEach(t => next.delete(t))
    } else {
      types.forEach(t => next.add(t))
    }
    onChange({ ...value, event_types: next.size > 0 ? Array.from(next) : undefined })
  }

  function pressed(types: EventType[]): boolean {
    return types.every(t => activeSet.has(t))
  }

  return (
    <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6, padding: '8px 0' }}>
      <button
        type="button"
        aria-pressed={noFilter}
        onClick={() => onChange({ ...value, event_types: undefined })}
        style={chipStyle(noFilter)}
      >
        Alle
      </button>
      {BUCKETS.map(b => (
        <button
          key={b.label}
          type="button"
          aria-pressed={pressed(b.types)}
          onClick={() => toggleBucket(b.types)}
          style={chipStyle(pressed(b.types))}
        >
          {b.label}
        </button>
      ))}
    </div>
  )
}

function chipStyle(active: boolean): React.CSSProperties {
  return {
    padding: '4px 10px',
    borderRadius: 999,
    border: `1px solid ${active ? 'var(--brand-blue, #4a90e2)' : 'var(--border-subtle, #ddd)'}`,
    background: active ? 'var(--brand-blue-soft, #e8f0fb)' : 'transparent',
    color: active ? 'var(--brand-blue, #4a90e2)' : 'var(--text-secondary, #555)',
    cursor: 'pointer',
    fontSize: 13,
    fontWeight: active ? 500 : 400,
  }
}
