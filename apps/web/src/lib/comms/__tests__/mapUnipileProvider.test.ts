import { describe, it, expect } from 'vitest'
import { mapUnipileProvider, providersForChannel } from '../mapUnipileProvider'

describe('mapUnipileProvider', () => {
  it('GOOGLE → email/gmail', () => {
    expect(mapUnipileProvider('GOOGLE')).toEqual({ channel: 'email', provider: 'gmail' })
  })
  it('OUTLOOK → email/outlook', () => {
    expect(mapUnipileProvider('OUTLOOK')).toEqual({ channel: 'email', provider: 'outlook' })
  })
  it('MAIL → email/imap', () => {
    expect(mapUnipileProvider('MAIL')).toEqual({ channel: 'email', provider: 'imap' })
  })
  it('WHATSAPP → whatsapp', () => {
    expect(mapUnipileProvider('WHATSAPP')).toEqual({ channel: 'whatsapp', provider: 'whatsapp' })
  })
  it('LINKEDIN → linkedin', () => {
    expect(mapUnipileProvider('LINKEDIN')).toEqual({ channel: 'linkedin', provider: 'linkedin' })
  })
  it('Unbekannt → null', () => {
    expect(mapUnipileProvider('TELEGRAM')).toBeNull()
  })
})

describe('providersForChannel', () => {
  it('email → Google/Outlook/IMAP', () => {
    expect(providersForChannel('email')).toEqual(['GOOGLE', 'OUTLOOK', 'MAIL'])
  })
  it('whatsapp → WHATSAPP', () => {
    expect(providersForChannel('whatsapp')).toEqual(['WHATSAPP'])
  })
  it('linkedin → LINKEDIN', () => {
    expect(providersForChannel('linkedin')).toEqual(['LINKEDIN'])
  })
})
