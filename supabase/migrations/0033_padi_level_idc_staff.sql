-- Add 'IDC Staff' to padi_level enum, between MSDT and MI in seniority order.
-- NOTE: ALTER TYPE ADD VALUE cannot run inside a transaction in older Postgres.
-- If db push fails, run manually in SQL Editor and `supabase migration repair --status applied 0033`.

ALTER TYPE padi_level ADD VALUE IF NOT EXISTS 'IDC Staff';
