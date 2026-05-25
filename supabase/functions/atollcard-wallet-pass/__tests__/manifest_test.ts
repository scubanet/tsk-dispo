import { assertEquals } from 'jsr:@std/assert@1'
import { buildManifest } from '../manifest.ts'

Deno.test('buildManifest: SHA-1 hashes of file contents', async () => {
  const files = {
    'pass.json':       new TextEncoder().encode('{"hello":"world"}'),
    'icon.png':        new Uint8Array([137, 80, 78, 71]),  // PNG magic
  }
  const m = await buildManifest(files)
  // SHA-1 of '{"hello":"world"}' = 2248ee2fa0aaaad99178531f924bf00b4b0a8f4e
  assertEquals(m['pass.json'], '2248ee2fa0aaaad99178531f924bf00b4b0a8f4e')
  // SHA-1 of [137,80,78,71] = 4effda12c2611e2e4feb6f0d342feb685ccd825b
  assertEquals(m['icon.png'],  '4effda12c2611e2e4feb6f0d342feb685ccd825b')
})

Deno.test('buildManifest: empty input returns empty object', async () => {
  const m = await buildManifest({})
  assertEquals(Object.keys(m).length, 0)
})
