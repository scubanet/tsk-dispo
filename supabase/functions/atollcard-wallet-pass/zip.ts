/**
 * Builds a .pkpass zip bundle from a map of filename → bytes.
 * Uses zip-js, returns the zip as Uint8Array ready to send in the response.
 */
import {
  ZipWriter, Uint8ArrayWriter, Uint8ArrayReader,
} from '@zip-js/zip-js'

export async function buildZip(
  files: Record<string, Uint8Array>,
): Promise<Uint8Array> {
  const writer = new ZipWriter(new Uint8ArrayWriter())
  for (const [name, bytes] of Object.entries(files)) {
    await writer.add(name, new Uint8ArrayReader(bytes))
  }
  return await writer.close()
}
