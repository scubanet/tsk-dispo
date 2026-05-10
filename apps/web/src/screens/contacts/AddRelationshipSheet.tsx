/**
 * AddRelationshipSheet — search for a contact and add a relationship.
 */

import { useState, useEffect } from 'react'
import { useTranslation } from 'react-i18next'
import { Drawer } from '@/foundation/layouts/Drawer'
import { listContacts, addRelationship } from '@/lib/contactQueries'
import type { RelationshipKind, Contact } from '@/types/contacts'

const KIND_OPTIONS: { value: RelationshipKind; labelKey: string }[] = [
  { value: 'works_at',      labelKey: 'contacts.rel_kind_works_at' },
  { value: 'owns',          labelKey: 'contacts.rel_kind_owns' },
  { value: 'spouse_of',     labelKey: 'contacts.rel_kind_spouse_of' },
  { value: 'child_of',      labelKey: 'contacts.rel_kind_child_of' },
  { value: 'parent_of',     labelKey: 'contacts.rel_kind_parent_of' },
  { value: 'referred_by',   labelKey: 'contacts.rel_kind_referred_by' },
  { value: 'subsidiary_of', labelKey: 'contacts.rel_kind_subsidiary_of' },
  { value: 'partner_of',    labelKey: 'contacts.rel_kind_partner_of' },
  { value: 'supplier_of',   labelKey: 'contacts.rel_kind_supplier_of' },
  { value: 'student_of',    labelKey: 'contacts.rel_kind_student_of' },
  { value: 'mentor_of',     labelKey: 'contacts.rel_kind_mentor_of' },
]

interface Props {
  fromContactId: string
  open: boolean
  onClose: () => void
  onSaved: () => void
}

