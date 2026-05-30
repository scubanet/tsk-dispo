import { describe, it, expect } from 'vitest'
import { normalizeInboundEvent } from '../normalizeInboundEvent'

const linkedinMsg = {
  account_id: 'acc1', account_type: 'LINKEDIN',
  account_info: { type: 'LINKEDIN', user_id: 'SELF_ID' },
  event: 'message_received', chat_id: 'chatA', timestamp: '2026-05-29T10:00:00.000Z',
  message_id: 'msg1', message: 'Hallo Dominik',
  sender: { attendee_provider_id: 'OTHER_ID', attendee_name: 'Sophie' },
  attendees: [{ attendee_provider_id: 'OTHER_ID' }, { attendee_provider_id: 'SELF_ID' }],
  attachments: [],
}
const emailIn = {
  email_id: 'mail1', account_id: 'acc2', event: 'mail_received',
  date: '2026-05-29T09:00:00.000Z',
  from_attendee: { identifier: 'Marco@Example.MT', identifier_type: 'EMAIL_ADDRESS' },
  to_attendees: [{ identifier: 'dominik@weckherlin.com' }],
  subject: 'Specialty Termine', body: '<p>Hi</p>', body_plain: 'Hi', has_attachments: false, message_id: '<x@y>',
}

describe('normalizeInboundEvent', () => {
  it('LinkedIn inbound', () => {
    const r = normalizeInboundEvent(linkedinMsg)
    expect(r).toMatchObject({ channel: 'linkedin', direction: 'inbound', external_id: 'msg1',
      counterparty_handle: 'OTHER_ID', summary: 'Hallo Dominik', thread_id: 'chatA' })
  })
  it('Messaging outbound erkennt eigenen Versand', () => {
    const r = normalizeInboundEvent({ ...linkedinMsg, message_id: 'msg2',
      sender: { attendee_provider_id: 'SELF_ID' } })
    expect(r).toMatchObject({ direction: 'outbound', counterparty_handle: 'OTHER_ID' })
  })
  it('E-Mail inbound matcht auf Absender (lowercased)', () => {
    const r = normalizeInboundEvent(emailIn)
    expect(r).toMatchObject({ channel: 'email', direction: 'inbound', external_id: 'mail1',
      counterparty_handle: 'marco@example.mt', summary: 'Specialty Termine', body: 'Hi' })
  })
  it('E-Mail outbound nimmt Empfänger als Gegenpart', () => {
    const r = normalizeInboundEvent({ ...emailIn, email_id: 'mail2', event: 'mail_sent' })
    expect(r).toMatchObject({ direction: 'outbound', counterparty_handle: 'dominik@weckherlin.com' })
  })
  it('Nicht-Nachrichten-Events → null', () => {
    expect(normalizeInboundEvent({ ...linkedinMsg, event: 'message_read' })).toBeNull()
    expect(normalizeInboundEvent({ email_id: 'x', account_id: 'a', event: 'mail_moved' })).toBeNull()
  })
  it('Unbekannter Kanal → null', () => {
    expect(normalizeInboundEvent({ ...linkedinMsg, account_type: 'TELEGRAM' })).toBeNull()
  })
})
