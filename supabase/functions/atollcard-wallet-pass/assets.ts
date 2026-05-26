/**
 * Loads the 6 static PNG assets as Uint8Arrays.
 *
 * Source: base64 strings embedded in assets-data.ts (auto-generated from
 * the assets/ folder by scripts/gen-assets-data.sh).
 *
 * Why not Deno.readFile from the assets/ folder?
 *   Supabase Edge Functions only bundle files referenced by static `import`
 *   statements. Sibling directories accessed via `Deno.readFile(new URL(...))`
 *   work LOCALLY but the assets aren't deployed — runtime returns
 *   `NotFound: path not found ... assets/icon.png`. Embedding the bytes as
 *   base64 in a .ts module forces the bundler to include them.
 */
import { ASSET_BASE64 } from './assets-data.ts'

const ASSET_NAMES = [
  'icon.png', 'icon@2x.png', 'icon@3x.png',
  'logo.png', 'logo@2x.png', 'logo@3x.png',
] as const

function decodeBase64(b64: string): Uint8Array {
  const bin = atob(b64)
  const out = new Uint8Array(bin.length)
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i)
  return out
}

let cachedAssets: Record<string, Uint8Array> | null = null

export async function loadAssets(): Promise<Record<string, Uint8Array>> {
  if (cachedAssets) return cachedAssets

  const out: Record<string, Uint8Array> = {}
  for (const name of ASSET_NAMES) {
    const b64 = ASSET_BASE64[name]
    if (!b64) throw new Error(`Missing embedded asset: ${name}`)
    out[name] = decodeBase64(b64)
  }
  cachedAssets = out
  return out
}
