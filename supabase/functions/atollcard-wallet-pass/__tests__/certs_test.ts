import { assertEquals, assertThrows } from 'jsr:@std/assert@1'
import { base64ToBytes } from '../certs.ts'

Deno.test('base64ToBytes: roundtrips simple ASCII', () => {
  const enc = btoa('hello world')
  const bytes = base64ToBytes(enc)
  assertEquals(new TextDecoder().decode(bytes), 'hello world')
})

Deno.test('base64ToBytes: throws on garbage', () => {
  assertThrows(() => base64ToBytes('!!!not-base64!!!'))
})
