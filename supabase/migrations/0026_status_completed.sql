-- Add 'completed' status to course_status enum.
--
-- NOTE: Postgres does not allow ALTER TYPE ADD VALUE inside a transaction
-- block in some configurations. If `supabase db push` fails on this migration
-- with the error "ALTER TYPE ... ADD cannot run inside a transaction block",
-- run this SQL line **manually** in the Supabase SQL Editor (which uses
-- autocommit), then re-run `supabase db push --include-all`.
ALTER TYPE course_status ADD VALUE IF NOT EXISTS 'completed';
