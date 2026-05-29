-- 0119_messaging_accounts.sql
-- ─────────────────────────────────────────────────────────────────
-- Comms-Integration: verbundene Messaging-Konten (E-Mail/WhatsApp/LinkedIn)
-- über Unipile. Speichert NUR die unipile_account_id — niemals OAuth-Tokens.
-- Spec: docs/superpowers/specs/2026-05-29-comms-integration-unipile-design.md §4.4, §5
-- ─────────────────────────────────────────────────────────────────

CREATE TABLE public.messaging_accounts (
  id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  channel            TEXT NOT NULL CHECK (channel IN ('email', 'whatsapp', 'linkedin')),
  unipile_account_id TEXT NOT NULL,
  provider           TEXT,                       -- gmail | outlook | imap | cloud_api | linkedin
  label              TEXT NOT NULL,
  owner_user_id      UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  status             TEXT NOT NULL DEFAULT 'connected'
    CHECK (status IN ('connected', 'disconnected', 'error')),
  connected_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_event_at      TIMESTAMPTZ
);

CREATE UNIQUE INDEX uq_messaging_accounts_unipile
  ON public.messaging_accounts(unipile_account_id);

CREATE INDEX idx_messaging_accounts_owner
  ON public.messaging_accounts(owner_user_id);

ALTER TABLE public.messaging_accounts ENABLE ROW LEVEL SECURITY;

-- Nutzer sehen/verwalten nur eigene Verbindungen. Inserts/Writes der
-- Edge Functions laufen über die Service-Rolle (umgeht RLS).
CREATE POLICY messaging_accounts_owner ON public.messaging_accounts
  FOR ALL TO authenticated
  USING (owner_user_id = auth.uid())
  WITH CHECK (owner_user_id = auth.uid());
