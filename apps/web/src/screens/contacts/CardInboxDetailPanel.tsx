import { useNavigate } from 'react-router-dom'
import { Avatar, Icon } from '@/foundation'
import { CardLeadStatusPill } from '@/components/CardLeadStatusPill'
import {
  useUpdateLeadStatus,
  useImportCardLead,
} from '@/hooks/useCardLeadActions'
import type { CardLeadRow } from '@/types/cardLeads'

interface Props {
  lead: CardLeadRow
  onClose: () => void
}

export function CardInboxDetailPanel({ lead, onClose }: Props) {
  const updateStatus = useUpdateLeadStatus()
  const importLead   = useImportCardLead()
  const navigate     = useNavigate()

  const displayName = [lead.first_name, lead.last_name].filter(Boolean).join(' ') || '(ohne Namen)'

  const mailto = lead.email
    ? `mailto:${lead.email}?subject=${encodeURIComponent(`Re: ${lead.topic ?? 'Anfrage'} — via Atoll-Card`)}`
    : null

  const tel        = lead.phone ? `tel:${lead.phone}` : null
  // E.164 strict for WhatsApp — strip non-digits except leading +
  const e164Strict = lead.phone?.match(/^\+\d{8,15}$/)?.[0]
  const whatsapp   = e164Strict ? `https://wa.me/${e164Strict.slice(1)}` : null

  function onActionClick(targetStatus: 'contacted') {
    if (lead.status === 'opened') {
      updateStatus.mutate({ id: lead.id, status: targetStatus })
    }
  }

  async function onImport() {
    if (!lead.email && !lead.phone) {
      const ok = window.confirm(
        'Lead hat keine Kontaktdaten — Import erstellt unvollständigen Contact. Trotzdem?'
      )
      if (!ok) return
    }
    try {
      const { contact_id, action } = await importLead.mutateAsync(lead.id)
      const msg =
        action === 'merged'            ? `In bestehenden Contact gemergt.`
      : action === 'already_imported'  ? `Schon importiert — öffne Contact.`
      : `Neuer Contact angelegt.`
      window.alert(msg) // TODO: replace with toast in a follow-up
      navigate(`/contacts?contact=${contact_id}`)
    } catch (e) {
      window.alert(`Import fehlgeschlagen: ${(e as Error).message}`)
    }
  }

  return (
    <div style={{ display: 'flex', flexDirection: 'column', height: '100%' }}>
      {/* Header */}
      <div style={{ display: 'flex', gap: 12, alignItems: 'flex-start',
                    padding: '16px 20px', borderBottom: '1px solid var(--border-subtle)' }}>
        <Avatar id={lead.id} name={displayName} color={lead.avatar_color ?? undefined} size="xl" />
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ fontSize: 18, fontWeight: 700 }}>{displayName}</div>
          <div style={{ fontSize: 13, color: 'var(--text-secondary)', marginTop: 2 }}>
            {lead.card_title}{lead.topic ? ` · ${lead.topic}` : ''}
          </div>
          <div style={{ marginTop: 8 }}>
            <CardLeadStatusPill status={lead.status} />
          </div>
        </div>
        <button type="button" onClick={onClose} aria-label="Schliessen"
                style={{ background: 'transparent', border: 'none', cursor: 'pointer' }}>
          <Icon.Close size={16} />
        </button>
      </div>

      {/* Body */}
      <div style={{ flex: 1, overflow: 'auto', padding: '16px 20px' }}>
        {lead.email && (
          <div style={{ marginBottom: 8 }}>
            <a href={`mailto:${lead.email}`} style={{ color: 'var(--brand-blue)' }}>
              {lead.email}
            </a>
          </div>
        )}
        {lead.phone && (
          <div style={{ marginBottom: 8 }}>
            <a href={`tel:${lead.phone}`} style={{ color: 'var(--brand-blue)' }}>
              {lead.phone}
            </a>
          </div>
        )}
        {lead.message && (
          <div style={{
            marginTop: 12, padding: 12, background: 'var(--surface-elevated)',
            borderRadius: 8, fontSize: 14, whiteSpace: 'pre-wrap',
          }}>
            {lead.message}
          </div>
        )}
        <div style={{ marginTop: 16, fontSize: 12, color: 'var(--text-tertiary)' }}>
          Eingegangen: {new Date(lead.captured_at).toLocaleString('de-CH')}
        </div>
      </div>

      {/* Actions */}
      <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8,
                    padding: '12px 20px', borderTop: '1px solid var(--border-subtle)' }}>
        {mailto && (
          <a className="atoll-btn" href={mailto} onClick={() => onActionClick('contacted')}>
            Antworten
          </a>
        )}
        {tel && (
          <a className="atoll-btn" href={tel} onClick={() => onActionClick('contacted')}>
            Anrufen
          </a>
        )}
        {whatsapp && (
          <a className="atoll-btn" href={whatsapp} target="_blank" rel="noreferrer"
             onClick={() => onActionClick('contacted')}>
            WhatsApp
          </a>
        )}
        <button
          type="button"
          className="atoll-btn atoll-btn--primary"
          disabled={lead.status === 'spam' || importLead.isPending}
          onClick={onImport}
        >
          {importLead.isPending ? 'Importiere…' : 'Importieren'}
        </button>
        <button
          type="button"
          className="atoll-btn"
          onClick={() => updateStatus.mutate({ id: lead.id, status: 'archived' })}
          disabled={lead.status === 'archived'}
        >
          Archivieren
        </button>
        <button
          type="button"
          className="atoll-btn"
          onClick={() => updateStatus.mutate({ id: lead.id, status: 'spam' })}
          disabled={lead.status === 'spam'}
        >
          Als Spam
        </button>
      </div>
    </div>
  )
}
