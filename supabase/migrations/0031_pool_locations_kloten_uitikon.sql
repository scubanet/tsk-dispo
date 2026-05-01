-- Add Kloten and Uitikon to pool_location enum.
-- NOTE: ALTER TYPE ADD VALUE cannot run inside a transaction in older Postgres.
-- If `supabase db push` fails on this migration, run manually in SQL Editor:

ALTER TYPE pool_location ADD VALUE IF NOT EXISTS 'kloten';
ALTER TYPE pool_location ADD VALUE IF NOT EXISTS 'uitikon';
