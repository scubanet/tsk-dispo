/**
 * RelationshipsTab — list + remove + add relationships for a contact.
 */

import { useState, useEffect, useCallback } from 'react'
import { listRelationships } from '@/lib/contactQueries'
import { supabase } from '@/lib/supabase'
import type { ContactRelationship, RelationshipKind } from '@/types/contacts'
import { AddRelationshipSheet } from '../AddRelationshipSheet'

const KIND_LABELS: Record<RelationshipKind, string> = {
  works_at: 'arbeitet bei',
  owns: 'besitzt',
  spouse_of: 'verheiratet mit',
  child_of: 'Kind von',
  parent_of: 'Elternteil von',
  referred_by: 'geworben durch',
  subsidiary_of: 'Tochter von',
  partner_of: 'Partner von',
  supplier_of: 'Lieferant von',
  student_of: 'Schüler von',
  mentor_of: 'Mentor von',
}

interface Props {
  contactId: string
}

export function RelationshipsTab({ contactId }: Props) {
  const [relationships, setRelationships] = useState<ContactRelationship[]>([])
  const [loading, setLoading] = useState(true)
  const [addOpen, setAddOpen] = useState(false)

  const load = useCallback(() => {
    setLoading(true)
    listRelationships(contactId)
      .then(setRelationships)
      .finally(() => setLoading(false))
  }, [contactId])

  useEffect(() => { load() }, [load])

  async function handleRemove(rel: ContactRelationship) {
    await supabase.from('contact_relationships').delete().eq('id', rel.id)
    load()
  }

  if (loading) {
    return <div className="contact-tab-body tab-stub">Lade Beziehungen…</div>
  }

  return (
    <div className="contact-tab-body">
      <div style={{ display: 'flex', justifyContent: 'flex-end', marginBottom: 'var(--space-3)' }}>
        <button
          type="button"
          className="contact-action-btn contact-action-btn--primary"
          onClick={() => setAddOpen(true)}
        >
          + Hinzufügen
        </button>
      </div>

      {relationships.length === 0 ? (
        <p className="tab-stub">Keine Beziehungen erfasst.</p>
      ) : (
        <ul className="relationship-list">
          {relationships.map((rel) => {
            const isFrom = rel.from_contact_id === contactId
            const other = isFrom ? rel.to_contact : rel.from_contact
            const direction = isFrom ? 'zu' : 'von'
            const kindLabel = KIND_LABELS[rel.kind] ?? rel.kind
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
                    <span className="contact-list-badge contact-list-badge--primary">Primär</span>
                  )}
                </div>
                <button
                  type="button"
                  className="relationship-list__remove"
                  aria-label="Beziehung entfernen"
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
          load()
        }}
      />
    </div>
  )
}
