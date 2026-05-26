#!/usr/bin/env bash
# Integration smoke for atollcard-wallet-pass.
#
# Requires:
#   - All 5 WALLET_* secrets exported in env
#   - SUPABASE_URL + SUPABASE_ANON_KEY exported
#   - A real card_id (from your test data) in CARD_ID env
#   - A valid JWT in JWT env (copy from browser DevTools after login)
#
# Usage:
#   export CARD_ID=<uuid> JWT=<jwt>
#   bash __tests__/smoke.sh

set -euo pipefail

: "${CARD_ID:?CARD_ID env var required}"
: "${JWT:?JWT env var required}"
: "${SUPABASE_URL:?SUPABASE_URL env var required}"

out=$(mktemp -t pkpass.XXXXXX).pkpass

echo "→ POST to ${SUPABASE_URL}/functions/v1/atollcard-wallet-pass"
curl -sS -X POST "${SUPABASE_URL}/functions/v1/atollcard-wallet-pass" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${JWT}" \
  -d "{\"card_id\":\"${CARD_ID}\"}" \
  -o "${out}"

size=$(wc -c < "${out}")
echo "→ Received ${size} bytes → ${out}"
[ "${size}" -gt 1000 ] || { echo "✗ pass too small, probably an error response:"; cat "${out}"; exit 1; }

echo "→ Inspecting zip contents:"
unzip -l "${out}" | grep -E "(pass\.json|manifest\.json|signature|icon|logo)"

echo "→ Extracting + verifying signature"
work=$(mktemp -d)
unzip -q -o "${out}" -d "${work}"

if [ ! -f "${work}/pass.json" ]; then echo "✗ no pass.json in zip"; exit 1; fi
if [ ! -f "${work}/manifest.json" ]; then echo "✗ no manifest.json in zip"; exit 1; fi
if [ ! -f "${work}/signature" ]; then echo "✗ no signature in zip"; exit 1; fi

# OpenSSL signature verification (noverify = skip chain validation, just check signature math)
openssl smime -verify \
  -in "${work}/signature" \
  -content "${work}/manifest.json" \
  -inform DER \
  -noverify \
  > /dev/null

echo "✓ Signature verification: SUCCESS"
echo "✓ pass.json preview:"
cat "${work}/pass.json" | head -30
echo
echo "✓ Smoke passed. Pass file: ${out}"
