// apps/web/src/screens/contacts/activity/ActivityComposer.tsx
//
// Phase G Phase 5 Task 3 — ActivityComposer.
//
// Composer für den globalen `/aktivitaet`-Screen. Pflicht-Pick: erst Contact,
// dann erst werden die 6 EventComposer-Optionen sichtbar. Die Selection bleibt
// nach Log-Aktionen erhalten, sodass mehrere Events am selben Contact geloggt
// werden können. Klick auf das ✕ im Chip resettet den Zustand.
import { useState } from 'react'
import { ContactPicker, type ContactPickerValue } from './ContactPicker'
import { EventComposer } from '@/screens/contacts/timeline/EventComposer'

export function ActivityComposer() {
  const [selected, setSelected] = useState<ContactPickerValue | null>(null)

  return (
    <div
      data-testid="activity-composer"
      style={{
        borderBottomWidth: 1,
        borderBottomStyle: 'solid',
        borderBottomColor: 'var(--border-subtle, #eee)',
        backgroundColor: 'var(--surface-primary, white)',
        position: 'sticky',
        top: 0,
        zIndex: 10,
      }}
    >
      <div style={{ padding: '12px 14px' }}>
        <ContactPicker
          value={selected}
          onChange={setSelected}
          placeholder="Welcher Contact?"
          autoFocus
        />
      </div>
      {selected && <EventComposer contactId={selected.id} />}
    </div>
  )
}
