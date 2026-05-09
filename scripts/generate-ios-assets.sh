#!/usr/bin/env bash
# Generates every iOS asset the app needs from a single source PNG.
#
# Usage:
#   ./scripts/generate-ios-assets.sh apps/web/public/atoll-logo.png
#
# The source must be at least 1024×1024, transparent background.
#
# Writes:
#   apps/ios-native/ATOLL/Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png
#   apps/ios-native/ATOLL/Resources/Assets.xcassets/AtollLogo.imageset/atoll-logo.png       (1×, 256)
#   apps/ios-native/ATOLL/Resources/Assets.xcassets/AtollLogo.imageset/atoll-logo@2x.png    (2×, 512)
#   apps/ios-native/ATOLL/Resources/Assets.xcassets/AtollLogo.imageset/atoll-logo@3x.png    (3×, 768)
#
# Important: iOS App Icons MUST NOT have transparency. The script flattens the
# AppIcon onto a white background. The Logo asset stays transparent.

set -euo pipefail

SRC="${1:-apps/web/public/atoll-logo.png}"
IOS_ROOT="apps/ios-native/ATOLL/Resources/Assets.xcassets"
APP_ICON_DIR="$IOS_ROOT/AppIcon.appiconset"
LOGO_DIR="$IOS_ROOT/AtollLogo.imageset"

if [[ ! -f "$SRC" ]]; then
  echo "❌ Source not found: $SRC"
  exit 1
fi

if ! command -v sips &> /dev/null; then
  echo "❌ 'sips' not found — this script needs macOS"
  exit 1
fi

mkdir -p "$LOGO_DIR"

resize() {
  local size=$1
  local target=$2
  local tmp
  tmp=$(mktemp -t atoll-asset).png
  cp "$SRC" "$tmp"
  sips -Z "$size" "$tmp" --out "$target" > /dev/null
  rm -f "$tmp"
  echo "  ✓ ${target} (${size}×${size})"
}

# AppIcon needs solid background — flatten transparency onto brand-deep blue.
flatten_app_icon() {
  local size=$1
  local target=$2
  local tmp
  tmp=$(mktemp -t atoll-icon).png
  cp "$SRC" "$tmp"
  sips -Z "$size" "$tmp" --padToHeightWidth "$size" "$size" \
    --padColor 042C53 --out "$target" > /dev/null
  rm -f "$tmp"
  echo "  ✓ ${target} (${size}×${size}, deep-blue bg)"
}

echo "Source: $SRC"
echo "Generating iOS App Icon (flat, solid bg — Apple requires no alpha)…"
flatten_app_icon 1024 "$APP_ICON_DIR/icon-1024.png"

# Legacy second AppIcon set (some projects have two)
LEGACY_APPICON="apps/ios-native/ATOLL/Assets.xcassets/AppIcon.appiconset"
if [[ -d "$LEGACY_APPICON" ]]; then
  flatten_app_icon 1024 "$LEGACY_APPICON/atoll-app-icon-1024.png"
fi

echo "Generating Logo asset (transparent, three scales)…"
resize 256 "$LOGO_DIR/atoll-logo.png"
resize 512 "$LOGO_DIR/atoll-logo@2x.png"
resize 768 "$LOGO_DIR/atoll-logo@3x.png"

echo
echo "✓ Done. Open Xcode → Clean Build (⇧⌘K) → Build (⌘B)"
echo "  AppIcon and Logo assets refresh on next launch."
