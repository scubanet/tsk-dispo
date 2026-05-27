// apps/web/src/screens/contacts/sidebar/sections/ContactSection.tsx
//
// Phase G Phase 3 — ContactSection: Email + Phone + Sprache (Inline-Edit).
// WhatsApp + Bevorzugter Kanal (Spec §5.3) deferred — Schema hat aktuell
// kein whatsapp-Feld; brauchen separate Migration + UI-Erweiterung.
import { SidebarSection } from '../SidebarSection'
import { EditableField } from '../EditableField'
import { useContactFieldMutation } from '@/hooks/useContactFieldMutation'
import type { ContactWithProperties } from '@/types/contactProperties'

interface Props {
  contact: ContactWithProperties
}

const LANGUAGES = ['de', 'en', 'fr', 'it']

export function ContactSection({ contact }: Props) {
  const mutate = useContactFieldMutation(contact.id)

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
      <EditableField
        label="Telefon"
        value={contact.primary_phone}
        type="tel"
        placeholder="+41 79 ..."
        onSave={(next) => mutate.mutateAsync({
          table: 'contacts', field: 'primary_phone', value: next || null,
        })}
      />
      <EditableField
        label="Sprache"
        value={contact.primary_language}
        validate={v => (v && !LANGUAGES.includes(v) ? `Erlaubt: ${LANGUAGES.join(', ')}` : null)}
        placeholder={LANGUAGES.join(' / ')}
        onSave={(next) => mutate.mutateAsync({
          table: 'contacts', field: 'primary_language', value: next || null,
        })}
      />
    </SidebarSection>
  )
}
