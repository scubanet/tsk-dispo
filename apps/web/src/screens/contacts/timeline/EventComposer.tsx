// apps/web/src/screens/contacts/timeline/EventComposer.tsx
//
// STUB für Phase G Phase 2 Task 4 — wird in Task 12 ersetzt durch den vollen
// Orchestrator (segmented control mit 6 Composer-Subkomponenten).

interface Props {
  contactId: string
}

export function EventComposer({ contactId: _contactId }: Props) {
  return (
    <div
      data-testid="event-composer-stub"
      style={{
        padding: '8px 14px',
        borderBottom: '1px solid var(--border-subtle, #eee)',
        color: 'var(--text-tertiary, #888)',
        fontSize: 12,
      }}
    >
      Composer-Stub — Task 12 ersetzt das durch segmented control + 6 Forms.
    </div>
  )
}
