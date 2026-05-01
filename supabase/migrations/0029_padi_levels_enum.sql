-- Add new PADI level values to the enum.
-- NOTE: ALTER TYPE ADD VALUE cannot run inside a transaction in older Postgres.
-- If `supabase db push` fails on this migration with the error
-- "ALTER TYPE ... ADD cannot run inside a transaction block", run these
-- statements manually in the Supabase SQL Editor (autocommit), then run:
--   supabase migration repair --status applied 0029
--   supabase db push

ALTER TYPE padi_level ADD VALUE IF NOT EXISTS 'AI';
ALTER TYPE padi_level ADD VALUE IF NOT EXISTS 'OWSI';
ALTER TYPE padi_level ADD VALUE IF NOT EXISTS 'MSDT';
ALTER TYPE padi_level ADD VALUE IF NOT EXISTS 'MI';
ALTER TYPE padi_level ADD VALUE IF NOT EXISTS 'CD';
ALTER TYPE padi_level ADD VALUE IF NOT EXISTS 'Andere';
