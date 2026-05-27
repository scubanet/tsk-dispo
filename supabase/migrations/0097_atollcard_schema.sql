-- 0097: AtollCard schema — digital business cards + lead capture.
--
-- AtollCard ist die zweite iOS-App im Atoll-OS-Ökosystem (nach AtollCal) und
-- braucht vier neue Tabellen:
--
--   • cards            — eine Visitenkarte (Persona) pro Zeile, FK auf contacts
--   • card_scans       — jeder Resolve-Event der Public-Page
--   • card_leads       — Lead-Capture aus dem Public-Formular
--   • nfc_tags         — physische NFC-Tags die mit einer Card-URL beschrieben sind
--
-- Owner-Modell:
--   `cards.person_id` referenziert `public.contacts.id`. RLS prüft via
--   `contact_instructor` Sidecar, dass auth.uid() zum Owner-Contact gehört.
--   Scans, Leads und NFC-Tags hängen über `card_id` an einer Card —
--   ihre RLS leitet sich vom Card-Owner ab.

-- ─────────────────────────── ENUMs ───────────────────────────

CREATE TYPE card_theme_preset AS ENUM (
  'courseDirector', 'seaExplorers', 'privat', 'custom'
);

CREATE TYPE card_instructor_level AS ENUM (
  'OWSI', 'MSDT', 'IDC Staff', 'MI', 'CD'
);

CREATE TYPE card_scan_source AS ENUM (
  'qr', 'nfc', 'airdrop', 'imessage', 'wallet', 'direct'
);

CREATE TYPE card_tapped_field AS ENUM (
  'email', 'phone', 'whatsapp', 'instagram', 'linkedin', 'website', 'leadForm'
);

CREATE TYPE card_lead_status AS ENUM (
  'new', 'opened', 'contacted', 'imported', 'archived', 'spam'
);

-- ─────────────────────────── cards ───────────────────────────

CREATE TABLE public.cards (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  person_id       UUID NOT NULL REFERENCES public.contacts(id) ON DELETE CASCADE,

  slug            TEXT NOT NULL UNIQUE
                    CHECK (slug ~ '^[a-z0-9][a-z0-9-]{0,62}[a-z0-9]?$'),
  title           TEXT NOT NULL,
  subtitle        TEXT,
  badge           TEXT,

  -- theme.preset is one of card_theme_preset; optional override hexes.
  theme           JSONB NOT NULL DEFAULT '{"preset":"courseDirector"}'::jsonb,

  -- dive_profile contains padi_member_number, instructor_level, specialties[],
  -- total_dives, since_year, teaching_languages[]. Optional — NULL = no
  -- dive profile shown on the card.
  dive_profile    JSONB,

  -- field_visibility — booleans for email/phone/whatsapp/instagram/linkedin/
  -- website/diveStats. Drives what the public page renders.
  field_visibility JSONB NOT NULL DEFAULT '{
    "email": true, "phone": true, "whatsapp": true,
    "instagram": false, "linkedin": false, "website": true,
    "diveStats": true
  }'::jsonb,

  is_default      BOOLEAN NOT NULL DEFAULT false,
  is_active       BOOLEAN NOT NULL DEFAULT true,

  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_cards_person       ON public.cards(person_id);
CREATE INDEX idx_cards_slug         ON public.cards(slug);
CREATE UNIQUE INDEX idx_cards_one_default_per_person
  ON public.cards(person_id) WHERE is_default;

COMMENT ON TABLE public.cards IS
  'Digital business cards. One person can own multiple cards (personas).';

-- ─────────────────────────── card_scans ───────────────────────────

CREATE TABLE public.card_scans (
  id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  card_id            UUID NOT NULL REFERENCES public.cards(id) ON DELETE CASCADE,
  scanned_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
  source             card_scan_source NOT NULL DEFAULT 'direct',
  ip_country         TEXT,                     -- ISO-3166-1 alpha-2 ("CH", "DE", …)
  user_agent         TEXT,
  converted_to_lead  BOOLEAN NOT NULL DEFAULT false,
  field_tapped       card_tapped_field
);

CREATE INDEX idx_card_scans_card_time   ON public.card_scans(card_id, scanned_at DESC);
CREATE INDEX idx_card_scans_time        ON public.card_scans(scanned_at DESC);

-- ─────────────────────────── card_leads ───────────────────────────

