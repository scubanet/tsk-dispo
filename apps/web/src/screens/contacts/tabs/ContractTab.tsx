/**
 * ContractTab — organization contract and billing fields.
 * Visible only for organizations with specific org_kinds.
 */

import type { ContactWithSidecars } from '@/types/contacts'
import { InlineTextField } from '@/foundation/compounds/InlineTextField'
import { updateOrganizationField } from '@/lib/contactQueries'

interface Props {
  contact: ContactWithSidecars
  onUpdated: () => void
}

export function ContractTab({ contact, onUpdated }: Props) {
  const org = contact.organization

  async function saveOrg<K extends Parameters<typeof updateOrganizationField>[1]>(
    field: K,
    value: Parameters<typeof updateOrganizationField<K>>[2],
  ) {
    await updateOrganizationField(contact.id, field, value)
    onUpdated()
  }

  return (
    <div className="contact-tab-body">
      <section className="contact-section">
        <h2 className="contact-section__title">Vertrag &amp; Abrechnung</h2>
        <InlineTextField
          label="Steuer-ID / UID"
          value={org?.tax_id}
          onCommit={async (v) => saveOrg('tax_id', v || null)}
          placeholder="CHE-123.456.789"
        />
        <InlineTextField
          label="Rechnungs-E-Mail"
          value={org?.billing_email}
          onCommit={async (v) => saveOrg('billing_email', v || null)}
          placeholder="billing@firma.ch"
        />
        <InlineTextField
          label="Vertragsart"
          value={org?.contract_type}
          onCommit={async (v) => saveOrg('contract_type', v || null)}
        />
        <InlineTextField
          label="Vertrag bis"
          value={org?.contract_until}
          onCommit={async (v) => saveOrg('contract_until', v || null)}
          placeholder="JJJJ-MM-TT"
        />
        <InlineTextField
          label="Zahlungsbedingungen"
          value={org?.payment_terms}
          onCommit={async (v) => saveOrg('payment_terms', v || null)}
          placeholder="z. B. 30 Tage netto"
        />
      </section>
    </div>
  )
}
