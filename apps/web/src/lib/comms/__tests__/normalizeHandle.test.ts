import { describe, it, expect } from 'vitest'
import { normalizeHandle } from '../normalizeHandle'

describe('normalizeHandle', () => {
  it('WhatsApp: Nummer ohne Plus → E.164', () => {
    expect(normalizeHandle('whatsapp', '41791234567')).toBe('+41791234567')
  })
  it('WhatsApp: Nummer mit Plus bleibt E.164', () => {
    expect(normalizeHandle('whatsapp', '+41 79 123 45 67')).toBe('+41791234567')
  })
  it('WhatsApp: ungültige Nummer → null', () => {
    expect(normalizeHandle('whatsapp', '123')).toBeNull()
  })
  it('E-Mail: trimmt und lowercased', () => {
    expect(normalizeHandle('email', '  Max@Example.COM ')).toBe('max@example.com')
  })
  it('E-Mail: ohne @ → null', () => {
    expect(normalizeHandle('email', 'kein-email')).toBeNull()
  })
  it('LinkedIn: trimmt Member-ID', () => {
    expect(normalizeHandle('linkedin', '  ACoAAB123  ')).toBe('ACoAAB123')
  })
  it('LinkedIn: leer → null', () => {
    expect(normalizeHandle('linkedin', '   ')).toBeNull()
  })
})