CREATE TABLE public.card_leads (
  id                       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  card_id                  UUID NOT NULL REFERENCES public.cards(id) ON DELETE CASCADE,

  first_name               TEXT NOT NULL,
  last_name                TEXT,
  email                    TEXT,
  phone                    TEXT,
  message                  TEXT,
  topic                    TEXT,           -- "IDC 2026 Anfrage", "Trial Dive"
  custom_answers           JSONB NOT NULL DEFAULT '{}'::jsonb,

  captured_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
  ip_country               TEXT,
  imported_to_address_book BOOLEAN NOT NULL DEFAULT false,
  status                   card_lead_status NOT NULL DEFAULT 'new',
  avatar_color             TEXT             -- hex like "#b8893a", optional
);

CREATE INDEX idx_card_leads_card_time   ON public.card_leads(card_id, captured_at DESC);
CREATE INDEX idx_card_leads_status      ON public.card_leads(status) WHERE status = 'new';

-- ─────────────────────────── nfc_tags ───────────────────────────

CREATE TABLE public.nfc_tags (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  card_id       UUID NOT NULL REFERENCES public.cards(id) ON DELETE CASCADE,
  tag_uid       TEXT NOT NULL UNIQUE,
  label         TEXT,
  written_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_seen_at  TIMESTAMPTZ
);

CREATE INDEX idx_nfc_tags_card ON public.nfc_tags(card_id);

-- ─────────────────────────── updated_at trigger ───────────────────────────

CREATE OR REPLACE FUNCTION public.set_cards_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

CREATE TRIGGER cards_updated_at
BEFORE UPDATE ON public.cards
FOR EACH ROW EXECUTE FUNCTION public.set_cards_updated_at();

-- ─────────────────────────── RLS ───────────────────────────
--
-- Strategy: a Card row belongs to the authenticated user iff the requesting
-- auth.uid() maps to the same contact via the contact_instructor sidecar
-- (`contact_instructor.contact_id = cards.person_id AND
--  contact_instructor.auth_user_id = auth.uid()`).
--
-- Public access for unauthenticated scanners is *not* via these tables —
-- the web app uses a server-side service-role token to render `/c/<slug>`,
-- so RLS here can be strict.

ALTER TABLE public.cards       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.card_scans  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.card_leads  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.nfc_tags    ENABLE ROW LEVEL SECURITY;

-- Helper: is this auth user the owner of the given person_id?
CREATE OR REPLACE FUNCTION public.is_card_owner(p_person_id UUID)
RETURNS BOOLEAN
LANGUAGE SQL
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.contact_instructor
    WHERE contact_id = p_person_id
      AND auth_user_id = auth.uid()
  );
$$;

GRANT EXECUTE ON FUNCTION public.is_card_owner(UUID) TO authenticated;

-- cards policies
CREATE POLICY cards_owner_select ON public.cards
  FOR SELECT TO authenticated
  USING (public.is_card_owner(person_id));

CREATE POLICY cards_owner_insert ON public.cards
  FOR INSERT TO authenticated
  WITH CHECK (public.is_card_owner(person_id));

CREATE POLICY cards_owner_update ON public.cards
  FOR UPDATE TO authenticated
  USING (public.is_card_owner(person_id))
  WITH CHECK (public.is_card_owner(person_id));

CREATE POLICY cards_owner_delete ON public.cards
  FOR DELETE TO authenticated
  USING (public.is_card_owner(person_id));

-- card_scans / card_leads / nfc_tags: owner via card_id
CREATE POLICY card_scans_owner ON public.card_scans
  FOR ALL TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.cards c
    WHERE c.id = card_scans.card_id AND public.is_card_owner(c.person_id)
  ))
  WITH CHECK (EXISTS (
    SELECT 1 FROM public.cards c
    WHERE c.id = card_scans.card_id AND public.is_card_owner(c.person_id)
  ));

CREATE POLICY card_leads_owner ON public.card_leads
  FOR ALL TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.cards c
    WHERE c.id = card_leads.card_id AND public.is_card_owner(c.person_id)
  ))
  WITH CHECK (EXISTS (
    SELECT 1 FROM public.cards c
    WHERE c.id = card_leads.card_id AND public.is_card_owner(c.person_id)
  ));

CREATE POLICY nfc_tags_owner ON public.nfc_tags
  FOR ALL TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.cards c
    WHERE c.id = nfc_tags.card_id AND public.is_card_owner(c.person_id)
  ))
  WITH CHECK (EXISTS (
    SELECT 1 FROM public.cards c
    WHERE c.id = nfc_tags.card_id AND public.is_card_owner(c.person_id)
  ));
