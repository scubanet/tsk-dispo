#!/bin/bash
set -e
DB_URL="${SUPABASE_DB_URL:-postgresql://postgres:postgres@127.0.0.1:54322/postgres}"

# Ensure pgtap extension exists
psql "$DB_URL" --quiet -c "CREATE EXTENSION IF NOT EXISTS pgtap;"

for f in "$(dirname "$0")"/*.sql; do
  echo "== $(basename "$f") =="
  psql "$DB_URL" --quiet -f "$f"
done
