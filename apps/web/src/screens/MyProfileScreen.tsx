import { useEffect, useState } from 'react'
import { useOutletContext } from 'react-router-dom'
import { format } from 'date-fns'
import { de } from 'date-fns/locale'
import { Topbar } from '@/components/Topbar'
import { Icon } from '@/components/Icon'
import { Chip } from '@/components/Chip'
import { Avatar } from '@/components/Avatar'
import { EmptyState } from '@/components/EmptyState'
import { Sheet } from '@/components/Sheet'
import { supabase } from '@/lib/supabase'
import {
  fetchMySkills,
  fetchMyAvailability,
  type MySkill,
  type AvailabilityRow,
} from '@/lib/queries'
import type { OutletCtx } from '@/layout/AppShell'

interface Profile {
  name: string
  initials: string
  color: string
  padi_level: string
  email: string | null
  phone: string | null
}

const inputStyle = {
  padding: '8px 10px',
  borderRadius: 8,
  border: '0.5px solid var(--hairline)',
  background: 'var(--surface-strong)',
  color: 'var(--ink)',
  font: 'inherit',
  fontSize: 13.5,
  width: '100%',
}

export function MyProfileScreen() {
  const { user } = useOutletContext<OutletCtx>()
  const [profile, setProfile] = useState<Profile | null>(null)
  const [skills, setSkills] = useState<MySkill[]>([])
  const [availability, setAvailability] = useState<AvailabilityRow[]>([])
  const [showAddAvail, setShowAddAvail] = useState(false)
  const [showEditProfile, setShowEditProfile] = useState(false)

  function refetchAvail() {
    if (!user.instructorId) return
    fetchMyAvailability(user.instructorId).then(setAvailability)
  }
  function refetchProfile() {
    if (!user.instructorId) return
    supabase
      .from('instructors')
      .select('name, initials, color, padi_level, email, phone')
      .eq('id', user.instructorId)
      .single()
      .then(({ data }) => setProfile(data as Profile | null))
  }

  useEffect(() => {
    if (!user.instructorId) return
    refetchProfile()
    fetchMySkills(user.instructorId).then(setSkills)
    refetchAvail()
  }, [user.instructorId])

  if (!user.instructorId) {
    return (
      <>
        <Topbar title="Mein Profil" />
        <EmptyState
          icon="tag"
          title="Kein Instructor verknüpft"
          description="Bitte den Dispatcher um die Login-Verknüpfung."
        />
      </>
    )
  }

  if (!profile) {
    return (
      <>
        <Topbar title="Mein Profil" />
        <div style={{ padding: 40 }} className="caption">Lade…</div>
      </>
    )
  }

  return (
    <>
      <Topbar title="Mein Profil" />

      <div className="screen-fade scroll" style={{ flex: 1, padding: '20px 24px 40px' }}>
        <div className="glass card" style={{ marginBottom: 16, display: 'flex', gap: 16, alignItems: 'center' }}>
          <Avatar initials={profile.initials} color={profile.color} size="lg" />
          <div style={{ flex: 1 }}>
            <div className="title-2">{profile.name}</div>
            <div className="caption">{profile.padi_level}</div>
            <div className="caption" style={{ marginTop: 4 }}>
              {profile.email || '—'}{profile.phone ? ` · ${profile.phone}` : ''}
            </div>
          </div>
          <button className="btn-secondary btn" onClick={() => setShowEditProfile(true)}>
            <Icon name="settings" size={14} /> Bearbeiten
          </button>
        </div>

        <div className="glass card" style={{ marginBottom: 16 }}>
          <div className="title-3" style={{ marginBottom: 12 }}>
            Meine Skills <span className="caption">({skills.length})</span>
          </div>
          {skills.length === 0 ? (
            <div className="caption">Keine Skills hinterlegt — Dispatcher kann sie in der Skill-Matrix setzen.</div>
          ) : (
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
              {skills.map((s) => <Chip key={s.code} tone="accent">{s.label}</Chip>)}
            </div>
          )}
        </div>

        <div className="glass card">
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 12 }}>
            <div className="title-3">Verfügbarkeit / Abwesenheit</div>
            <button className="btn" onClick={() => setShowAddAvail(true)}>
              <Icon name="plus" size={14} /> Eintragen
            </button>
          </div>

          {availability.length === 0 ? (
            <div className="caption">
              Hier kannst du Urlaub, Krankheit oder andere Abwesenheiten eintragen.
              Der Dispatcher sieht das beim Planen.
            </div>
          ) : (
            <div style={{ display: 'grid', gap: 6 }}>
              {availability.map((a) => (
                <AvailabilityRowView key={a.id} row={a} onDeleted={refetchAvail} />
              ))}
            </div>
          )}
        </div>
      </div>

      <AvailabilityAddSheet
        open={showAddAvail}
        onClose={() => setShowAddAvail(false)}
        onCreated={refetchAvail}
        instructorId={user.instructorId}
      />

      <ProfileEditSheet
        open={showEditProfile}
        onClose={() => setShowEditProfile(false)}
        onSaved={refetchProfile}
        instructorId={user.instructorId}
        currentEmail={profile.email}
      />
    </>
  )
}

