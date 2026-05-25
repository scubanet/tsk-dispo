/**
 * Apple Wallet manifest.json builder: SHA-1 hex digest of each file in
 * the pass bundle. The manifest itself is what gets PKCS#7-signed.
 */

export interface ManifestMap { [filename: string]: string }

async function sha1Hex(bytes: Uint8Array): Promise<string> {
  const hash = await crypto.subtle.digest('SHA-1', bytes)
  return Array.from(new Uint8Array(hash))
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('')
}

export async function buildManifest(
  files: Record<string, Uint8Array>,
): Promise<ManifestMap> {
  const out: ManifestMap = {}
  for (const [name, bytes] of Object.entries(files)) {
    out[name] = await sha1Hex(bytes)
  }
  return out
}
