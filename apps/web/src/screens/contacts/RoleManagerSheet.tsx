/**
 * RoleManagerSheet — Drawer for managing a contact's roles[] array
 * and the corresponding sidecar rows (contact_instructor, contact_student).
 */

import { useState } from 'react'
import { Drawer } from '@/foundation/layouts/Drawer'
import { supabase } from '@/lib/supabase'
import type { ContactRole } from '@/types/contacts'

// All available roles with display labels
const ALL_ROLES: { value: ContactRole; label: string; hasSidecar?: boolean }[] = [
  { value: 'instructor', label: 'TL/DM', hasSidecar: true },
  { value: 'cd', label: 'CD' },
  { value: 'owner', label: 'Owner' },
  { value: 'dispatcher', label: 'Dispatcher' },
  { value: 'student', label: 'Schüler', hasSidecar: true },
  { value: 'candidate', label: 'Kandidat' },
  { value: 'newsletter', label: 'Newsletter' },
  { value: 'supplier', label: 'Lieferant' },
  { value: 'partner_rep', label: 'Partner-Rep' },
  { value: 'authority', label: 'Behörde' },
]

interface Props {
  contactId: string
  currentRoles: ContactRole[]
  open: boolean
  onClose: () => void
  onSaved: () => void
}

export function RoleManagerSheet({ contactId, currentRoles, open, onClose, onSaved }: Props) {
  const [draft, setDraft] = useState<ContactRole[]>(currentRoles)
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState<string | null>(null)

  function toggle(role: ContactRole, checked: boolean) {
    setDraft((prev) =>
      checked ? [...prev, role] : prev.filter((r) => r !== role)
    )
  }

  async function handleSave() {
    setSaving(true)
    setError(null)
    try {
      // 1. Update contacts.roles
      const { error: rolesErr } = await supabase
        .from('contacts')
        .update({ roles: draft })
        .eq('id', contactId)
      if (rolesErr) throw rolesErr

      // 2. Manage instructor sidecar
      const hadInstructor = currentRoles.includes('instructor')
      const wantsInstructor = draft.includes('instructor')
      if (!hadInstructor && wantsInstructor) {
        const { error: insErr } = await supabase
          .from('contact_instructor')
          .insert({ contact_id: contactId, account_balance: 0, active: true })
        if (insErr) throw insErr
      } else if (hadInstructor && !wantsInstructor) {
        const { error: delErr } = await supabase
          .from('contact_instructor')
          .delete()
          .eq('contact_id', contactId)
        if (delErr) throw delErr
      }

      // 3. Manage student sidecar
      const hadStudent = currentRoles.includes('student')
      const wantsStudent = draft.includes('student')
      if (!hadStudent && wantsStudent) {
        const { error: insErr } = await supabase
          .from('contact_student')
          .insert({ contact_id: contactId, is_candidate: false })
        if (insErr) throw insErr
      } else if (hadStudent && !wantsStudent) {
        const { error: delErr } = await supabase
          .from('contact_student')
          .delete()
          .eq('contact_id', contactId)
        if (delErr) throw delErr
      }

      onSaved()
      onClose()
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Fehler beim Speichern')
    } finally {
      setSaving(false)
    }
  }

  return (
    <Drawer
      open={open}
      onClose={onClose}
      title="Rollen verwalten"
      width={Math.round(window.innerWidth * 0.3)}
      ariaLabel="Rollen verwalten"
      footer={
        <div style={{ display: 'flex', gap: 'var(--space-3)', justifyContent: 'flex-end', padding: 'var(--space-4)' }}>
          <button type="button" className="contact-action-btn" onClick={onClose} disabled={saving}>
            Abbrechen
          </button>
          <button type="button" className="contact-action-btn contact-action-btn--primary" onClick={handleSave} disabled={saving}>
            {saving ? 'Speichern…' : 'Speichern'}
          </button>
        </div>
      }
    >
      <div style={{ padding: 'var(--space-5)' }}>
        {error && (
          <div style={{ color: 'var(--brand-red)', marginBottom: 'var(--space-4)', fontSize: 'var(--text-body)' }}>
            {error}
          </div>
        )}
        <ul style={{ listStyle: 'none', margin: 0, padding: 0, display: 'flex', flexDirection: 'column', gap: 'var(--space-2)' }}>
          {ALL_ROLES.map(({ value, label }) => (
            <li key={value} style={{ display: 'flex', alignItems: 'center', gap: 'var(--space-3)', padding: 'var(--space-2) 0', borderBottom: '1px solid var(--border-tertiary)' }}>
              <input
                type="checkbox"
                id={`role-${value}`}
                checked={draft.includes(value)}
                onChange={(e) => toggle(value, e.target.checked)}
                style={{ width: 16, height: 16, cursor: 'pointer', flexShrink: 0 }}
              />
              <label
                htmlFor={`role-${value}`}
                style={{ fontSize: 'var(--text-body)', color: 'var(--text-primary)', cursor: 'pointer', flex: 1 }}
              >
                {label}
              </label>
            </li>
          ))}
        </ul>
      </div>
    </Drawer>
  )
}
