/**
 * ContractTab — organization contract and billing fields.
 * Visible only for organizations with specific org_kinds.
 */

import { useTranslation } from 'react-i18next'
import type { ContactWithSidecars } from '@/types/contacts'
import { InlineTextField } from '@/foundation/compounds/InlineTextField'
import { updateOrganizationField } from '@/lib/contactQueries'

interface Props {
  contact: ContactWithSidecars
  onUpdated: () => void
}

export function ContractTab({ contact, onUpdated }: Props) {
  const { t } = useTranslation()
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
        <h2 className="contact-section__title">{t('contacts.section_contract')}</h2>
        <InlineTextField
          label={t('contacts.field_tax_id')}
          value={org?.tax_id}
          onCommit={async (v) => saveOrg('tax_id', v || null)}
          placeholder="CHE-123.456.789"
        />
        <InlineTextField
          label={t('contacts.field_billing_email')}
          value={org?.billing_email}
          onCommit={async (v) => saveOrg('billing_email', v || null)}
          placeholder="billing@firma.ch"
        />
        <InlineTextField
          label={t('contacts.field_contract_type')}
          value={org?.contract_type}
          onCommit={async (v) => saveOrg('contract_type', v || null)}
        />
        <InlineTextField
          label={t('contacts.field_contract_until')}
          value={org?.contract_until}
          onCommit={async (v) => saveOrg('contract_until', v || null)}
          placeholder={t('contacts.birth_date_placeholder')}
        />
        <InlineTextField
          label={t('contacts.field_payment_terms')}
          value={org?.payment_terms}
          onCommit={async (v) => saveOrg('payment_terms', v || null)}
          placeholder={t('contacts.payment_terms_placeholder')}
        />
      </section>
    </div>
  )
}
