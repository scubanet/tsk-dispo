-- 0079: Contacts unified CRM schema (Part 1 — enums + main table)

CREATE TYPE contact_kind AS ENUM ('person', 'organization');

CREATE TYPE relationship_kind AS ENUM (
  'works_at', 'owns', 'spouse_of', 'child_of', 'parent_of',
  'referred_by', 'subsidiary_of', 'partner_of', 'supplier_of',
  'student_of', 'mentor_of'
);

CREATE TABLE public.contacts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  kind contact_kind NOT NULL,

  -- Person fields
  first_name TEXT,
  last_name TEXT,
  birth_date DATE,
  gender TEXT,

  -- Org fields
  legal_name TEXT,
  trading_name TEXT,

  -- Generated display name
  display_name TEXT GENERATED ALWAYS AS (
    CASE
      WHEN kind = 'organization' THEN COALESCE(trading_name, legal_name)
      ELSE last_name || ', ' || first_name
    END
  ) STORED,

  primary_email TEXT,
  emails JSONB NOT NULL DEFAULT '[]',
  phones JSONB NOT NULL DEFAULT '[]',
  addresses JSONB NOT NULL DEFAULT '[]',

  languages TEXT[] NOT NULL DEFAULT '{}',
  roles TEXT[] NOT NULL DEFAULT '{}',
  tags TEXT[] NOT NULL DEFAULT '{}',

  notes TEXT,
  owner_id UUID REFERENCES public.contacts(id) ON DELETE SET NULL,

  consent_marketing BOOLEAN NOT NULL DEFAULT false,
  consent_marketing_at TIMESTAMPTZ,
  consent_marketing_source TEXT,

  source TEXT,

  archived_at TIMESTAMPTZ,
  merged_into_id UUID REFERENCES public.contacts(id) ON DELETE SET NULL,

  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID,

  CONSTRAINT contacts_person_fields_check CHECK (
    kind = 'organization'
    OR (first_name IS NOT NULL AND last_name IS NOT NULL)
  ),
  CONSTRAINT contacts_org_fields_check CHECK (
    kind = 'person' OR legal_name IS NOT NULL
  ),
  CONSTRAINT contacts_no_self_merge CHECK (id <> merged_into_id)
);

CREATE INDEX idx_contacts_kind     ON public.contacts(kind);
CREATE INDEX idx_contacts_owner    ON public.contacts(owner_id);
CREATE INDEX idx_contacts_roles    ON public.contacts USING GIN(roles);
CREATE INDEX idx_contacts_tags     ON public.contacts USING GIN(tags);
CREATE INDEX idx_contacts_archived ON public.contacts(archived_at)
  WHERE archived_at IS NULL;
CREATE INDEX idx_contacts_search   ON public.contacts USING GIN(
  to_tsvector('simple',
    COALESCE(first_name,'') || ' ' ||
    COALESCE(last_name,'')  || ' ' ||
    COALESCE(legal_name,'') || ' ' ||
    COALESCE(trading_name,'') || ' ' ||
    COALESCE(primary_email,'') || ' ' ||
    COALESCE(notes,'')
  )
);

COMMENT ON TABLE public.contacts IS
  'Unified CRM contacts table. Replaces instructors, people, organizations.';
