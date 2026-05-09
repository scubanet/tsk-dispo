#!/usr/bin/env bash
# Generates every logo size the app needs from a single source PNG.
#
# Usage:
#   ./scripts/generate-logo-variants.sh apps/web/public/atoll-logo.png
#
# The source must be at least 1024×1024, transparent background.
# Variants written:
#   apps/web/public/atoll-logo.png      → kept as-is (the source)
#   apps/web/public/icon-192.png        → 192×192 (PWA)
#   apps/web/public/icon-512.png        → 512×512 (PWA)
#   apps/web/public/apple-touch-icon.png → 180×180 (iOS Home Screen)
#   apps/web/public/favicon-32.png       → 32×32  (browser tab)
#
# Note: favicon.ico is left untouched (multi-size .ico needs ImageMagick).
#       Generate via https://favicon.io/favicon-converter/ if you want to
#       refresh it.

set -euo pipefail

SRC="${1:-apps/web/public/atoll-logo.png}"
OUT_DIR="$(dirname "$SRC")"

if [[ ! -f "$SRC" ]]; then
  echo "❌ Source not found: $SRC"
  exit 1
fi

if ! command -v sips &> /dev/null; then
  echo "❌ 'sips' not found — this script needs macOS"
  exit 1
fi

# sips reads from a copy so we don't mutate the source
copy() {
  local size=$1
  local target=$2
  local tmp
  tmp=$(mktemp -t atoll-logo).png
  cp "$SRC" "$tmp"
  sips -Z "$size" "$tmp" --out "$target" > /dev/null
  rm -f "$tmp"
  echo "  ✓ ${target} (${size}×${size})"
}

echo "Source: $SRC"
echo "Generating variants…"
copy 192 "$OUT_DIR/icon-192.png"
copy 512 "$OUT_DIR/icon-512.png"
copy 180 "$OUT_DIR/apple-touch-icon.png"
copy 32  "$OUT_DIR/favicon-32.png"

echo
echo "✓ Done. Restart the dev server (Vite caches public/)."
echo "  Optional: regenerate favicon.ico via https://favicon.io"
