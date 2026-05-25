/**
 * Loads the 6 static PNG assets from the assets/ folder.
 * Reads them once at module-load time and caches in a closure variable
 * so per-request handling is just a dict-lookup.
 */

const ASSET_NAMES = [
  'icon.png', 'icon@2x.png', 'icon@3x.png',
  'logo.png', 'logo@2x.png', 'logo@3x.png',
] as const

let cachedAssets: Record<string, Uint8Array> | null = null

export async function loadAssets(): Promise<Record<string, Uint8Array>> {
  if (cachedAssets) return cachedAssets

  const out: Record<string, Uint8Array> = {}
  for (const name of ASSET_NAMES) {
    const url = new URL(`./assets/${name}`, import.meta.url)
    out[name] = await Deno.readFile(url)
  }
  cachedAssets = out
  return out
}
