import { describe, it, expect } from 'vitest'
import { toUnipileRecipient } from '../toUnipileRecipient'

describe('toUnipileRecipient', () => {
  it('email → identifier', () => {
    expect(toUnipileRecipient('email', { email: 'a@b.com' })).toEqual({ kind: 'email', identifier: 'a@b.com' })
  })
  it('whatsapp → <e164 ohne +>@s.whatsapp.net', () => {
    expect(toUnipileRecipient('whatsapp', { e164: '+41791234567' }))
      .toEqual({ kind: 'attendee', identifier: '41791234567@s.whatsapp.net' })
  })
  it('whatsapp → strippt Leerzeichen & Sonderzeichen aus e164', () => {
    expect(toUnipileRecipient('whatsapp', { e164: '+41 79 877 80 80' }))
      .toEqual({ kind: 'attendee', identifier: '41798778080@s.whatsapp.net' })
  })
  it('linkedin → member_id', () => {
    expect(toUnipileRecipient('linkedin', { linkedin_member_id: 'ACoAAB' }))
      .toEqual({ kind: 'attendee', identifier: 'ACoAAB' })
  })
  it('fehlender Handle → null', () => {
    expect(toUnipileRecipient('email', {})).toBeNull()
    expect(toUnipileRecipient('whatsapp', {})).toBeNull()
    expect(toUnipileRecipient('linkedin', {})).toBeNull()
  })
})
