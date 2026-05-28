// apps/web/src/screens/contacts/sidebar/sections/ContactSection.tsx
//
// Phase G Phase 3 — ContactSection: Email (Inline-Edit), Phone + Sprache (read-only v1).
//
// Schema-Realität auf Prod (Hotfix 2026-05-28):
//   • primary_phone / primary_language existieren nicht.
//   • Phone wohnt in JSONB-Array `phones` mit shape { label, e164, primary }.
//   • Language wohnt in TEXT[]-Array `languages`.
// → Phone+Sprache werden in v1 read-only angezeigt (erster primary-Eintrag bzw.
//   erste Sprache). Inline-Edit für Arrays kommt in Phase 3.x mit eigenem
//   Multi-Value-Editor — out of scope für die Sidebar-Foundation.
import { SidebarSection } from '../SidebarSection'
import { EditableField } from '../EditableField'
import { useContactFieldMutation } from '@/hooks/useContactFieldMutation'
import type { ContactWithProperties } from '@/types/contactProperties'

interface Props {
  contact: ContactWithProperties
}

/** Erstes primary-Element aus phones-JSONB, sonst erstes überhaupt, sonst null. */
function primaryPhone(contact: ContactWithProperties): string | null {
  if (!contact.phones || contact.phones.length === 0) return null
  const primary = contact.phones.find(p => p.primary === true)
  return primary?.e164 ?? contact.phones[0]?.e164 ?? null
}

function primaryLanguage(contact: ContactWithProperties): string | null {
  return contact.languages?.[0] ?? null
}

export function ContactSection({ contact }: Props) {
  const mutate = useContactFieldMutation(contact.id)
  const phone = primaryPhone(contact)
  const lang = primaryLanguage(contact)

  return (
    <SidebarSection id="contact" title="Kontakt" defaultOpen>
      <EditableField
        label="Email"
        value={contact.primary_email}
        type="email"
        validate={v => (v && !v.includes('@') ? 'Email braucht @' : null)}
        onSave={(next) => mutate.mutateAsync({
          table: 'contacts', field: 'primary_email', value: next || null,
        })}
      />
      <ReadOnlyRow label="Telefon" value={phone} />
      <ReadOnlyRow label="Sprache" value={lang} />
    </SidebarSection>
  )
}

/** Kleine read-only Row im EditableField-Stil (Label + statischer Wert). */
function ReadOnlyRow({ label, value }: { label: string; value: string | null }) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 2, padding: '6px 0' }}>
      <div style={{ fontSize: 11, color: 'var(--text-tertiary, #888)', letterSpacing: 0.2 }}>
        {label}
      </div>
      <div
        style={{
          fontSize: 13,
          padding: '4px 6px',
          color: value == null ? 'var(--text-tertiary, #888)' : 'var(--text-primary, #222)',
        }}
      >
        {value == null || value === '' ? '—' : value}
      </div>
    </div>
  )
}
