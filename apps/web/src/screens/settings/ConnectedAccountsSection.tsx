// apps/web/src/screens/settings/ConnectedAccountsSection.tsx
// Settings-Sektion "Verbundene Konten" — Hosted-Auth-Connect pro Kanal +
// Status-Liste. Nur für Comms-Staff gerendert (Guard in SettingsScreen).
// Spec: docs/superpowers/specs/2026-05-29-comms-integration-unipile-design.md §6.2
import { useMessagingAccounts, useConnectAccount } from '@/hooks/useMessagingAccounts'
import type { CommsChannel } from '@/types/messaging'
import { Icon, type IconName } from '@/foundation/primitives/Icon'

const CHANNELS: { key: CommsChannel; label: string; icon: IconName }[] = [
  { key: 'email', label: 'E-Mail', icon: 'mail' },
  { key: 'whatsapp', label: 'WhatsApp', icon: 'brand-whatsapp' },
  { key: 'linkedin', label: 'LinkedIn', icon: 'brand-linkedin' },
]

function iconForChannel(channel: CommsChannel): IconName {
  if (channel === 'email') return 'mail'
  if (channel === 'whatsapp') return 'brand-whatsapp'
  return 'brand-linkedin'
}

export function ConnectedAccountsSection() {
  const { data: accounts = [], isLoading } = useMessagingAccounts()
  const connect = useConnectAccount()

  return (
    <section className="atoll-cockpit__card">
      <h2 className="atoll-cockpit__card-title">Verbundene Konten</h2>
      <p className="atoll-cockpit__card-sub">
        E-Mail, WhatsApp und LinkedIn für die Kombox verbinden.
      </p>

      <div style={{ display: 'flex', gap: 'var(--space-2)', flexWrap: 'wrap', marginBottom: 'var(--space-3)' }}>
        {CHANNELS.map(c => (
          <button
            key={c.key}
            type="button"
            className="atoll-btn atoll-btn--primary"
            disabled={connect.isPending}
            onClick={() => connect.mutate(c.key)}
          >
            <Icon name={c.icon} size={14} /> {c.label} verbinden
          </button>
        ))}
      </div>

      {connect.error && (
        <p className="caption" style={{ color: 'var(--brand-red)' }}>
          Verbindung fehlgeschlagen — bitte erneut versuchen.
        </p>
      )}

      {isLoading ? (
        <p className="caption">Lädt…</p>
      ) : accounts.length === 0 ? (
        <p className="caption">Noch keine Konten verbunden.</p>
      ) : (
        <ul style={{ listStyle: 'none', padding: 0, margin: 0, display: 'flex', flexDirection: 'column', gap: 'var(--space-2)' }}>
          {accounts.map(a => (
            <li key={a.id} style={{ display: 'flex', alignItems: 'center', gap: 'var(--space-2)' }}>
              <Icon name={iconForChannel(a.channel)} size={16} />
              <span>{a.label}</span>
              <span className="caption-2">
                {a.status === 'connected' ? '· verbunden' : a.status === 'error' ? '· Fehler' : '· getrennt'}
              </span>
            </li>
          ))}
        </ul>
      )}
    </section>
  )
}
