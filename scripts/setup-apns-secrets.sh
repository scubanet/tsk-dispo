#!/usr/bin/env bash
#
# Setzt die APNs-Secrets für die Supabase Edge Function.
# Nicht in Git committen — die .p8 ist sensitive.
#
# Usage: ./scripts/setup-apns-secrets.sh
#
# Voraussetzung: supabase CLI installiert und im richtigen Projekt verlinkt
#   brew install supabase/tap/supabase
#   supabase link --project-ref axnrilhdokkfujzjifhj

set -euo pipefail

P8_PATH="apps/Apple/AuthKey_43R2JT8J22.p8"
KEY_ID="43R2JT8J22"
TEAM_ID="XK8VBSPJQH"
BUNDLE_ID="swiss.atoll.app"

if [[ ! -f "$P8_PATH" ]]; then
  echo "❌ .p8 nicht gefunden bei: $P8_PATH"
  echo "   Lege sie dort ab oder passe das Skript an."
  exit 1
fi

echo "→ Setze APNS_AUTH_KEY (PEM-Inhalt der .p8)…"
supabase secrets set APNS_AUTH_KEY="$(cat "$P8_PATH")"

echo "→ Setze APNS_KEY_ID = $KEY_ID"
supabase secrets set APNS_KEY_ID="$KEY_ID"

echo "→ Setze APNS_TEAM_ID = $TEAM_ID"
supabase secrets set APNS_TEAM_ID="$TEAM_ID"

echo "→ Setze APNS_BUNDLE_ID = $BUNDLE_ID"
supabase secrets set APNS_BUNDLE_ID="$BUNDLE_ID"

echo "→ Setze APNS_ENVIRONMENT = sandbox (für Xcode-Builds)"
echo "   später auf 'production' umstellen für TestFlight/App Store:"
echo "   supabase secrets set APNS_ENVIRONMENT=production"
supabase secrets set APNS_ENVIRONMENT=sandbox

echo ""
echo "✓ Alle Secrets gesetzt. Liste anzeigen:"
supabase secrets list
echo ""
echo "Nächster Schritt: Edge Function deployen"
echo "   supabase functions deploy send-assignment-notification"
