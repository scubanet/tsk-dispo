// apps/web/src/screens/contacts/sidebar/StatBand.tsx
//
// STUB für Phase G Phase 3 Task 5 — wird in Task 13 ersetzt durch 4-Tile-Band
// (Saldo / Aktive Kurse / Letzter Kontakt / Nächste Action).
import type { ContactWithProperties } from '@/types/contactProperties'

interface Props {
  contact: ContactWithProperties
}

export function StatBand({ contact: _contact }: Props) {
  return (
    <div data-testid="stat-band-stub" style={{ padding: 8, color: '#888', fontSize: 12 }}>
      StatBand-Stub (Task 13)
    </div>
  )
}