function ProfileEditSheet({
  open, onClose, onSaved, instructorId, currentEmail,
}: {
  open: boolean
  onClose: () => void
  onSaved: () => void
  instructorId: string
  currentEmail: string | null
}) {
  const [phone, setPhone] = useState('')
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    if (!open) return
    setError(null)
    supabase
      .from('instructors')
      .select('phone')
      .eq('id', instructorId)
      .single()
      .then(({ data }) => setPhone(data?.phone ?? ''))
  }, [open, instructorId])

  async function save() {
    setSaving(true)
    setError(null)
    const { error: updErr } = await supabase
      .from('instructors')
      .update({ phone: phone.trim() || null })
      .eq('id', instructorId)
    setSaving(false)
    if (updErr) { setError(updErr.message); return }
    onSaved()
    onClose()
  }

  return (
    <Sheet open={open} onClose={onClose} title="Mein Profil bearbeiten">
      <div style={{ display: 'grid', gap: 14 }}>
        <div className="caption">
          Email + Name + Skills sind fix vom Dispatcher gesetzt. Du kannst aber deine Telefon-/WhatsApp-Nummer eintragen.
        </div>

        <div>
          <div className="caption-2" style={{ marginBottom: 4 }}>EMAIL (FIX)</div>
          <input
            value={currentEmail ?? ''}
            disabled
            style={{ ...inputStyle, opacity: 0.5 }}
          />
        </div>

        <div>
          <div className="caption-2" style={{ marginBottom: 4 }}>TELEFON / WHATSAPP</div>
          <input
            value={phone}
            onChange={(e) => setPhone(e.target.value)}
            placeholder="+41 79 123 45 67"
            style={inputStyle}
          />
          <div className="caption-2" style={{ marginTop: 4 }}>
            Internationales Format. Wird im TL/DM-Verzeichnis sichtbar — der Dispatcher kann dich darüber anschreiben.
          </div>
        </div>

        {error && <div className="chip chip-red">{error}</div>}

        <div style={{ display: 'flex', gap: 8 }}>
          <button className="btn-secondary btn" onClick={onClose}>Abbrechen</button>
          <button className="btn" onClick={save} disabled={saving} style={{ flex: 1 }}>
            {saving ? 'Speichere…' : 'Speichern'}
          </button>
        </div>
      </div>
    </Sheet>
  )
}

function AvailabilityRowView({ row, onDeleted }: { row: AvailabilityRow; onDeleted: () => void }) {
  const tone =
    row.kind === 'urlaub'    ? 'accent' :
    row.kind === 'abwesend'  ? 'orange' : 'green'
  async function del() {
    if (!confirm(`Eintrag "${row.kind}" wirklich löschen?`)) return
    await supabase.from('availability').delete().eq('id', row.id)
    onDeleted()
  }
  return (
    <div className="glass-thin" style={{ padding: 10, borderRadius: 10, display: 'flex', gap: 10, alignItems: 'center' }}>
      <Chip tone={tone}>{row.kind}</Chip>
      <div style={{ flex: 1 }}>
        <div style={{ fontSize: 13 }}>
          {format(new Date(row.from_date), 'd. MMM', { locale: de })}
          {row.from_date !== row.to_date && ` – ${format(new Date(row.to_date), 'd. MMM yyyy', { locale: de })}`}
        </div>
        {row.note && <div className="caption-2" style={{ marginTop: 2 }}>{row.note}</div>}
      </div>
      <button className="btn-icon" onClick={del} title="Löschen">
        <Icon name="x" size={14} />
      </button>
    </div>
  )
}

function AvailabilityAddSheet({
  open, onClose, onCreated, instructorId,
}: {
  open: boolean
  onClose: () => void
  onCreated: () => void
  instructorId: string
}) {
  const [kind, setKind] = useState<'urlaub' | 'abwesend' | 'verfügbar'>('urlaub')
  const [fromDate, setFromDate] = useState(new Date().toISOString().slice(0, 10))
  const [toDate, setToDate] = useState(new Date().toISOString().slice(0, 10))
  const [note, setNote] = useState('')
  const [saving, setSaving] = useState(false)

  async function save() {
    setSaving(true)
    const { error } = await supabase.from('availability').insert({
      instructor_id: instructorId,
      from_date: fromDate,
      to_date: toDate,
      kind,
      note: note.trim() || null,
    })
    setSaving(false)
    if (error) {
      alert('Fehler: ' + error.message)
      return
    }
    onCreated()
    onClose()
    setKind('urlaub')
    setNote('')
  }

  return (
    <Sheet open={open} onClose={onClose} title="Verfügbarkeit eintragen">
      <div style={{ display: 'grid', gap: 14 }}>
        <div>
          <div className="caption-2" style={{ marginBottom: 4 }}>ART</div>
          <select value={kind} onChange={(e) => setKind(e.target.value as typeof kind)} style={inputStyle}>
            <option value="urlaub">Urlaub</option>
            <option value="abwesend">Abwesend</option>
            <option value="verfügbar">Explizit verfügbar</option>
          </select>
        </div>

        <div>
          <div className="caption-2" style={{ marginBottom: 4 }}>VON</div>
          <input
            type="date"
            value={fromDate}
            onChange={(e) => setFromDate(e.target.value)}
            style={inputStyle}
          />
        </div>

        <div>
          <div className="caption-2" style={{ marginBottom: 4 }}>BIS</div>
          <input
            type="date"
            value={toDate}
            onChange={(e) => setToDate(e.target.value)}
            style={inputStyle}
          />
        </div>

        <div>
          <div className="caption-2" style={{ marginBottom: 4 }}>NOTIZ (OPTIONAL)</div>
          <input
            value={note}
            onChange={(e) => setNote(e.target.value)}
            placeholder="z.B. Tessin, mit Familie"
            style={inputStyle}
          />
        </div>

        <div style={{ display: 'flex', gap: 8 }}>
          <button className="btn-secondary btn" onClick={onClose}>Abbrechen</button>
          <button className="btn" onClick={save} disabled={saving} style={{ flex: 1 }}>
            {saving ? 'Speichere…' : 'Eintragen'}
          </button>
        </div>
      </div>
    </Sheet>
  )
}
