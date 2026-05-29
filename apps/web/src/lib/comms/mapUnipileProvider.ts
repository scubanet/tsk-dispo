// apps/web/src/lib/comms/mapUnipileProvider.ts
// Übersetzt zwischen Unipile-Account-Typen und unseren CommsChannel/provider.
// Spec: docs/superpowers/specs/2026-05-29-comms-integration-unipile-design.md §4.4
import type { CommsChannel } from '@/types/messaging'

export interface ChannelProvider {
  channel: CommsChannel
  provider: string
}

const MAP: Record<string, ChannelProvider> = {
  GOOGLE:   { channel: 'email',    provider: 'gmail' },
  OUTLOOK:  { channel: 'email',    provider: 'outlook' },
  MAIL:     { channel: 'email',    provider: 'imap' },
  WHATSAPP: { channel: 'whatsapp', provider: 'whatsapp' },
  LINKEDIN: { channel: 'linkedin', provider: 'linkedin' },
}

export function mapUnipileProvider(unipileType: string): ChannelProvider | null {
  return MAP[unipileType.toUpperCase()] ?? null
}

export function providersForChannel(channel: CommsChannel): string[] {
  if (channel === 'email') return ['GOOGLE', 'OUTLOOK', 'MAIL']
  if (channel === 'whatsapp') return ['WHATSAPP']
  return ['LINKEDIN']
}
