import { assertEquals } from 'jsr:@std/assert@1'
import {
  BlobReader, BlobWriter, ZipReader, Uint8ArrayReader,
} from 'jsr:@zip-js/zip-js@2.7'
import { buildZip } from '../zip.ts'

Deno.test('buildZip: roundtrip — files in, same files out', async () => {
  const files = {
    'pass.json':       new TextEncoder().encode('{"a":1}'),
    'manifest.json':   new TextEncoder().encode('{"pass.json":"abc"}'),
    'icon.png':        new Uint8Array([1, 2, 3]),
  }
  const zipBytes = await buildZip(files)

  // Validate zip is readable + same entries
  const reader = new ZipReader(new BlobReader(new Blob([zipBytes])))
  const entries = await reader.getEntries()
  await reader.close()

  const names = entries.map(e => e.filename).sort()
  assertEquals(names, ['icon.png', 'manifest.json', 'pass.json'])
})
