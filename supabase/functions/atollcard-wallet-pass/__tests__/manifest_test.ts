import { assertEquals } from 'jsr:@std/assert@1'
import { buildManifest } from '../manifest.ts'

Deno.test('buildManifest: SHA-1 hashes of file contents', async () => {
  const files = {
    'pass.json':       new TextEncoder().encode('{"hello":"world"}'),
    'icon.png':        new Uint8Array([137, 80, 78, 71]),  // PNG magic
  }
  const m = await buildManifest(files)
  // SHA-1 of '{"hello":"world"}' = a45cc7ed85bd62f37b50a6cd1ce32edd5ac21a9c
  assertEquals(m['pass.json'], 'a45cc7ed85bd62f37b50a6cd1ce32edd5ac21a9c')
  // SHA-1 of [137,80,78,71] = a839ada4cb6bd0fa78b78a48e9bcf6cf8a4dc9bb
  assertEquals(m['icon.png'],  'a839ada4cb6bd0fa78b78a48e9bcf6cf8a4dc9bb')
})

Deno.test('buildManifest: empty input returns empty object', async () => {
  const m = await buildManifest({})
  assertEquals(Object.keys(m).length, 0)
})
