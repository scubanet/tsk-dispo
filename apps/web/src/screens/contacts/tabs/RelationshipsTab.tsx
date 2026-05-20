/**
 * RelationshipsTab — list + remove + add relationships for a contact.
 */

import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { useQueryClient } from '@tanstack/react-query'
import { removeRelationship } from '@/lib/contactQueries'
import type { ContactRelationship, RelationshipKind } from '@/types/contacts'
import { useContactRelationships } from '@/hooks/useContactTabs'
import { AddRelationshipSheet } from '../AddRelationshipSheet'

const KIND_LABEL_KEYS: Record<RelationshipKind, string> = {
  works_at: 'contacts.rel_kind_works_at',
  owns: 'contacts.rel_kind_owns',
  spouse_of: 'contacts.rel_kind_spouse_of',
  child_of: 'contacts.rel_kind_child_of',
  parent_of: 'contacts.rel_kind_parent_of',
  referred_by: 'contacts.rel_kind_referred_by',
  subsidiary_of: 'contacts.rel_kind_subsidiary_of',
  partner_of: 'contacts.rel_kind_partner_of',
  supplier_of: 'contacts.rel_kind_supplier_of',
  student_of: 'contacts.rel_kind_student_of',
  mentor_of: 'contacts.rel_kind_mentor_of',
}

interface Props {
  contactId: string
}

export function RelationshipsTab({ contactId }: Props) {
  const { t } = useTranslation()
  const qc = useQueryClient()
  const { data: relationships = [], isLoading: loading } = useContactRelationships(contactId)
  const [addOpen, setAddOpen] = useState(false)

  function refresh() {
    qc.invalidateQueries({ queryKey: ['contact', 'relationships', contactId] })
  }

  async function handleRemove(rel: ContactRelationship) {
    await removeRelationship(rel.id)
    refresh()
  }

  if (loading) {
    return <div className="contact-tab-body tab-stub">{t('contacts.loading_relationships')}</div>
  }

  return (
    <div className="contact-tab-body">
      <div style={{ display: 'flex', justifyContent: 'flex-end', marginBottom: 'var(--space-3)' }}>
        <button
          type="button"
          className="contact-action-btn contact-action-btn--primary"
          onClick={() => setAddOpen(true)}
        >
          {t('contacts.add_relationship')}
        </button>
      </div>

      {relationships.length === 0 ? (
        <p className="tab-stub">{t('contacts.no_relationships')}</p>
      ) : (
        <ul className="relationship-list">
          {relationships.map((rel) => {
            const isFrom = rel.from_contact_id === contactId
            const other = isFrom ? rel.to_contact : rel.from_contact
            const direction = isFrom ? t('contacts.rel_dir_to') : t('contacts.rel_dir_from')
            const kindLabel = KIND_LABEL_KEYS[rel.kind] ? t(KIND_LABEL_KEYS[rel.kind]) : rel.kind
            return (
              <li key={rel.id} className="relationship-list__item">
                <div className="relationship-list__info">
                  <span className="relationship-list__kind">{kindLabel}</span>
                  <span className="relationship-list__dir">{direction}</span>
                  <span className="relationship-list__name">{other?.display_name ?? '—'}</span>
                  {rel.role_at_org && (
                    <span className="relationship-list__role">{rel.role_at_org}</span>
                  )}
                  {rel.is_primary && (
                    <span className="contact-list-badge contact-list-badge--primary">{t('contacts.primary_badge')}</span>
                  )}
                </div>
                <button
                  type="button"
                  className="relationship-list__remove"
                  aria-label={t('contacts.remove_rel_aria')}
                  onClick={() => handleRemove(rel)}
                >
                  ×
                </button>
              </li>
            )
          })}
        </ul>
      )}

      <AddRelationshipSheet
        fromContactId={contactId}
        open={addOpen}
        onClose={() => setAddOpen(false)}
        onSaved={() => {
          setAddOpen(false)
          refresh()
        }}
      />
    </div>
  )
}
