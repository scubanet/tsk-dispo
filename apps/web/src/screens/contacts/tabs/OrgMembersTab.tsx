/**
 * OrgMembersTab — lists all contacts with a 'works_at' relationship to this org.
 * Visible only for organization contacts.
 */

import { useState, useEffect } from 'react'
import { supabase } from '@/lib/supabase'

interface MemberRow {
  id: string
  from_contact_id: string
  role_at_org: string | null
  from_contact: {
    id: string
    display_name: string
    primary_email: string | null
    roles: string[]
  } | null
}

interface Props {
  orgId: string
  onSelectContact?: (id: string) => void
}

export function OrgMembersTab({ orgId, onSelectContact }: Props) {
  const [members, setMembers] = useState<MemberRow[]>([])
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    let cancelled = false
    setLoading(true)
    void (async () => {
      const { data } = await supabase
        .from('contact_relationships')
        .select(
          'id, from_contact_id, role_at_org, ' +
          'from_contact:contacts!contact_relationships_from_contact_id_fkey(id, display_name, primary_email, roles)',
        )
        .eq('to_contact_id', orgId)
        .eq('kind', 'works_at')
      if (!cancelled) {
        setMembers((data ?? []) as unknown as MemberRow[])
        setLoading(false)
      }
    })()
    return () => { cancelled = true }
  }, [orgId])

  if (loading) return <div className="contact-tab-body tab-stub">Lade Mitglieder…</div>

  if (members.length === 0) {
    return <div className="contact-tab-body tab-stub">Keine Mitglieder erfasst.</div>
  }

  return (
    <div className="contact-tab-body">
      <ul className="members-list">
        {members.map((m) => (
          <li
            key={m.id}
            className="members-list__item"
            style={{ cursor: onSelectContact ? 'pointer' : 'default' }}
            onClick={() => onSelectContact?.(m.from_contact_id)}
          >
            <span className="members-list__name">{m.from_contact?.display_name ?? '—'}</span>
            {m.role_at_org && (
              <span className="members-list__role" style={{ color: 'var(--text-tertiary)', fontSize: 'var(--text-meta)' }}>
                {m.role_at_org}
              </span>
            )}
            {m.from_contact?.primary_email && (
              <span className="members-list__email" style={{ color: 'var(--text-tertiary)', fontSize: 'var(--text-meta)' }}>
                {m.from_contact.primary_email}
              </span>
            )}
          </li>
        ))}
      </ul>
    </div>
  )
}