export function AddRelationshipSheet({ fromContactId, open, onClose, onSaved }: Props) {
  const { t } = useTranslation()
  const [search, setSearch] = useState('')
  const [results, setResults] = useState<Contact[]>([])
  const [selected, setSelected] = useState<Contact | null>(null)
  const [kind, setKind] = useState<RelationshipKind>('works_at')
  const [roleAtOrg, setRoleAtOrg] = useState('')
  const [isPrimary, setIsPrimary] = useState(false)
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState<string | null>(null)

  // Search effect
  useEffect(() => {
    if (search.length < 2) {
      setResults([])
      return
    }
    listContacts({ searchText: search }, 0, 20).then(({ rows }) => {
      setResults(rows.filter((c) => c.id !== fromContactId))
    })
  }, [search, fromContactId])

  async function handleSave() {
    if (!selected) return
    setSaving(true)
    setError(null)
    try {
      await addRelationship({
        from_contact_id: fromContactId,
        to_contact_id: selected.id,
        kind,
        role_at_org: roleAtOrg || undefined,
        is_primary: isPrimary,
      })
      resetState()
      onSaved()
    } catch (err) {
      setError(err instanceof Error ? err.message : t('contacts.rel_error_save'))
    } finally {
      setSaving(false)
    }
  }

  function resetState() {
    setSearch('')
    setResults([])
    setSelected(null)
    setKind('works_at')
    setRoleAtOrg('')
    setIsPrimary(false)
    setError(null)
  }

  function handleClose() {
    resetState()
    onClose()
  }

  return (
    <Drawer
      open={open}
      onClose={handleClose}
      title={t('contacts.add_rel_title')}
      width={480}
      footer={
        selected ? (
          <div style={{ display: 'flex', gap: 'var(--space-3)', justifyContent: 'flex-end' }}>
            <button
              type="button"
              onClick={handleClose}
              style={{ padding: 'var(--space-2) var(--space-4)', borderRadius: 'var(--radius-sm)', border: '1px solid var(--border-secondary)', background: 'var(--bg-secondary)', cursor: 'pointer' }}
            >
              {t('common.cancel')}
            </button>
            <button
              type="button"
              onClick={handleSave}
              disabled={saving}
              style={{ padding: 'var(--space-2) var(--space-4)', borderRadius: 'var(--radius-sm)', border: 'none', background: 'var(--brand-blue)', color: '#fff', cursor: 'pointer', fontWeight: 'var(--weight-medium)' }}
            >
              {saving ? t('common.saving') : t('common.save')}
            </button>
          </div>
        ) : undefined
      }
    >
      <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--space-4)', padding: 'var(--space-4)' }}>
        {/* Search phase */}
        {!selected && (
          <>
            <div>
              <label style={{ display: 'block', fontSize: 'var(--text-label)', fontWeight: 'var(--weight-medium)', marginBottom: 'var(--space-2)' }}>
                {t('contacts.rel_search_label')}
              </label>
              <input
                type="search"
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                placeholder={t('contacts.rel_search_placeholder')}
                style={{ width: '100%', padding: 'var(--space-2) var(--space-3)', borderRadius: 'var(--radius-sm)', border: '1px solid var(--border-secondary)', fontSize: 'var(--text-body)' }}
              />
            </div>

            {results.length > 0 && (
              <ul style={{ listStyle: 'none', margin: 0, padding: 0, border: '1px solid var(--border-secondary)', borderRadius: 'var(--radius-sm)', overflow: 'hidden' }}>
                {results.map((c) => (
                  <li
                    key={c.id}
                    onClick={() => setSelected(c)}
                    style={{ padding: 'var(--space-2) var(--space-3)', cursor: 'pointer', borderBottom: '1px solid var(--border-secondary)', fontSize: 'var(--text-body)' }}
                  >
                    <div style={{ fontWeight: 'var(--weight-medium)' }}>{c.display_name}</div>
                    {c.primary_email && (
                      <div style={{ fontSize: 'var(--text-meta)', color: 'var(--text-tertiary)' }}>{c.primary_email}</div>
                    )}
                  </li>
                ))}
              </ul>
            )}
          </>
        )}

        {/* Relationship form phase */}
        {selected && (
          <>
            <div style={{ padding: 'var(--space-3)', background: 'var(--bg-secondary)', borderRadius: 'var(--radius-sm)' }}>
              <div style={{ fontSize: 'var(--text-meta)', color: 'var(--text-tertiary)' }}>{t('contacts.rel_selected_label')}</div>
              <div style={{ fontWeight: 'var(--weight-medium)' }}>{selected.display_name}</div>
              {selected.primary_email && (
                <div style={{ fontSize: 'var(--text-meta)', color: 'var(--text-tertiary)' }}>{selected.primary_email}</div>
              )}
              <button
                type="button"
                onClick={() => { setSelected(null); setSearch('') }}
                style={{ marginTop: 'var(--space-2)', fontSize: 'var(--text-meta)', color: 'var(--brand-blue)', background: 'none', border: 'none', cursor: 'pointer', padding: 0 }}
              >
                {t('contacts.rel_change')}
              </button>
            </div>

            <div>
              <label style={{ display: 'block', fontSize: 'var(--text-label)', fontWeight: 'var(--weight-medium)', marginBottom: 'var(--space-2)' }}>
                {t('contacts.rel_kind_label')}
              </label>
              <select
                value={kind}
                onChange={(e) => setKind(e.target.value as RelationshipKind)}
                style={{ width: '100%', padding: 'var(--space-2) var(--space-3)', borderRadius: 'var(--radius-sm)', border: '1px solid var(--border-secondary)', fontSize: 'var(--text-body)' }}
              >
                {KIND_OPTIONS.map((o) => (
                  <option key={o.value} value={o.value}>{t(o.labelKey)}</option>
                ))}
              </select>
            </div>

            {kind === 'works_at' && (
              <div>
                <label style={{ display: 'block', fontSize: 'var(--text-label)', fontWeight: 'var(--weight-medium)', marginBottom: 'var(--space-2)' }}>
                  {t('contacts.rel_role_label')}
                </label>
                <input
                  type="text"
                  value={roleAtOrg}
                  onChange={(e) => setRoleAtOrg(e.target.value)}
                  placeholder={t('contacts.rel_role_placeholder')}
                  style={{ width: '100%', padding: 'var(--space-2) var(--space-3)', borderRadius: 'var(--radius-sm)', border: '1px solid var(--border-secondary)', fontSize: 'var(--text-body)' }}
                />
              </div>
            )}

            <label style={{ display: 'flex', alignItems: 'center', gap: 'var(--space-2)', cursor: 'pointer', fontSize: 'var(--text-body)' }}>
              <input
                type="checkbox"
                checked={isPrimary}
                onChange={(e) => setIsPrimary(e.target.checked)}
              />
              {t('contacts.rel_primary_label')}
            </label>

            {error && (
              <p style={{ color: 'var(--brand-red)', fontSize: 'var(--text-meta)' }}>{error}</p>
            )}
          </>
        )}
      </div>
    </Drawer>
  )
}
